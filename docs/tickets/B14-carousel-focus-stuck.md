# B14: Focus doesn't move past a Dia window in a carousel

PRD: section 7 "Windows" and section 13 "Logging and diagnostics".

## Problem

> when I get to a certain point in the ring buffer (I can't tell if it's the end of the ring buffer or some other bug) the layout gets all messed up and it's just 3 cascaded windows and the carousel messes up

The carousel in the recording has 13 windows. The ring order includes Slack, Dia and WeChat in sequence. `L` from Slack moves the windows for Dia, but Slack stays in front. Each next `L` gives the same result.

## Events

1. Before each focus action, Tiller reads the system focused window. Tiller sets the focused window of the carousel to it. A click on a window then changes the focused window of the carousel.
2. `L` from Slack sets Dia as the focused window of the carousel. The frames are set for Dia.
3. Tiller sets `AXMain` on the Dia window, raises it and sets `AXFrontmost` on Dia. Each call returns success. Dia doesn't become the active app. Slack stays in front, over the Dia window and the WeChat window. The visible result is three windows in a cascade.
4. The next `L` reads Slack as the system focused window. The focused window of the carousel goes back to Slack. `L` then moves focus to Dia again, and step 3 occurs again.

Dia stays inactive after `AXFrontmost` from each app that was tested: Slack and Finder. `NSRunningApplication.activate()` makes Dia active. 

## Fix

`AXWindows.focus` and `AXWindows.raise` call `NSRunningApplication.activate()` after `AXFrontmost`. Each focus action also writes a `focus` line to the log. The line is described in section 13 "Logging and diagnostics" of the PRD.

## Proof

[B14-carousel-focus-stuck](../../Tests/Proof/B14-carousel-focus-stuck): 13 windows in one Full Screen container: 10 test windows, Slack, Dia and WeChat. `L` 28 times goes through the ring twice and wraps. `H` 14 times goes back through the ring. Each step passes. `focus-log.txt` shows Dia as the system focused window after each focus action to Dia. `default-steps/` is the end-to-end test with the default steps. It passes.

Before the fix, the same run failed from the first `L` to Dia: the system focused window stayed Slack for 12 steps.
