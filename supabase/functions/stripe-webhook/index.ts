// supabase/functions/stripe-webhook/index.ts
// Supabase Edge Function to handle Stripe webhook events
//
// Required environment variables (set via `supabase secrets set`):
// - STRIPE_SECRET_KEY: Stripe secret key
// - STRIPE_WEBHOOK_SECRET: Webhook signing secret from Stripe Dashboard
//
// Configure this endpoint in Stripe Dashboard:
// Webhook URL: https://<project-ref>.supabase.co/functions/v1/stripe-webhook
// Events to listen for:
// - checkout.session.completed
// - customer.subscription.updated
// - customer.subscription.deleted
// - invoice.paid (optional)
//
// Referral Program:
// - When a referred user subscribes to Pro within 90 days of signup,
//   the referrer gets 1 free month of Pro
// - Max 6 free months per referrer per calendar year
// - Anti-gaming: same stripe_customer_id = no reward

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
import Stripe from 'https://esm.sh/stripe@14.5.0?target=deno'

// CORS headers (webhooks from Stripe don't need CORS, but included for completeness)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
}

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight (shouldn't happen for webhooks, but just in case)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    // Get environment variables
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
    const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')

    if (!stripeSecretKey || !webhookSecret) {
      console.error('Stripe environment variables not configured')
      return new Response('Server configuration error', { status: 500 })
    }

    // Initialize Stripe
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16',
      httpClient: Stripe.createFetchHttpClient(),
    })

    // Initialize Supabase client with service role for admin operations
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Get the signature header
    const signature = req.headers.get('stripe-signature')
    if (!signature) {
      console.error('Missing stripe-signature header')
      return new Response('Missing signature', { status: 400 })
    }

    // Get the raw body for signature verification
    const body = await req.text()

    // Verify the webhook signature
    let event: Stripe.Event
    try {
      event = await stripe.webhooks.constructEventAsync(
        body,
        signature,
        webhookSecret
      )
    } catch (err) {
      console.error('Webhook signature verification failed:', err)
      return new Response('Invalid signature', { status: 400 })
    }

    console.log('Received webhook event:', event.type, 'ID:', event.id)

    // Handle different event types
    switch (event.type) {
      case 'checkout.session.completed': {
        await handleCheckoutCompleted(stripe, supabaseClient, event.data.object as Stripe.Checkout.Session)
        break
      }

      case 'customer.subscription.updated': {
        await handleSubscriptionUpdated(supabaseClient, event.data.object as Stripe.Subscription)
        break
      }

      case 'customer.subscription.deleted': {
        await handleSubscriptionDeleted(supabaseClient, event.data.object as Stripe.Subscription)
        break
      }

      case 'invoice.paid': {
        // Optional: Log successful invoice payments
        const invoice = event.data.object as Stripe.Invoice
        console.log('Invoice paid:', invoice.id, 'Customer:', invoice.customer)
        break
      }

      default:
        console.log('Unhandled event type:', event.type)
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Webhook error:', error)
    return new Response('Webhook handler error', { status: 500 })
  }
})

/**
 * Handle checkout.session.completed event
 * This is triggered when a customer successfully completes checkout
 */
