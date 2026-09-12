<p align="center">
  <img src="MactoyThemer/Assets.xcassets/AppIcon.appiconset/icon_128x128%402x.png" width="128" alt="MactoyThemer app icon">
</p>

<h1 align="center">MactoyThemer</h1>

<p align="center">Your Ventoy, your style.</p>

<p align="center">
  <a href="https://github.com/Ic0u/MactoyThemer/releases/latest"><img src="https://img.shields.io/github/v/release/Ic0u/MactoyThemer?style=flat" alt="Latest release"></a>
  <a href="https://github.com/Ic0u/MactoyThemer/actions/workflows/release.yml"><img src="https://github.com/Ic0u/MactoyThemer/actions/workflows/release.yml/badge.svg" alt="Release macOS"></a>
  <img src="https://img.shields.io/badge/macOS-10.13%2B-555?logo=apple&logoColor=white" alt="macOS 10.13 or later">
</p>

MactoyThemer is a native macOS utility for installing and managing themes on a mounted Ventoy drive. It uses AppKit and keeps the interface compact.

## Download

Choose a download, unzip it, and move **MactoyThemer.app** to Applications.

| Download | Mac | Minimum macOS |
| --- | --- | --- |
| [Mac (arm64)](https://github.com/Ic0u/MactoyThemer/releases/latest/download/MactoyThemer-mac-arm64.zip) | Apple Silicon | 11 |
| [Mac (x64)](https://github.com/Ic0u/MactoyThemer/releases/latest/download/MactoyThemer-mac-x64.zip) | Intel | 10.13 |
| [Mac Universal](https://github.com/Ic0u/MactoyThemer/releases/latest/download/MactoyThemer-mac-universal.zip) | Apple Silicon and Intel | 11 / 10.13 |

GitHub Actions builds are ad-hoc signed and not notarized by Apple; macOS Gatekeeper may block them when first opened. Sparkle uses the universal download for automatic updates.

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
