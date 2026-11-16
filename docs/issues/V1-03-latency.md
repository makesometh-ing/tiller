# V1-03: Make focus steps and layout changes faster

Work file: [F24](../work/F24-latency.md)

## Problem

A container focus step doesn't move a window. It takes about 24 ms. Most of that time is the read of all windows. With WeChat, a layout change takes 77 to 141 ms. Each window gets a size call, a position call and a second size call.

## What to build

- Use one size call for each window, if the frame read back after the move is correct.
- Keep a cached window list. Update it from the Accessibility notifications. These notifications are read in V1-01 (Put new windows in a container, and remove closed windows).

## Acceptance criteria

- [ ] The frame read back after each move is the target frame, for the test windows and for WeChat.
- [ ] A container focus step doesn't read all windows.

## Proof

The latency of the same steps before and after the change, for the test windows and for WeChat, from the log.
