# rsg-legendary

Legendary animal hunting for the RSG Framework (rsg-core 3.0.3).

## How it works
1. **Buy a map** from the Legendary Trapper (ox_target). Each legendary shows its price, or how long until it returns if you are on cooldown.
2. **Use the map** from your inventory. The hunting area and the first tracks appear on your map.
3. **Follow the trail.** Inspect each set of tracks (ox_target). Every clue reveals the next; after the last one the legendary appears nearby. Predators (bear, wolf, cougar, panther, boar, bull gator) attack; the rest wander.
4. **Kill and skin it** with the normal in-game skinning. If a model has no skin prompt, an ox_target "Skin" option appears after a short delay (or straight away for animals with `skin = 'target'`).
5. **Sell** pelts and trinkets back to the trapper. Each player can hunt each legendary once per cooldown (default 24 hours).

15 legendaries: bear, buck, boar, wolf, cougar, panther, big horn ram, moose, elk, fox, coyote, bull gator, beaver, pronghorn and Tatanka bison.

## Requirements
rsg-core, rsg-inventory, ox_lib, ox_target, oxmysql.

## Install
1. Add the items from `installation/shared_items.lua` to `rsg-core/shared/items.lua` and add their images to `rsg-inventory/html/images`.
2. `ensure rsg-legendary` after its requirements.
3. That's it. The `rsg_legendary_cooldowns` table is created automatically on first start.

## Configuration (`shared/config.lua`)
- **Trappers:** NPC model, coords and blip. The ped only spawns when a player is within `TrapperSpawnDistance`.
- **Hunt flow:** hunt duration, clue count and spread, inspect/skin times, cooldown hours, money type.
- **Animals:** model, outfit preset, price (names/descriptions are in the locales), zone centre and radius, aggression, health multiplier, rewards and skin mode.
- **SellPrices:** what the trapper pays per item.

Zone centres are approximate. Stand where you want each hunt and update `zone` (x/y only; height is found automatically). Use `/legendpreview` to choose each animal's outfit preset.

## Languages
All text (notifications, ox_target labels, blips, NUI, command help, animal names and descriptions, Discord logs) lives in `locales/*.json`.

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language in your `server.cfg`:

```
setr ox:locale en
```

To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values. Keep `%s` / `%d` placeholders in the same order. Item labels come from `rsg-core/shared/items.lua`, not these files.

## Commands
| Command | Who | What |
|---|---|---|
| `/abandonhunt` | everyone | Give up your current hunt (the map is used up) |
| `/legendpreview <animal> <preset>` | admin | Spawn a frozen preview of a legendary for 30 seconds |

## Discord webhooks
All logging is configured in `server/sv_config.lua` (server only, so webhook URLs never reach players).

1. In Discord: channel settings > Integrations > Webhooks > New Webhook > Copy URL.
2. Paste URLs into `SvConfig.Webhooks.Urls`. Use one channel for everything (`Default`) or split them:

| Channel | Logs |
|---|---|
| `Shop` | maps bought, items sold (amounts and totals) |
| `Hunt` | hunt started (zone, expiry), clues found, legendary appeared/respawned, abandoned, expired |
| `Kill` | legendary skinned with the rewards given |
| `Admin` | `/legendpreview` use |
| `Suspicious` | failed server checks that point to cheating: claiming someone else's or a living carcass, skinning or inspecting clues from far away, faked spawns, tampered maps |

3. Turn single log types on or off in `Events` (`clue_found` is off by default because it's chatty).
4. Optional: set `SuspiciousRoleId` to ping a staff role on suspicious logs.

Each log shows the player name and server ID, character name, citizen ID, Discord mention, license and coords (`ShowCoords`). Messages are queued and sent one at a time (`QueueDelay`) so Discord's rate limit is never hit.

## Security
Everything that matters runs on the server: trapper distance checks for buying and selling, rate limiting, clue order and distance checks, and the skinned carcass must be the exact networked animal spawned for that player's hunt (model, dead, distance) before rewards and the cooldown are given.

## Notes
- rsg-hunting listens for the same skinning event. If any legendary model is in rsg-hunting's skin lookup, players will get that reward too, so keep them out of it.
- Hunts are not saved across a resource or server restart; an active hunt (and its map) is lost.

Support: https://buymeacoffee.com/rexshack
