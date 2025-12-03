'use client'

import React, { useState } from 'react'

interface FAQ {
  question: string
  answer: string
}

const faqs: FAQ[] = [
  {
    question: 'Who is SEO Lens for?',
    answer:
      'SEO Lens is built for people who own more than one domain—creators, indie hackers, small businesses, and "domain hoarders" who want a single place to see what all their domains are doing.',
  },
  {
    question: 'What does the free plan include?',
    answer:
      'The free plan lets you connect one domain, scan up to 20 pages, and see SEO suggestions for missing titles, descriptions, and H1 tags. It's a great way to clean up your main site and see how SEO Lens works.',
  },
  {
    question: 'How often does SEO Lens scan my sites?',
    answer:
      'On the free plan, you can run scans manually whenever you like. On the Pro and Lifetime plans, SEO Lens can automatically scan your domains weekly so you can spot issues and changes over time.',
  },
  {
    question: 'What happens if I cancel Pro?',
    answer:
      'If you cancel Pro, your account will fall back to the free limits. Your existing data may be kept, but you'll only be able to actively manage and scan within the free plan's domain and page limits.',
  },
  {
    question: 'Can SEO Lens change my DNS or redirects for me?',
    answer:
      'Right now, SEO Lens is a guide and safety net—it shows you where redirects and SEO issues are, and gives provider-specific setup tips. In v1 it does not directly modify your DNS or hosting settings for safety. You stay in control of your infrastructure.',
  },
]

export function FAQSection(): React.JSX.Element {
  return (
    <section className="py-16 lg:py-24 bg-white" aria-label="Frequently Asked Questions">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 mb-4">
            Frequently asked questions
          </h2>
          <p className="text-lg text-gray-600">
            A few quick answers about how SEO Lens works.
          </p>
        </div>

        {/* FAQ items */}
        <div className="space-y-4">
          {faqs.map((faq, index) => (
            <FAQItem key={index} faq={faq} />
          ))}
        </div>
      </div>
    </section>
  )
}

interface FAQItemProps {
  faq: FAQ
}

function FAQItem({ faq }: FAQItemProps): React.JSX.Element {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <div className="border border-slate-200 rounded-xl overflow-hidden bg-white">
      <button
        onClick={() => setIsOpen(!isOpen)}
        aria-expanded={isOpen}
        className="w-full px-6 py-4 text-left flex items-center justify-between gap-4 hover:bg-slate-50 transition-colors"
      >
        <span className="font-semibold text-gray-900 text-base sm:text-lg">
          {faq.question}
        </span>
        <svg
          className={`w-5 h-5 text-gray-500 flex-shrink-0 transition-transform ${
            isOpen ? 'rotate-180' : ''
          }`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>
      {isOpen && (
        <div className="px-6 pb-4 pt-2">
          <p className="text-gray-700 leading-relaxed">{faq.answer}</p>
        </div>
      )}
    </div>
  )
}
