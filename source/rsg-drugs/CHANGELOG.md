# Changelog

All notable changes to rsg-drugs. Newest first.

## 3.3.0

### Added
- **Product potency** (`Config.Quality`): crew skill sets the potency of what they make, input potency is partly carried through, and the lab shows it per stock type. Withdrawn items carry `info.potency` (rounded to `Step` so stacks still merge) and it changes what bags and bricks sell for (`PriceMin` to `PriceMax`). Bricks are exported best potency first.
- **Heat and raids** (`Config.Heat`): making and selling drugs builds heat on your lab (shown as a bar in the lab panel). A hot lab can be reported: on-duty law get a map blip and a notification, the owner is warned, and an officer can use *Raid Lab* on the processing NPC within the window. A raid destroys `SeizePercent` of the stock and pays the officer. If nobody raids in time the heat drops only to `HeatAfterEscape`.
- **Low wage chest warning** (`Config.Payroll`): the owner is told when the chest covers fewer than `WarnShifts` shifts.
- **rsg-skills** (`Config.Skills`): a `drugs` skill is registered, drug XP feeds it, `sell_bonus` raises NPC bag and brick export prices and `speed_bonus` speeds up the crew. Skill XP is reset with drug XP when jailed.
- **rsg-reputation** (`Config.Reputation`): sales, refusals and exports cost honor and town standing; admitting addicts and raids earn it. Towns that are hostile to you buy less (`HostileBuyMult`).
- **rsg-economy** (`Config.Economy`): NPC bag sales follow the town's market multiplier and move it (flooding a town lowers the price).
- **Opium** substance (`opium_resin` item, see `installation/shared_items.lua`): a hook for your own gathering or crafting scripts. Tobacco is fed by rsg-smoking through `AddUse`.
- New locale keys in all 11 languages: `payroll_low`, `raid_*`, `ui_heat`, `ui_raid_warn`, `ui_potency`, `cfg_sub_opium`, `cfg_skill_drugs`, `cfg_skill_drugs_desc`.

### Changed
- `server/integrations.lua` holds the guarded rsg-skills / rsg-reputation / rsg-economy calls: a missing or restarting resource never breaks rsg-drugs.
- `DrugsProximityNpc` accepts a list of target options.

## 3.2.0

### Added
- Push-to-talk keeps working while a panel is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`). All NUI focus now goes through one helper (`DrugsNuiFocus` in `client/utils.lua`).
- Lab, export and addiction panels close automatically when you walk away from the NPC or die.
- Firing a worker needs a second click ("Confirm?") so a slip can't sack someone.
- `Config.Addiction.Rehab.Reward.PlayerCooldown` (default 300 s): one rehab bonus per officer per cooldown for admitting players (stops two friends farming each other).
- `server/utils.lua`: shared `DrugsCallback` wrapper and `DrugsEnsureDatabase()`.

### Changed
- The lab payload now includes the player's supplies, so opening the lab and every action is one server callback instead of two (`rsg-drugs:server:getSupplies` is removed).
- Both database tables are built by one function (with a clear console message on success or failure) instead of three separate queries.
- The rehab timer and addiction tick check the replicated statebag first and only copy the full player object for players who are in rehab or have an addiction, instead of every player every 5 s / 60 s.
- Tobacco substance label is localised (`cfg_sub_tobacco`); new `ui_confirm` key. Both added to all 11 languages.

### Fixed
- NPC sale / refusal state is cleared when the ped is removed, so a recycled network id can't inherit another NPC's "already sold" or "refused" flag.
- An error during an NPC sale could leave the sell option hidden until the next restart; the sale is now wrapped so it always resets.
- Opening a panel twice quickly (target double click) could run two opens.
- `/setaddiction` ignores a NaN level.
- Merged duplicate `playerDropped` handlers in `server/addiction.lua`.

## 3.1.4

### Changed
- Alcohol addiction now hooks the server event `rsg-consume:server:consumed` (rsg-consume 3.3.0+) instead of a client relay (`rsg-drugs:server:consumed` is removed). Items cancelled early or refunded no longer count as a use.

## 3.1.3

### Changed
- The brick export market is now saved in a new `rsg_drugs_state` table (created automatically, also in `installation/install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. The previous KVP market is not migrated: the market starts fresh (empty stock, normal demand) after this update.

## 3.1.2

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
