# rsg-treasure

Treasure map hunting for RSG Framework. Using a treasure map puts a search circle on the map. Equip `weapon_kit_metal_detector` inside the circle: the detector vibrates and bleeps louder, higher and faster, and an on-screen signal meter fills, as you close in. When you pinpoint the spot, press [J] to dig and the muddy strongbox is pulled out of the ground, and the server checks everything before paying out cash and random loot. The map is used up when you find the treasure.

## Requirements
- rsg-core, rsg-inventory, ox_lib

## Install
1. Drop `rsg-treasure` into your resources folder and `ensure rsg-treasure` after rsg-core, rsg-inventory and ox_lib.
2. Add the item to `rsg-core/shared/items.lua`:
```lua
treasure_map = { name = 'treasure_map', label = 'Treasure Map', weight = 50, type = 'item', image = 'treasure_map.png', unique = true, useable = true, shouldClose = true, description = 'An old map marking buried loot.' },
```
3. Add `treasure_map.png` to `rsg-inventory/html/images/`.
4. Set your dig spots and loot in `shared/config.lua`. Any reward item that isn't in your items list is skipped.

## Languages
Includes en, de, el, es, fr, ja, nl, pl, pt-br and ro (`locales/*.json`), covering both in-game text and Discord logs. The language comes from ox_lib's `ox:locale` convar, for example `setr ox:locale "de"` in your server.cfg.

## Discord Webhooks
Set your webhook URLs in `server/sv_config.lua`. That file is server-only, so players never see the URLs. Leave a channel blank to use `Default`, and leave everything blank to turn logging off.

| Channel | Logs |
|---|---|
| `Hunts` | Map used (hunt started, with the dig spot), map re-opened |
| `Rewards` | Treasure dug up: cash, items, location, whether loot was lost to a full inventory |
| `Security` | Dig spam inside the cooldown, digs too far from the spot (red alert if over 50m), digs with no active hunt, digs after the map was removed, payouts requested without a full dig (red alert) |

Each log shows the character name, citizen ID, player name, server ID, licence and Discord mention. Messages are queued and re-sent after a Discord rate limit (429). Set `MentionOnAlert` to a role ping such as `<@&ROLE_ID>` to be alerted on red security logs.

Other resources can log through it too: `exports['rsg-treasure']:SendLog('Rewards', 'Title', 'Description', 'reward', source, { { name = 'Field', value = 'Value' } })`

## Notes
- Players need `weapon_kit_metal_detector` held to search and in their inventory to dig (the server checks the inventory). Make sure the item exists in your shared items/weapons.
- Active hunts are kept in server memory. After a restart, use the map again to get a new spot.
- Using the map again during a hunt re-shows the same search circle (it no longer re-rolls, so the spot can't be triangulated).
- The server times the dig: it starts when the dig animation starts at the spot, and the payout is refused unless the full `Config.DigTime` has passed. Triggering the payout callback directly does nothing.
- If the server rejects a dig (too far, cooldown, missing detector/tool) the strongbox is reburied and you can press [J] again.
- Reward items missing from your shared items are skipped and a warning is printed in the server console on start.
- Set `Config.RequiredItem = 'shovel'` (or your tool's item name) to make players carry a digging tool.

Support: https://buymeacoffee.com/rexshack
