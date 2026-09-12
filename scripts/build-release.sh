#!/bin/bash
set -euo pipefail

variant=${1:?Expected arm64, x64, or universal}
source_dir=${2:?Expected the tagged source directory}
output_dir=${3:?Expected an output directory}
: "${RELEASE_TAG:?Set RELEASE_TAG to the version tag}"

case "$variant" in
    arm64) architectures=(arm64) ;;
    x64) architectures=(x86_64) ;;
    universal) architectures=(arm64 x86_64) ;;
    *) echo "Unknown architecture: $variant" >&2; exit 1 ;;
esac

build_dir=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mactoy-build.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
mkdir -p "$output_dir"

# CI has no Apple signing identity. Ad-hoc builds cannot use team-based library
# validation with Sparkle; production Developer ID exports should enable runtime.
xcodebuild -project "$source_dir/MactoyThemer.xcodeproj" \
    -scheme MactoyThemer -configuration Release \
    -derivedDataPath "$build_dir" \
    -onlyUsePackageVersionsFromResolvedFile \
    "ARCHS=${architectures[*]}" ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    ENABLE_HARDENED_RUNTIME=NO build

app="$build_dir/Build/Products/Release/MactoyThemer.app"
python3 - "$app" "$RELEASE_TAG" "${architectures[@]}" <<'PY'
from pathlib import Path
import os
import plistlib
import subprocess
import sys

app = Path(sys.argv[1])
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
if info["CFBundleShortVersionString"] != sys.argv[2][1:]:
    raise SystemExit("Tag version must match MARKETING_VERSION in the tagged source.")
repo = os.environ.get("GITHUB_REPOSITORY", "Ic0u/MactoyThemer")
if info.get("SUFeedURL") != f"https://github.com/{repo}/releases/latest/download/appcast.xml":
    raise SystemExit("The app has the wrong Sparkle feed URL.")
binary = app / "Contents/MacOS/MactoyThemer"
actual = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
if set(actual) != set(sys.argv[3:]):
    raise SystemExit(f"Unexpected app architectures: {actual}")
# Swift back-deployment libraries are intentionally x86_64-only: they support
# old Intel macOS versions, while Apple Silicon macOS provides that runtime.
# Verify every other Mach-O component against the selected release variant.
for path in app.rglob("*"):
    if path.is_file() and not path.is_symlink():
        kind = subprocess.check_output(["file", "-b", str(path)], text=True)
        is_swift_back_deployment_library = (
            path.parent.name == "Frameworks"
            and path.name.startswith("libswift")
            and path.suffix == ".dylib"
        )
        if "Mach-O" in kind and not is_swift_back_deployment_library:
            subprocess.run(["lipo", str(path), "-verify_arch", *sys.argv[3:]], check=True)
subprocess.run(["codesign", "--verify", "--deep", "--strict", "--all-architectures", str(app)], check=True)
with open(app.parent / "launch.log", "w") as log:
    process = subprocess.Popen([str(binary)], stdout=log, stderr=log)
    try:
        code = process.wait(timeout=5)
        raise SystemExit(f"App exited during launch check ({code}). See launch.log.")
    except subprocess.TimeoutExpired:
        print(f"Verified {actual}; native launch check passed.")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
PY

package_dir="$build_dir/package"
mkdir "$package_dir"
ditto "$app" "$package_dir/MactoyThemer.app"
ln -s /Applications "$package_dir/Applications"
hdiutil create -quiet -ov -format UDZO -fs HFS+ \
    -volname "MactoyThemer ${RELEASE_TAG#v} ($variant)" \
    -srcfolder "$package_dir" "$output_dir/MactoyThemer-mac-$variant.dmg"
hdiutil verify "$output_dir/MactoyThemer-mac-$variant.dmg"
