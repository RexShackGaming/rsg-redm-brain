# rsg-samples — Developer Docs

## Dependencies
`rsg-core`, `rsg-target`, `oxmysql`, OneSync. **No ox_lib** (removed in 2.1.1).

## Framework usage
| Feature | Provided by |
|---|---|
| Locales (`locale(key, ...)`) | `@rsg-core/shared/locale.lua`, files in `locales/*.json`, convar `rsg:locale` |
| Client notify | `exports['rsg-core']:Notify({ title, description, type, duration })` |
| Server notify | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` (local `notify()` helper in `server/main.lua`) |
| Leaderboard interaction | `exports['rsg-target']:addSphereZone` (`client/target.lua`) |
| Player ped | `PlayerPedId()` |
| Database | oxmysql; `player_samples` table auto-created (`Config.AutoInstallDB`), manual SQL in `install/rsg-samples.sql` |

## Languages
en, de, el, es, fr, ja, nl, pl, pt-br, ro — add more by copying `locales/en.json`.

## Commands
- `/samplesmenu` — open the samples UI
- `/samplecert` — show your certificate
- `/setfeatured <animal>` — admin: set/clear the featured animal

## Security
Sample payouts are validated server-side (model, health, distance, duplicate checks) before any reward is paid.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-samples 3.0.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`/onesync`, `oxmysql`, `rsg-target`, `rsg-core`

### Database

Tables: `player_samples`.

For a manual install set `Config.AutoDatabase = false` and import `install/rsg-samples.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.DebugClient` | `false` | Print client-side debug logs to F8 console |
| `Config.DebugServer` | `false` | Print server-side debug logs to server console |
| `Config.AutoInstallDB` | `true` | create the player_samples table automatically on resource start |
| `Config.StoreSampleData` | `true` | false = no DB writes; collections kept in memory until restart (testing only) |
| `Config.SampleHoldTime` | `4000` | ms — how long to hold the prompt to collect |
| `Config.AnimalCleanupTime` | `90000` | ms — how long before a sedated animal recovers (90s) |
| `Config.SampleCooldown` | `3000` | ms — server-side minimum gap between a player's sample submissions (anti-spam/exploit) |
| `Config.LeaderboardLocation` | `table` |  |
| `Config.ShowBlip` | `true` |  |
| `Config.BlipSprite` | `'blip_shop_trapper'` | blip sprite name (or hash) |
| `Config.BlipColor` | `'BLIP_MODIFIER_MP_COLOR_8'` | blip colour modifier ('' = default) |
| `Config.BlipScale` | `0.2` |  |
| `Config.MilestoneRewards` | `table` |  |
| `Config.FirstDiscoveryBonus` | `500` |  |
| `Config.FeaturedAnimal` | `''` | e.g. 'bear', 'moose', 'bison' — must match a name in hashToAnimalMap (server/main.lua) |
| `Config.FeaturedMultiplier` | `2` | reward is multiplied by this when sampling the featured animal |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-samples:client:openSamplesMenu` | client | `data` | `client/main.lua` |
| `rsg-samples:server:sampleAnimal` | server | `netId` | `server/main.lua` |
| `rsg-samples:server:requestMenu` | server | `` | `server/main.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-samples:server:sampleAnimal', netId)
-- from a server script
TriggerClientEvent('rsg-samples:client:openSamplesMenu', source, data)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/samplesmenu` | locale('cmd_samplesmenu') | `server/main.lua` |
| `/samplecert` | locale('cmd_samplecert') | `server/main.lua` |
| `/setfeatured` | locale('cmd_setfeatured') | `server/main.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
