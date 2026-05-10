#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/release/build_local_macos_release.sh [version[+build]]

Builds an ad-hoc signed local macOS ZIP into ../release-artifacts.

If version is omitted, the pubspec.yaml patch version and build number are
incremented by one before building. If a version without +build is provided,
build number defaults to the pubspec.yaml build number.

  Environment:
  ANYCAST_SCOUT_BUNDLE_SOURCE_DIR  optional prebuilt backend bundle source

Example:
  tools/release/build_local_macos_release.sh 1.0.8+2
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PUBSPEC_VERSION="$(sed -n 's/^version: *\([0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*\).*/\1/p' pubspec.yaml | head -n1)"
PUBSPEC_BUILD_NUMBER="$(sed -n 's/^version: *[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*+\([0-9][0-9]*\).*/\1/p' pubspec.yaml | head -n1)"
BUILD_NUMBER="${PUBSPEC_BUILD_NUMBER:-1}"

VERSION_INPUT="${1:-}"
if [ -z "$VERSION_INPUT" ]; then
  if ! [[ "$PUBSPEC_VERSION" =~ ^([0-9]+)[.]([0-9]+)[.]([0-9]+)$ ]]; then
    usage >&2
    exit 64
  fi
  VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))"
  BUILD_NUMBER="$((BUILD_NUMBER + 1))"
  NEXT_FULL_VERSION="$VERSION+$BUILD_NUMBER"
  export NEXT_FULL_VERSION
  perl -0pi -e 's/^version: *[0-9]+[.][0-9]+[.][0-9]+(?:[+][0-9]+)?$/version: $ENV{NEXT_FULL_VERSION}/m' pubspec.yaml
else
  VERSION="$VERSION_INPUT"
fi

if [[ "$VERSION" =~ ^([0-9]+[.][0-9]+[.][0-9]+)[+]([0-9]+)$ ]]; then
  BUILD_NUMBER="${BASH_REMATCH[2]}"
  VERSION="${BASH_REMATCH[1]}"
fi

if ! [[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  usage >&2
  exit 64
fi

BACKEND_VERSION="unknown"
APP_NAME="Anycast Scout by Pingle.app"
APP_PATH="$ROOT/build/macos/Build/Products/Release/$APP_NAME"
ARTIFACT_DIR="$(cd "$ROOT/.." && pwd)/release-artifacts"
ARTIFACT_APP_PATH="$ARTIFACT_DIR/$APP_NAME"
ZIP_PATH="$ARTIFACT_DIR/anycast-scout-gui-macos-adhoc-v$VERSION.zip"

if [ -z "${ANYCAST_SCOUT_BUNDLE_SOURCE_DIR:-}" ]; then
  BACKEND_DIR=""
  for candidate in "$ROOT/../anycast-scout" "$ROOT/../backend"; do
    if [ -f "$candidate/Cargo.toml" ]; then
      BACKEND_DIR="$candidate"
      break
    fi
  done

  if [ -z "$BACKEND_DIR" ]; then
    echo "Failed to find sibling Anycast Scout backend checkout." >&2
    exit 1
  fi

  cargo build --release --locked --manifest-path "$BACKEND_DIR/Cargo.toml"
  BACKEND_VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$BACKEND_DIR/Cargo.toml" | head -n1)"

  BUNDLE_SOURCE="$(mktemp -d)"
  trap 'rm -rf "$BUNDLE_SOURCE"' EXIT
  mkdir -p "$BUNDLE_SOURCE/backend"
  install -m 755 "$BACKEND_DIR/target/release/anycast-scout" \
    "$BUNDLE_SOURCE/backend/anycast-scout"
  export ANYCAST_SCOUT_BUNDLE_SOURCE_DIR="$BUNDLE_SOURCE"
fi

export ANYCAST_SCOUT_REQUIRE_BUNDLE=1

rm -rf "$APP_PATH"
if ! flutter pub get --offline --enforce-lockfile; then
  echo "Flutter package cache is incomplete. Run 'flutter pub get' once, then retry." >&2
  exit 1
fi
flutter build macos --release --no-pub \
  --build-name "$VERSION" \
  --build-number "$BUILD_NUMBER" \
  --dart-define "ANYCAST_SCOUT_GUI_VERSION=$VERSION+$BUILD_NUMBER" \
  --dart-define "ANYCAST_SCOUT_CORE_VERSION=${BACKEND_VERSION:-unknown}"

codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
test -x "$APP_PATH/Contents/Resources/backend/anycast-scout"

mkdir -p "$ARTIFACT_DIR"
rm -rf "$ARTIFACT_APP_PATH"
ditto "$APP_PATH" "$ARTIFACT_APP_PATH"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | sed "s#  .*/#  #" > "$ZIP_PATH.sha256"

printf '%s\n' "$ZIP_PATH"
cat "$ZIP_PATH.sha256"
