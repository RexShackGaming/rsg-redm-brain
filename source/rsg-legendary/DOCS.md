# rsg-legendary – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Trappers, hunt flow, animals, prices, extras |
| `client/client.lua`, `client/main.js` | Trapper, trail, clues, animal, skinning |
| `server/server.lua` | Maps, hunts, cooldowns, rewards, trophies, groups |
| `server/sv_config.lua`, `server/webhooks.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI trapper shop and trophy board |
| `installation/install.sql` | Manual database install |
| `installation/shared_items.lua` | Items to add to `rsg-core/shared/items.lua` |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
1. **Buy a map** from the Legendary Trapper (rsg-target). Each legendary shows its price, or the time until it returns if you are on cooldown. Map purchase can require hunting XP (`XPRequirement`).
2. **Use the map** from your inventory. The hunting area and first tracks appear on the map.
3. **Follow the trail:** hold `E` at each set of tracks to inspect them. Each clue reveals the next; after the last (`ClueCount`) the legendary appears nearby.
4. **Kill and skin it** with normal skinning. If a model has no skin prompt, an rsg-target "Skin" option appears after `SkinFallbackDelay` seconds.
5. **Sell** pelts and trinkets back to the trapper. Each player can hunt each legendary once per `CooldownHours` (default 24).

Extras:
- **Kill quality:** kills with a bow, knife, throwing knives or varmint rifle (`Quality.PerfectWeapons`) are *perfect* and multiply trinket rewards.
- **Bonus trinket:** `BonusTrinketChance` chance of one extra.
- **Trophy board:** a Trophies tab shows the first hunter and fastest hunt per legendary, plus your own kills.
- **Group hunts:** the owner runs `/invitehunt <id>`; the invitee runs `/accepthunt`. Members see the trail, and rewards are shared with members within `ShareDistance` of the carcass.
- **Saved hunts** survive relogs and restarts until they expire (`SaveHunts`).
- **Cooldown telegrams** through rsg-telegram when a legendary is huntable again.

15 legendaries: bear, buck, boar, wolf, cougar, panther, big horn ram, moose, elk, fox, coyote, bull gator, beaver, pronghorn and Tatanka bison.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Trappers` | list | `id`, `model`, `coords`, `blip` |
| `TrapperInteractDistance` / `TrapperServerDistance` / `TrapperSpawnDistance` | `3.0` / `6.0` / `80.0` | Distances |
| `MapItem` | `'legendary_map'` | Map item |
| `HuntDuration` | `3600` | Seconds a hunt stays active |
| `ClueCount`, `ClueSpread`, `RouteToClue` | `3`, `120.0`, `true` | Trail |
| `ClueZoneDistance`, `ClueTargetDistance`, `CluePromptKey`, `CluePromptHold` | | Clue prompt |
| `ClueInspectDist`, `ClueInspectTime`, `ClueScenario` | `4.0`, `5000` | Inspection |
| `SpawnOffset`, `ActivateDistance` | `60.0`, `120.0` | Animal spawn |
| `SkinFallbackDelay`, `SkinTime`, `DeleteCarriedPelt`, `SkinMaxDistance` | `15`, `8000`, `true`, `6.0` | Skinning |
| `CooldownHours` | `24` | Per player, per legendary |
| `MoneyType` | `'cash'` | Payment account |
| `Quality` | table | `Enabled`, `PerfectWeapons`, `TrinketMult` (2) |
| `BonusTrinketChance` | `0.10` | Extra trinket chance |
| `Trophies`, `Group`, `SaveHunts`, `CooldownTelegram` | tables | Extras (`Group`: `MaxMembers` 3, `InviteDistance` 10, `InviteTimeout` 60, `ShareDistance` 30) |
| `XPRequirement` | table | `Enabled`, `DefaultMinXP` (1000), `RepName` (`hunting`) |
| `Animals` | table | Per animal: model, outfit preset, price, zone centre and radius, aggression, health multiplier, rewards, skin mode |
| `SellPrices` | table | Trapper's price per item |

Zone centres are approximate: stand where you want a hunt and update `zone` (x/y only). Use `/legendpreview` to pick outfit presets. Webhook URLs are in `server/sv_config.lua`.

## 4. Exports, events and commands
| Name | Side | Notes |
|---|---|---|
| `GetTrophies(citizenid)` | server export | A hunter's trophy data |
| `rsg-legendary:server:animalSpawned` | server event | `(netId)` register the legendary |
| `rsg-legendary:client:startHunt` | client event | `(data)` |
| `rsg-legendary:client:endHunt` | client event | End the hunt |
| `rsg-legendary:client:preview` | client event | `(key, preset)` outfit preview |

| Command | Who | What |
|---|---|---|
| `/abandonhunt` | everyone | Abandon the active hunt |
| `/invitehunt <id>` | hunt owner | Invite a nearby player (when groups are enabled) |
| `/accepthunt` | invitee | Accept the invite |
| `/legendpreview` | admin | Preview an animal's outfit presets |

## 5. Database
Created and upgraded automatically on start: `rsg_legendary_cooldowns`, `rsg_legendary_trophies`, `rsg_legendary_hunts`. `installation/install.sql` is the manual option. Add `installation/shared_items.lua` to your items file and the images to `rsg-inventory/html/images`.

## 6. Security
The server owns the hunt: map use, clue distance, animal registration, skin distance (`SkinMaxDistance`), cooldowns and rewards. Sales remove items first and refund on failure; inventory space is checked before giving items.

