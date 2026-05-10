#!/usr/bin/env bash
set -euo pipefail

echo "=== ci_post_xcodebuild.sh ==="

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
  echo "Not an archive build (action=${CI_XCODEBUILD_ACTION:-unknown}), skipping."
  exit 0
fi

if [ "${CI_XCODEBUILD_EXIT_CODE:-0}" != "0" ]; then
  echo "xcodebuild failed (exit=${CI_XCODEBUILD_EXIT_CODE}); skipping notarization."
  exit 0
fi

APP_PATH="${CI_DEVELOPER_ID_SIGNED_APP_PATH:-}"
if [ -z "$APP_PATH" ]; then
  for candidate in \
    "${CI_ARCHIVE_PRODUCTS_PATH:-}/Applications"/*.app \
    "${CI_ARCHIVE_PATH:-}/Products/Applications"/*.app; do
    if [ -d "$candidate" ]; then
      APP_PATH="$candidate"
      break
    fi
  done
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "No archived .app found; no Developer ID app to notarize."
  exit 0
fi

BACKEND_BIN="$APP_PATH/Contents/Resources/backend/anycast-scout"
test -x "$BACKEND_BIN"

APP_NAME="$(basename "$APP_PATH" .app)"
ARTIFACT_ROOT="${CI_WORKSPACE_PATH:-$(pwd)}/anycast-scout-artifacts"
mkdir -p "$ARTIFACT_ROOT"

echo "Validating Developer ID signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH" || true

NOTARY_AUTH_ARGS=()
NOTARY_TEMP_DIR=""
NOTARY_PROFILE="${ANYCAST_SCOUT_NOTARY_KEYCHAIN_PROFILE:-}"
NOTARY_KEY_B64="${ANYCAST_SCOUT_NOTARY_PRIVATE_KEY_B64:-}"
NOTARY_KEY_TEXT="${ANYCAST_SCOUT_NOTARY_PRIVATE_KEY:-}"
NOTARY_KEY_ID="${ANYCAST_SCOUT_NOTARY_KEY_ID:-T26WGR4HML}"
NOTARY_ISSUER_ID="${ANYCAST_SCOUT_NOTARY_ISSUER_ID:-5ccd33ce-d5ef-4a45-8c46-1121af557dbf}"

cleanup_notary_temp_dir() {
  if [ -n "$NOTARY_TEMP_DIR" ]; then
    rm -rf "$NOTARY_TEMP_DIR"
  fi
}
trap cleanup_notary_temp_dir EXIT

if [ -n "$NOTARY_PROFILE" ]; then
  NOTARY_AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  echo "Using notarytool keychain profile."
elif [ -n "$NOTARY_KEY_B64" ] || [ -n "$NOTARY_KEY_TEXT" ]; then
  if [ -z "$NOTARY_KEY_ID" ] || [ -z "$NOTARY_ISSUER_ID" ]; then
    echo "ANYCAST_SCOUT_NOTARY_KEY_ID and ANYCAST_SCOUT_NOTARY_ISSUER_ID are required for API key notarization."
    exit 1
  fi
  NOTARY_TEMP_DIR="$(mktemp -d)"
  NOTARY_KEY_FILE="$NOTARY_TEMP_DIR/AuthKey_${NOTARY_KEY_ID}.p8"
  if [ -n "$NOTARY_KEY_B64" ]; then
    if ! printf '%s' "$NOTARY_KEY_B64" | base64 --decode >"$NOTARY_KEY_FILE" 2>/dev/null; then
      printf '%s' "$NOTARY_KEY_B64" | base64 -D >"$NOTARY_KEY_FILE"
    fi
  else
    printf '%s\n' "$NOTARY_KEY_TEXT" >"$NOTARY_KEY_FILE"
  fi
  chmod 600 "$NOTARY_KEY_FILE"
  NOTARY_AUTH_ARGS=(--key "$NOTARY_KEY_FILE" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
  echo "Using App Store Connect API key for notarization."
else
  echo "Notary credentials are not configured; skipping notarization."
  exit 0
fi

UNSTAPLED_ZIP="$ARTIFACT_ROOT/${APP_NAME}-${CI_TAG:-untagged}-${CI_BUILD_NUMBER:-0}-developer-id.zip"
STAPLED_ZIP="$ARTIFACT_ROOT/${APP_NAME}-${CI_TAG:-untagged}-${CI_BUILD_NUMBER:-0}-developer-id-notarized.zip"
NOTARY_RESULT="$ARTIFACT_ROOT/notary-submit-${CI_BUILD_ID:-local}.json"
NOTARY_LOG="$ARTIFACT_ROOT/notary-log-${CI_BUILD_ID:-local}.json"

echo "Creating notarization ZIP: $UNSTAPLED_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$UNSTAPLED_ZIP"

NOTARY_ARGS=("${NOTARY_AUTH_ARGS[@]}" --wait)
if [ -n "${ANYCAST_SCOUT_NOTARY_WEBHOOK_URL:-}" ]; then
  NOTARY_ARGS+=(--webhook "$ANYCAST_SCOUT_NOTARY_WEBHOOK_URL")
fi
if [ "${ANYCAST_SCOUT_NOTARY_NO_S3_ACCELERATION:-0}" = "1" ]; then
  NOTARY_ARGS+=(--no-s3-acceleration)
fi

echo "Submitting app to notarization service..."
xcrun notarytool submit "$UNSTAPLED_ZIP" "${NOTARY_ARGS[@]}" \
  --output-format json | tee "$NOTARY_RESULT"

SUBMISSION_ID="$(/usr/bin/plutil -extract id raw -o - "$NOTARY_RESULT" 2>/dev/null || true)"
if [ -n "$SUBMISSION_ID" ]; then
  xcrun notarytool log "$SUBMISSION_ID" \
    "${NOTARY_AUTH_ARGS[@]}" "$NOTARY_LOG" || true
fi

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "Creating stapled distribution ZIP: $STAPLED_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$STAPLED_ZIP"

echo "Notarized artifact: $STAPLED_ZIP"
echo "=== post-xcodebuild complete ==="
