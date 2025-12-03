import { NextRequest, NextResponse } from 'next/server'

// Price IDs mapping
const PRICE_IDS = {
  'pro-monthly': 'price_1SaICB5qHmqMYJiA1Ab3X3Mh',
  'pro-yearly': 'price_1SaIDG5qHmqMYJiAVT6WH0ER',
  'lifetime': 'price_1SaIEI5qHmqMYJiAKdIZb4iy',
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams, origin } = new URL(request.url)
    const plan = searchParams.get('plan') as keyof typeof PRICE_IDS

    if (!plan || !PRICE_IDS[plan]) {
      return NextResponse.json(
        { error: 'Invalid plan specified' },
        { status: 400 }
      )
    }

    // For marketing page clicks, redirect to app with upgrade parameter
    // The Flutter app will handle authentication and checkout
    const appUrl = process.env.NEXT_PUBLIC_APP_URL || `${origin}/app`
    return NextResponse.redirect(`${appUrl}#/upgrade?plan=${plan}`)
  } catch (error) {
    console.error('Checkout API error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
