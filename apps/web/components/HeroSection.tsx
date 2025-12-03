import Image from 'next/image'
import Link from 'next/link'

// Placeholder Logo component
function Logo() {
  return (
    <div className="flex items-center gap-2">
      <svg
        width="32"
        height="32"
        viewBox="0 0 32 32"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="text-primary"
        aria-hidden="true"
      >
        <circle cx="16" cy="16" r="16" fill="currentColor" opacity="0.1" />
        <path
          d="M16 8L8 12V20L16 24L24 20V12L16 8Z"
          fill="currentColor"
        />
      </svg>
      <span className="text-xl font-bold text-gray-900">SEO Lens</span>
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
              <div className="absolute inset-0 bg-gradient-to-br from-slate-100 to-slate-200 flex items-center justify-center">
                <div className="text-center space-y-3 p-8">
                  <div className="w-16 h-16 mx-auto bg-primary/10 rounded-full flex items-center justify-center">
                    <svg
                      className="w-8 h-8 text-primary"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2"
                      />
                    </svg>
                  </div>
                  <p className="text-gray-600 font-medium">Product Screenshot</p>
                  <p className="text-sm text-gray-500">Dashboard mockup coming soon</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </header>
  )
}
