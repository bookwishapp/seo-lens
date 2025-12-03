#!/bin/bash
set -e

# Get absolute paths
PROJECT_ROOT=$(pwd)
FLUTTER_SDK="$PROJECT_ROOT/../flutter"

# Build Next.js app
cd "$PROJECT_ROOT/apps/web"
npm run build

# Build Flutter app
cd "$PROJECT_ROOT/apps/flutter"
"$FLUTTER_SDK/bin/flutter" build web --release --base-href=/app/ --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Copy Flutter build to Next.js public directory
mkdir -p "$PROJECT_ROOT/apps/web/public/app"
cp -r build/web/* "$PROJECT_ROOT/apps/web/public/app/"
