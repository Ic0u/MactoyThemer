# Updates through GitHub Releases

Sparkle is linked through Swift Package Manager. The app menu provides manual
update checks and an automatic-check toggle. Updates use the latest release's
`appcast.xml` asset:

```text
https://github.com/Ic0u/MactoyThemer/releases/latest/download/appcast.xml
```

The public GitHub repository and Sparkle public key are configured without
embedded credentials. The private key stays in the macOS Keychain under the
`Ic0u.MactoyThemer` account.

## One-time setup

1. Resolve packages in Xcode. Sparkle's `bin` tools are under
   `SourcePackages/artifacts/sparkle/Sparkle/` in the project's DerivedData folder.
2. The signing key is stored in the local Keychain under `Ic0u.MactoyThemer`.
   Retrieve its public key with `bin/generate_keys --account Ic0u.MactoyThemer -p`.
3. Keep `SPARKLE_GITHUB_REPOSITORY` set to `Ic0u/MactoyThemer` in the app
   target's build settings. `Configuration/Info.plist` embeds the resulting feed
   and public key.
4. Export the signing key with
   `bin/generate_keys --account Ic0u.MactoyThemer -x /secure/path/sparkle.key`.
   Add that file's contents as the GitHub Actions secret `SPARKLE_PRIVATE_KEY`.
   Keep a secure backup and remove the temporary export. Never commit it.
5. Keep `.github/workflows/release.yml`, the release scripts, and
   `Package.resolved` committed to GitHub.

## Release an update

1. Increase `CURRENT_PROJECT_VERSION`; Sparkle compares this build number.
   Set `MARKETING_VERSION` to the release version, such as `1.1`.
2. Commit the changes, then push a matching tag:

   ```sh
   git tag -a v1.1 -m "MactoyThemer 1.1"
   git push origin main v1.1
   ```

3. **Release macOS** builds the tagged app source in three jobs:

   | Download | Architectures | Runner |
   | --- | --- | --- |
   | `MactoyThemer-mac-arm64.zip` | arm64 | `macos-15` |
   | `MactoyThemer-mac-x64.zip` | x86_64 | `macos-15-intel` |
   | `MactoyThemer-mac-universal.zip` | arm64 + x86_64 | `macos-15` |

4. Each job checks the version, architectures, bundle signatures, and native
   launch. Only after all jobs succeed does the workflow upload the downloads and
   `MactoyThemer-SHA256SUMS.txt`, sign the universal archive with Sparkle, and
   publish the completed draft as the latest release.
5. To build an existing tag, run **Release macOS** from the Actions tab and enter
   its tag. Existing downloads and appcasts are preserved on retries. This also
   preserves v1.0's original `MactoyThemer.zip` update URL. Published immutable
   releases cannot receive additional assets. Only stable version tags are accepted.
6. Test **Check for Updates…** from an older installed build in `/Applications`,
   including installation and relaunch. Every architecture uses the universal
   update so the same feed works on both Mac types.

## Apple signing

The CI builds are ad-hoc signed and not notarized. They disable Hardened Runtime
because ad-hoc signatures cannot satisfy team-based library validation for
Sparkle. Gatekeeper may block downloaded builds. Sparkle's Ed25519 signature
provides update integrity, not Apple notarization.

For Developer ID distribution, configure Apple signing and notarization before
packaging, and enable Hardened Runtime for the app and embedded helpers. Store
credentials in Actions secrets, never in the repository. The local Xcode project
keeps Hardened Runtime enabled for builds signed with an Apple identity.

Sparkle stays on 2.9 patch releases for macOS 10.13 support. Apple Silicon builds
require macOS 11 or later.

References: [Sparkle setup](https://sparkle-project.org/documentation/),
[GitHub release events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release).
