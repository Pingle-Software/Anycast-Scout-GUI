#!/usr/bin/env bash
set -euo pipefail

echo "=== ci_post_clone.sh - preparing Anycast Scout GUI for Xcode Cloud ==="

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO_ROOT"

if [ -n "${CI_DERIVED_DATA_PATH:-}" ]; then
  XCC_CACHE="$CI_DERIVED_DATA_PATH/.anycast-scout-cache"
else
  XCC_CACHE="$HOME/.anycast-scout-xcode-cloud"
fi

FLUTTER_HOME="$XCC_CACHE/flutter"
export PUB_CACHE="${PUB_CACHE:-$XCC_CACHE/pub-cache}"
export CARGO_HOME="${CARGO_HOME:-$XCC_CACHE/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$XCC_CACHE/rustup}"
mkdir -p "$FLUTTER_HOME" "$PUB_CACHE" "$CARGO_HOME" "$RUSTUP_HOME"

export HOMEBREW_NO_AUTO_UPDATE=1
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  rm -rf "$FLUTTER_HOME"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$CARGO_HOME/bin:$PATH"

flutter --version
flutter config --enable-swift-package-manager 2>/dev/null || true
flutter precache --macos
flutter pub get --offline --enforce-lockfile

RUST_TOOLCHAIN="${ANYCAST_SCOUT_RUST_TOOLCHAIN:-1.95}"
if ! command -v rustup >/dev/null 2>&1; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain "$RUST_TOOLCHAIN"
fi
rustup toolchain install "$RUST_TOOLCHAIN" --profile minimal
rustup default "$RUST_TOOLCHAIN"
rustc --version
cargo --version

BACKEND_REF="${ANYCAST_SCOUT_BACKEND_REF:-}"
if [ -z "$BACKEND_REF" ]; then
  BACKEND_REF="$(tr -d '[:space:]' < "$REPO_ROOT/backend.ref")"
fi
if [ -z "$BACKEND_REF" ]; then
  echo "ANYCAST_SCOUT_BACKEND_REF/backend.ref is empty." >&2
  exit 1
fi

BACKEND_URL="${ANYCAST_SCOUT_BACKEND_URL:-https://gitlab.com/pingle_software/tools/anycast-scout/backend.git}"
BACKEND_DIR="${ANYCAST_SCOUT_BACKEND_DIR:-$(cd "$REPO_ROOT/.." && pwd)/backend-xcode-cloud}"

ASKPASS=""
if [ -n "${ANYCAST_SCOUT_GITLAB_TOKEN:-}" ]; then
  ASKPASS="$XCC_CACHE/git-askpass.sh"
  cat >"$ASKPASS" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' oauth2 ;;
  *) printf '%s\n' "$ANYCAST_SCOUT_GITLAB_TOKEN" ;;
esac
EOF
  chmod 700 "$ASKPASS"
  export GIT_ASKPASS="$ASKPASS"
  export GIT_TERMINAL_PROMPT=0
  CLONE_URL="${BACKEND_URL/https:\/\//https:\/\/oauth2@}"
else
  CLONE_URL="$BACKEND_URL"
fi

if [ ! -d "$BACKEND_DIR/.git" ]; then
  if [ -z "${ANYCAST_SCOUT_GITLAB_TOKEN:-}" ]; then
    echo "ANYCAST_SCOUT_GITLAB_TOKEN is required in Xcode Cloud to clone the backend repo." >&2
    exit 1
  fi
  git clone "$CLONE_URL" "$BACKEND_DIR"
fi

git -C "$BACKEND_DIR" remote set-url origin "$CLONE_URL"
git -C "$BACKEND_DIR" fetch --tags origin
git -C "$BACKEND_DIR" checkout --detach "$BACKEND_REF"
test "$(git -C "$BACKEND_DIR" rev-parse HEAD)" = "$(git -C "$BACKEND_DIR" rev-parse "$BACKEND_REF")"

cargo build --release --locked --manifest-path "$BACKEND_DIR/Cargo.toml"
BACKEND_BIN="$BACKEND_DIR/target/release/anycast-scout"
test -x "$BACKEND_BIN"
"$BACKEND_BIN" --version

BUNDLE_SOURCE="$REPO_ROOT/.xcode-cloud/backend-bundle"
rm -rf "$BUNDLE_SOURCE"
mkdir -p "$BUNDLE_SOURCE/backend"
install -m 755 "$BACKEND_BIN" "$BUNDLE_SOURCE/backend/anycast-scout"
printf '%s\n' "$BACKEND_REF" >"$BUNDLE_SOURCE/backend.ref"

RELEASE_TAG="${CI_TAG:-${CI_COMMIT_TAG:-}}"
if [ -n "$RELEASE_TAG" ]; then
  RELEASE_VERSION="${RELEASE_TAG#release-macos-v}"
  RELEASE_VERSION="${RELEASE_VERSION#v}"
  BUILD_NAME="${RELEASE_VERSION%%+*}"
  BUILD_NUMBER="$(printf '%s' "${CI_BUILD_NUMBER:-1}" | tr -cd '0-9')"
  if [ -z "$BUILD_NUMBER" ]; then
    BUILD_NUMBER="1"
  fi

  GENERATED_XCCONFIG="macos/Flutter/ephemeral/Flutter-Generated.xcconfig"
  TMP_XCCONFIG="${GENERATED_XCCONFIG}.tmp"
  if [ -f "$GENERATED_XCCONFIG" ]; then
    grep -v -E '^(FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER)=' "$GENERATED_XCCONFIG" >"$TMP_XCCONFIG" || true
  else
    : >"$TMP_XCCONFIG"
  fi
  {
    printf 'FLUTTER_BUILD_NAME=%s\n' "$BUILD_NAME"
    printf 'FLUTTER_BUILD_NUMBER=%s\n' "$BUILD_NUMBER"
  } >>"$TMP_XCCONFIG"
  mv "$TMP_XCCONFIG" "$GENERATED_XCCONFIG"
fi

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi
(cd macos && pod install --repo-update)

echo "=== Anycast Scout GUI environment ready for Xcode Cloud ==="
