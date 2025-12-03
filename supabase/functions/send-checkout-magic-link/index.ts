// supabase/functions/send-checkout-magic-link/index.ts
// Send magic link to user after successful checkout (for guest checkouts)
//
// Required environment variables:
// - STRIPE_SECRET_KEY: Stripe secret key
// - FRONTEND_URL: Base URL of the Flutter web app

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
import Stripe from 'https://esm.sh/stripe@14.5.0?target=deno'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
    const frontendUrl = Deno.env.get('FRONTEND_URL')

    if (!stripeSecretKey || !frontendUrl) {
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16',
      httpClient: Stripe.createFetchHttpClient(),
    })

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Get session_id from request
    const { session_id } = await req.json()

    if (!session_id) {
      return new Response(
        JSON.stringify({ error: 'Missing session_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Retrieve the Stripe session to get customer email
    const session = await stripe.checkout.sessions.retrieve(session_id)

    if (!session || session.status !== 'complete') {
      return new Response(
        JSON.stringify({ error: 'Invalid or incomplete session' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const customerEmail = session.customer_details?.email || session.customer_email

    if (!customerEmail) {
      return new Response(
        JSON.stringify({ error: 'No email found in session' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Send magic link
    const { error } = await supabaseClient.auth.signInWithOtp({
      email: customerEmail,
      options: {
        emailRedirectTo: `${frontendUrl}/#/onboarding`,
      },
    })

    if (error) {
      console.error('Failed to send magic link:', error)
      return new Response(
        JSON.stringify({ error: 'Failed to send magic link' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        email: customerEmail,
        message: 'Magic link sent'
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Magic link function error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
