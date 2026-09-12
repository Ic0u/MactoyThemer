#!/bin/bash
set -euo pipefail

repository="Ic0u/MactoyThemer"
app_name="MactoyThemer"
variant=${MACTOY_VARIANT:-auto}
install_dir=${MACTOY_PREFIX:-/Applications}
verbose=${MACTOY_DEBUG:-0}

# Pin your Apple Developer Team ID here. Find it with:
#   codesign -dv --verbose=4 /Applications/MactoyThemer.app 2>&1 | grep TeamIdentifier
# Empty means the installer cannot prove the app is really yours.
expected_team_id=${MACTOY_TEAM_ID:-""}

minimum_macos_major=10
minimum_macos_minor=13

if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
    accent=$'\033[38;5;'"${MACTOY_ACCENT:-45}"'m'
    green=$'\033[38;5;78m'
    red=$'\033[38;5;203m'
    track=$'\033[38;5;238m'
    dim=$'\033[2m'
    bold=$'\033[1m'
    reset=$'\033[0m'
    clear_line=$'\033[K'
    columns=$(/usr/bin/tput cols 2>/dev/null || echo 80)
    interactive=1
else
    accent="" green="" red="" track="" dim="" bold="" reset="" clear_line=""
    columns=80
    interactive=0
fi
[[ "$columns" =~ ^[0-9]+$ ]] || columns=80

indent="  "

# ------------------------------------------------------------- output ------

die() {
    printf '\n%s\n' "${indent}${bold}${red}${1}${reset}" >&2
    [[ -n "${2:-}" ]] && printf '%s\n' "${indent}${dim}${2}${reset}" >&2
    exit 1
}

# Maintainer-facing. Hidden unless MACTOY_DEBUG=1 -- a user can't act on these.
debug() {
    (( verbose == 1 )) || return 0
    printf '%s\n' "${indent}${dim}· ${1}${reset}" >&2
}

repeat_character() {
    local character=$1 count=$2 output=""
    while [[ "$count" -gt 0 ]]; do
        output="$output$character"
        count=$((count - 1))
    done
    printf '%s' "$output"
}

if (( columns < 78 )); then bar_width=14; else bar_width=32; fi

