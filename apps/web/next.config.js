/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    return {
      // These rewrites run after checking all pages/routes and static files
      fallback: [
        // Serve Flutter SPA for all /app/* routes (except static files)
        {
          source: '/app/:path*',
          destination: '/app/index.html',
        },
      ],
    };
  },
};

module.exports = nextConfig;
