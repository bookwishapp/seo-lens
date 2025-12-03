import { NextRequest, NextResponse } from 'next/server'

// Supabase project URL for edge functions
const SUPABASE_URL = 'https://npvynslhkwcstiserepx.supabase.co'

// Production app URL (Flutter web app)
const APP_URL = 'https://seolens.io/app'

// Plan configuration with price IDs and checkout modes
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
    const { searchParams } = new URL(request.url)
    const plan = searchParams.get('plan') as keyof typeof PLAN_CONFIG
    const ref = searchParams.get('ref')

    if (!plan || !PLAN_CONFIG[plan]) {
      return NextResponse.json(
        { error: 'Invalid plan specified' },
        { status: 400 }
      )
    }

    const config = PLAN_CONFIG[plan]

    // Build success and cancel URLs for Stripe (hardcoded for reliability)
    // Pass through ref param if present for referral tracking
    const refParam = ref ? `&ref=${encodeURIComponent(ref)}` : ''
    const successUrl = `${APP_URL}#/checkout/success?session_id={CHECKOUT_SESSION_ID}${refParam}`
    const cancelUrl = `${APP_URL}#/checkout/canceled${ref ? `?ref=${encodeURIComponent(ref)}` : ''}`

    console.log('Creating checkout session:', { plan, successUrl, cancelUrl })

    // Call Supabase edge function to create Stripe checkout session (guest mode)
    const response = await fetch(`${SUPABASE_URL}/functions/v1/create-checkout-session`, {
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
      const errorData = await response.json().catch(() => ({}))
      console.error('Checkout session creation failed:', errorData)
      return NextResponse.json(
        { error: errorData.error || 'Failed to create checkout session' },
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

    // Redirect to Stripe Checkout page
    return NextResponse.redirect(data.url)
  } catch (error) {
    console.error('Checkout API error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
