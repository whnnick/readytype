#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="$(plutil -extract CFBundleShortVersionString raw ReadyType/ReadyType/Resources/ReadyTypeInfo.plist)"
TAG="${1:-v$VERSION}"
REPOSITORY="${READYTYPE_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
BLACK_BOX_ZH="docs/versions/$VERSION/BLACK_BOX_TESTS.zh-CN.md"
BLACK_BOX_EN="docs/versions/$VERSION/BLACK_BOX_TESTS.md"

fail() {
  echo "Release-state check failed: $1" >&2
  exit 1
}

[[ "$TAG" == "v$VERSION" ]] || fail "tag $TAG does not match app version $VERSION"
git rev-parse --verify "$TAG" >/dev/null 2>&1 || fail "local tag $TAG is missing"

TAG_COMMIT="$(git rev-list -n 1 "$TAG")"
REMOTE_COMMIT="$(gh api "repos/$REPOSITORY/commits/$TAG" --jq .sha)"
[[ "$TAG_COMMIT" == "$REMOTE_COMMIT" ]] || fail "local and remote tag commits differ"

LATEST_TAG="$(gh api "repos/$REPOSITORY/releases/latest" --jq .tag_name)"
[[ "$LATEST_TAG" == "$TAG" ]] || fail "latest release is $LATEST_TAG, expected $TAG"

gh release view "$TAG" --repo "$REPOSITORY" --json isDraft,isPrerelease \
  --jq 'select(.isDraft == false and .isPrerelease == false)' | grep -q . \
  || fail "$TAG is draft or prerelease"

ASSETS="$(gh release view "$TAG" --repo "$REPOSITORY" --json assets --jq '.assets[].name')"
for asset in ReadyType.app.zip ReadyType.dmg SHA256SUMS.txt; do
  grep -Fxq "$asset" <<<"$ASSETS" || fail "missing release asset $asset"
done

grep -Fq "version-$VERSION-green" README.md || fail "README badge does not show $VERSION"
grep -Fq "version-$VERSION-green" README.zh-CN.md || fail "Chinese README badge does not show $VERSION"
grep -Fq "## $VERSION" CHANGELOG.md || fail "English changelog is missing $VERSION"
grep -Fq "## $VERSION" CHANGELOG.zh-CN.md || fail "Chinese changelog is missing $VERSION"
grep -Fq "$TAG" "$BLACK_BOX_ZH" || fail "Chinese black-box record is missing $TAG"
grep -Fq "$TAG" "$BLACK_BOX_EN" || fail "English black-box record is missing $TAG"

echo "Release state verified: $REPOSITORY $TAG ($TAG_COMMIT)"
