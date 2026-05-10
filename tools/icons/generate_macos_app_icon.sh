#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICON_DOCUMENT="$ROOT/macos/Runner/Anycast_Scout.icon"
APPICONSET="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
MACOS_MASTER="$ROOT/assets/icon/app_icon_macos.png"
ICTOOL="${ICTOOL:-/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool}"
MAGICK="${MAGICK:-$(command -v magick || true)}"

if [ ! -x "$ICTOOL" ]; then
  echo "Icon Composer ictool was not found at: $ICTOOL" >&2
  echo "Install Xcode with Icon Composer or set ICTOOL to the ictool path." >&2
  exit 1
fi

if [ ! -d "$ICON_DOCUMENT" ]; then
  echo "Icon Composer document was not found: $ICON_DOCUMENT" >&2
  exit 1
fi

if [ -z "$MAGICK" ]; then
  echo "ImageMagick 'magick' was not found." >&2
  echo "Install ImageMagick or set MAGICK to the magick executable path." >&2
  exit 1
fi

mkdir -p "$APPICONSET"

export_icon() {
  local size="$1"
  local output="$2"
  local tmp

  tmp="$(mktemp "${TMPDIR:-/tmp}/anycast-scout-icon.XXXXXX.png")"

  "$ICTOOL" "$ICON_DOCUMENT" \
    --export-image \
    --output-file "$tmp" \
    --platform macOS \
    --rendition Default \
    --width "$size" \
    --height "$size" \
    --scale 1 >/dev/null

  "$MAGICK" "$tmp" -colorspace sRGB -depth 8 "PNG32:$output"
  rm -f "$tmp"
}

export_icon 1024 "$MACOS_MASTER"
for size in 16 32 64 128 256 512 1024; do
  export_icon "$size" "$APPICONSET/app_icon_${size}.png"
done
