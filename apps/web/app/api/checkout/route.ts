import { NextRequest, NextResponse } from 'next/server'

// Price IDs and plan configuration
const PLAN_CONFIG = {
  'pro-monthly': {
    priceId: 'price_1SaICB5qHmqMYJiA1Ab3X3Mh',
    mode: 'subscription' as const,
    interval: 'monthly' as const,
  },
  'pro-yearly': {
    priceId: 'price_1SaIDG5qHmqMYJiAVT6WH0ER',
    mode: 'subscription' as const,
    interval: 'yearly' as const,
  },
  'lifetime': {
    priceId: 'price_1SaIEI5qHmqMYJiAKdIZb4iy',
    mode: 'payment' as const,
    interval: 'lifetime' as const,
  },
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams, origin } = new URL(request.url)
    const plan = searchParams.get('plan') as keyof typeof PLAN_CONFIG

    if (!plan || !PLAN_CONFIG[plan]) {
      return NextResponse.json(
        { error: 'Invalid plan specified' },
        { status: 400 }
      )
    }

    const config = PLAN_CONFIG[plan]
    // Use server-side env var (without NEXT_PUBLIC prefix) or fall back to client var
    const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL
    const appUrl = process.env.NEXT_PUBLIC_APP_URL || `${origin}/app`

    if (!supabaseUrl) {
      console.error('SUPABASE_URL not configured')
      return NextResponse.json(
        { error: 'Server configuration error' },
        { status: 500 }
      )
    }

    // Build success and cancel URLs
    const successUrl = `${appUrl}#/checkout/success?session_id={CHECKOUT_SESSION_ID}`
    const cancelUrl = `${appUrl}#/checkout/canceled`

    // Call Supabase edge function to create checkout session (guest mode - no auth)
    const response = await fetch(`${supabaseUrl}/functions/v1/create-checkout-session`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        price_id: config.priceId,
        mode: config.mode,
        interval: config.interval,
        success_url: successUrl,
        cancel_url: cancelUrl,
      }),
    })

    if (!response.ok) {
      const error = await response.json()
      console.error('Checkout session creation failed:', error)
      return NextResponse.json(
        { error: error.error || 'Failed to create checkout session' },
        { status: response.status }
      )
    }

    const data = await response.json()

    if (!data.url) {
      return NextResponse.json(
        { error: 'No checkout URL returned' },
        { status: 500 }
      )
    }

    // Redirect to Stripe Checkout
    return NextResponse.redirect(data.url)
  } catch (error) {
    console.error('Checkout API error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
