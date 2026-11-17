# B10: Dark window-stack icon on the chip, and V in the key bar

## Problem

> I noticed in your mockup that there was a V for mode in the leader key display. I'm not sure that should be there, considering it's specific to the container, isn't it not?

> that icon for the window one behind the other ... Have the icon be not dark. It must be like the transparent so it matches the colour.

## Events

1. The chip drew the window-stack icon with a dark fill.
2. The `V` key on the chip had a dark background.
3. The key bar listed `V` without saying that it acts on the container.

## Fix

The icon is the SF Symbol `rectangle.on.rectangle` in the chip text color. The `V` key on the chip has a light translucent background. `V` is in the CONTAINER section of the key bar.

## Proof

[overlay-chip-fix-dark](../../Tests/Proof/overlay-chip-fix-dark), [key-bar-sections-dark](../../Tests/Proof/key-bar-sections-dark).
