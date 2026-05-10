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

magick -background none assets/icon/app_icon_windows.svg \
  -resize 1024x1024 \
  -colorspace sRGB \
  -type TrueColorAlpha \
  -depth 8 \
  PNG32:assets/icon/app_icon_windows.png

dart run flutter_launcher_icons

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# flutter_launcher_icons exposes one Windows icon size. Pack the common Win32
# layers into the final ICO so Windows can choose exact matches instead of
# scaling a single 256px image.
for size in 16 24 32 48 256; do
  magick assets/icon/app_icon_windows.png \
    -resize "${size}x${size}" \
    -colorspace sRGB \
    -type TrueColorAlpha \
    -depth 8 \
    PNG32:"$tmp_dir/app_icon_${size}.png"
done

magick \
  "$tmp_dir/app_icon_16.png" \
  "$tmp_dir/app_icon_24.png" \
  "$tmp_dir/app_icon_32.png" \
  "$tmp_dir/app_icon_48.png" \
  "$tmp_dir/app_icon_256.png" \
  windows/runner/resources/app_icon.ico
