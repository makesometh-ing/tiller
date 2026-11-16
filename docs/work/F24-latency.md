# F24: Latency of frame changes in slow apps

Status: **Not done**

## Request

> we're working with UI and window management, so latency and jankiness is simply not acceptable and will kill this app dead

Source: [requirements-as-written.md, section 2](../requirements-as-written.md).

## What exists

- Each action is logged with its latency, from the key press in the event tap to the last window move.
- With the test windows, a layout change takes 25 to 50 ms. A focus step takes 19 to 35 ms.
- With the WeChat windows, a layout change took 77 to 141 ms. WeChat took 23 to 80 ms to resize one window. A move without a resize took 1 to 3 ms.
- Windows of different apps are moved in parallel. `AXEnhancedUserInterface` is turned off during a move.
- A container focus moves 0 windows and still takes about 24 ms. Most of that time is the read of all windows.

## Proof

[window-rule-wechat](../../Tests/Proof/window-rule-wechat) (`setframes-timing.log`).

## Open items

- `AXWindows.setFrame` sets the size, the position, and the size again. Test one size call per window.
- Cache the window list, so that a focus step doesn't read all windows.
