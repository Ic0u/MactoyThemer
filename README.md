# MactoyThemer

<p align="center">
  <img src="MactoyThemer/Assets.xcassets/AppIcon.appiconset/icon_128x128%402x.png" width="128" alt="MactoyThemer app icon">
</p>

MactoyThemer is a native macOS utility for installing and managing themes on a mounted Ventoy drive. It uses AppKit and keeps the interface compact.

## Download

Download **MactoyThemer.zip** from [Releases](https://github.com/Ic0u/MactoyThemer/releases/latest), unzip it, and move **MactoyThemer.app** to Applications. Version 1.0 includes Intel and Apple Silicon support.

The v1.0 build is not notarized by Apple; macOS Gatekeeper may block it when first opened.

## Features

- Detects mounted Ventoy drives, with manual folder selection when needed.
- Installs theme folders and `.zip`, `.zipx`, `.tar`, `.tgz`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, and `.tar.zst` archives.
- Updates `ventoy/ventoy.json` while preserving unrelated Ventoy settings.
- Selects the default theme and display resolution.
- Removes individual themes or all installed themes.
- Checks for signed updates through Sparkle and GitHub Releases.
- Supports English and Vietnamese.

## Requirements

- macOS 10.13 or later
- Xcode with the macOS SDK for building from source
- A mounted Ventoy data partition for normal use

## Build

```sh
git clone git@github.com:Ic0u/MactoyThemer.git
cd MactoyThemer
xcodebuild -resolvePackageDependencies \
  -project MactoyThemer.xcodeproj -scheme MactoyThemer
xcodebuild -project MactoyThemer.xcodeproj \
  -scheme MactoyThemer -configuration Debug build
```

Open `MactoyThemer.xcodeproj` in Xcode for interactive development.

## Test

```sh
xcodebuild -project MactoyThemer.xcodeproj \
  -scheme MactoyThemer -destination 'platform=macOS' test
```

Tests use temporary directories in place of USB volumes. Release and Sparkle setup is documented in [docs/UPDATES.md](docs/UPDATES.md).
