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
  title: 'SEO Lens – SEO checks for every domain you own',
  description: 'SEO Lens scans your domains, checks up to 50 pages per site, and surfaces clear suggestions for missing titles, meta descriptions, H1 tags, and redirect issues.',
  openGraph: {
    title: 'SEO Lens – SEO checks for every domain you own',
    description: 'SEO Lens scans your domains, checks up to 50 pages per site, and surfaces clear suggestions for missing titles, meta descriptions, H1 tags, and redirect issues.',
    url: 'https://seolens.io',
    siteName: 'SEO Lens',
    images: [
      {
        url: 'https://seolens.io/og-image.png',
        width: 1200,
        height: 630,
        alt: 'SEO Lens - SEO checks for every domain you own',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'SEO Lens – SEO checks for every domain you own',
    description: 'SEO Lens scans your domains, checks up to 50 pages per site, and surfaces clear suggestions for missing titles, meta descriptions, H1 tags, and redirect issues.',
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
