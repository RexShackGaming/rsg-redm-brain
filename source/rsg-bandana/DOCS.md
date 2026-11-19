# rsg-bandana – Docs (v3.0.3)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. For other scripts
6. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core` |
| `shared/config.lua` | Command, item, timings, native values |
| `client/client.lua` | Toggle logic, animation, export |
| `server/server.lua` | `/bandana` command and optional useable item |
| `server/versionchecker.lua` | GitHub version check |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- `/bandana` pulls the bandana over the face or drops it round the neck, using the RDR2 wearable-state system (male and female, on foot or mounted).
- Hand-to-face animation: right hand on foot, left hand mounted.
- Blocked while dead, ragdolled, swimming, hogtied, cuffed or in a vehicle. The state is re-checked after the animation, so it can't finish if the player is downed mid-way.
- Only works once the character is fully logged in; per-toggle cooldown; the bandana is lowered cleanly if the resource restarts.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Command` | `'bandana'` | Toggle command |
| `UseItem` | `false` | Also toggle by using an inventory item |
| `ItemName` | `'bandana'` | Item to register as useable (must exist in rsg-core items) |
| `Cooldown` | `2500` | ms between toggles |
| `AnimTime` | `1200` | ms into the animation before the state swaps |
| `PlayAnim` | `true` | Play the hand-to-face animation |
| `Debug` | `false` | Print neckwear state to F8 |

`NeckwearCategory`, `StateUp`, `StateDown` and `Anims` come from decompiled game scripts and should not be changed.

## 4. Exports, events and commands
| Name | Side | Notes |
|---|---|---|
| `IsWearingBandana()` | client export | Reads the ped's real clothing state |
| `rsg-bandana:client:toggle` | client event | Toggle (sent by the server) |

| Command | Who | What |
|---|---|---|
| `/bandana` | everyone | Raise or lower the bandana |

## 5. For other scripts
- Use `exports['rsg-bandana']:IsWearingBandana()` for anything that matters (for example witness checks); it stays correct after wardrobe changes.
- State bag `Player(src).state.bandana` (server) / `LocalPlayer.state.bandana` (client) is handy for display, but it is set by the client, so don't trust it for anything a cheater could exploit.

## 6. Troubleshooting
| Problem | Fix |
|---|---|
| Nothing happens | Character must be loaded and not dead, swimming, cuffed or in a vehicle |
| Item does nothing | `UseItem = true` and the item exists in `items.lua` |
| Toggles too slowly | Lower `Cooldown` |
| Wrong state after clothing change | Use the export instead of the state bag |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-bandana 3.0.3**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Command` | `'bandana'` | /bandana toggles up/down |
| `Config.UseItem` | `false` | true = also toggle by using an inventory item |
| `Config.ItemName` | `'bandana'` | item to register as useable (must exist in rsg-core items) |
| `Config.Cooldown` | `2500` | ms between toggles |
| `Config.AnimTime` | `1200` | ms into the animation before the state swaps |
| `Config.PlayAnim` | `true` | play the RDR2 hand-to-face animation |
| `Config.Debug` | `false` | print neckwear state to F8 when toggling |
| `Config.NeckwearCategory` | `0x5FC29285` | "neckwear" (same for male and female MP peds) |
| `Config.StateUp` | `-1829635046` | wearable state: bandana over face |
| `Config.StateDown` | `joaat('BASE')` | wearable state: bandana round neck |
| `Config.Anims` | `table` |  |

### Exports

**Client**

| Export | Arguments | File |
|---|---|---|
| `IsWearingBandana` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-bandana']:IsWearingBandana()
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-bandana:client:toggle` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |

```lua
-- from a server script
TriggerClientEvent('rsg-bandana:client:toggle', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
