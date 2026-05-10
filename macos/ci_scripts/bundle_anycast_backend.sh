#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${ANYCAST_SCOUT_BUNDLE_SOURCE_DIR:-${SRCROOT}/../.xcode-cloud/backend-bundle}"
RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

require_bundle="${ANYCAST_SCOUT_REQUIRE_BUNDLE:-0}"
if [ "${CI_XCODE_CLOUD:-}" = "TRUE" ] || [ "${CI_XCODE_CLOUD:-}" = "1" ]; then
  require_bundle="1"
fi

if [ ! -d "$SOURCE_DIR" ]; then
  if [ "$require_bundle" = "1" ]; then
    echo "error: Anycast backend bundle source is missing: $SOURCE_DIR" >&2
    exit 1
  fi
  echo "Anycast backend bundle source not found at $SOURCE_DIR; skipping."
  exit 0
fi

BACKEND_BIN="$SOURCE_DIR/backend/anycast-scout"

if [ ! -x "$BACKEND_BIN" ]; then
  echo "error: expected executable backend at $BACKEND_BIN" >&2
  exit 1
fi

mkdir -p "$RESOURCES_DIR/backend"
install -m 755 "$BACKEND_BIN" "$RESOURCES_DIR/backend/anycast-scout"

test -x "$RESOURCES_DIR/backend/anycast-scout"

echo "Bundled Anycast backend into $RESOURCES_DIR"