async function handleCheckoutCompleted(
  stripe: Stripe,
  supabase: ReturnType<typeof createClient>,
  session: Stripe.Checkout.Session
): Promise<void> {
  console.log('Processing checkout.session.completed:', session.id)

  // Get the Supabase user ID from session metadata
  let supabaseUserId = session.metadata?.supabase_user_id
  const interval = session.metadata?.interval // 'monthly', 'yearly', or 'lifetime'

  // If no user ID in metadata, this is a guest checkout (payment-first flow)
  // We need to create or find the user by email
  if (!supabaseUserId) {
    console.log('Guest checkout detected, creating/finding user by email')

    const customerEmail = session.customer_details?.email || session.customer_email
    if (!customerEmail) {
      console.error('No email found in checkout session')
      return
    }

    console.log('Looking up user by email:', customerEmail)

    // Look up user by email in auth.users via admin API
    // Use pagination to handle large user bases
    let userWithEmail: { id: string } | null = null
    let page = 1
    const perPage = 1000

    while (!userWithEmail) {
      const { data: usersPage, error: listError } = await supabase.auth.admin.listUsers({ page, perPage })

      if (listError) {
        console.error('Error listing users:', listError)
        break
      }

      if (!usersPage?.users?.length) break

      const found = usersPage.users.find(u => u.email?.toLowerCase() === customerEmail.toLowerCase())
      if (found) {
        userWithEmail = { id: found.id }
        break
      }

      if (usersPage.users.length < perPage) break
      page++
    }

    if (userWithEmail) {
      console.log('Found existing user with email:', customerEmail, 'ID:', userWithEmail.id)
      supabaseUserId = userWithEmail.id
    } else {
      // Create new user with random password (they'll use magic link to log in)
      console.log('Creating new user with email:', customerEmail)
      const randomPassword = crypto.randomUUID()

      const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
        email: customerEmail,
        password: randomPassword,
        email_confirm: true, // Auto-confirm email since they paid
      })

      if (createError || !newUser.user) {
        console.error('Failed to create user:', createError)
        return
      }

      supabaseUserId = newUser.user.id
      console.log('Created new user:', supabaseUserId)
    }
  }

  const stripeCustomerId = typeof session.customer === 'string'
    ? session.customer
    : session.customer?.id

  // Ensure profile exists before updating (handles new users and edge cases)
  const { error: profileError } = await supabase
    .from('profiles')
    .upsert({
      id: supabaseUserId,
      created_at: new Date().toISOString(),
    }, {
      onConflict: 'id',
      ignoreDuplicates: true, // Don't update if exists
    })

  if (profileError) {
    console.error('Failed to ensure profile exists:', profileError)
    // Continue anyway - update might still work if profile exists
  }

  if (session.mode === 'subscription') {
    // Handle Pro subscription checkout
    const subscriptionId = typeof session.subscription === 'string'
      ? session.subscription
      : session.subscription?.id

    if (!subscriptionId) {
      console.error('No subscription ID in completed session')
      return
    }

    // Fetch the full subscription object to get period end
    const subscription = await stripe.subscriptions.retrieve(subscriptionId)

    console.log('Updating profile for subscription:', {
      userId: supabaseUserId,
      subscriptionId: subscription.id,
      status: subscription.status,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
    })

    // Update the user's profile with subscription info
    const { error } = await supabase
      .from('profiles')
      .update({
        plan_tier: 'pro',
        stripe_customer_id: stripeCustomerId,
        stripe_subscription_id: subscription.id,
        plan_renews_interval: interval || (subscription.items.data[0]?.plan?.interval === 'year' ? 'yearly' : 'monthly'),
        plan_status: subscription.status,
        plan_current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
        plan_updated_at: new Date().toISOString(),
      })
      .eq('id', supabaseUserId)

    if (error) {
      console.error('Failed to update profile for subscription:', error)
      throw error
    }

    console.log('Profile updated to Pro plan for user:', supabaseUserId)

    // Process referral reward for Pro subscriptions
    await processReferralReward(supabase, supabaseUserId, stripeCustomerId)

  } else if (session.mode === 'payment') {
    // Handle Lifetime one-time payment
    const paymentIntentId = typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id

    console.log('Updating profile for lifetime payment:', {
      userId: supabaseUserId,
      paymentIntentId,
    })

    // Update the user's profile with lifetime access
    const { error } = await supabase
      .from('profiles')
      .update({
        plan_tier: 'lifetime',
        stripe_customer_id: stripeCustomerId,
        stripe_lifetime_payment_id: paymentIntentId,
        plan_renews_interval: 'lifetime',
        plan_status: 'active',
        plan_current_period_end: null, // Lifetime has no end date
        plan_updated_at: new Date().toISOString(),
      })
      .eq('id', supabaseUserId)

    if (error) {
      console.error('Failed to update profile for lifetime:', error)
      throw error
    }

    console.log('Profile updated to Lifetime plan for user:', supabaseUserId)
  }
}

/**
 * Handle customer.subscription.updated event
 * This is triggered when a subscription is updated (status change, renewal, etc.)
 */
async function handleSubscriptionUpdated(
  supabase: ReturnType<typeof createClient>,
  subscription: Stripe.Subscription
): Promise<void> {
  console.log('Processing customer.subscription.updated:', subscription.id, 'Status:', subscription.status)

  // Find the user by subscription ID
  const { data: profile, error: fetchError } = await supabase
    .from('profiles')
    .select('id, plan_tier')
    .eq('stripe_subscription_id', subscription.id)
    .single()

  if (fetchError || !profile) {
    console.error('Could not find profile for subscription:', subscription.id)
    return
  }

  // Don't downgrade lifetime users
  if (profile.plan_tier === 'lifetime') {
    console.log('Skipping subscription update for lifetime user:', profile.id)
    return
  }

  // Determine if the subscription is still active
  const activeStatuses = ['active', 'trialing']
  const isActive = activeStatuses.includes(subscription.status)

  if (isActive) {
    // Update subscription info
    const { error } = await supabase
      .from('profiles')
      .update({
        plan_tier: 'pro',
        plan_status: subscription.status,
        plan_current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
        plan_updated_at: new Date().toISOString(),
      })
      .eq('id', profile.id)

    if (error) {
      console.error('Failed to update profile on subscription update:', error)
    } else {
      console.log('Profile subscription info updated for user:', profile.id)
    }
  } else {
    // Subscription is no longer active (canceled, past_due, etc.)
    // Downgrade to free
    const { error } = await supabase
      .from('profiles')
      .update({
        plan_tier: 'free',
        plan_status: subscription.status,
        plan_renews_interval: null,
        plan_current_period_end: subscription.current_period_end
          ? new Date(subscription.current_period_end * 1000).toISOString()
          : null,
        plan_updated_at: new Date().toISOString(),
      })
      .eq('id', profile.id)

    if (error) {
      console.error('Failed to downgrade profile on subscription status change:', error)
    } else {
      console.log('Profile downgraded to Free for user:', profile.id, 'Status:', subscription.status)
    }
  }
}

