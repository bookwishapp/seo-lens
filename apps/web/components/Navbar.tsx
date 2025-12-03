import Link from 'next/link'
import { LogIn } from 'lucide-react'

export function Navbar() {
  return (
    <nav className="bg-white border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          {/* Logo/Brand */}
          <Link href="/" className="flex items-center gap-2 text-xl font-bold text-gray-900">
            <img
              src="/seo_lens_logo.svg"
              alt="SEO Lens"
              width={32}
              height={32}
              className="flex-shrink-0"
            />
            SEO Lens
          </Link>

          {/* Login button */}
          <Link
            href="/app"
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <LogIn className="w-4 h-4" />
            Log in
          </Link>
        </div>
      </div>
    </nav>
  )
}
