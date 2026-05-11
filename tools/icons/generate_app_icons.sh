#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required to render app icons." >&2
  exit 127
fi

mkdir -p assets/icon

magick -background none assets/icon/app_icon.svg \
  -resize 1024x1024 \
  -colorspace sRGB \
  -type TrueColor \
  -alpha remove \
  -alpha off \
  -depth 8 \
  PNG24:assets/icon/app_icon.png

magick -background none assets/icon/app_icon_macos.svg \
  -resize 1024x1024 \
  -colorspace sRGB \
  -type TrueColor \
  -alpha remove \
  -alpha off \
  -depth 8 \
  PNG24:assets/icon/app_icon_macos.png

dart run flutter_launcher_icons
