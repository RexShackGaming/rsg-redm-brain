# Changelog

All notable changes to rsg-farming. Newest first.

## 3.6.0

### New
- **Scarecrow** (`p_scarecrow05x`): lowers the pest chance around it (`Config.Scarecrow`).
- **Sprinkler** (`Config.Sprinkler`): waters nearby plants from an rsg-wellpump pump using its new `DrawWater` export (needs rsg-wellpump 3.1.0). The default model is a placeholder.
- New table `rsg_farming_props` (created automatically; also in `install.sql`) and 9 locale keys in all 11 languages.
- Requires the `scarecrow` and `sprinkler` items in rsg-core.

## 3.5.0

### New
- **Owner alerts**: the planter gets one notification per type per growth tick when crops are ready, dry, infested or withered (`Config.Alerts`).
- **Map blips** for the plants you can tend (`Config.Blips`).
- **Per-crop seasons** (`seasons` on a crop overrides `Config.Seasons`; warm-season crops now crawl in winter, potatoes cope) and **weather effects** (`Config.WeatherEffects`: snow, blizzards, hail, sandstorms and heat; `hardy = true` crops ignore cold). Check the crop examples if you do not want the new balance.
- **Farmland**: `Config.RequirePlantZone` + `Config.PlantZones` restrict planting to farm areas, `Config.PlantTool` requires an item such as a hoe (not consumed). Both are checked on the server.
- **Shared farms** (`Config.Sharing`, off by default): members of the planter's gang or job can tend, harvest and remove that plant.
- **Crop theft** (`Config.Theft`, off by default): non-owners can harvest for a reduced yield; the owner is notified, on-duty lawmen can be alerted through rsg-lawman (never for `illegal = true` crops such as weed), and an rsg-reputation action is applied.
- **Soil and compost** (`Config.Soil`): patches of ground tire when the same crop is harvested again and again; rotate crops or use a fertiliser with `soil > 0` to heal them. A Soil bar shows in the panel. Stored in the new `rsg_farming_soil` table.
- **Fertiliser tiers**: `Config.Fertilizers` replaces `FertilizerItem` / `FertilizerAmount` / `FertilizerBoost`; each entry has `item`, `amount`, `boost` and `soil`.

### Changed
- Saving: dirty plants are written with one batched UPDATE per 100 plants instead of one UPDATE each (UPDATE only, so a harvested plant can never come back).
- Scenario clean-up (`Config.ScenarioCleanup = 'tracked'`): only props that attached to the player's ped are removed; nothing else in the world is touched, and the wait after an action is shorter (`Config.ScenarioExitWait`). `'sweep'` restores the old behaviour.
- The `[G]` prompt text shows `Config.InteractKeyName` (locale key `tend_plant` now takes the key and the crop).
- `shared/zones.lua` holds the zone checks used by both client and server (the duplicated helpers were removed).
- `rsg_farming_plants` gets a `share_key` column (added automatically; see `install.sql` for manual upgrades).
- 11 new locale keys in all 11 languages: `alert_ready`, `alert_thirsty`, `alert_pests`, `alert_dead`, `alert_theft`, `law_alert_theft`, `blip_plant`, `place_not_farmland`, `need_tool`, `soil_poor`, `ui_soil`.

## 3.4.0

### Security
- Plant data is now filtered per player: the server only sends your own plants plus other players' plants within `Config.SyncDistance` (default 250 m). Before, every client received the position of every plant on the server, so a modified client could map everyone's farms.
- The plant callback now refuses calls that arrive faster than `Config.PlantTime` allows, so the planting animation can't be skipped to spam placements.

### Performance
- Syncs no longer re-send every plant to every player each growth tick (this grew with players x plants). Players who travel far get the plants around their new position every few seconds; single-plant updates go only to the owner and players in range.
- Plants with pests are no longer marked for saving on every tick (pests aren't stored).
- The `[G]` prompt fallback (`UseTarget = false`) no longer polls every frame; it uses a slow proximity loop plus a rebindable key.

### Changed
- New `Config.UseKeyMapping` / `Config.InteractKeyName`: the `[G]` prompt key is registered through rsg-core `RegisterKey` and is rebindable in the game's key settings. `Config.UseKeyMapping = false` keeps the old `Config.InteractKey` control polling.
- New `Config.ReopenAfterAction`: the plant panel reopens after watering, fertilising or treating, so tending is one click per step.
- Callback handler errors are logged and answered with a failure instead of leaving the client waiting for a timeout.
- `/farmlevel` help text is now localised; new locale keys `key_tend` and `cmd_farmlevel` in all 11 languages.
- Removed the unused `Utils.idsOwnedBy` / `Utils.broadcastOwned` helpers.

## 3.3.0

### Changed
- Well pumps moved to the new standalone **rsg-wellpump** resource (now a required dependency). rsg-farming no longer places pumps, fills buckets or stores pumps; watering calls `exports['rsg-wellpump']:UseBucket(src)`.
- Removed `Config.WellPump`, `Config.WaterReturnItem`, the `pump_*` and `bucket_uses` locale keys, and the `rsg_farming_wellpumps` table from the schema and `install.sql`. Existing pumps are imported by rsg-wellpump on its first start; the old table is left untouched.

## 3.2.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
