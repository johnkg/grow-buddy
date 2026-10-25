#!/bin/bash
# Installs Flutter (pinned to CI's version) in Claude Code cloud sessions.
# The Node server is zero-dep, so it needs nothing beyond the preinstalled node.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION=3.47.4
FLUTTER_HOME="$HOME/flutter"

if ! "$FLUTTER_HOME/bin/flutter" --version 2>/dev/null | grep -q "Flutter $FLUTTER_VERSION "; then
  rm -rf "$FLUTTER_HOME"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xf "$tmp/flutter.tar.xz" -C "$HOME"
  rm -rf "$tmp"
fi

# Tarball is owned by another uid; git refuses to run in it otherwise.
git config --global --get-all safe.directory | grep -qx "$FLUTTER_HOME" \
  || git config --global --add safe.directory "$FLUTTER_HOME"

export PATH="$FLUTTER_HOME/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

flutter config --no-analytics >/dev/null
flutter precache --web >/dev/null
cd "$CLAUDE_PROJECT_DIR/grow_buddy_client"
flutter pub get
