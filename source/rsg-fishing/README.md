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
- **Live key presses:** a HUD row lights up while the player holds its key.
- **Bobber indicator:** a float image follows the bobber on screen. It turns into a wriggling fish when a fish is hooked, and back into a float if the fish gets away.
- **Server-side checks:** only real bait items are accepted, a catch needs spent bait first, a catch cooldown applies, and fish weight is capped.
- **Logging:** catches are sent to `rsg-log` (`fishing` channel).
- **Languages:** cs, de, el, en, es, fr, it, pl, pt-br.

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- `rsg-log` (optional, for catch logs)

## Installation

1. Put `rsg-fishing` in your `resources` folder.
2. Make sure the bait items listed in `Config.Baits` and the fish items exist in your RSG shared items.
3. Add it to `server.cfg` after its dependencies:
   ```
   ensure ox_lib
   ensure rsg-core
   ensure rsg-fishing
   ```
4. Restart the server. After updating the UI files, restart the resource (players may need to reconnect).

## How to fish (players)

1. Take out your fishing rod.
2. Use a bait item from your inventory.
3. Follow the HUD: prepare the rod, then cast.
4. Watch the float. When it turns into a fish, hook it and reel it in.
5. Keep the fish or throw it back.

## Configuration (`config.lua`)

| Option | Description |
|---|---|
| `Config.Difficulty` | How hard fish pull back while reeling |
| `Config.ReelSpeed` | How fast the hook reels towards the player |
| `Config.StruggleChance` | Chance per tick that a hooked fish struggles (0.0–1.0) |
| `Config.FishWeightMultiplier` | Converts game weight units to the KG shown to players |
| `Config.CatchCooldown` | Minimum ms between accepted catches |
| `Config.MaxRawFishWeight` | Upper limit on the weight accepted from clients |
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
config.lua            Settings
```

## Exports (client)

- `GET_TASK_FISHING_DATA_EXTRA`
- `SET_TASK_FISHING_DATA_EXTRA`
- `VERTICAL_PROBE`

## License

See [LICENSE](LICENSE).
