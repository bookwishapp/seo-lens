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
  const supabaseUserId = session.metadata?.supabase_user_id
  const interval = session.metadata?.interval // 'monthly', 'yearly', or 'lifetime'

  if (!supabaseUserId) {
    console.error('No supabase_user_id in session metadata')
    return
  }

  const stripeCustomerId = typeof session.customer === 'string'
    ? session.customer
    : session.customer?.id

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