/**
 * Handle customer.subscription.deleted event
 * This is triggered when a subscription is fully canceled/deleted
 */
async function handleSubscriptionDeleted(
  supabase: ReturnType<typeof createClient>,
  subscription: Stripe.Subscription
): Promise<void> {
  console.log('Processing customer.subscription.deleted:', subscription.id)

  // Find the user by subscription ID
  const { data: profile, error: fetchError } = await supabase
    .from('profiles')
    .select('id, plan_tier')
    .eq('stripe_subscription_id', subscription.id)
    .single()

  if (fetchError || !profile) {
    console.error('Could not find profile for deleted subscription:', subscription.id)
    return
  }

  // Don't downgrade lifetime users (they shouldn't have a subscription, but just in case)
  if (profile.plan_tier === 'lifetime') {
    console.log('Skipping subscription deletion for lifetime user:', profile.id)
    return
  }

  // Downgrade to free
  const { error } = await supabase
    .from('profiles')
    .update({
      plan_tier: 'free',
      plan_status: 'canceled',
      plan_renews_interval: null,
      // Keep the subscription ID for history
      // stripe_subscription_id: null,
      plan_current_period_end: null,
      plan_updated_at: new Date().toISOString(),
    })
    .eq('id', profile.id)

  if (error) {
    console.error('Failed to downgrade profile on subscription deletion:', error)
  } else {
    console.log('Profile downgraded to Free for user:', profile.id)
  }
}

/**
 * Process referral reward when a referred user subscribes to Pro
 *
 * Rules:
 * - Referred user must have signed up via referral link (referred_by is set)
 * - Must be within 90 days of signup (referred_at)
 * - Must be their first Pro subscription (referral_reward_granted is false)
 * - Anti-gaming: referrer and referred cannot share same stripe_customer_id
 * - Cap: max 6 free months per referrer per calendar year
 */
