// supabase/functions/create-checkout-session/index.ts
// Supabase Edge Function to create a Stripe Checkout session
//
// Required environment variables (set via `supabase secrets set`):
// - STRIPE_SECRET_KEY: Stripe secret key (use test key for development)
// - FRONTEND_URL: Base URL of the Flutter web app (e.g., https://seolens.io/app)
// - STRIPE_PRICE_PRO_MONTHLY: Stripe Price ID for $2.99/month Pro plan
// - STRIPE_PRICE_PRO_YEARLY: Stripe Price ID for $19.99/year Pro plan
// - STRIPE_PRICE_LIFETIME: Stripe Price ID for $49.99 one-time Lifetime purchase

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
import Stripe from 'https://esm.sh/stripe@14.5.0?target=deno'

interface CheckoutRequest {
  price_id: string
  mode: 'subscription' | 'payment'
  interval: 'monthly' | 'yearly' | 'lifetime'
  success_url?: string
  cancel_url?: string
}

interface CheckoutResponse {
  url: string
}

interface ErrorResponse {
  error: string
}

// CORS headers for preflight and actual requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get environment variables
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
    const frontendUrl = Deno.env.get('FRONTEND_URL')

    // Valid price IDs (hardcoded for reliability)
    const VALID_PRICES = {
      'price_1SaICB5qHmqMYJiA1Ab3X3Mh': { mode: 'subscription', interval: 'monthly' },
      'price_1SaIDG5qHmqMYJiAVT6WH0ER': { mode: 'subscription', interval: 'yearly' },
      'price_1SaIEI5qHmqMYJiAKdIZb4iy': { mode: 'payment', interval: 'lifetime' },
    }

    if (!stripeSecretKey) {
      console.error('STRIPE_SECRET_KEY not configured')
      return new Response(
        JSON.stringify({ error: 'Stripe not configured' } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // FRONTEND_URL is optional now - client can pass success/cancel URLs directly
    // Kept for backward compatibility

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

    // Get the authorization header (optional for guest checkout)
    const authHeader = req.headers.get('Authorization')
    let user = null
    let isAuthenticated = false

    if (authHeader) {
      // Authenticated user (upgrade from settings)
      const token = authHeader.replace('Bearer ', '')
      const { data: authData, error: authError } = await supabaseClient.auth.getUser(token)

      if (!authError && authData.user) {
        user = authData.user
        isAuthenticated = true
        console.log('Authenticated checkout for user:', user.id)
      }
    }

    // For guest checkout (no auth), we'll create a session without customer ID
    // and the webhook will handle user creation

    // Parse the request body
    const body: CheckoutRequest = await req.json()
    const { price_id, mode, interval, success_url, cancel_url } = body

    // Validate the price_id and mode combination
    const validPrice = VALID_PRICES[price_id as keyof typeof VALID_PRICES]
    if (!validPrice || validPrice.mode !== mode || validPrice.interval !== interval) {
      console.error('Invalid checkout request:', { price_id, mode, interval })
      return new Response(
        JSON.stringify({ error: 'Invalid price, mode, or interval combination' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let stripeCustomerId: string | undefined = undefined

    // For authenticated users, get or create Stripe customer
    if (isAuthenticated && user) {
      const { data: profile } = await supabaseClient
        .from('profiles')
        .select('id, stripe_customer_id')
        .eq('id', user.id)
        .single()

      stripeCustomerId = profile?.stripe_customer_id

      // Create Stripe customer if one doesn't exist
      if (!stripeCustomerId) {
        console.log('Creating new Stripe customer for user:', user.id)

        const customer = await stripe.customers.create({
          email: user.email,
          metadata: {
            supabase_user_id: user.id,
          },
        })

        stripeCustomerId = customer.id

        // Save the Stripe customer ID to the profile
        await supabaseClient
          .from('profiles')
          .update({ stripe_customer_id: stripeCustomerId })
          .eq('id', user.id)
      }
    }
    // For guest checkout, don't create customer - Stripe will handle it

    // Build success and cancel URLs
    // The success URL includes a session_id placeholder that Stripe will replace
    // Use client-provided URLs if available, otherwise fall back to FRONTEND_URL env var
    const finalSuccessUrl = success_url
      ? success_url.replace('{CHECKOUT_SESSION_ID}', '{CHECKOUT_SESSION_ID}')
      : frontendUrl
        ? `${frontendUrl}/#/checkout/success?session_id={CHECKOUT_SESSION_ID}`
        : null

    const finalCancelUrl = cancel_url
      ? cancel_url
      : frontendUrl
        ? `${frontendUrl}/#/checkout/canceled`
        : null

    if (!finalSuccessUrl || !finalCancelUrl) {
      console.error('No success or cancel URLs provided')
      return new Response(
        JSON.stringify({ error: 'Success and cancel URLs required' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create the Checkout Session
    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      mode: mode,
      line_items: [
        {
          price: price_id,
          quantity: 1,
        },
      ],
      success_url: finalSuccessUrl,
      cancel_url: finalCancelUrl,
      metadata: {
        interval: interval,
      },
    }

    // Add customer for authenticated users, let Stripe collect email for guests
    if (stripeCustomerId) {
      sessionParams.customer = stripeCustomerId
      sessionParams.metadata!.supabase_user_id = user!.id
    } else {
      // Guest checkout - Stripe will collect email
      sessionParams.customer_email = undefined // Let Stripe ask for email
    }

    // For subscriptions, add subscription metadata
    if (mode === 'subscription') {
      sessionParams.subscription_data = {
        metadata: {
          interval: interval,
        },
      }
      if (isAuthenticated && user) {
        sessionParams.subscription_data.metadata.supabase_user_id = user.id
      }
    }

    // For one-time payments (lifetime), add payment intent metadata
    if (mode === 'payment') {
      sessionParams.payment_intent_data = {
        metadata: {
          interval: interval,
        },
      }
      if (isAuthenticated && user) {
        sessionParams.payment_intent_data.metadata.supabase_user_id = user.id
      }
    }

    const userInfo = isAuthenticated && user ? user.id : 'guest'
    console.log('Creating Checkout session for:', userInfo, 'mode:', mode, 'interval:', interval)

    const session = await stripe.checkout.sessions.create(sessionParams)

    if (!session.url) {
      console.error('Stripe session created but no URL returned')
      return new Response(
        JSON.stringify({ error: 'Failed to create checkout session' } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('Checkout session created:', session.id)

    return new Response(
      JSON.stringify({ url: session.url } as CheckoutResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Checkout session error:', error)

    // Check if it's a Stripe error
    if (error instanceof Stripe.errors.StripeError) {
      return new Response(
        JSON.stringify({ error: `Stripe error: ${error.message}` } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Internal server error' } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
