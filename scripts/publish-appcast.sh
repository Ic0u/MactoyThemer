#!/bin/bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repo}"
: "${RELEASE_TAG:?Set RELEASE_TAG to an existing release tag}"


# Restrict tags to version-like names so they can be used directly in asset URLs.
if [[ ! "$RELEASE_TAG" =~ ^v?[0-9]+(\.[0-9]+)*([-+][A-Za-z0-9.-]+)?$ ]]; then
    echo "Expected a version tag such as v1.2.0." >&2
    exit 1
fi

release_state=$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json isPrerelease --jq .isPrerelease)
if [[ "$release_state" == true ]]; then
    echo "The stable appcast does not publish prereleases." >&2
    exit 1
fi

# A draft can already contain its signed feed before it is published.
# Leave those assets alone, including when GitHub release immutability is enabled.
if [[ "${GITHUB_EVENT_NAME:-}" == release || "${PRESERVE_EXISTING_APPCAST:-}" == true ]] && \
   [[ "$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json assets --jq '[.assets[].name] | index("appcast.xml") != null')" == true ]]; then
    echo "The release already contains appcast.xml."
    exit 0
fi

: "${SPARKLE_PRIVATE_KEY:?Configure the SPARKLE_PRIVATE_KEY Actions secret}"
: "${SPARKLE_BIN:?Set SPARKLE_BIN to the resolved Sparkle bin directory}"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mkdir "$work_dir/updates"
archive_name=${SPARKLE_ARCHIVE_NAME:-MactoyThemer.zip}
case "$archive_name" in
    MactoyThemer.zip|MactoyThemer-mac-universal.zip) ;;
    *) echo "The stable feed requires the universal archive." >&2; exit 1 ;;
esac
gh release download "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" \
    --pattern "$archive_name" --dir "$work_dir/updates"

# Verify the distributed app was configured for this repository before signing.
python3 - "$work_dir/updates/$archive_name" <<'PY'
import base64
import os
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    info = plistlib.loads(archive.read("MactoyThemer.app/Contents/Info.plist"))
expected = f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/releases/latest/download/appcast.xml"
if info.get("SUFeedURL") != expected:
    raise SystemExit("Release app has the wrong SUFeedURL. Rebuild with SPARKLE_GITHUB_REPOSITORY set.")
try:
    key = base64.b64decode(info.get("SUPublicEDKey", ""), validate=True)
except ValueError:
    raise SystemExit("Release app has an invalid Sparkle public key.")
if len(key) != 32:
    raise SystemExit("Release app is missing its Sparkle public key.")
PY

# Read the secret through stdin; never print it or put it on the command line.
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix "https://github.com/$GITHUB_REPOSITORY/releases/download/$RELEASE_TAG/" \
    -o "$work_dir/updates/appcast.xml" "$work_dir/updates"

python3 - "$work_dir/updates/appcast.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

items = ET.parse(sys.argv[1]).findall("./channel/item/enclosure")
signature = "{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature"
if len(items) != 1 or not items[0].get(signature):
    raise SystemExit("Expected one signed release archive in the appcast.")
PY

gh release upload "$RELEASE_TAG" "$work_dir/updates/appcast.xml" \
    --repo "$GITHUB_REPOSITORY" --clobber