async function processReferralReward(
  supabase: ReturnType<typeof createClient>,
  referredUserId: string,
  referredStripeCustomerId: string | undefined
): Promise<void> {
  console.log('Processing referral reward for user:', referredUserId)

  try {
    // Fetch the referred user's profile with referral info
    const { data: referredProfile, error: fetchError } = await supabase
      .from('profiles')
      .select('id, referred_by, referred_at, referral_reward_granted, stripe_customer_id')
      .eq('id', referredUserId)
      .single()

    if (fetchError || !referredProfile) {
      console.log('Could not fetch referred profile:', fetchError?.message)
      return
    }

    // Check 1: Was this user referred?
    if (!referredProfile.referred_by) {
      console.log('User was not referred, skipping reward')
      return
    }

    // Check 2: Has reward already been granted for this referred user?
    if (referredProfile.referral_reward_granted) {
      console.log('Referral reward already granted for this user, skipping')
      return
    }

    // Check 3: Is the subscription within 90 days of signup?
    if (!referredProfile.referred_at) {
      console.log('No referred_at timestamp, skipping reward')
      return
    }

    const referredAt = new Date(referredProfile.referred_at)
    const now = new Date()
    const daysSinceReferral = Math.floor((now.getTime() - referredAt.getTime()) / (1000 * 60 * 60 * 24))

    if (daysSinceReferral > 90) {
      console.log(`Referral window expired: ${daysSinceReferral} days since signup (max 90)`)

      // Log the expired referral event
      await logReferralEvent(supabase, referredProfile.referred_by, referredUserId, 'reward_denied', {
        reason: 'window_expired',
        days_since_referral: daysSinceReferral,
      })
      return
    }

    // Find the referrer by their referral_code
    const { data: referrerProfile, error: referrerError } = await supabase
      .from('profiles')
      .select('id, stripe_customer_id, referral_free_months_earned, referral_free_months_this_year, referral_year, referral_free_until')
      .eq('referral_code', referredProfile.referred_by)
      .single()

    if (referrerError || !referrerProfile) {
      console.log('Could not find referrer profile:', referrerError?.message)
      return
    }

    // Check 4: Anti-gaming - same Stripe customer ID?
    if (
      referrerProfile.stripe_customer_id &&
      referredStripeCustomerId &&
      referrerProfile.stripe_customer_id === referredStripeCustomerId
    ) {
      console.log('Anti-gaming: referrer and referred share same Stripe customer ID, denying reward')

      await logReferralEvent(supabase, referrerProfile.id, referredUserId, 'reward_denied', {
        reason: 'same_stripe_customer',
      })
      return
    }

    // Check 5: Annual cap (max 6 free months per calendar year)
    const currentYear = now.getFullYear()
    let monthsThisYear = referrerProfile.referral_free_months_this_year || 0

    // Reset counter if it's a new year
    if (referrerProfile.referral_year !== currentYear) {
      monthsThisYear = 0
    }

    if (monthsThisYear >= 6) {
      console.log(`Referrer has reached annual cap: ${monthsThisYear}/6 months this year`)

      await logReferralEvent(supabase, referrerProfile.id, referredUserId, 'reward_denied', {
        reason: 'annual_cap_reached',
        months_this_year: monthsThisYear,
      })
      return
    }

    // All checks passed! Grant the reward
    console.log('Granting referral reward to referrer:', referrerProfile.id)

    // Calculate new referral_free_until
    const currentFreeUntil = referrerProfile.referral_free_until
      ? new Date(referrerProfile.referral_free_until)
      : null

    // If they already have free time that extends past now, add to it
    // Otherwise, start from now
    const baseDate = currentFreeUntil && currentFreeUntil > now ? currentFreeUntil : now
    const newFreeUntil = new Date(baseDate)
    newFreeUntil.setMonth(newFreeUntil.getMonth() + 1)

    // Update referrer's profile with the reward
    const { error: updateReferrerError } = await supabase
      .from('profiles')
      .update({
        referral_free_months_earned: (referrerProfile.referral_free_months_earned || 0) + 1,
        referral_free_months_this_year: monthsThisYear + 1,
        referral_year: currentYear,
        referral_free_until: newFreeUntil.toISOString(),
      })
      .eq('id', referrerProfile.id)

    if (updateReferrerError) {
      console.error('Failed to update referrer profile:', updateReferrerError)
      return
    }

    // Mark the referred user as having generated a reward
    const { error: updateReferredError } = await supabase
      .from('profiles')
      .update({
        referral_reward_granted: true,
      })
      .eq('id', referredUserId)

    if (updateReferredError) {
      console.error('Failed to update referred profile:', updateReferredError)
      // Continue anyway - the referrer got their reward
    }

    // Log the successful reward
    await logReferralEvent(supabase, referrerProfile.id, referredUserId, 'reward_granted', {
      free_until: newFreeUntil.toISOString(),
      months_earned_total: (referrerProfile.referral_free_months_earned || 0) + 1,
      months_this_year: monthsThisYear + 1,
    })

    console.log(`Referral reward granted! Referrer ${referrerProfile.id} now has free Pro until ${newFreeUntil.toISOString()}`)

  } catch (error) {
    console.error('Error processing referral reward:', error)
    // Don't throw - referral reward failure shouldn't fail the whole webhook
  }
}

/**
 * Log a referral event for tracking/debugging
 */
async function logReferralEvent(
  supabase: ReturnType<typeof createClient>,
  referrerId: string,
  referredId: string,
  eventType: string,
  details: Record<string, unknown>
): Promise<void> {
  try {
    // First, we need to get the referrer's user ID from their referral_code
    // If referrerId is already a UUID, use it directly
    let referrerUserId = referrerId

    // Check if it looks like a referral code (starts with SL-)
    if (referrerId.startsWith('SL-')) {
      const { data: referrer } = await supabase
        .from('profiles')
        .select('id')
        .eq('referral_code', referrerId)
        .single()

      if (referrer) {
        referrerUserId = referrer.id
      } else {
        console.log('Could not find referrer for event logging:', referrerId)
        return
      }
    }

    await supabase
      .from('referral_events')
      .insert({
        referrer_id: referrerUserId,
        referred_id: referredId,
        event_type: eventType,
        details: details,
      })
  } catch (error) {
    console.error('Failed to log referral event:', error)
    // Don't throw - logging failure shouldn't affect main flow
  }
}
