# F18: Settings window and shortcut recorder

## Request

> CleanShot settings are pretty good in terms. Have giving me a good reference. Have how I want our settings page to look. So one thing I do want is to be able to configure the leader key properly straight away.
>
> but I also love the rectangle pro way of showing the current shortcuts, wiping, them, or rec-recording them

> \> Variant 1: sidebar, recorder fields
>
> this one, definitely. your mockups look great!

Source: [requirements-as-written.md, section 10](../requirements-as-written.md).

## What exists

- "Settings…" (⌘,) in the Tiller menu opens the settings window.
- The window has a sidebar with colored icons. The pages are Shortcuts and About.
- The Shortcuts page has the leader key field, "Show the key bar", and one field for each action in sections: Screen, Container, Window and App.
- A shortcut field shows its keys in a grey field with a clear button (✕). An empty field shows "Record shortcut".
- A click on a field starts recording. The field gets a teal edge and shows "Press keys…". The event tap passes the next key press to the field. `Esc` cancels.
- One chord has one action. A chord recorded for a second action is removed from the first action.
- Shortcuts are saved in the Tiller defaults as JSON.

## Proof

[hyper-dark](../../Tests/Proof/hyper-dark), [hyper-light](../../Tests/Proof/hyper-light).
