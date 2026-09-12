#!/bin/bash
set -euo pipefail

repository="Ic0u/MactoyThemer"
variant=${MACTOY_VARIANT:-auto}

if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
    cyan=$'\033[38;5;45m'
    green=$'\033[38;5;82m'
    dim=$'\033[2m'
    bold=$'\033[1m'
    reset=$'\033[0m'
else
    cyan=""
    green=""
    dim=""
    bold=""
    reset=""
fi

print_banner() {
    printf '%s' "$cyan"
    printf '%s\n' \
        '▓▒░▀▄             ▄▀▄ ▄▀▄ ▀█▀ ▄▀▄ █ ▒ ▄▓▒░░░░░▒▓▓▒░░▒▓ █ ▒ ▄▀▀ █▀▄▀▄ ▄▀▀ █▀▄' \
        '▒▒░░█▀▄  ▄▀▄      ▓▄▓ ▓    ▓  ▓ ▓  ▀▓  ▀▀▀▀▀▀█▒░█▀▀▀▀▀ ▓▀▓ ▓▀  ▓ ▓ ▓ ▓▀  ▓▄▀' \
        '▒░░▄███▀▀███▀▄    ▒ ▒ ▀▄▀  ▒  ▀▄▀ ▒▄▀      ▄▀▒░▄▀      ▒ █ ▀▄▄ ▒ ▀ ▒ ▀▄▄ ▒ █' \
        '░█▒ ▀▄░▒█▄▀▄██░▄                         ▄▀██▄▀' \
        '█▓▒   ▒░█   █░▒▓█                      ▄▀██▄▀' \
        '░▒▓   ░▄▀ ▄▀██▓▀                      █▒░▄▀' \
        '▀▀▀       ▄█▄▀                         ▀▀'
    printf '%s\n\n' "$reset"
}

repeat_character() {
    local character=$1
    local count=$2
    local output=""
    while [[ "$count" -gt 0 ]]; do
        output="$output$character"
        count=$((count - 1))
    done
    printf '%s' "$output"
}

show_progress() {
    local current=$1
    local label=$2
    local total=6
    local width=24
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local filled_bar
    local empty_bar
    filled_bar=$(repeat_character '█' "$filled")
    empty_bar=$(repeat_character '░' "$empty")
    printf '  %s[%s%s]%s %s%d/%d%s  %s\n' \
        "$cyan" "$filled_bar" "$empty_bar" "$reset" \
        "$dim" "$current" "$total" "$reset" "$label"
}

print_banner

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
show_progress 1 "Detected Mac architecture: $variant"

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

show_progress 2 "Downloading MactoyThemer-mac-$variant.dmg"
/usr/bin/curl --fail --location --progress-bar --show-error \
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
show_progress 3 "SHA-256 checksum verified"

show_progress 4 "Mounting and verifying the app"
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
show_progress 5 "Installing in /Applications"
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

show_progress 6 "Opening MactoyThemer"
/usr/bin/open "$destination"
printf '\n  %s%s✓ MactoyThemer is installed and open.%s\n' "$bold" "$green" "$reset"
