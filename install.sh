#!/bin/bash
set -euo pipefail

repository="Ic0u/MactoyThemer"
app_name="MactoyThemer"
variant=${MACTOY_VARIANT:-auto}
install_dir=${MACTOY_PREFIX:-/Applications}


expected_team_id=${MACTOY_TEAM_ID:-""}

minimum_macos_major=10
minimum_macos_minor=13

if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
    cyan=$'\033[38;5;45m'
    green=$'\033[38;5;82m'
    yellow=$'\033[38;5;214m'
    red=$'\033[38;5;203m'
    dim=$'\033[2m'
    bold=$'\033[1m'
    reset=$'\033[0m'
else
    cyan="" green="" yellow="" red="" dim="" bold="" reset=""
fi

die() {
    printf '\n  %s%s✗ %s%s\n' "$bold" "$red" "$1" "$reset" >&2
    exit 1
}

warn() {
    printf '  %s! %s%s\n' "$yellow" "$1" "$reset" >&2
}

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

total_steps=7
show_progress() {
    local current=$1
    local label=$2
    local width=24
    local filled=$((current * width / total_steps))
    local empty=$((width - filled))
    printf '  %s[%s%s]%s %s%d/%d%s  %s\n' \
        "$cyan" "$(repeat_character '█' "$filled")" \
        "$(repeat_character '░' "$empty")" "$reset" \
        "$dim" "$current" "$total_steps" "$reset" "$label"
}

print_banner

# ---------------------------------------------------------------- guards ----

[[ "$(/usr/bin/uname -s)" == Darwin ]] || die "$app_name only runs on macOS."

os_version=$(/usr/bin/sw_vers -productVersion)
os_major=${os_version%%.*}
os_rest=${os_version#*.}
os_minor=${os_rest%%.*}
[[ "$os_minor" =~ ^[0-9]+$ ]] || os_minor=0

if (( os_major < minimum_macos_major )) ||
   (( os_major == minimum_macos_major && os_minor < minimum_macos_minor )); then
    die "Requires macOS ${minimum_macos_major}.${minimum_macos_minor} or later (found $os_version)."
fi

[[ -d "$install_dir" ]] || die "Install directory does not exist: $install_dir"

# --------------------------------------------------------- privileges ------

# /Applications is writable by admin users. Only escalate if it genuinely is not.
if [[ -w "$install_dir" ]]; then
    needs_sudo=0
    run_priv() { "$@"; }
else
    needs_sudo=1
    run_priv() { /usr/bin/sudo "$@"; }
    warn "$install_dir is not writable; administrator password required."
    /usr/bin/sudo -v || die "Could not obtain administrator privileges."
fi

# ------------------------------------------------------- architecture ------

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
    *) die "MACTOY_VARIANT must be arm64, x64, or universal." ;;
esac
show_progress 1 "Detected Mac architecture: $variant"

# ------------------------------------------------------------ staging ------

asset="$app_name-mac-$variant.dmg"
base_url="https://github.com/$repository/releases/latest/download"
work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mactoy-installer.XXXXXX")
mount_dir="$work_dir/mount"
dmg="$work_dir/$asset"
destination="$install_dir/$app_name.app"
backup=""
mounted=0

cleanup() {
    local status=$?
    if [[ "$mounted" == 1 ]]; then
        /usr/bin/hdiutil detach "$mount_dir" -quiet -force 2>/dev/null || true
    fi
    # Restore a backed-up install if we were interrupted before the new copy landed.
    if [[ -n "$backup" && -e "$backup" && ! -e "$destination" ]]; then
        warn "Restoring previous installation."
        run_priv /bin/mv "$backup" "$destination" 2>/dev/null || true
    fi
    if [[ -n "$backup" && -e "$backup" ]]; then
        run_priv /bin/rm -rf "$backup" 2>/dev/null || true
    fi
    /bin/rm -rf "$work_dir"
    exit "$status"
}
trap cleanup EXIT INT TERM

curl_common=(--fail --location --show-error --proto '=https' --tlsv1.2
             --connect-timeout 15 --retry 3 --retry-delay 2)

show_progress 2 "Downloading $asset"
/usr/bin/curl "${curl_common[@]}" --progress-bar "$base_url/$asset" --output "$dmg" \
    || die "Download failed. Check your connection or pick a variant with MACTOY_VARIANT."

/usr/bin/curl "${curl_common[@]}" --silent \
    "$base_url/$app_name-SHA256SUMS.txt" --output "$work_dir/SHA256SUMS.txt" \
    || die "Could not fetch the checksum manifest."

