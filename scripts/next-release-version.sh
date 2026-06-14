#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUMP="${SHOTLENS_VERSION_BUMP:-minor}"

latest_tag="$(git -C "$ROOT_DIR" tag --list 'v[0-9]*' --sort=-v:refname | head -n 1 || true)"
if [[ -z "$latest_tag" ]]; then
  echo "v1.0.0"
  exit 0
fi

if [[ ! "$latest_tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Latest release tag must use three-part semver like v1.2.3, got: $latest_tag" >&2
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

case "$BUMP" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    echo "SHOTLENS_VERSION_BUMP must be major, minor, or patch; got: $BUMP" >&2
    exit 1
    ;;
esac

echo "v$major.$minor.$patch"
