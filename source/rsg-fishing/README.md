# rsg-fishing

Fishing for **RSG-Core** (RedM), version 3.2.0. Full technical reference: [DOCS.md](DOCS.md).

 Players equip a fishing rod, bait it with an item from their inventory, cast, hook and reel in fish. Caught fish go into the inventory with their weight. An on-screen HUD guides the player through each step.

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
- **Bite conditions:** the bite chance rises at dawn and dusk and in drizzle or rain, and falls at midday, at night and in storms (`Config.BiteModifiers`, weather from rsg-weather). The controls HUD shows Bites: Poor / Fair / Good.
- **Regional fish:** the state under the hook decides which species can bite (`Config.Regions.Pools`). The legendary sockeye salmon only bites at the waters in `Config.Regions.LegendarySpots`.
- **Angler's journal:** `/fishjournal` opens a window with your catalogue of species (times caught and best weight), the server's record for each species and the top anglers. Records are announced when beaten and can pay a reward (`Config.Records`).
- **Skill perks (rsg-skills):** the `fishing` skill adds `bite_chance` (more bites), `line_strength` (the line strains less) and `rare_chance` (heavier fish).
- **Reputation (rsg-reputation):** a first catch of a species, a beaten record and a completed journal give honor and standing (`Config.Reputation`).
- **Logging:** catches are sent to `rsg-log` (`fishing` channel) when `Config.Log` is on.
- **Languages:** cs, de, el, en, es, fr, it, ja, nl, pl, pt-br, ro, ru. Set with `setr rsg:locale <lang>`.

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [oxmysql](https://github.com/overextended/oxmysql) (journal and records)
- `rsg-log` (optional, for catch logs)
- `rsg-weather`, `rsg-skills`, `rsg-reputation` (optional; each feature is skipped when the resource is not started)

## Installation

1. Put `rsg-fishing` in your `resources` folder.
2. Make sure the bait items listed in `Config.Baits` and the fish items exist in your RSG shared items.
3. Add it to `server.cfg` after its dependencies:
   ```
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-fishing
   ```
4. The database tables (`rsg_fishing_journal`, `rsg_fishing_records`) are created automatically on first start. To install them manually, set `Config.AutoDatabase = false` and import `install.sql`.
5. For the perks and reputation, use rsg-skills 3.0.1+ and rsg-reputation 3.0.3+ (they add the fishing perks and actions).
6. Restart the server. After updating the UI files, restart the resource (players may need to reconnect).

## How to fish (players)

1. Take out your fishing rod.
2. Use a bait item from your inventory.
3. Follow the HUD: prepare the rod, then cast.
4. Watch the float. When it turns into a fish, hook it, then **hold** the reel key (SPACE) to bring it in. When the fish struggles (splashing, tension bar rising), let go until it calms down, then hold again.
5. Keep the fish or throw it back.

## Configuration (`shared/config.lua`)

| Option | Description |
|---|---|
| `Config.Difficulty` | How long (ms) each reel pull lasts. It is repeated while the reel key is held, so this mostly sets how quickly the fish stops when you let go |
| `Config.ReelInSpeed` | How fast a hooked fish swims towards you while you reel (default `1.5`) |
| `Config.ReelSpeed` | How fast an empty hook/lure reels towards the player (CTRL, before a fish bites) |
| `Config.StruggleChance` | Chance per tick that a hooked fish struggles (0.0–1.0) |
| `Config.FishWeightMultiplier` | Converts game weight units to the KG shown to players |
| `Config.CatchCooldown` | Minimum ms between accepted catches |
| `Config.MaxRawFishWeight` | Upper limit on the weight accepted from clients |
| `Config.GroundPickup` | Store fish picked up off the ground (no bait needed). Set `false` to stop it |
| `Config.GroundPickupLimit` | `Max` ground pickups per player per `Window` seconds (default 10 per hour) |
| `Config.MinCatchTime` | Minimum ms between bait on the rod and an accepted catch |
| `Config.EnforceBaitList` | Fish only bite, and the server only accepts them, when the bait is listed for them in `Config.BaitsPerFish` |
| `Config.BiteChance` | Chance per second that a fish next to the hook bites (0.0–1.0) |
| `Config.WeightBands` / `Config.WeightFactor` | Weight ranges for small / medium / large fish |
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
| `Config.fishData` | Fish model, display name and weight band |

If a HUD key name is wrong for your keybinds, change it in `Config.ControlKeys`. If a row doesn't light up when the key is pressed, change its control in `Config.ControlInputs`.

## Journal, records and regions

- **Command:** `/fishjournal` (`Config.Journal.Command`). Set `Config.Journal.Key` to a key name such as `'J'` for a key that players can rebind in the game's key settings (needs rsg-core 3.5.0+).
- While the journal is open, game controls are blocked but push-to-talk keeps working (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).
- **Regions:** change which species can bite in each state in `Config.Regions.Pools`; set `Config.Regions.Enabled = false` to allow every fish everywhere. Add `coords` and `radius` to a legendary spot to have the server check the player's position too.
- **Bite conditions:** tune `Config.BiteModifiers.Time` and `.Weather`, or turn them off with `Enabled = false`.
- **Records:** `Config.Records` (`Enabled`, `Announce`, `Reward`, `TopCount`).

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

- `rsg-fishing:server:newRecord` (local event for other scripts): `(src, family, kg, previousHolderName)`, fired when a server record is beaten.

- `rsg-fishing:server:catchFish` (renamed from `rsg-fishing:FishToInventory`; update any script that triggered the old name)

## Changelog

**3.2.0**
- New: bite conditions (time of day and weather), regional fish pools and legendary spots, angler's journal with server records and top anglers (`/fishjournal`), rsg-skills perks and rsg-reputation actions.
- New dependency: oxmysql. Two tables are created automatically.
- `Config.fishData` rows now carry a species family as a third value.

**3.1.1**
- Security: the server now checks the fish against the bait used (`Config.EnforceBaitList`), the time since the bait went on the rod (`Config.MinCatchTime`) and the weight band of the fish, and caps ground pickups (`Config.GroundPickupLimit`). Before, a modified client could claim any fish, including the most valuable ones, for the price of one bait.
- Bait is now spent when it is put on the rod, not when the item is used, so holstering the rod early no longer wastes it.
- Fewer game calls while fishing (minigame writes are sent once per frame and only when changed) and fewer NUI messages for the bobber marker.
- Items are added and removed through rsg-inventory exports.
- Removed unused provision strings from `Config.fishData`; weight bands now live in `Config.WeightBands` / `Config.fishData`; new `Config.BiteChance`.

**3.1.0**
- Optional rsg-skills integration: fishing XP per catch (`Config.Skills`).

**3.0.4**
- Fixed reeling: holding the reel key now keeps pulling the fish in. Before, each key press only pulled for half a second, and a key held through a struggle did nothing afterwards.
- The reel key is read even when the fishing task disables the control.
- The client now takes network control of the hooked fish, so reeling works on fish spawned by another player.
- New `Config.ReelInSpeed`.
- Added `DOCS.md`.

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

## rsg-skills integration

Optional. When `rsg-skills` is started, every fish caught with the rod awards fishing XP (`Config.Skills.CatchXP`, default 10). Fish picked up off the ground earn nothing. Set `Config.Skills.Enabled = false` to turn it off. Nothing breaks when rsg-skills is not installed.


## License

See [LICENSE](LICENSE).

Support the Project : https://rexshack.tebex.store/
