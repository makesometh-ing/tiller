# F02: Proof bundles and the end-to-end test runner

Status: **Done**

## Request

> one of the absolute requirements I have here is that you must provide me proof for everything you do - verifiability is a non-negotiable for everything in this app, a proof bundle - whether its screenshots, videos, logs, or whatever - must be provided for everything to be passed or marked as done.

> By the way, all the proofs that you're making shouldn't be in the root folder. They should go in some kind of testing or proof part because most have the proof stuff is just going to be a throwaway anyway. I just want you to prove it every time you do some task

Source: [requirements-as-written.md, sections 4 and 9](../requirements-as-written.md).

## What exists

- `build/tiller-proof` opens the test windows app, starts Tiller in proof mode, sends key presses and writes a proof bundle.
- Each proof bundle contains `summary.md`, `frames.json`, `latency.log`, a screenshot after each step and a screen recording `run.mov`.
- Each step compares the actual frame of each window with the expected frame. A difference of more than 1 point fails the step.
- Each step checks that the focused window is the expected window.
- The test windows write each key press that they receive to `~/Library/Logs/Tiller/testwindows-keys.log`. A key press from the run that reaches a test window while leader key mode is active fails the run.
- Options: `--steps` sets the steps. `--apps` adds other apps. `--leader` and `--keys` set the shortcuts. `--appearance light|dark` sets the system appearance and restores it after the run.
- Special steps: `leader`, `hover`, `?`, `settings`, `settings-close`, `record:<target>`, `chord:<spec>`, `pass:<spec>`, `toggle:showKeyBar`.
- Proof bundles are stored in `Tests/Proof/<task>/`. Git ignores this folder.

## Decisions

- In proof mode, Tiller manages only the windows of the apps in `--only-bundle-ids`, so that a proof run doesn't move your windows.
- Proof runs use the defaults domain `com.tiller.Tiller.proof`, so that a proof run doesn't change your saved shortcuts.

## Proof

Every folder in [Tests/Proof](../../Tests/Proof).

## Open items

- The key bar position is saved in your real defaults during a proof run. See [B11](B11-key-bar-position-saved-in-proof-runs.md).
