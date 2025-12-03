import Image from 'next/image'
import Link from 'next/link'

// Logo component
function Logo() {
  return (
    <div className="flex items-center gap-4">
      <img
        src="/seo_lens_logo.svg"
        alt="SEO Lens Logo"
        width={96}
        height={96}
        className="flex-shrink-0"
      />
      <span className="text-3xl font-bold text-gray-900">SEO Lens</span>
    </div>
  )
}

export function HeroSection() {
  return (
    <header className="bg-gradient-to-b from-slate-50 to-white">
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-20">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Left column - Content */}
          <div className="space-y-8">
            {/* Logo */}
            <div className="flex justify-start">
              <Logo />
            </div>

            {/* Main heading */}
            <div className="space-y-4">
              <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-gray-900 leading-tight">
                SEO checks for every domain you own.
              </h1>

              <p className="text-lg sm:text-xl text-gray-600 leading-relaxed max-w-2xl">
                Connect your domains, run a scan, and get clear suggestions for missing H1s, meta descriptions, and redirect issues.
              </p>
            </div>

            {/* Benefits list */}
            <ul className="space-y-3" role="list">
              <li className="flex items-start gap-3">
                <svg
                  className="w-6 h-6 text-primary flex-shrink-0 mt-0.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span className="text-gray-700 text-base sm:text-lg">
                  See every domain and redirect in one view.
                </span>
              </li>
              <li className="flex items-start gap-3">
                <svg
                  className="w-6 h-6 text-primary flex-shrink-0 mt-0.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span className="text-gray-700 text-base sm:text-lg">
                  Find missing titles, descriptions, and H1 tags.
                </span>
              </li>
              <li className="flex items-start gap-3">
                <svg
                  className="w-6 h-6 text-primary flex-shrink-0 mt-0.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span className="text-gray-700 text-base sm:text-lg">
                  Prioritize fixes instead of sifting through raw data.
                </span>
              </li>
              <li className="flex items-start gap-3">
                <svg
                  className="w-6 h-6 text-primary flex-shrink-0 mt-0.5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span className="text-gray-700 text-base sm:text-lg">
                  <strong>PLUS:</strong> Never miss another domain expiration date again!
                </span>
              </li>
            </ul>

            {/* CTAs */}
            <div className="flex flex-col sm:flex-row gap-4">
              <Link
                href="/app"
                className="btn-primary"
              >
                Scan my domains
              </Link>
              <Link
                href="/app"
                className="btn-secondary"
              >
                View live demo
              </Link>
            </div>

            {/* Supporting detail */}
            <p className="text-sm text-gray-500">
              Scans up to 50 pages per domain in v1.
            </p>
          </div>

          {/* Right column - Product mockup */}
          <div className="relative lg:order-last order-first">
            <div className="aspect-[4/3] relative rounded-lg overflow-hidden shadow-2xl border border-gray-200 bg-white">
              <img
                src="/hero_screenshot.png"
                alt="SEO Lens Dashboard Screenshot"
                className="w-full h-full object-cover"
              />
            </div>
          </div>
        </div>
      </section>
    </header>
  )
}
