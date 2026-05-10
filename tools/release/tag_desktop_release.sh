#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/release/tag_desktop_release.sh <version>

Creates and pushes paired desktop release tags:
  v<version>                 -> GitLab desktop release pipeline
  release-macos-v<version>   -> Xcode Cloud macOS archive

Example:
  tools/release/tag_desktop_release.sh 1.2.3
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

VERSION="${1:-}"
if ! [[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  usage >&2
  exit 64
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty; commit or stash changes before tagging." >&2
  exit 1
fi

GITLAB_TAG="v${VERSION}"
MACOS_TAG="release-macos-v${VERSION}"

for tag in "$GITLAB_TAG" "$MACOS_TAG"; do
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "Tag already exists locally: $tag" >&2
    exit 1
  fi
  if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
    echo "Tag already exists on origin: $tag" >&2
    exit 1
  fi
done

git tag -a "$GITLAB_TAG" -m "Anycast Scout GUI ${GITLAB_TAG}"
git tag -a "$MACOS_TAG" -m "Anycast Scout GUI macOS ${VERSION}"

git push origin "$GITLAB_TAG" "$MACOS_TAG"
