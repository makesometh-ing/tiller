# V1-16: Signed and notarized release on GitHub Releases

Blocked by: Apple Developer Program membership, the GitHub repository, and V1-15 (Build from source on any Mac).

## What to build

A script `scripts/release.sh` that does these steps on your Mac:

1. Sets the version in `Info.plist` from the git tag.
2. Builds Tiller for Apple silicon. macOS 27 runs only on Apple silicon.
3. Signs Tiller with the Developer ID Application certificate, with the hardened runtime and a secure timestamp.
4. Sends Tiller to Apple for notarization with `xcrun notarytool submit --wait`.
5. Staples the notarization ticket with `xcrun stapler staple`.
6. Makes `Tiller-<version>.zip` with `ditto`.
7. Makes a GitHub release with the zip, with `gh release create`.

## Acceptance criteria

- [ ] `spctl --assess --verbose Tiller.app` shows `source=Notarized Developer ID`.
- [ ] The zip downloaded from GitHub opens on another Mac without a Gatekeeper warning.
- [ ] The Accessibility permission is kept after an update to the next release.

## Proof

The script output, the `spctl` output, and a screenshot of the first launch of the downloaded zip.
