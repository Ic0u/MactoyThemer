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
5. Commit the workflow, publishing script, and `Package.resolved` to GitHub.

## Release an update

1. Increase `CURRENT_PROJECT_VERSION`; Sparkle compares this build number.
   Update `MARKETING_VERSION` for the displayed version.
2. Archive with Xcode, export using Developer ID, and notarize the app, including
   Sparkle's embedded helpers. The app still targets macOS 10.13.
3. Package the exported app, preserving bundle structure:

   ```sh
   ditto -c -k --sequesterRsrc --keepParent /path/to/MactoyThemer.app MactoyThemer.zip
   ```

4. Create a draft GitHub release with a version tag such as `v1.1.0`, attach
   `MactoyThemer.zip`, then run **Publish Sparkle appcast** with that tag from the
   Actions tab. It signs the archive and attaches `appcast.xml` to that release.
5. Publish the release and mark it latest. Generating the appcast while still a
   draft avoids a missing-feed window and works with immutable releases. The
   workflow also runs when a release is published and skips releases that already
   contain `appcast.xml`. Manual reruns replace only that asset on editable
   releases. Prereleases are excluded from the stable feed.
6. From an older installed build in `/Applications`, test **Check for Updates…**,
   download, installation, and relaunch. Test scheduled checks after granting
   Sparkle permission. A passing build does not verify delivery or signing.

Keep Hardened Runtime enabled for distribution. Use an Apple Development
identity for local builds so library validation can load Sparkle. The dependency
stays on Sparkle 2.9 patch releases to preserve macOS 10.13 support.

References: [Sparkle setup](https://sparkle-project.org/documentation/),
[GitHub release events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release).
