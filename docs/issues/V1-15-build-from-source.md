# V1-15: Build from source on any Mac

## Problem

`scripts/build.sh` stops when an Apple Development certificate isn't in the keychain. A person without an Apple account can't build Tiller.

## What to build

- `scripts/build.sh` signs with the identity in `TILLER_SIGN_IDENTITY` when it is set.
- Without `TILLER_SIGN_IDENTITY`, `scripts/build.sh` signs with an Apple Development certificate. Without that certificate, it signs ad-hoc. It then says that the Accessibility permission must be granted again after each rebuild.
- A `README.md` at the root of the repository: what Tiller does, the requirements (macOS 26 or later, Xcode or the Command Line Tools), the build steps, the Accessibility permission, and a link to the PRD.
- The `LICENSE` file contains the GPL 3.0 text. It was added on 16 November 2026.

## Acceptance criteria

- [ ] `scripts/build.sh` builds Tiller in a new macOS user account without a certificate.
- [ ] Tiller built ad-hoc works after the Accessibility permission is granted.

## Proof

The build output in the new user account, and a screenshot of the leader key overlay from that build.
