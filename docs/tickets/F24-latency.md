# F24: Latency of frame changes in slow apps

## Request

> we're working with UI and window management, so latency and jankiness is simply not acceptable and will kill this app dead

Source: [requirements-as-written.md, section 2](../requirements-as-written.md).

## What exists

- Each action is logged with its latency, from the key press in the event tap to the last window move.
- With the test windows, a layout change takes 25 to 50 ms. A focus step takes 19 to 35 ms.
- With the WeChat windows, a layout change took 77 to 141 ms. WeChat took 23 to 80 ms to resize one window. A move without a resize took 1 to 3 ms.
- Windows of different apps are moved in parallel. `AXEnhancedUserInterface` is turned off during a move.
- A container focus step doesn't move a window. It takes about 24 ms. Most of that time is used to read all windows.
- A size call, a position call and a second size call are made for each window.

## Proof

[window-rule-wechat](../../Tests/Proof/window-rule-wechat) (`setframes-timing.log`).

## What to build

The behaviour is described in [PRD.md, section 14 "Latency"](../PRD.md#14-latency).

- Compare one size call for each window with the current size, position and size calls.
- Update the cached window list from the Accessibility notifications of [F13: New, closed, minimized and hidden windows](F13-new-windows.md).

## Acceptance criteria

- [ ] The frame read back after each move is the target frame, for the test windows and for WeChat.
- [ ] A container focus step doesn't read all windows.

## Proof needed

The latency of the same steps before and after the change, for the test windows and for WeChat, from the log.
