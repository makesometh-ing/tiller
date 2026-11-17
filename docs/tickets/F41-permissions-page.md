# F41: Permissions page in the settings

## Request

> we need an onboarding to ask for the accessibility permissions on start, and a permission tab to show permissions and whether they've been granted and a way to request if granted etc.

## What exists

- At launch without the Accessibility permission, the macOS Accessibility prompt is shown one time.
- The Tiller menu shows one line with the event tap state.

## What to build

The behaviour is described in [PRD.md, section 4 "Platform and build"](../PRD.md#4-platform-and-build).

- Make 3 mockups of the Permissions page, in the light and the dark appearance, for approval. Make them with the mockups for the permission window in ticket F35 "Accessibility permission window at the first launch".

## Acceptance criteria

- [ ] After `tccutil reset Accessibility com.tiller.Tiller`, the Permissions page shows Accessibility as not granted, with a button.
- [ ] The button opens System Settings → Privacy & Security → Accessibility.
- [ ] After the permission is granted, the page shows Accessibility as granted without a relaunch.

## Proof needed

Screenshots of the mockups, and of the Permissions page before and after the permission is granted, in the light and the dark appearance.
