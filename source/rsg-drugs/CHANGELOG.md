# Changelog

All notable changes to rsg-drugs. Newest first.

## 3.4.0

### Added
- **Towns** (`Config.Corner.Towns`): per-town price, buyer limit, heat and undercover-chance modifiers (needs rsg-economy).
- **Regulars** (`Config.Corner.Regulars`): a fair sale can win a regular who returns, pays more and orders more as loyalty grows, and is lost if insulted. Saved on the character.
- **Bribes** (`Config.Heat.Bribe`): the lab owner can bribe an officer to call off a pending raid (can fail) or to cool the heat down. Button in the Overview tab.
- 11 new locale keys in all 11 languages.

### Added
- **Corner selling:** buyer types (*tight wallet*, *big spender*), **undercover stings** (a bust seizes the goods, pays nothing, adds heat and shows the law the exact spot; only while law is online), a persistent **corner rank** that raises prices, a **demand** system where sales push the street price down for everyone, and a **town average** (rsg-economy) in the haggle panel. `Haggle.MaxDealsPerHour` caps haggles per player.
- **Law:** hotspot blips shrink while an on-duty officer stands inside them (`Alert.ShrinkStep`, `MinRadius`); busts use `Alert.ExactRadius`.
- **Lab:** **Upgrades** tab (dryer, processor, packing, fire and security levels), **random events** (worker theft, lab fire; offline owners get a notice), and a **Leaderboard** tab (top dealers by money earned, units sold, best potency; new `server/board.lua`).
- 41 new locale keys in all 11 languages.

### Changed
- Withdrawal stress is applied by the server each addiction tick through rsg-hud `GainStress` instead of the client firing `hud:server:GainStress`.
- Lab saves are queued asynchronously (the resource-stop save still waits for the database).
- Rehab confiscation writes the stash before removing items, so a crash mid-way can't lose them.
- Hooking a buyer can be restricted to real ambient peds on the server (`Config.Addiction.NPC.AmbientPopTypes`, off by default until the population type values are checked on your build).

### Fixed
- **Security:** lab actions (hire, fire, assign, deposit, withdraw, payroll) now reject NaN / infinite / non-numeric amounts and ids from a modified client (they slipped past the `< 1` / `> max` range checks and could have corrupted lab stock).
- **Security:** the addiction craving and rehab loops no longer trust the replicated `addiction` statebag, which a client can overwrite to look clean and skip the craving tick. The server now keeps its own per-player flags.
- Market average uses a trimmed mean once 10+ sales exist, so a few joke prices from one player can't move the number everyone sees.
- A buyer who walked away from a haggle, and a hostile-town refusal, were only ignored for 60 s / 45 s instead of for good (a Lua `and nil or` slip).
- A hooked ambient buyer was left standing still with events blocked after its scenario; it now goes back to normal life afterwards.
- Lab panel: clicks while an action is in flight are ignored, so fast clicking no longer drops actions silently against the server's 300 ms limit.

### Changed
- Docs list `Config.Corner.AddictRebuyMinutes` again (it is used for hooked ambient buyers).

### Fixed
- The buyer no longer wanders off while the haggle panel is open: after turning to face you it is told to stand still, keeps its keep-task flag, and is called back (and re-held) if it drifts more than a few metres away.

### Added
- **Street market average:** the server records the price per unit of every corner sale and shows the average of the last `Config.Corner.Market.Window` sales (all players, per item) in the haggle panel, once `MinSales` sales exist. Stored in `rsg_drugs_state` (key `corner_market`, no new table) and saved every minute and on resource stop. New locale key `ui_cn_market` in all 11 languages.

### Changed
- Corner customers are ambient townsfolk again (so addiction works), with spawned customers as a fallback. New `Approach.Source`: `'both'` (default: ambient first, spawn when none is found or the ambient one can't reach you), `'ambient'` or `'spawn'`. `Radius` and `IgnoreSeconds` are back. `addicts = true` again on the corner items; only ambient buyers get hooked.
- New `Approach.Debug` prints why a customer didn't show (candidates found, no control of the ped, didn't arrive, server refusal).

