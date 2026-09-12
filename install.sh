#!/bin/bash
set -euo pipefail

repository="Ic0u/MactoyThemer"
variant=${MACTOY_VARIANT:-auto}

if [[ "$variant" == auto ]]; then
    translated=$(/usr/sbin/sysctl -in sysctl.proc_translated 2>/dev/null || true)
    if [[ "$(/usr/bin/uname -m)" == arm64 || "$translated" == 1 ]]; then
        variant=arm64
    else
        variant=x64
    fi
fi

case "$variant" in
    arm64|x64|universal) ;;
    *) echo "MACTOY_VARIANT must be arm64, x64, or universal." >&2; exit 1 ;;
esac

asset="MactoyThemer-mac-$variant.dmg"
base_url="https://github.com/$repository/releases/latest/download"
work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mactoy-installer.XXXXXX")
mount_dir="$work_dir/mount"
dmg="$work_dir/$asset"
mounted=0

cleanup() {
    if [[ "$mounted" == 1 ]]; then
        /usr/bin/hdiutil detach "$mount_dir" -quiet || true
    fi
    /bin/rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

echo "Downloading MactoyThemer for $variant…"
/usr/bin/curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 "$base_url/$asset" --output "$dmg"
/usr/bin/curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 "$base_url/MactoyThemer-SHA256SUMS.txt" \
    --output "$work_dir/SHA256SUMS.txt"

expected=$(/usr/bin/awk -v name="$asset" '$2 == name { print $1 }' "$work_dir/SHA256SUMS.txt")
actual=$(/usr/bin/shasum -a 256 "$dmg" | /usr/bin/awk '{ print $1 }')
if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    echo "Download checksum verification failed." >&2
    exit 1
fi

/bin/mkdir "$mount_dir"
/usr/bin/hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount_dir" -quiet
mounted=1
source_app="$mount_dir/MactoyThemer.app"
staged_app="$work_dir/MactoyThemer.app"
test -d "$source_app"
/usr/bin/ditto "$source_app" "$staged_app"
/usr/bin/codesign --verify --deep --strict --all-architectures "$staged_app"

# Remove quarantine from this verified app only, then replace an older install.
/usr/bin/xattr -dr com.apple.quarantine "$staged_app" 2>/dev/null || true
destination="/Applications/MactoyThemer.app"
backup="/Applications/.MactoyThemer.backup.$$"
/usr/bin/sudo -v
if [[ -e "$destination" ]]; then
    /usr/bin/sudo /bin/mv "$destination" "$backup"
fi
if ! /usr/bin/sudo /usr/bin/ditto "$staged_app" "$destination"; then
    /usr/bin/sudo /bin/rm -rf "$destination"
    if [[ -e "$backup" ]]; then
        /usr/bin/sudo /bin/mv "$backup" "$destination"
    fi
    exit 1
fi
/usr/bin/sudo /usr/bin/xattr -dr com.apple.quarantine "$destination" 2>/dev/null || true
/usr/bin/sudo /usr/bin/codesign --verify --deep --strict --all-architectures "$destination"
if [[ -e "$backup" ]]; then
    /usr/bin/sudo /bin/rm -rf "$backup"
fi

/usr/bin/open "$destination"
echo "MactoyThemer is installed in /Applications and open."
