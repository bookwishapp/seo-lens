/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    return [
      // Serve Flutter SPA for all /app sub-routes (SPA routing)
      // Match /app/anything but not /app/file.ext (static files have dots)
      {
        source: '/app/report/:path*',
        destination: '/app/index.html',
      },
      {
        source: '/app/auth',
        destination: '/app/index.html',
      },
      {
        source: '/app/home',
        destination: '/app/index.html',
      },
      {
        source: '/app/domains/:path*',
        destination: '/app/index.html',
      },
      {
        source: '/app/settings',
        destination: '/app/index.html',
      },
      {
        source: '/app/onboarding',
        destination: '/app/index.html',
      },
      {
        source: '/app/upgrade',
        destination: '/app/index.html',
      },
      {
        source: '/app/referral',
        destination: '/app/index.html',
      },
      {
        source: '/app/suggestions',
        destination: '/app/index.html',
      },
      {
        source: '/app/checkout/:path*',
        destination: '/app/index.html',
      },
    ];
  },
};

module.exports = nextConfig;
