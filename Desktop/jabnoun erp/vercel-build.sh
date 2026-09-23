#!/bin/bash

set -e

echo "=== Installing Flutter ==="

git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter

export PATH="$PWD/_flutter/bin:$PATH"

flutter config --enable-web --no-analytics

echo "=== Flutter version ==="
flutter --version

echo "=== Creating .env ==="

printf 'SUPABASE_URL=%s\n' "$SUPABASE_URL" > .env
printf 'SUPABASE_ANON_KEY=%s\n' "$SUPABASE_ANON_KEY" >> .env

echo "=== Installing Flutter dependencies ==="

flutter pub get

echo "=== Building Flutter Web ==="

flutter build web --release

echo "=== Build completed ==="