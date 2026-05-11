#!/usr/bin/env bash
set -euo pipefail

if [ -z "${FLUTTER_VERSION:-}" ]; then
  echo "FLUTTER_VERSION is required" >&2
  exit 64
fi

runner_temp="${RUNNER_TEMP:-/tmp}"
install_dir="${runner_temp}/flutter-${FLUTTER_VERSION}"

if [ ! -x "${install_dir}/bin/flutter" ]; then
  rm -rf "$install_dir"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$install_dir"
fi

echo "${install_dir}/bin" >>"$GITHUB_PATH"
"${install_dir}/bin/flutter" config --no-analytics
"${install_dir}/bin/flutter" --version
