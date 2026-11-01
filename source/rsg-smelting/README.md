# rsg-smelting

Turn ores into metal bars at smelter NPCs or ore-bucket props. Built for **RSG-Core** (RedM) with ox_lib, ox_target and rsg-inventory.

## Features
- Smelter NPCs with blips, spawned/despawned by proximity (`lib.points`)
- Optional world-prop smelters via ox_target (`p_bucketore03x`, `p_horseprops03x` by default)
- NUI recipe list with live ore counts, batch quantity picker and progress bar (Backspace cancels)
- All validation server-side: recipe, batch size, distance, item counts, elapsed time
- Ores are taken when smelting starts and refunded on cancel, failure, full output inventory, resource stop, or disconnect. Refunds that don't fit, and refunds owed after a disconnect, logout or server crash, are saved (resource KVP) and paid when the character next logs in or opens a smelter
- ox_lib notifications and locales (`locales/en.json`)
- Discord webhook logging with separate channels, per-event toggles, rate-limit queue and security pings

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)

## Installation
1. Drop `rsg-smelting` into your resources folder.
2. Make sure every input/output item in `Config.Recipes` exists in `rsg-core/shared/items.lua`.
3. Add `ensure rsg-smelting` to your server.cfg after its dependencies.

## Configuration (`shared/config.lua`)
| Option | Description |
|---|---|
| `Config.Smelters` | NPC locations: `id`, `label`, `model`, `coords` (vector4), `scenario`, `blip` |
| `Config.SpawnDistance` | Distance at which NPCs spawn |
| `Config.TargetDistance` | ox_target interaction range |
| `Config.SmeltProps` | Enable/disable prop smelters, UI label and prop models |
| `Config.MaxUseDistance` | Server-side max distance from the smelter to start/finish |
| `Config.MaxBatch` | Max bars per smelt |
| `Config.ImagePath` | Item image folder used by the UI |
| `Config.Recipes` | `output`, `label`, `time` (ms per bar), `inputs` (per bar) |

## Discord Webhooks
Configured in **`server/sv_config.lua`** (server-only, so URLs are never sent to clients).

1. In Discord: *Channel Settings → Integrations → Webhooks → New Webhook → Copy URL*.
2. Paste URLs into `SVConfig.Webhooks.Urls`. You can use one URL for all three channels or split them:
   - `smelting` – starts, completions, cancels, full-inventory refunds
   - `security` – suspicious activity (invalid recipe/amount, not near smelter, finishing too early) and failed validations
   - `refunds` – disconnects mid-smelt, rejoin refunds, resource-stop refunds, refunds that failed (inventory full)
3. Optionally set `SecurityPing` to a role mention (`<@&ROLE_ID>`) to ping staff on security events. Normal logs never ping.

Each event in `SVConfig.Webhooks.Events` can be turned on/off, moved to another channel or recoloured. Embeds include player name, server ID, character name, citizen ID, Discord mention, license and coords (`ShowCoords`).

Messages go through a queue (`SendInterval`, `MaxQueue`) that respects Discord's rate limits and retries on HTTP 429.

Other resources can log through the same system:
```lua
exports['rsg-smelting']:SendWebhook('suspicious', source, { { 'Check', 'Custom' }, { 'Detail', 'something' } }, 'Optional description')
```

## Locales
All player-facing text (notifications, target labels, blips, NUI, smelter/recipe names) and Discord webhook text live in `locales/<lang>.json`.

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language in server.cfg with `setr ox:locale de`.

`label` values in `shared/config.lua` (smelters, blip, prop smelter, recipes) are locale keys; if a key doesn't exist the text is shown as-is, so plain text still works. When adding a smelter or recipe, add its key to every locale file.

## Notes
- Prop smelters can't be verified server-side (map props aren't networked). Fill `Config.SmeltProps.locations` with the prop coordinates you allow, otherwise the server only checks the player is standing near the reported prop position. Set `Config.SmeltProps.enabled = false` if you only want fixed NPC smelters.
- A smelt belongs to the character that started it; switching character mid-smelt holds the refund for the original character.
- A smelt the client never finishes (game crash) is refunded automatically when the player next starts one.

## Changelog
### 3.0.0
- All remaining hardcoded text moved to locales, including config labels and Discord webhook embeds
- Added de, el, es, fr, ja, nl, pl, pt-br and ro translations
- Added Discord webhook system (`server/sv_config.lua`, `server/webhook.lua`)
- Owed disconnect refunds lost on resource stop are now logged for manual compensation
- Fixed NUI focus getting stuck when the smelt request was rejected client-side
- Ore removal now rolls back if any item fails to remove (no partial loss)
- Players who disconnect mid-smelt are refunded on next login; resource stop refunds online players
- Output is checked with `CanAddItem` before giving; uses rsg-inventory exports with reasons
- Moved all strings to locales (Lua + NUI); fixed invalid `en.json`
- NPC spawning moved to `lib.points` (no constant distance loop)
- Enter confirms / Escape closes in the quantity modal
- Removed unused `client/client.lua`, `server/server.lua`, `Config.Debug`; version checker now loaded
