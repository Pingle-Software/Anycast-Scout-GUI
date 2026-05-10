#!/usr/bin/env bash
set -euo pipefail

if [ -z "${FLUTTER_VERSION:-}" ]; then
  echo "FLUTTER_VERSION is required" >&2
  exit 64
fi

runner_temp="${RUNNER_TEMP:-/tmp}"
path_dir=""

if [ "${RUNNER_OS:-}" = "Windows" ]; then
  runner_temp_posix="$(cygpath -u "$runner_temp")"
else
  runner_temp_posix="$runner_temp"
fi

install_dir="${runner_temp_posix}/flutter-${FLUTTER_VERSION}"

if [ ! -x "${install_dir}/bin/flutter" ]; then
  rm -rf "$install_dir"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$install_dir"
fi

path_dir="${install_dir}/bin"
if [ "${RUNNER_OS:-}" = "Windows" ]; then
  path_dir="$(cygpath -w "$path_dir")"
fi

echo "$path_dir" >>"$GITHUB_PATH"
"${install_dir}/bin/flutter" config --no-analytics
"${install_dir}/bin/flutter" --version
