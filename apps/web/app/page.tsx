import type { Metadata } from 'next'
import { HeroSection } from '@/components/HeroSection'
import { PlatformDownloadsSection } from '@/components/PlatformDownloadsSection'
import { PricingSection } from '@/components/PricingSection'
import { FAQSection } from '@/components/FAQSection'

export const metadata: Metadata = {
  title: 'SEO Lens – SEO Audit Tool for All Your Domains',
  description: 'Scan your domains, find missing titles, meta descriptions, and H1 tags. Get clear SEO suggestions and fix issues before they hurt your rankings.',
}

export default function Home() {
  return (
    <main>
      <HeroSection />
      <PlatformDownloadsSection />
      <PricingSection />
      <FAQSection />
    </main>
  )
}
