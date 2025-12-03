#!/bin/bash
set -e

# Install Next.js dependencies
cd apps/web
npm install

# Clone or update Flutter SDK
if cd ../../flutter; then
  git pull
  cd ../seo_lens
else
  cd ..
  git clone https://github.com/flutter/flutter.git
  cd seo_lens
fi

# Verify Flutter installation
../flutter/bin/flutter doctor

# Install Flutter dependencies
cd apps/flutter
../../flutter/bin/flutter pub get
