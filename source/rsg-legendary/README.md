# rsg-legendary

Legendary animal hunting for the RSG Framework (rsg-core 3.0.3).

## How it works
1. **Buy a map** from the Legendary Trapper (rsg-target). Each legendary shows its price, or how long until it returns if you are on cooldown.
2. **Use the map** from your inventory. The hunting area and the first tracks appear on your map.
3. **Follow the trail.** Hold **E** at each set of tracks to inspect them. Every clue reveals the next; after the last one the legendary appears nearby. Predators (bear, wolf, cougar, panther, boar, bull gator) attack; the rest wander.
4. **Kill and skin it** with the normal in-game skinning. If a model has no skin prompt, an rsg-target "Skin" option appears after a short delay (or straight away for animals with `skin = 'target'`).
5. **Sell** pelts and trinkets back to the trapper. Each player can hunt each legendary once per cooldown (default 24 hours).

### Extras
- **Kill quality:** a legendary killed with a bow, knife, throwing knives or varmint rifle (`Config.Quality.PerfectWeapons`) is a *perfect* kill and gives extra trinkets (`TrinketMult`). Checked on the server from the carcass's cause of death.
- **Bonus trinket:** every kill has a `Config.BonusTrinketChance` chance of one extra trinket.
- **Trophy board:** a *Trophies* tab at the trapper shows the first hunter and the fastest hunt for each legendary, plus your own kills and perfect kills.
- **Group hunts:** the hunt owner runs `/invitehunt <id>` on a nearby player, who types `/accepthunt`. Members see the trail on their map. When the legendary is skinned, members within `ShareDistance` get the trinkets and the cooldown too; the owner keeps the pelt.
- **Saved hunts:** an active hunt survives a relog, a resource restart or a server restart until it expires (`Config.SaveHunts`).
- **Cooldown telegrams:** with rsg-telegram running, the trapper sends a telegram when a legendary is huntable again.
- **Trophy export** for other resources (e.g. wall trophies in rsg-housing): `exports['rsg-legendary']:GetTrophies(citizenid)` returns `{ animal, seconds, quality, killed_at }` rows.

15 legendaries: bear, buck, boar, wolf, cougar, panther, big horn ram, moose, elk, fox, coyote, bull gator, beaver, pronghorn and Tatanka bison.

## Requirements
rsg-core, rsg-inventory, rsg-target, oxmysql. No ox_lib needed (notify, callbacks, progress bars and locales come from rsg-core).

Optional: rsg-telegram (cooldown telegrams). Optional: rsg-hunting. Its hunting XP gates which maps a player can buy (`Config.XPRequirement`); without it the `hunting` rep is used.

## Install
1. Add the items from `installation/shared_items.lua` to `rsg-core/shared/items.lua` and add their images to `rsg-inventory/html/images`.
2. `ensure rsg-legendary` after its requirements.
3. That's it. The `rsg_legendary_cooldowns`, `rsg_legendary_trophies` and `rsg_legendary_hunts` tables are created (and upgraded) automatically on start.

## Configuration (`shared/config.lua`)
- **Trappers:** NPC model, coords and blip. The ped only spawns when a player is within `TrapperSpawnDistance`.
- **Hunt flow:** hunt duration, clue count and spread, inspect/skin times, cooldown hours, money type.
- **Animals:** model, outfit preset, price (names/descriptions are in the locales), zone centre and radius, aggression, health multiplier, rewards and skin mode.
- **SellPrices:** what the trapper pays per item.
- **Quality / BonusTrinketChance / Trophies / Group / SaveHunts / CooldownTelegram:** the extras above.

Zone centres are approximate. Stand where you want each hunt and update `zone` (x/y only; height is found automatically). Use `/legendpreview` to choose each animal's outfit preset.

## Languages
All text (notifications, target labels and prompts, blips, NUI, command help, animal names and descriptions, Discord logs) lives in `locales/*.json`.

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language in your `server.cfg`:

```
setr rsg:locale en
```

To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values. Keep `%s` / `%d` placeholders in the same order. Item labels come from `rsg-core/shared/items.lua`, not these files.

## Changelog
**3.2.0** – kill quality, bonus trinkets, trophy board + `GetTrophies` export, group hunts, saved hunts, cooldown telegrams.

**3.1.0** – removed ox_lib (rsg-core notify, callbacks, progress bar, locales); ox_target → rsg-target; legendary is deleted on disconnect/expiry; sell refunds items if payment fails; map-use lock can no longer get stuck; spawn-failure notify no longer spams; skin progress bar blocks mounting; NUI Escape only closes when open.

## Commands
| Command | Who | What |
|---|---|---|
| `/abandonhunt` | everyone | Give up your current hunt (the map is used up), or leave a group hunt |
| `/invitehunt <id>` | hunt owner | Invite a nearby player to your hunt |
| `/accepthunt` | everyone | Join the hunt you were invited to |
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
- If a player disconnects or a hunt expires, the spawned legendary is removed from the world.

Support: https://buymeacoffee.com/rexshack
