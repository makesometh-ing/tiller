# One workspace for each screen

Each screen has exactly one workspace with its own container layout. The workspace state is stored with the display UUID as the key. A layout set on one screen doesn't change another screen. The requirements drawing defined one workspace for the whole Mac. The owner changed it to "singleton per screen".

## Considered options

- One workspace for all screens. This option was rejected.
- Workspaces mapped to macOS Spaces. This option was rejected. A move of a window to another Space needs SIP partly disabled.

## Consequences

- A command to copy a container layout to another screen is planned. The two workspaces stay separate.
