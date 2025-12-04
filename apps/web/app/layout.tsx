import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { Navbar } from '@/components/Navbar'
import { ReferralProvider } from '@/components/ReferralProvider'
import './globals.css'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
})

export const metadata: Metadata = {
  title: {
    default: 'SEO Lens – SEO Audit Tool for All Your Domains',
    template: '%s | SEO Lens',
  },
  description: 'Scan your domains, find missing titles, meta descriptions, and H1 tags. Get clear SEO suggestions and fix issues before they hurt your rankings.',
  openGraph: {
    title: 'SEO Lens – SEO Audit Tool for All Your Domains',
    description: 'Scan your domains, find missing titles, meta descriptions, and H1 tags. Get clear SEO suggestions and fix issues before they hurt your rankings.',
    url: 'https://seolens.io',
    siteName: 'SEO Lens',
    images: [
      {
        url: 'https://seolens.io/og-image.png',
        width: 1200,
        height: 630,
        alt: 'SEO Lens - SEO Audit Tool for All Your Domains',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'SEO Lens – SEO Audit Tool for All Your Domains',
    description: 'Scan your domains, find missing titles, meta descriptions, and H1 tags. Get clear SEO suggestions and fix issues before they hurt your rankings.',
    images: ['https://seolens.io/og-image.png'],
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className={inter.variable}>
      <body className={`${inter.className} antialiased`}>
        <ReferralProvider>
          <Navbar />
          {children}
        </ReferralProvider>
      </body>
    </html>
  )
}
