# rsg-rocks — developer docs

## Architecture

| File | Purpose |
|---|---|
| `client/client.lua` | Zone sync, streams rock props/targets near the player, mining flow |
| `client/workshop.lua` | Camp blips/propsets, drilling and smelting (timed work), foreman target options |
| `client/npcs.lua` | Distance-spawned camp foreman peds with rsg-target |
| `client/nui.lua` | Shared NUI focus (`RocksSetNuiFocus(owner, state)`) for the drill menu and lamp panel, with the single push-to-talk whitelist loop |
| `client/drillmenu.lua` | Foreman drill NUI (`html/`): rock counts, amount stepper, Drill / Drill All; push-to-talk whitelist while focused |
| `client/hatlight.lua` + `html/hatlight.js` | Miner's lamp: draws `DRAW_LIGHT_WITH_RANGE` ahead of the head while the hat is worn; panel (top left, draggable when focused via `/minerlight`) for colour / brightness / spread / on-off; settings + position in client KVP `rsg-rocks:hatlight`; shared via state bag `rocksHatLight` |
| `client/mininghat.lua` | Miner's hat (requires `mininghat` item, auto near rocks + toggle on item use): takes the player's own hat off (meta ped category `hats`, same natives as rsg-wardrobe `/hat`) while the miner's hat is worn and keeps it off (re-checked every second), attaches hat + lamp props, re-applies the hat when the miner's hat comes off (component read off the ped, else rsg-character's clothes cache) |
| `client/admin.lua` | Admin rock placement mode (ghost prop) |
| `server/server.lua` | DB setup/seed, zones, work sessions, rewards, XP, durability, admin commands |

## Database

Table `rsg_rocks_zones` (auto-created, or `install.sql`):

| Column | Type | Notes |
|---|---|---|
| id | INT PK | zone id used by client/server |
| x, y, z | DOUBLE | world coords |
| radius | FLOAT | interact radius (default 2) |
| ore_type | VARCHAR | `rock` or `saltrock` |
| label | VARCHAR | optional, unused by the script |
| enabled | TINYINT | 0 = disabled |

## Work sessions (security model)

Every reward is the end of a server-side session: the client fires a `Start*` event, the server validates (distance, item, cooldown) and records `{kind, key, startTime}`; the `Finish*` event only pays out if the session matches and the elapsed time is within `duration - tolerance` .. `duration + Config.MiningSessionGrace`. Sessions are single-use and cleared on cancel or disconnect. Ore type is always taken from the server's zone record, never from the client.

## Events

| Event | Side | Purpose |
|---|---|---|
| `rsg-rocks:server:StartMining (zoneId)` | server | Open mining session |
| `rsg-rocks:server:MineReward (zoneId)` | server | Finish mining, validate and reward |
| `rsg-rocks:server:StartDrill (item)` / `FinishDrill (item)` | server | Drill one `resource_rock` / `resource_salt_rock` near a camp |
| `rsg-rocks:server:StartSmelt (index)` / `FinishSmelt (index)` | server | Smelt `Config.SmeltRecipes[index]` near a camp |
| `rsg-rocks:server:CancelWork` | server | Clear the active session |
| `rsg-rocks:server:AdminAddRock (oreType, radius, coords, heading)` | server | Admin place from the rsg-gizmo result; validated with `rsg-gizmo:IsPlacementValid` (`Config.AdminPlaceDistance`); zone stored 1.5 m above the prop, heading saved |
| `rsg-rocks:client:SetZones` | client | Full zone list sync |
| `rsg-rocks:client:ZoneDepleted (id, ms)` | client | Global deplete timer for a rock |
| `rsg-rocks:client:SetCooldown (id, ms)` | client | Personal cooldown confirmed by the server |
| `rsg-rocks:client:StartPlaceRock` | client | Enter admin placement mode |
| `rsg-rocks:server:StartDrill (item)` / `FinishDrill (item)` | server | One rock per timed session (`DrillTime`); the client repeats it for a batch |
| `rsg-rocks:client:StopDrillBatch` | client | Server stops a running batch (inventory full, out of rocks, failed session) |
| `rsg-rocks:client:HatWorn (state)` | client (local) | Fired by mininghat.lua when the hat goes on/off; shows/hides the lamp panel |
| `rsg-rocks:client:ToggleMiningHat` | client | Put the miner's hat on / take it off (fired when the `mininghat` item is used) |

## Callbacks

| Name | Returns |
|---|---|
| `rsg-rocks:server:GetZones` | zone list + this character's remaining personal cooldowns (requested on player load and resource restart) |

## Changelog

### 3.0.1
- Fixed: the miner's hat clipped into the player's own hat. The own hat was only removed when its component hash could be read off the ped, and that lookup could fail. It is now removed whenever the `hats` category is in use, and removed again if it comes back while the miner's hat is on (`/hat`, outfit change, revive). It is put back when the miner's hat comes off; if the player had already taken it off with `/hat`, it stays off.
- Fixed: a pickaxe kept at 0 quality (`Config.PickaxeBreakAtZero = false`) could still mine. Mining now needs a pickaxe with quality above 0 (checked on the client for the message, and on the server at start and reward); otherwise the player is told the pickaxe is worn out (`pickaxe_worn`, all 10 locales). Durability is taken from the usable pickaxe, not a 0-quality spare. Raise `info.quality` from a repair / sharpening script to make it usable again.

### 3.6.5 (audit)
- Fixed: smelting could start in the pause between batch-drilled rocks and silently end the batch; smelting and opening the drill menu now say "busy" while work is running.
- Fixed: taking the miner's hat off (using the item) away from a mine stopped it auto-wearing at the next mine visit.
- Fixed: the hat lamp kept shining from dead players (the hat props were already removed on death).
- UX: a drill that fails the server check (walked away from the camp, timing) now explains why instead of silently ending the batch (`work_failed`).
- Optimised: the lamp's colour/brightness/spread are cached when changed instead of parsing the hex colour every frame.

### 3.6.4
- Fixed: rocks placed with `/addrock` spawned in a slightly different spot than the gizmo ghost. rsg-gizmo positions without the model offset (`SetEntityCoordsNoOffset`) while rocks spawn with `CreateObject`, which applies it. The admin client now measures that offset with a hidden probe object and saves compensated coords, so the rock appears exactly where it was placed. Existing rocks are unchanged.

### 3.6.3
- Fixed: `/addrock` refused placement inside mines ("indoors") because mines are interiors and rsg-gizmo blocked interiors. Interiors are now allowed (`Config.AdminPlaceAllowInterior = true`); water is still blocked.

### 3.6.2
- Fixed: two lights on the miner's hat (the chosen colour plus a white one). The `s_movieprojection01x` projector prop has its own built-in light; it is no longer spawned while the adjustable lamp (`Config.MiningHat.light.enabled`) is on, so the lamp is the only light source.

### 3.6.1
- Fixed: personal mining cooldowns were tied to the player's server id, so reconnecting reset them. They are now stored per character (citizenid), survive reconnects and character switches, and are sent back to the client on load so the "try again in Xs" message stays correct. They still reset on a server/resource restart.

### 3.6.0 (audit)
- Fixed: the drill menu could be reopened in the pause between rocks and start a second batch on top of the first (sessions clashed and rocks failed). A batch now blocks the menu and new drills until it ends.
- Fixed: other players' lamp values from their state bag are clamped (colour 0-255, spread and intensity to config limits) so a modified client can't push huge lights onto everyone.
- Optimised: admin rock changes no longer despawn and respawn every rock for every player; only removed or changed rocks are respawned.
- Optimised: removed the `rsg-rocks:server:HasPickaxe` callback round trip before mining (instant client check for UX; the server still checks on start and reward).
- Optimised: one shared NUI focus / push-to-talk loop (`client/nui.lua`) instead of one per UI; the lamp light loop no longer duplicates it.
- Cleanup: expired personal cooldowns are pruned server-side; the hat notification uses `RSGCore.Functions.Notify`; removed unused `mineid` config field and unused locale keys (`drill_label`, `drill_option`, `drill_menu_amount`).

### 3.5.1
- Changed: the lamp panel is hidden until `/minerlight` is used and hides again on Done / Esc.
- Fixed: the light jumped metres away when changing spread (its forward offset was multiplied by the spread). It now sits a fixed `Config.MiningHat.light.forward` metres ahead of the head and spread only changes the radius.
- Fixed: colour / range / intensity are passed to `DRAW_LIGHT_WITH_RANGE` as proper ints / floats, and other players' state-bag data is validated before drawing.

### 3.5.0
- Added: miner's lamp light. While the hat is worn a panel shows top left (drag it by the header when focused) to set the light colour (12 presets), brightness (0-100 %), spread (`minSpread`-`maxSpread` metres) and on/off. `/minerlight` focuses the panel, Esc / Done releases it; push-to-talk keeps working.
- RDR3 has no spotlight native, so the lamp is a point light (`DRAW_LIGHT_WITH_RANGE`) placed ahead of the head; spread = light radius. Tune with `Config.MiningHat.light` (`forward`, `height`, `maxIntensity`).
- Settings and panel position are saved per player (client KVP). With `syncToOthers` the lamp is shared through the `rocksHatLight` state bag so nearby players (`drawDistance`) see it.

### 3.4.0
- Changed: `/addrock` now uses rsg-gizmo to place the rock (move, rotate heading, snap to ground; blocked in interiors/water). The server validates the result with `exports['rsg-gizmo']:IsPlacementValid` within `Config.AdminPlaceDistance`.
- Added: `heading` column on `rsg_rocks_zones` (added automatically to existing tables); rock props spawn with their saved heading.
- Added: rsg-gizmo dependency.

### 3.3.0
- Added: talking to the camp foreman opens a drill NUI listing each drillable rock (`Config.DrillableRocks`) with the amount owned; pick an amount or Drill All.
- Added: batch drilling one rock at a time: each rock is its own server-validated `DrillTime` session, gives its output (and XP) as soon as it finishes, then the next rock starts until the chosen amount is reached (`Config.DrillMaxBatch`, `Config.DrillBatchPause`). The progress bar shows "Drilling rock 3/10"; cancelling stops the batch, and it stops automatically if rocks run out or the inventory is full. A summary notification shows how many were drilled.
- Added: `Config.AllowPushToTalkWhileOpen` / `Config.PushToTalkControls` so rsg-voice push-to-talk works while the menu is open.
- Changed: the two separate "Drill rock" target options are replaced by one "Drill rocks" option.

### 3.2.0
- Added: the miner's hat only works while the `mininghat` item (`Config.MiningHat.item`) is in the inventory (`requireItem`); it comes off if the item is dropped, given or sold.
- Added: using the `mininghat` item puts the hat on / takes it off anywhere. Taking it off near rocks keeps it off until you leave that mine; auto-wear near rocks can be disabled with `autoWear = false`.

### 3.1.0
- Fixed: miner's hat not removed after leaving — tighter default distances (12 m on / 20 m off), props deleted with network control + attached-prop sweep, hat logic wrapped in pcall so it can't stop the zone loop. `Config.MiningHat.debug` prints distances to F8.
- Added: miner's hat (from rex-mininghat) put on automatically within `Config.MiningHat.enterDistance` of a mining rock and removed past `exitDistance`; the original hat is given back. Re-attached after death / clothing reload, restored on logout and resource stop.

### 3.0.1
- Fixed: smelting and drilling could be spammed instantly by triggering the server event directly — both now use timed server sessions like mining.
- Fixed: client set the personal cooldown even when the server refused the reward; cooldown now comes from the server.
- Fixed: pickaxe durability never saved (called a non-existent `Player.Functions.SetItemData`); now uses `exports['rsg-inventory']:SetItemInfo(src, slot, info)`.
- Fixed: `/delrock` couldn't delete disabled rocks; `/togglerock <id>` reported success for ids that don't exist.
- Fixed: target option vanished while a rock was depleted with no feedback — it now stays and shows the remaining time.
- Fixed: foreman target not removed on despawn; propset requested/released once per camp instead of once.
- UX: one smelt option per recipe with item labels (previously auto-smelted the first affordable recipe with raw item names).
- Fixed: pickaxe prop stuck in hand after mining (scenario prop now cleaned up).
- UX: can't start mining while mounted, in a vehicle or swimming.
- Clean-up: removed unused events (`client:StopPlaceRock`, `client:drillrocksinput`), unused `GetMiningXP` callback, legacy string pools, label column sync; default zones seeded in one query; descriptive locale keys; added de, el, es, fr, ja, nl, pl, pt-br, ro.
- Breaking for integrations: events renamed (`CancelMining` → `CancelWork`, `finishdrilling` → `StartDrill`/`FinishDrill`, `Smelt` → `StartSmelt`/`FinishSmelt`; mining events take only the zone id).
