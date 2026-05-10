#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: download_backend_release.sh <backend-repository> <backend-tag> <platform> <output-dir>

Platforms:
  linux-amd64
  windows-amd64
  macos-universal
EOF
}

if [ "$#" -ne 4 ]; then
  usage >&2
  exit 64
fi

backend_repository="$1"
backend_tag="$2"
platform="$3"
output_dir="$4"

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN is required for gh release download" >&2
  exit 64
fi

checksum_verify() {
  local checksum="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "$checksum"
  else
    shasum -a 256 -c "$checksum"
  fi
}

download_archive() {
  local archive="$1"
  local destination="$2"
  mkdir -p "$destination"
  gh release download "$backend_tag" \
    --repo "$backend_repository" \
    --dir "$destination" \
    --pattern "$archive"
  gh release download "$backend_tag" \
    --repo "$backend_repository" \
    --dir "$destination" \
    --pattern "${archive}.sha256"
  (cd "$destination" && checksum_verify "${archive}.sha256")
}

extract_backend() {
  local archive="$1"
  local source_dir="$2"
  local binary_name="$3"
  local extract_dir="${source_dir}/extract"
  mkdir -p "$extract_dir"
  tar -xzf "${source_dir}/${archive}" -C "$extract_dir"
  test -f "${extract_dir}/${binary_name}"
  printf '%s\n' "${extract_dir}/${binary_name}"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "${output_dir}/backend"

case "$platform" in
  linux-amd64)
    archive="anycast-scout-linux-amd64.tar.gz"
    download_archive "$archive" "$tmp_dir/linux"
    backend_bin="$(extract_backend "$archive" "$tmp_dir/linux" anycast-scout)"
    cp "$backend_bin" "${output_dir}/backend/anycast-scout"
    chmod 755 "${output_dir}/backend/anycast-scout"
    "${output_dir}/backend/anycast-scout" --version
    ;;
  windows-amd64)
    archive="anycast-scout-windows-amd64.tar.gz"
    download_archive "$archive" "$tmp_dir/windows"
    backend_bin="$(extract_backend "$archive" "$tmp_dir/windows" anycast-scout.exe)"
    cp "$backend_bin" "${output_dir}/backend/anycast-scout.exe"
    ;;
  macos-universal)
    download_archive anycast-scout-macos-amd64.tar.gz "$tmp_dir/macos-amd64"
    download_archive anycast-scout-macos-arm64.tar.gz "$tmp_dir/macos-arm64"
    amd64_bin="$(extract_backend anycast-scout-macos-amd64.tar.gz "$tmp_dir/macos-amd64" anycast-scout)"
    arm64_bin="$(extract_backend anycast-scout-macos-arm64.tar.gz "$tmp_dir/macos-arm64" anycast-scout)"
    lipo -create -output "${output_dir}/backend/anycast-scout" "$amd64_bin" "$arm64_bin"
    chmod 755 "${output_dir}/backend/anycast-scout"
    lipo -info "${output_dir}/backend/anycast-scout"
    "${output_dir}/backend/anycast-scout" --version
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

find "$output_dir" -maxdepth 3 -type f -print
