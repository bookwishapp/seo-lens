import { HeroSection } from '@/components/HeroSection'
import { PlatformDownloadsSection } from '@/components/PlatformDownloadsSection'
import { PricingSection } from '@/components/PricingSection'
import { FAQSection } from '@/components/FAQSection'

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
