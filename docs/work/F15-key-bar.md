# F15: Key bar, key list and the Show the key bar setting

Status: **Done**

## Request

> B. Bottom bar -is the option we want for the leader key overlay. It should be draggable though, and default to the bottom of the screen. maybe with slightly smaller fonts, just 1 pt less

> why not a `?` to show a popup that shows the complete control list? ... Or put all controls in the leader key, but prefix or section them for in the leader key to say what they act on. maybe remove the text from the container chip, too, just the vertical or horizontal icon is good enough?

> where is the "show the key bar" toggle? this is a nice, idea.

Source: [requirements-as-written.md, sections 9 and 10](../requirements-as-written.md).

## What exists

- The key bar is at the bottom center of the screen by default. It can be dragged. Its position is kept.
- The keys are in 4 sections with a heading: SCREEN (`1` to `4`), CONTAINER (`K`, `J`, `V`), WINDOW (`H`, `L`, `F`) and APP (`R`). `?` and `Esc` are at the right end.
- `?` opens the full key list above the key bar, with a description for each key. `?` again closes it.
- The key bar and the key list read the saved shortcuts. A key without a shortcut isn't shown.
- "Show the key bar" in the settings is on by default. When it is off, leader key mode shows the containers and pills without the key bar. The key list then opens at the bottom center of the screen.

## Decisions

- The sections by what the keys act on were recommended and approved: "ok, do it".

## Proof

[key-bar-sections-dark](../../Tests/Proof/key-bar-sections-dark), [key-bar-sections-light](../../Tests/Proof/key-bar-sections-light), [key-bar-setting-dark](../../Tests/Proof/key-bar-setting-dark), [key-bar-setting-light](../../Tests/Proof/key-bar-setting-light).

## Open items

- The key bar and the key list open on the main screen only. See [F27](F27-multiple-screens.md).