# ----------------------------------------------------------- integrity -----

# Tolerate both text (two spaces) and binary (*) checksum formats, and any
# leading path components in the manifest.
expected=$(/usr/bin/awk -v name="$asset" '
    {
        file = $2
        sub(/^\*/, "", file)
        sub(/^.*\//, "", file)
        if (file == name) { print $1; exit }
    }' "$work_dir/SHA256SUMS.txt")

actual=$(/usr/bin/shasum -a 256 "$dmg" | /usr/bin/awk '{ print $1 }')

[[ -n "$expected" ]] || die "No checksum listed for $asset."
[[ "$actual" == "$expected" ]] || die "Checksum mismatch -- the download is corrupt or tampered with."
show_progress 3 "SHA-256 checksum verified"

# ------------------------------------------------------------- signing -----

show_progress 4 "Mounting disk image"
/bin/mkdir "$mount_dir"
/usr/bin/hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount_dir" -quiet \
    || die "Could not mount $asset."
mounted=1

source_app="$mount_dir/$app_name.app"
staged_app="$work_dir/$app_name.app"
[[ -d "$source_app" ]] || die "$app_name.app not found inside the disk image."

/usr/bin/ditto "$source_app" "$staged_app"

show_progress 5 "Verifying code signature"
/usr/bin/codesign --verify --deep --strict --all-architectures "$staged_app" \
    || die "Code signature is invalid. Refusing to install."

# A valid signature alone proves nothing about WHO signed it -- an ad-hoc
# signature passes the check above. Pin the Team ID to prove provenance.
signing_info=$(/usr/bin/codesign -dv --verbose=4 "$staged_app" 2>&1 || true)
actual_team_id=$(printf '%s\n' "$signing_info" | /usr/bin/awk -F'=' '/^TeamIdentifier=/ { print $2; exit }')
authority=$(printf '%s\n' "$signing_info" | /usr/bin/awk -F'=' '/^Authority=/ { print $2; exit }')

if [[ -n "$expected_team_id" ]]; then
    [[ "$actual_team_id" == "$expected_team_id" ]] \
        || die "Unexpected signing team: got '${actual_team_id:-none}', expected '$expected_team_id'."
    printf '  %ssigned by %s (%s)%s\n' "$dim" "${authority:-unknown}" "$actual_team_id" "$reset"
else
    warn "No Team ID pinned -- signature origin is unverified."
    warn "Set MACTOY_TEAM_ID, or edit expected_team_id in this script."
fi

# Gatekeeper assessment: informational. Fails for signed-but-not-notarized apps.
if /usr/sbin/spctl --assess --type execute "$staged_app" >/dev/null 2>&1; then
    notarized=1
else
    notarized=0
    warn "App is not notarized; quarantine will be cleared manually."
fi

# ----------------------------------------------------------- installing ----

if /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1; then
    warn "$app_name is running -- asking it to quit."
    /usr/bin/osascript -e "quit app \"$app_name\"" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1 || break
        /bin/sleep 0.5
    done
    /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1 \
        && die "$app_name is still running. Quit it and retry."
fi

show_progress 6 "Installing in $install_dir"

if [[ -e "$destination" ]]; then
    backup="$install_dir/.$app_name.backup.$$"
    run_priv /bin/mv "$destination" "$backup" || die "Could not move the existing install aside."
fi

if ! run_priv /usr/bin/ditto "$staged_app" "$destination"; then
    run_priv /bin/rm -rf "$destination" 2>/dev/null || true
    die "Install failed."
fi

if (( notarized == 0 )); then
    run_priv /usr/bin/xattr -dr com.apple.quarantine "$destination" 2>/dev/null || true
fi

# Re-verify what actually landed on disk, not just what we staged.
run_priv /usr/bin/codesign --verify --deep --strict --all-architectures "$destination" \
    || die "Installed copy failed signature verification."

if (( needs_sudo == 1 )); then
    # Hand ownership back so Sparkle can self-update without authenticating.
    run_priv /usr/sbin/chown -R "$(/usr/bin/id -un):admin" "$destination" 2>/dev/null || true
fi

if [[ -n "$backup" && -e "$backup" ]]; then
    run_priv /bin/rm -rf "$backup"
    backup=""
fi

installed_version=$(/usr/bin/defaults read "$destination/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")

show_progress 7 "Opening $app_name"
/usr/bin/open "$destination"
printf '\n  %s%s✓ %s %s installed and open.%s\n' \
    "$bold" "$green" "$app_name" "$installed_version" "$reset"
