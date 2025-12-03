'use client'

import React from 'react'
import Link from 'next/link'

interface PricingPlan {
  name: string
  price: string
  priceSubtext?: string
  label: string
  features: string[]
  ctaText: string
  ctaHref: string
  highlighted?: boolean
}

const plans: PricingPlan[] = [
  {
    name: 'Free',
    price: 'Free',
    label: 'For trying it out on your main site.',
    features: [
      '1 domain',
      'Up to 20 pages per scan',
      'Manual scans only',
      'SEO suggestions for missing titles, descriptions, and H1 tags',
      'Redirect chain view',
      'Basic domain notes',
    ],
    ctaText: 'Start free',
    ctaHref: '/app',
  },
  {
    name: 'Pro',
    price: '$2.99 / month',
    priceSubtext: 'or $19.99 / year',
    label: 'For creators & domain hoarders with a small portfolio.',
    features: [
      'Up to 10 domains',
      'Up to 50 pages per domain per scan',
      'Weekly automatic scans',
      'SEO suggestions for titles, meta, H1s, and canonicals',
      'WHOIS/RDAP autofill for registrar & expiry date',
      'Expiration reminders (via Suggestions, email later)',
      'Redirect plan with provider-specific setup tips',
    ],
    ctaText: 'Upgrade to Pro',
    ctaHref: '/api/checkout?plan=pro-monthly',
    highlighted: true,
  },
  {
    name: 'Lifetime',
    price: 'One-time $49.99',
    label: 'Limited founding offer.',
    features: [
      'Everything in Pro',
      'One-time payment',
      'No subscription ever',
      'Includes future improvements to the Pro feature set',
    ],
    ctaText: 'Get lifetime access',
    ctaHref: '/api/checkout?plan=lifetime',
  },
]

export function PricingSection(): React.JSX.Element {
  return (
    <section className="bg-slate-50 py-16 lg:py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 mb-4">
            Simple pricing for domain hoarders.
          </h2>
          <p className="text-lg text-gray-600 max-w-2xl mx-auto">
            Start free. Upgrade when you want SEO Lens watching more domains for you.
          </p>
        </div>

        {/* Pricing cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 lg:gap-8 mb-8">
          {plans.map((plan) => (
            <PricingCard key={plan.name} plan={plan} />
          ))}
        </div>

        {/* Reassurance line */}
        <p className="text-center text-sm text-gray-600 max-w-3xl mx-auto">
          No risk: Start free with one domain and upgrade only if SEO Lens actually helps you clean things up.
        </p>
      </div>
    </section>
  )
}

interface PricingCardProps {
  plan: PricingPlan
}

function PricingCard({ plan }: PricingCardProps): React.JSX.Element {
  return (
    <div
      className={`bg-white rounded-2xl border-2 p-6 lg:p-8 flex flex-col ${
        plan.highlighted
          ? 'border-primary shadow-lg relative'
          : 'border-slate-200'
      }`}
    >
      {/* Popular badge */}
      {plan.highlighted && (
        <div className="absolute -top-4 left-1/2 -translate-x-1/2">
          <span className="bg-primary text-white text-xs font-semibold px-4 py-1.5 rounded-full shadow-md">
            Most popular
          </span>
        </div>
      )}

      {/* Plan name */}
      <h3 className="text-2xl font-bold text-gray-900 mb-2">{plan.name}</h3>

      {/* Label */}
      <p className="text-sm text-gray-600 mb-4">{plan.label}</p>

      {/* Price */}
      <div className="mb-6">
        <p className="text-3xl font-extrabold text-gray-900">{plan.price}</p>
        {plan.priceSubtext && (
          <p className="text-sm text-gray-500 mt-1">{plan.priceSubtext}</p>
        )}
      </div>

      {/* Features */}
      <ul className="space-y-3 mb-8 flex-grow">
        {plan.features.map((feature, idx) => (
          <li key={idx} className="flex items-start gap-2">
            <svg
              className="w-5 h-5 text-primary flex-shrink-0 mt-0.5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M5 13l4 4L19 7"
              />
            </svg>
            <span className="text-sm text-gray-700">{feature}</span>
          </li>
        ))}
      </ul>

      {/* CTA button */}
      <Link
        href={plan.ctaHref}
        className={`block text-center py-3 px-6 rounded-lg font-semibold transition-colors ${
          plan.highlighted
            ? 'bg-primary text-white hover:bg-primary/90'
            : 'bg-slate-100 text-gray-900 hover:bg-slate-200'
        }`}
      >
        {plan.ctaText}
      </Link>
    </div>
  )
}
