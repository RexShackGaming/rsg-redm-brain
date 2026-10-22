# rsg-goldpanning

Gold panning for the RSG Framework (RedM). Stand in a river, use a gold pan, and sift for nuggets.

## Features

- Use the `tool_goldpan` item while standing in one of the configured rivers/creeks
- ox_lib progress bar (cancellable) with scoop and shake animations
- Tiered rewards (small / medium / large) with configurable chances and amounts
- Server-authoritative anti-exploit: the server chooses the pan duration, validates timing, checks the player didn't move away, and enforces spot memory so the same spot can't be farmed
- Cooldown between pans
- Optional Discord webhooks for rewards and suspicious claims, plus `rsg-log` support
- ox_lib locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)

## Installation

1. Drop `rsg-goldpanning` into your resources folder.
2. Add the item from `installation/shared_items.lua` to `rsg-core/shared/items.lua` (skip if it already exists).
3. Copy `installation/images/tool_goldpan.png` to `rsg-inventory/html/images/`.
4. Make sure your reward item (default `resource_gold_nugget`) exists in `rsg-core/shared/items.lua`.
5. Add `ensure rsg-goldpanning` to your `server.cfg` after `rsg-core`, `rsg-inventory` and `ox_lib`.

## Configuration

| File | What's in it |
|------|--------------|
| `shared/config.lua` | Pan item, cooldown, pan duration, reward items/tiers, find chance, movement rules, allowed water bodies |
| `server/sv_config.lua` | Discord webhook URLs and colours (server-only, never sent to clients) |
| `locales/*.json` | All player-facing, progress bar, log and webhook text |

Key options:

- `Config.PanItem` — useable item name (default `tool_goldpan`)
- `Config.Cooldown` — seconds between pans
- `Config.PanTime` — crouch time and min/max total pan time (ms)
- `Config.GoldChance` — % chance to find anything
- `Config.RewardTiers` — tier chance (should total 100) and amount
- `Config.MinMovementDistance` / `Config.SpotMemoryTime` — how far to move and how long a spot stays "panned out"
- `Config.MaxDriftDistance` — how far a player may move during a pan before the claim is rejected

## How it works

1. Using the item → server checks cooldown → client checks you're on foot in valid water.
2. Server opens a session, picks a random duration and records your position.
3. Client plays the progress bar. Cancelling ends the session with no reward.
4. On completion the server validates the session, timing, position, that you still have the pan, and inventory space before giving the reward.

## Languages

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

Set the language in `server.cfg`, e.g. `setr ox:locale de`. To add another, copy `locales/en.json` to `locales/<code>.json` and translate the values (keep the `%s` / `%d` / `%.2f` placeholders in the same order).
