# Feather HUD

> The official player HUD for the Feather Framework — an always-on Resource Strip showing cash, gold, tokens, and XP/rank.

## Screenshots

<!-- Add screenshots here, e.g.: -->
<!-- ![Resource Strip](./screenshots/resource-strip.png) -->

## Features

- Always-on Resource Strip: cash, gold, tokens, and an XP/rank bar with a level shield
- No interaction, no screen real estate taken up by a panel — legible over any background, never blocks mouse or camera input
- Configurable anchor position (all 8 screen corners/edges/sides), padding, scale, and an optional legibility scrim
- Updates live as a player's economy changes — no menu to open, no manual refresh

## Requirements

- RedM server with `fx_version` `cerulean` or newer
- Lua 5.4 (`lua54 'yes'` is set in the manifest)
- [`feather-core`](https://github.com/FeatherFramework/feather-core) — feather-hud reads character/economy data
  through it and has no data of its own

## Installation

1. Download `feather-hud.zip` from [releases/latest](https://github.com/DavFount/feather-hud/releases/latest)
2. Extract and place the `feather-hud` folder into your server's `resources` directory
3. Add `ensure feather-hud` to your `server.cfg` (after `feather-core`)
4. Restart the server or start the resource with `start feather-hud`

## Configuration

Dollars and gold now read from Economy's open wallets through the source-bound
`hud.state.get.v1` RPC. Minor-unit balances convert using each currency's catalog
precision. Character money fields are not used. Tokens/XP remain on the existing
Character path. HUD reads do not provision wallets or maintain a ledger.

Economy outbox events broadcast an empty invalidation signal, not ledger data.
Clients coalesce signals and refresh only their own session; periodic 10-second
reads recover missed signals. Logout clears/hides state, spawn invalidates older
in-flight reads, and unavailable wallet reads hide the strip rather than assume
zero balances. Pause visibility cannot overwrite a newly refreshed wallet state.
Both currencies render integer minor-unit balances using Economy catalog
precision (currently two decimals). The formatter avoids floating-point division
and preserves small gold amounts and large balances. Unavailable/invalid values
are not formatted as zero. Run pnpm test for formatter regression coverage.
UI source changes require a production build and deployment of ui/dist contents
to the deployed resource's ui folder; generated files are not source commits.

Start Core and Economy before HUD. The manifest now declares both dependencies:
run refresh then restart feather-hud. `HudEconomyContractSmokeTest` expects 2/2
passes with no funds moved (route installed and outbox subscription).

All settings live in `config.lua`. Positioning uses a `HudPosition` table of named constants instead of raw text,
so there's no risk of a typo silently breaking the layout:

```lua
Config.ResourceStrip = {
    anchor  = HudPosition.BottomRight, -- HudPosition.TopLeft, .TopCenter, .TopRight,
                                        -- .MiddleLeft, .MiddleRight,
                                        -- .BottomLeft, .BottomCenter, .BottomRight
    padding = 26,   -- Distance in pixels from the screen edge the strip is anchored to
    scale   = 1.0,  -- Uniform size multiplier -- 1.0 is normal size, 1.2 is 20% bigger, 0.8 is 20% smaller
    scrim   = true  -- Soft dark backdrop behind the text so it stays readable over bright backgrounds
}
```

An unrecognized `anchor` value falls back to `HudPosition.BottomRight` automatically.

## Development

The NUI is a Vue 3 + Vite app in `ui/`:

```bash
cd ui
pnpm install
pnpm build   # outputs to ui/dist -- see below for how it gets deployed
pnpm dev     # live dev server for UI iteration
pnpm lint
```

`fxmanifest.lua` points at `ui/index.html` and `ui/assets/*.*` directly (not `ui/dist/`) — the release workflow's
zip step flattens `ui/dist/`'s contents up one level to match. When testing a local build without going through a
release, copy `ui/dist/`'s *contents* (not the folder itself) into `ui/` — `dist/index.html` → `ui/index.html`,
`dist/assets/*` → `ui/assets/*`.

## Troubleshooting

If you encounter any issues or have questions, post in our [discord](https://discord.gg/zBCPbPJGZw) bugs and
support channel. You may also open an issue on the issue tracker tab of GitHub.

## Contributing

Contributions to any of our Feather scripts are welcome! If you have improvements or bug fixes, feel free to
submit a pull request.