# ONE bar for the whole install. Redrawn in place; the label says what's
# happening. Percent budget: download 0-70, verify 70-90, install 90-100.
progress() {
    local pct=$1 label=$2

    if (( interactive == 0 )); then
        printf '%s\n' "${indent}${label}"
        return 0
    fi

    (( pct > 100 )) && pct=100
    (( pct < 0 )) && pct=0
    local filled=$(( bar_width * pct / 100 ))
    local empty=$(( bar_width - filled ))

    local available=$(( columns - bar_width - 8 ))
    (( available < 12 )) && available=12
    (( ${#label} > available )) && label="${label:0:$((available - 2))}.."

    local bar="${accent}$(repeat_character '█' "$filled")${track}$(repeat_character '█' "$empty")"
    # Single argument: no specifier/argument count to get wrong.
    printf '%s\r' "${indent}${dim}[${bar}${dim}]${reset}  ${label}${clear_line}"
}

progress_clear() {
    (( interactive == 1 )) && printf '\r%s' "$clear_line"
    return 0
}

print_banner() {
    local line
    if (( columns < 78 )); then
        printf '\n%s\n\n' "${indent}${bold}${accent}${app_name}${reset}"
        return 0
    fi
    printf '\n%s' "$accent"
    while IFS= read -r line; do
        printf '%s\n' "${indent}${line}"
    done <<'ART'
▓▒░▀▄             ▄▀▄ ▄▀▄ ▀█▀ ▄▀▄ █ ▒ ▄▓▒░░░░░▒▓▓▒░░▒▓ █ ▒ ▄▀▀ █▀▄▀▄ ▄▀▀ █▀▄
▒▒░░█▀▄  ▄▀▄      ▓▄▓ ▓    ▓  ▓ ▓  ▀▓  ▀▀▀▀▀▀█▒░█▀▀▀▀▀ ▓▀▓ ▓▀  ▓ ▓ ▓ ▓▀  ▓▄▀
▒░░▄███▀▀███▀▄    ▒ ▒ ▀▄▀  ▒  ▀▄▀ ▒▄▀      ▄▀▒░▄▀      ▒ █ ▀▄▄ ▒ ▀ ▒ ▀▄▄ ▒ █
░█▒ ▀▄░▒█▄▀▄██░▄                         ▄▀██▄▀
█▓▒   ▒░█   █░▒▓█                      ▄▀██▄▀
░▒▓   ░▄▀ ▄▀██▓▀                      █▒░▄▀
▀▀▀       ▄█▄▀                         ▀▀
ART
    printf '%s\n' "$reset"
}

# ------------------------------------------------------------- guards ------

[[ "$(/usr/bin/uname -s)" == Darwin ]] || die "$app_name only runs on macOS."

os_version=$(/usr/bin/sw_vers -productVersion)
os_major=${os_version%%.*}
os_rest=${os_version#*.}
os_minor=${os_rest%%.*}
[[ "$os_minor" =~ ^[0-9]+$ ]] || os_minor=0

if (( os_major < minimum_macos_major )) ||
   (( os_major == minimum_macos_major && os_minor < minimum_macos_minor )); then
    die "$app_name needs macOS ${minimum_macos_major}.${minimum_macos_minor} or later." \
        "You're running macOS $os_version."
fi

[[ -d "$install_dir" ]] || die "Can't find $install_dir."

print_banner

if [[ -w "$install_dir" ]]; then
    needs_sudo=0
    run_priv() { "$@"; }
else
    needs_sudo=1
    run_priv() { /usr/bin/sudo "$@"; }
    printf '%s\n\n' "${indent}${dim}Administrator password needed to install.${reset}"
    /usr/bin/sudo -v || die "Installation cancelled."
fi

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
debug "architecture: $variant"

# ------------------------------------------------------------ staging ------

asset="$app_name-mac-$variant.dmg"
base_url="https://github.com/$repository/releases/latest/download"
# TMPDIR ends with a slash on macOS; normalize so the sweep's glob produces
# the same spelling as mktemp did.
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work_dir=$(/usr/bin/mktemp -d "$tmp_root/mactoy-installer.XXXXXX")
mount_dir="$work_dir/mount"
dmg="$work_dir/$asset"
destination="$install_dir/$app_name.app"
backup=""
mounted=0

cleanup() {
    local status=$?
    progress_clear

    if [[ "$mounted" == 1 ]]; then
        for _ in 1 2 3; do
            /usr/bin/hdiutil detach "$mount_dir" -quiet 2>/dev/null && break
            /bin/sleep 0.3
        done
        /usr/sbin/diskutil info "$mount_dir" >/dev/null 2>&1 \
            && /usr/bin/hdiutil detach "$mount_dir" -quiet -force 2>/dev/null || true
    fi

    if [[ -n "$backup" && -e "$backup" && ! -e "$destination" ]]; then
        run_priv /bin/mv "$backup" "$destination" 2>/dev/null || true
        debug "restored the previous version after an interrupted install"
    fi
    if [[ -n "$backup" && -e "$backup" ]]; then
        run_priv /bin/rm -rf "$backup" 2>/dev/null || true
    fi

    /bin/rm -rf "$work_dir" 2>/dev/null || true
    debug "removed temporary files"
    exit "$status"
}
trap cleanup EXIT INT TERM

# A run killed with SIGKILL or by power loss never fires the trap above, so it
# leaves a mounted image, a temp dir, or a backup behind. Sweep those now.
sweep_leftovers() {
    local leftover swept=0

    for leftover in "$tmp_root"/mactoy-installer.*; do
        [[ -d "$leftover" ]] || continue
        # Inode comparison, not string comparison -- path spelling ("//" vs "/",
        # symlinked temp roots) must never let this delete the current run's dir.
        [[ "$leftover" -ef "$work_dir" ]] && continue
        if /usr/sbin/diskutil info "$leftover/mount" >/dev/null 2>&1; then
            /usr/bin/hdiutil detach "$leftover/mount" -quiet -force 2>/dev/null || true
        fi
        /bin/rm -rf "$leftover" 2>/dev/null || true
        swept=$((swept + 1))
    done

    for leftover in "$install_dir"/."$app_name".backup.*; do
        [[ -e "$leftover" ]] || continue
        # If the app is missing, that backup IS the user's only copy.
        if [[ ! -e "$destination" ]]; then
            run_priv /bin/mv "$leftover" "$destination" 2>/dev/null || true
            debug "restored an interrupted install from backup"
        else
            run_priv /bin/rm -rf "$leftover" 2>/dev/null || true
        fi
        swept=$((swept + 1))
    done

    (( swept > 0 )) && debug "cleaned up $swept leftover item(s) from a previous run"
    return 0
}
sweep_leftovers

curl_common=(--fail --location --show-error --proto '=https' --tlsv1.2
             --connect-timeout 15 --retry 3 --retry-delay 2)

# --------------------------------------------------------- downloading -----

progress 0 "Downloading"

total_bytes=$(/usr/bin/curl "${curl_common[@]}" --silent --head "$base_url/$asset" 2>/dev/null \
    | /usr/bin/awk 'BEGIN { IGNORECASE = 1 }
                    /^content-length:/ { gsub(/\r/, ""); value = $2 }
                    END { if (value ~ /^[0-9]+$/) print value }' || true)

if (( interactive == 1 )); then
    # curl --progress-bar draws its own full-width bar at column 0 and wrecks
    # the layout, so download quietly and drive our bar from the file size.
    /usr/bin/curl "${curl_common[@]}" --silent "$base_url/$asset" --output "$dmg" &
    curl_pid=$!
    while kill -0 "$curl_pid" 2>/dev/null; do
        if [[ -n "$total_bytes" && "$total_bytes" -gt 0 && -f "$dmg" ]]; then
            got=$(/usr/bin/stat -f%z "$dmg" 2>/dev/null || echo 0)
            pct=$(( got * 100 / total_bytes ))
            (( pct > 100 )) && pct=100
            progress $(( pct * 70 / 100 )) "Downloading  ${pct}%"
        fi
        /bin/sleep 0.1
    done
    wait "$curl_pid" || die "Download failed." "Check your internet connection and try again."
else
    /usr/bin/curl "${curl_common[@]}" --silent "$base_url/$asset" --output "$dmg" \
        || die "Download failed." "Check your internet connection and try again."
fi

/usr/bin/curl "${curl_common[@]}" --silent \
    "$base_url/$app_name-SHA256SUMS.txt" --output "$work_dir/SHA256SUMS.txt" \
    || die "Download failed." "Check your internet connection and try again."

# ----------------------------------------------------------- verifying -----

progress 70 "Verifying"

expected=$(/usr/bin/awk -v name="$asset" '
    { file = $2; sub(/^\*/, "", file); sub(/^.*\//, "", file)
      if (file == name) { print $1; exit } }' "$work_dir/SHA256SUMS.txt")
actual=$(/usr/bin/shasum -a 256 "$dmg" | /usr/bin/awk '{ print $1 }')

[[ -n "$expected" && "$actual" == "$expected" ]] \
    || die "This download didn't arrive intact." "Nothing was installed. Please try again."

/bin/mkdir "$mount_dir"
/usr/bin/hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount_dir" -quiet \
    || die "Couldn't open the downloaded file." "Nothing was installed. Please try again."
mounted=1

source_app="$mount_dir/$app_name.app"
staged_app="$work_dir/$app_name.app"
[[ -d "$source_app" ]] || die "The download is missing $app_name." "Nothing was installed."
/usr/bin/ditto "$source_app" "$staged_app"

progress 80 "Verifying"

/usr/bin/codesign --verify --deep --strict --all-architectures "$staged_app" 2>/dev/null \
    || die "This copy of $app_name couldn't be verified." "Nothing was installed."

# A valid signature proves the app is unmodified, not who made it. An ad-hoc
# signature passes the check above, so pin the Team ID to prove provenance.
signing_info=$(/usr/bin/codesign -dv --verbose=4 "$staged_app" 2>&1 || true)
actual_team_id=$(printf '%s\n' "$signing_info" | /usr/bin/awk -F'=' '/^TeamIdentifier=/ { print $2; exit }')

if [[ -n "$expected_team_id" ]]; then
    [[ "$actual_team_id" == "$expected_team_id" ]] \
        || die "This copy of $app_name isn't from the official developer." "Nothing was installed."
    debug "signed by team $actual_team_id"
else
    debug "NO TEAM ID PINNED -- set expected_team_id. Provenance is unverified."
fi

if /usr/sbin/spctl --assess --type execute "$staged_app" >/dev/null 2>&1; then
    notarized=1
else
    notarized=0
    debug "app is not notarized -- clearing quarantine manually"
fi

# ---------------------------------------------------------- installing -----

progress 90 "Installing"

if /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1; then
    /usr/bin/osascript -e "quit app \"$app_name\"" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1 || break
        /bin/sleep 0.5
    done
    /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1 \
        && die "$app_name is still open." "Quit it and run this again."
fi

if [[ -e "$destination" ]]; then
    backup="$install_dir/.$app_name.backup.$$"
    run_priv /bin/mv "$destination" "$backup" || die "Couldn't replace the existing $app_name."
fi

if ! run_priv /usr/bin/ditto "$staged_app" "$destination"; then
    run_priv /bin/rm -rf "$destination" 2>/dev/null || true
    die "Couldn't install to $install_dir."
fi

(( notarized == 0 )) && run_priv /usr/bin/xattr -dr com.apple.quarantine "$destination" 2>/dev/null || true

run_priv /usr/bin/codesign --verify --deep --strict --all-architectures "$destination" 2>/dev/null \
    || die "The installed copy couldn't be verified." "Please try again."

# Hand ownership back so Sparkle can self-update without asking for a password.
(( needs_sudo == 1 )) && run_priv /usr/sbin/chown -R "$(/usr/bin/id -un):admin" "$destination" 2>/dev/null || true

if [[ -n "$backup" && -e "$backup" ]]; then
    run_priv /bin/rm -rf "$backup"
    backup=""
fi

progress 100 "Installing"

# ----------------------------------------------------------------- done ----

installed_version=$(/usr/bin/defaults read "$destination/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "")
if [[ -n "$installed_version" ]]; then
    ready_message="$app_name $installed_version is ready."
else
    ready_message="$app_name is ready."
fi

/usr/bin/open "$destination"

progress_clear
printf '\n%s\n' "${indent}${bold}${green}✓${reset}  ${bold}${ready_message}${reset}"

# A copy in the other common location would keep launching the old version.
# Flagged, never deleted -- removing an app the user put elsewhere isn't our call.
for other in /Applications "$HOME/Applications"; do
    [[ "$other" == "$install_dir" ]] && continue
    [[ -e "$other/$app_name.app" ]] || continue
    printf '%s\n' "${indent}${dim}   Another copy is in $other -- you may want to remove it.${reset}"
done

printf '\n'