### Changed
- **Spawned customers:** corner selling no longer borrows ambient NPCs. A customer is spawned `Approach.SpawnMin`-`SpawnMax` m away (out of sight when possible, on walkable ground, not in water), walks up to you, haggles, then walks `LeaveDistance` m away and is deleted. The next customer follows after `EverySeconds`, until you run out of stock or cancel with `/corner`. Customers that die, can't reach you or are refused are removed the same way; all are deleted when the session or resource stops. A customer who is reported to the law flees before being deleted.
- Customer models are a random pick from `Config.Corner.Approach.Models` (town-folk models, names checked against rdr3_discoveries).
- Config: removed `Approach.Radius` and `IgnoreSeconds`; `Timeout` is now 60 s; added `SpawnMin`, `SpawnMax`, `LeaveDistance`, `LeaveSpeed`, `LeaveTimeout`, `DespawnDistance`, `Models`.
- Spawned customers can't become addicts, so `addicts` is `false` on the corner items and `AddictRebuyMinutes` is no longer used for buyers. Existing ambient addicts keep working.

### Added
- **Package handover prop:** on a successful corner sale (and a brick export) a `s_drugpackage_02x` package appears in the player's hand during the handover animation, passes to the NPC's hand part way through (`Prop.HandoffAt`) and is removed when the animation ends. The prop is networked so nearby players see it. Configure the model, hand bone, timing and offsets in `Config.Corner.Anim.Prop`; `Enabled = false` keeps the animation without the package. If the model can't load the handover plays without it.
- `DrugsHandover(ped, frozen, prop)` takes the prop settings as a third argument; a leftover prop is removed when the resource stops.

### Added
- **Corner selling** (`shared/config_corner.lua`, `server/corner.lua`, `client/corner.lua`, `html/corner.*`): run `/corner` to start working your spot. Ambient NPCs walk up to you one at a time and a haggle panel opens. You name a price per unit, the buyer counters, and you go back and forth until they accept, you accept their counter, they run out of patience and walk off, or you walk away. Each buyer has a hidden price limit and patience; asking far above their limit costs extra patience and an insulted buyer can report you to the law. You must stay within `Spot.LeaveRadius` of your spot; the session ends if you die, are jailed or in rehab, or run out of stock. On-duty law can't deal.
- Sellable items are configured in `Config.Corner.Items` (`weed_bag` and `weed_joint` by default), each with a base street price, a max quantity per buyer and whether the buyer can get hooked.
- Street price follows potency, the rsg-skills `sell_bonus` perk and the rsg-economy town multiplier. Each sale pays XP, builds heat per item, costs honor and standing, and is reported to the town market. Hostile towns make most buyers ignore you.
- Server exports `IsCornerSelling(src)` and `StopCorner(src)`; client event `rsg-drugs:client:npcBought(ped, hooked)`.
- 43 new locale keys in all 11 languages: `corner_*`, `ui_cn_*`, `cmd_corner` and the buyers' lines (`corner_say_*`).

### Changed
- The one-click *Sell Bag of Weed* target option on every NPC is gone, replaced by corner selling. `Config.Addiction.Selling` is replaced by `Config.Corner` (the handover animation is now `Config.Corner.Anim`, the law alert `Config.Corner.Alert`, the rebuy delay `Config.Corner.AddictRebuyMinutes`). `BuyChance`, `Cooldown`, `PriceMin`/`PriceMax` and `RequireNetworkedPed` no longer exist: buyers come to you and the haggle sets the price.
- `DrugsIsAmbient` (client) and `DrugsNpc` / `DrugsAlertLaw` / `DrugsInRehab` (server) are shared helpers that corner selling and the addiction code both use.

### Removed
- Unused locale keys: `sell_weed`, `sell_success`, `sell_already`, `sell_addict_wait`, `sell_refused`, `sell_no_item`, `sell_cooldown`, `sell_no_buyer`, and the server callback `rsg-drugs:server:sellWeedBag`.

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
