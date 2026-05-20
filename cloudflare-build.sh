#!/usr/bin/env bash
# Cloudflare Workers/Pages build step for the Flutter web app.
# Installs the Flutter SDK on a fresh build runner (Cloudflare's
# image doesn't include it) and produces a release web build at
# build/web, which wrangler.toml then deploys.
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo ">>> Cloning Flutter SDK ($FLUTTER_CHANNEL) into $FLUTTER_DIR"
  git clone --depth 1 -b "$FLUTTER_CHANNEL" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"

flutter --version
flutter config --no-analytics --no-cli-animations
flutter pub get
flutter build web --release
