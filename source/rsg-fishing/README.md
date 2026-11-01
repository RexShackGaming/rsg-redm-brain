# rsg-fishing

Fishing for **RSG-Core** (RedM). Players equip a fishing rod, bait it with an item from their inventory, cast, hook and reel in fish. Caught fish go into the inventory with their weight. An on-screen HUD guides the player through each step.

## Features

- **Bait system:** 15 usable bait and lure items. Each fish species has its own bait preferences (`Config.BaitsPerFish`).
- **Controls HUD (top-left):** a dark panel that shows the current step and the keys for it.
  - Rod out with no bait: warns the player to use bait from their inventory.
  - Rod baited: shows the bait name and the keys to prepare and cast.
  - Line in the water: hook, reset cast, reel lure.
  - Fish on: reel in, reset cast (green highlight).
  - Fish caught: fish name and weight, keep or throw back.
- **Line tension:** reeling while a fish struggles strains the line. A tension bar in the HUD goes green, amber, then red; at 100% the line snaps and the fish and bait are lost. Bigger fish strain it faster. Ease off to let it recover.
- **Sound, rumble and music:** bite, struggle, snap and catch sounds from the game's own fishing soundset, controller rumble on bites, struggles, snaps and catches, and the game's fishing music while you fish. Each can be turned off.
- **Live key presses:** a HUD row lights up while the player holds its key.
- **Bobber indicator:** a float image follows the bobber on screen. It turns into a wriggling fish when a fish is hooked, and back into a float if the fish gets away.
- **Server-side checks:** only real bait items are accepted, a minigame catch needs a spent bait (one catch per bait), a catch cooldown applies, fish weight is capped and inventory space is checked before the fish is added.
- **Ground pickup:** fish picked up off the ground go straight into the inventory (can be turned off with `Config.GroundPickup`).
- **Logging:** catches are sent to `rsg-log` (`fishing` channel) when `Config.Log` is on.
- **Languages:** cs, de, el, en, es, fr, it, ja, nl, pl, pt-br, ro. Set with `setr rsg:locale <lang>`.

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- `rsg-log` (optional, for catch logs)

## Installation

1. Put `rsg-fishing` in your `resources` folder.
2. Make sure the bait items listed in `Config.Baits` and the fish items exist in your RSG shared items.
3. Add it to `server.cfg` after its dependencies:
   ```
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-fishing
   ```
4. Restart the server. After updating the UI files, restart the resource (players may need to reconnect).

## How to fish (players)

1. Take out your fishing rod.
2. Use a bait item from your inventory.
3. Follow the HUD: prepare the rod, then cast.
4. Watch the float. When it turns into a fish, hook it and reel it in.
5. Keep the fish or throw it back.

## Configuration (`shared/config.lua`)

| Option | Description |
|---|---|
| `Config.Difficulty` | How hard fish pull back while reeling |
| `Config.ReelSpeed` | How fast the hook reels towards the player |
| `Config.StruggleChance` | Chance per tick that a hooked fish struggles (0.0–1.0) |
| `Config.FishWeightMultiplier` | Converts game weight units to the KG shown to players |
| `Config.CatchCooldown` | Minimum ms between accepted catches |
| `Config.MaxRawFishWeight` | Upper limit on the weight accepted from clients |
| `Config.GroundPickup` | Store fish picked up off the ground (no bait needed). Set `false` to stop it |
| `Config.Log` | Send catches to `rsg-log` |
| `Config.LineSnap` | `Enabled`, `Gain` (tension per frame while reeling a struggling fish), `Recover` (tension lost per frame otherwise) |
| `Config.Sounds` | `Enabled`, `Soundset`, and the sound `Names` (set one to `''` to mute it) |
| `Config.Rumble` | `Enabled` and `{ duration ms, frequency 0-255 }` for `Bite`, `Struggle`, `Snap`, `Caught` |
| `Config.Music` | `Enabled`, `Start` and `Stop` music events |
| `Config.Debug` | Debug prints and fish markers |
| `Config.ControlKeys` | Key names shown in the HUD (display only) |
| `Config.ControlInputs` | Controls watched for the live key highlight (hash or `INPUT_*` name) |
| `Config.BobberMarker` | `Enabled`, `ScreenIcon` (float/fish image), `ScreenIconSize` (px) |
| `Config.Baits` | Items that can be used as bait |
| `Config.BaitsPerFish` | Which baits attract which fish |
| `Config.fishData` | Fish names and provision data |

If a HUD key name is wrong for your keybinds, change it in `Config.ControlKeys`. If a row doesn't light up when the key is pressed, change its control in `Config.ControlInputs`.

## Files

```
client/client.lua     Fishing logic, HUD and bobber updates
client/client_js.js   Fishing minigame data read/write
server/server.lua     Bait items, catch checks, inventory, logging
html/index.html       Controls HUD and bobber indicator (NUI)
locales/*.json        Translations
shared/config.lua     Settings
```

## Exports (client)

- `GET_TASK_FISHING_DATA_EXTRA`
- `SET_TASK_FISHING_DATA_EXTRA`

## Server events

- `rsg-fishing:server:catchFish` (renamed from `rsg-fishing:FishToInventory`; update any script that triggered the old name)

## Changelog

**3.0.3**
- Line tension and snapping, with a tension bar in the HUD.
- Fishing sounds, controller rumble and fishing music (from the RDR3 decompiled `fishing_core.c`).

**3.0.2**
- Removed ox_lib: locales, notifications and ped lookups now use rsg-core.
- Inventory space is checked before a fish is added; no more lost fish with full pockets.
- Fixed double item popups (AddItem/RemoveItem already show them).
- Fixed a kept fish being picked up a second time by the ground pickup loop.
- Fixed channel catfish using the small-fish weight range.
- Struggle splash effect no longer spawns every frame and its asset load can no longer hang.
- Removed unused prompt groups (the HUD replaced them), the unused `VERTICAL_PROBE` export and duplicated fish tables.
- HUD title is now translated. Added ja, nl and ro locales.

## License

See [LICENSE](LICENSE).

Support: https://buymeacoffee.com/rexshack
