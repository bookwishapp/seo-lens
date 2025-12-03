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
    const priceProMonthly = Deno.env.get('STRIPE_PRICE_PRO_MONTHLY')
    const priceProYearly = Deno.env.get('STRIPE_PRICE_PRO_YEARLY')
    const priceLifetime = Deno.env.get('STRIPE_PRICE_LIFETIME')

    if (!stripeSecretKey) {
      console.error('STRIPE_SECRET_KEY not configured')
      return new Response(
        JSON.stringify({ error: 'Stripe not configured' } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!frontendUrl) {
      console.error('FRONTEND_URL not configured')
      return new Response(
        JSON.stringify({ error: 'Frontend URL not configured' } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
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

    // Get the authorization header to identify the user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify the JWT and get the user
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

    if (authError || !user) {
      console.error('Auth error:', authError)
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse the request body
    const body: CheckoutRequest = await req.json()
    const { price_id, mode, interval } = body

    // Validate the price_id and mode combination
    const validCombinations = [
      { priceId: priceProMonthly, mode: 'subscription', interval: 'monthly' },
      { priceId: priceProYearly, mode: 'subscription', interval: 'yearly' },
      { priceId: priceLifetime, mode: 'payment', interval: 'lifetime' },
    ]

    const isValidRequest = validCombinations.some(
      combo => combo.priceId === price_id && combo.mode === mode && combo.interval === interval
    )

    if (!isValidRequest) {
      console.error('Invalid checkout request:', { price_id, mode, interval })
      return new Response(
        JSON.stringify({ error: 'Invalid price, mode, or interval combination' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get or create the user's profile to retrieve/store Stripe customer ID
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('id, stripe_customer_id')
      .eq('id', user.id)
      .single()

    if (profileError && profileError.code !== 'PGRST116') {
      console.error('Profile fetch error:', profileError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch user profile' } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let stripeCustomerId = profile?.stripe_customer_id

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
      const { error: updateError } = await supabaseClient
        .from('profiles')
        .update({ stripe_customer_id: stripeCustomerId })
        .eq('id', user.id)

      if (updateError) {
        console.error('Failed to save Stripe customer ID:', updateError)
        // Continue anyway - the customer was created in Stripe
      }
    }

    // Build success and cancel URLs
    // The success URL includes a session_id placeholder that Stripe will replace
    const successUrl = `${frontendUrl}/#/checkout/success?session_id={CHECKOUT_SESSION_ID}`
    const cancelUrl = `${frontendUrl}/#/checkout/canceled`

    // Create the Checkout Session
    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      customer: stripeCustomerId,
      mode: mode,
      line_items: [
        {
          price: price_id,
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        supabase_user_id: user.id,
        interval: interval,
      },
    }

    // For subscriptions, add subscription metadata too
    if (mode === 'subscription') {
      sessionParams.subscription_data = {
        metadata: {
          supabase_user_id: user.id,
          interval: interval,
        },
      }
    }

    // For one-time payments (lifetime), add payment intent metadata
    if (mode === 'payment') {
      sessionParams.payment_intent_data = {
        metadata: {
          supabase_user_id: user.id,
          interval: interval,
        },
      }
    }

    console.log('Creating Checkout session for user:', user.id, 'mode:', mode, 'interval:', interval)

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
