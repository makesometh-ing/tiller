# F21: Open at login

## Request

> also we need an open at login option which is off by default

Source: [requirements-as-written.md, section 10](../requirements-as-written.md).

## What exists

Only a mockup exists. The mockup of the General page is in [settings-v2.html](../mockups/settings-v2.html).

## What to build

The behaviour is described in [PRD.md, section 11 "Settings window and menu bar menu"](../PRD.md#11-settings-window-and-menu-bar-menu).

- Use `SMAppService.mainApp` for "Open at login".

## Acceptance criteria

- [ ] With the "Open at login" switch on, Tiller is listed in System Settings → General → Login Items.
- [ ] Tiller opens after a log out and a log in.

## Proof needed

Screenshots of the General page and of Login Items, and the log after a log in.