## 7. How-tos
- Move a hunt: edit the animal's `zone`.
- Remove the XP gate: `XPRequirement.Enabled = false`.
- Without rsg-hunting, the `hunting` rep is used for the XP check.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Can't buy a map | Cooldown, not enough XP, or not near the trapper |
| No skin prompt | Wait `SkinFallbackDelay` for the rsg-target Skin option |
| Hunt gone after restart | Check `SaveHunts` and the `rsg_legendary_hunts` table |
| Animal didn't appear | Get within `ActivateDistance` of the spawn point after the last clue |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-legendary 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Database

Tables: `rsg_legendary_cooldowns`, `rsg_legendary_trophies`, `rsg_legendary_hunts`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.Debug` | `false` |  |
| `Config.Trappers` | `table` |  |
| `Config.TrapperInteractDistance` | `3.0` | rsg-target distance |
| `Config.TrapperServerDistance` | `6.0` | server-side check for buy/sell |
| `Config.TrapperSpawnDistance` | `80.0` | trapper ped only exists while a player is this close |
| `Config.MapItem` | `'legendary_map'` |  |
| `Config.HuntDuration` | `60 * 60` | seconds a started hunt stays active |
| `Config.ClueCount` | `3` | clues to inspect before the animal appears |
| `Config.ClueSpread` | `120.0` | clues are scattered this far from the zone centre (metres, 2D) |
| `Config.RouteToClue` | `true` | draw a GPS route to the next clue |
| `Config.ClueZoneDistance` | `40.0` | clue prompt is armed once you're this close (terrain is loaded) |
| `Config.ClueTargetDistance` | `3.0` | how close you must be for the 'Inspect tracks' prompt to show |
| `Config.CluePromptKey` | `0xCEFD9220` | E (RSGCore.Shared.Keybinds['E']) |
| `Config.CluePromptHold` | `1000` | ms to hold the key |
| `Config.ClueInspectDist` | `4.0` | server check: player must be this close to a clue |
| `Config.ClueInspectTime` | `5000` | ms crouch-inspect |
| `Config.ClueScenario` | ``WORLD_HUMAN_CROUCH_INSPECT`` | rdr3_discoveries/animations/scenarios |
| `Config.SpawnOffset` | `60.0` | animal spawns this far beyond the last clue |
| `Config.ActivateDistance` | `120.0` | the legendary spawns once you are this close to its spawn point |
| `Config.SkinFallbackDelay` | `15` | seconds after death before an rsg-target 'Skin' option appears (0 = never). Covers models with no native skin  |
| `Config.SkinTime` | `8000` | ms progress bar for rsg-target skinning |
| `Config.DeleteCarriedPelt` | `true` | remove the vanilla pelt the game puts on your shoulder (you get the RSG items instead) |
| `Config.SkinMaxDistance` | `6.0` | server: player must be this close to the carcass |
| `Config.CooldownHours` | `24` | per player, per legendary animal |
| `Config.MoneyType` | `'cash'` |  |
| `Config.Quality` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.PerfectWeapons` | `{ `WEAPON_BOW`, `WEAPON_BOW_IMPROVED`, `WEAPON_MELEE_KNIFE`, `WEAPON_T` |  |
| `Config.TrinketMult` | `2` |  |
| `Config.BonusTrinketChance` | `0.10` | 0.0 - 1.0 |
| `Config.Trophies` | `table` |  |
| `Config.CacheSec` | `60` |  |
| `Config.Group` | `table` |  |
| `Config.MaxMembers` | `3` |  |
| `Config.InviteDistance` | `10.0` |  |
| `Config.InviteTimeout` | `60` |  |
| `Config.ShareDistance` | `30.0` |  |
| `Config.SaveHunts` | `true` |  |
| `Config.CooldownTelegram` | `table` |  |
| `Config.CheckMin` | `5` |  |
| `Config.XPRequirement` | `table` | stored as player rep 'hunting'). Each animal can set its own minXP; otherwise DefaultMinXP is used. |
| `Config.DefaultMinXP` | `1000` |  |
| `Config.RepName` | `'hunting'` |  |
| `Config.ZoneBlipStyle` | ``BLIP_STYLE_AREA`` | Blip styles (rdr3_discoveries/useful_info_from_rpfs/blip_styles) |
| `Config.ClueBlipStyle` | ``BLIP_STYLE_OBJECTIVE`` |  |
| `Config.Animals` | `table` |  |
| `Config.SellPrices` | `table` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `GetTrophies` | `citizenid` | `server/server.lua` |

```lua
-- example
local result = exports['rsg-legendary']:GetTrophies(citizenid)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-legendary:client:startHunt` | client | `data` | `client/client.lua` |
| `rsg-legendary:client:endHunt` | client | `` | `client/client.lua` |
| `rsg-legendary:client:preview` | client | `key, preset` | `client/client.lua` |
| `rsg-legendary:server:animalSpawned` | server | `netId` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-legendary:server:animalSpawned', netId)
-- from a server script
TriggerClientEvent('rsg-legendary:client:startHunt', source, data)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/abandonhunt` | locale('cmd_abandon') | `server/server.lua` |
| `/invitehunt` | locale('cmd_invite') | `server/server.lua` |
| `/accepthunt` | locale('cmd_accept') | `server/server.lua` |
| `/legendpreview` | locale('cmd_preview') | `server/server.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
