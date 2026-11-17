# F01: Tech stack and build

## Request

> latest and greatest macOS SDKs. I have no idea what swiftUI, appkit are, how they differ, what else is available, but I want a proposal from you which is most appropriate. for example, if we need to use objective-c to make this app blazingly fast, then we should do that.

> xcode is fucking installed you heap of garbage, but I'd be fine if you didn't use it.

Source: [requirements-as-written.md, sections 2 and 4](../requirements-as-written.md).

## What exists

- The code is Swift 6 in a Swift package. The package has four targets: `TillerCore` (layout and rule logic without UI), `Tiller` (the app), `TillerTestWindows` (a test app) and `tiller-proof` (the end-to-end test runner).
- AppKit is used for the app, the menu bar icon and the overlay panels. SwiftUI is used for the views in the overlay and the settings window.
- The Accessibility API (`AXUIElement`) moves and resizes the windows of other apps. A `CGEventTap` reads key presses.
- `scripts/build.sh` builds the app bundles without Xcode. It signs them with the Apple Development certificate. A stable signature keeps the Accessibility permission after each rebuild.
- `scripts/test.sh` runs the unit tests with the Command Line Tools. It adds the path of the Swift Testing macro plugin. SwiftPM doesn't find the plugin without this path.
- The minimum macOS version is 26.0. The SDK is macOS 27.2.

## Proof

Each proof bundle in `Tests/Proof/` was built with these scripts.
