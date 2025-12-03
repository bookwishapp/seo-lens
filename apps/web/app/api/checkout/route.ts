import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

// Price IDs mapping
const PRICE_IDS = {
  'pro-monthly': 'price_1SaICB5qHmqMYJiA1Ab3X3Mh',
  'pro-yearly': 'price_1SaIDG5qHmqMYJiAVT6WH0ER',
  'lifetime': 'price_1SaIEI5qHmqMYJiAKdIZb4iy',
}

const PRICE_CONFIG = {
  'pro-monthly': { mode: 'subscription', interval: 'monthly' },
  'pro-yearly': { mode: 'subscription', interval: 'yearly' },
  'lifetime': { mode: 'payment', interval: 'lifetime' },
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const plan = searchParams.get('plan') as keyof typeof PRICE_IDS

    if (!plan || !PRICE_IDS[plan]) {
      return NextResponse.json(
        { error: 'Invalid plan specified' },
        { status: 400 }
      )
    }

    // Check if user is authenticated
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: request.headers.get('Authorization') || '',
        },
      },
    })

    const {
      data: { user },
    } = await supabase.auth.getUser()

    // If no user, redirect to sign up first
    if (!user) {
      const origin = request.headers.get('origin') || process.env.NEXT_PUBLIC_APP_URL
      return NextResponse.redirect(
        `${origin}/app?upgrade=${plan}`
      )
    }

    // Call Supabase Edge Function to create checkout session
    const priceId = PRICE_IDS[plan]
    const config = PRICE_CONFIG[plan]

    const { data, error } = await supabase.functions.invoke(
      'create-checkout-session',
      {
        body: {
          price_id: priceId,
          mode: config.mode,
          interval: config.interval,
        },
      }
    )

    if (error) {
      console.error('Checkout session error:', error)
      return NextResponse.json(
        { error: 'Failed to create checkout session' },
        { status: 500 }
      )
    }

    if (!data?.url) {
      return NextResponse.json(
        { error: 'No checkout URL returned' },
        { status: 500 }
      )
    }

    // Redirect to Stripe checkout
    return NextResponse.redirect(data.url)
  } catch (error) {
    console.error('Checkout API error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
