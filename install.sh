#!/bin/bash
set -e

# Install Next.js dependencies
cd apps/web
npm install
cd ../..

# Get the project directory name dynamically
PROJECT_DIR=$(basename "$PWD")

# Clone or update Flutter SDK (parallel to project directory)
if [ -d "../flutter/.git" ]; then
  echo "Updating existing Flutter SDK..."
  cd ../flutter
  git pull
  cd ../$PROJECT_DIR
elif [ -d "../flutter" ]; then
  echo "Removing incomplete Flutter directory..."
  cd ..
  rm -rf flutter
  echo "Cloning fresh Flutter SDK..."
  git clone https://github.com/flutter/flutter.git flutter
  cd $PROJECT_DIR
else
  echo "Cloning Flutter SDK..."
  cd ..
  git clone https://github.com/flutter/flutter.git flutter
  cd $PROJECT_DIR
fi

# Verify Flutter installation
../flutter/bin/flutter doctor

# Install Flutter dependencies
cd apps/flutter
../../flutter/bin/flutter pub get
