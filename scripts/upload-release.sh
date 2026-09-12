#!/bin/bash
set -euo pipefail

output_dir=${1:?Expected the directory containing all three downloads}
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY}"
: "${RELEASE_TAG:?Set RELEASE_TAG}"
: "${GITHUB_OUTPUT:?Set GITHUB_OUTPUT}"

# Complete the matrix before touching release assets.
for variant in arm64 x64 universal; do
    test -s "$output_dir/MactoyThemer-mac-$variant.zip"
done

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
gh release list --repo "$GITHUB_REPOSITORY" --limit 1000 --json tagName > "$work_dir/releases.json"
if ! python3 - "$work_dir/releases.json" "$RELEASE_TAG" <<'PY'
import json
import sys
sys.exit(0 if any(r["tagName"] == sys.argv[2] for r in json.load(open(sys.argv[1]))) else 1)
PY
then
    cat > "$work_dir/notes.md" <<'NOTES'
Download the ZIP for your Mac, unzip it, and move MactoyThemer.app to Applications.

- **Mac (arm64):** Apple Silicon, macOS 11 or later.
- **Mac (x64):** Intel, macOS 10.13 or later.
- **Mac Universal:** both architectures; used by Sparkle for updates.

These GitHub Actions builds are ad-hoc signed and not notarized by Apple. macOS Gatekeeper may block them when first opened.

MactoyThemer-SHA256SUMS.txt contains the download checksums.
NOTES
    gh release create "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --verify-tag \
        --draft --title "MactoyThemer ${RELEASE_TAG#v}" --notes-file "$work_dir/notes.md"
fi

gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" \
    --json isDraft,isImmutable,isPrerelease,assets > "$work_dir/release.json"
python3 - "$work_dir/release.json" "$GITHUB_OUTPUT" <<'PY'
import json
import sys
release = json.load(open(sys.argv[1]))
if release["isImmutable"] or release["isPrerelease"]:
    raise SystemExit("Expected an editable stable release.")
with open(sys.argv[2], "a") as output:
    output.write(f"draft={str(release['isDraft']).lower()}\n")
PY

# Keep already-published files intact on retries. Use their bytes for checksums.
for variant in arm64 x64 universal; do
    asset="MactoyThemer-mac-$variant.zip"
    if python3 - "$work_dir/release.json" "$asset" <<'PY'
import json
import sys
sys.exit(0 if any(a["name"] == sys.argv[2] for a in json.load(open(sys.argv[1]))["assets"]) else 1)
PY
    then
        gh release download "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" \
            --pattern "$asset" --dir "$output_dir" --clobber
    else
        gh release upload "$RELEASE_TAG" "$output_dir/$asset" --repo "$GITHUB_REPOSITORY"
    fi
done

python3 - "$output_dir" <<'PY'
from pathlib import Path
import hashlib
import sys
root = Path(sys.argv[1])
lines = []
for variant in ("arm64", "x64", "universal"):
    archive = root / f"MactoyThemer-mac-{variant}.zip"
    lines.append(f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")
(root / "MactoyThemer-SHA256SUMS.txt").write_text("".join(lines))
PY
gh release upload "$RELEASE_TAG" "$output_dir/MactoyThemer-SHA256SUMS.txt" \
    --repo "$GITHUB_REPOSITORY" --clobber
