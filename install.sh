#!/bin/bash
set -e

# Get absolute paths
PROJECT_ROOT=$(pwd)
FLUTTER_SDK="$PROJECT_ROOT/../flutter"

# Install root dependencies (for Vercel framework detection)
cd "$PROJECT_ROOT"
npm install

# Install Next.js app dependencies
cd "$PROJECT_ROOT/apps/web"
npm install

# Clone or update Flutter SDK (parallel to project directory)
if [ -d "$FLUTTER_SDK/.git" ]; then
  echo "Updating existing Flutter SDK..."
  cd "$FLUTTER_SDK"
  git pull
elif [ -d "$FLUTTER_SDK" ]; then
  echo "Removing incomplete Flutter directory..."
  rm -rf "$FLUTTER_SDK"
  echo "Cloning fresh Flutter SDK..."
  cd "$(dirname "$FLUTTER_SDK")"
  git clone https://github.com/flutter/flutter.git flutter
else
  echo "Cloning Flutter SDK..."
  cd "$(dirname "$FLUTTER_SDK")"
  git clone https://github.com/flutter/flutter.git flutter
fi

# Verify Flutter installation
cd "$PROJECT_ROOT"
"$FLUTTER_SDK/bin/flutter" doctor

# Install Flutter dependencies
cd "$PROJECT_ROOT/apps/flutter"
"$FLUTTER_SDK/bin/flutter" pub get
