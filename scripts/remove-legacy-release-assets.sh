#!/bin/bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY}"
: "${RELEASE_TAG:?Set RELEASE_TAG}"

assets=$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" \
    --json assets --jq '.assets[].name')
for asset in \
    MactoyThemer.zip \
    MactoyThemer-mac-arm64.zip \
    MactoyThemer-mac-x64.zip \
    MactoyThemer-mac-universal.zip \
    SHA256SUMS.txt
do
    if printf '%s\n' "$assets" | grep -Fxq "$asset"; then
        gh release delete-asset "$RELEASE_TAG" "$asset" \
            --repo "$GITHUB_REPOSITORY" --yes
    fi
done
