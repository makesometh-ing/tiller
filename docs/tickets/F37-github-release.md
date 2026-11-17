# F37: Signed and notarized release on GitHub Releases

## Request

> but I also want to package and publish for macOs 27 on github releases.

Source: [requirements-as-written.md, section 13](../requirements-as-written.md).

## What to build

Add a script `scripts/release.sh`. It does these steps on your Mac:

1. Sets the version in `Info.plist` from the git tag.
2. Builds Tiller for Apple silicon. macOS 27 runs only on Apple silicon.
3. Signs Tiller with the Developer ID Application certificate, with the hardened runtime and a secure timestamp.
4. Sends Tiller to Apple for notarization with `xcrun notarytool submit --wait`.
5. Staples the notarization ticket with `xcrun stapler staple`.
6. Makes `Tiller-<version>.zip` with `ditto`.
7. Runs `gh release create` to make a GitHub release with the zip.

## Acceptance criteria

- [ ] `spctl --assess --verbose Tiller.app` shows `source=Notarized Developer ID`.
- [ ] Tiller from the zip downloaded from GitHub opens on another Mac without a Gatekeeper warning.
- [ ] The Accessibility permission is kept after an update to the next release.

## Proof needed

The script output, the `spctl` output, and a screenshot of the first launch of the downloaded zip.
