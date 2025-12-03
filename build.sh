#!/bin/bash
set -e

# Build Next.js app
cd apps/web
npm run build

# Build Flutter app
cd ../flutter
../../flutter/bin/flutter build web --release --base-href=/app/ --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Copy Flutter build to Next.js public directory
mkdir -p ../web/public/app
cp -r build/web/* ../web/public/app/
