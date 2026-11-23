# Changelog

All notable changes to rsg-consume. Newest first.

## 3.3.0

### Added
- **Fullness limit:** food/drink that would only restore a need that is already at `Fullness.BlockAt` is refused before the item is taken.
- **Quality scaling:** hunger/thirst gains scale with the item's `info.quality` (rsg-inventory decay).
- **Spoilage:** very low quality food can make you sick (vomit, thirst loss, stress) with a server-rolled chance.
- **Alcohol tolerance:** stored in player metadata, raises the drunk / pass-out thresholds, decays over real time. Export `GetTolerance(src)`.
- **Hangover:** passing out costs thirst and adds stress (server side, rate limited).
- **Cancel key:** stop eating/drinking; the server measures progress, refunds below `Cancel.RefundBelow`, otherwise applies a proportional share.
- **Timed buffs:** per-item `buff = { health = {...}, stamina = {...} }`. Samples on coffee, tea and the stews.
- **Warm / cold items:** per category or per item `warmth`, through the new rsg-hud `AddWarmth` export (rsg-hud 3.2.2).
- **Bars:** `Config.Bars` lets players order and drink at a counter via rsg-target (cash, money refunded if it can't be drunk). Ships empty: add your own coordinates.
- **Share a drink:** target a nearby player and hand them one of `Config.Share.Items`.
- **Server event `rsg-consume:server:consumed(src, itemName, category, data, meta)`** after a real consumption. rsg-drugs addiction now uses it instead of a client relay (rsg-drugs 3.1.4).
- 14 new locale keys in all 11 languages. `rsg-target` is now a dependency.

## 3.2.0

### Security
- Server rejects a "finished" report that arrives faster than the animation can run (`Config.MinDuration`): no effects are applied and the item is refunded, so the animation can no longer be skipped for instant stats.

### Fixed
- Stress was applied from the client through `hud:server:GainStress`, an event rsg-hud does not have, so items with negative stress (26 of them) never added stress, and stress relief was client-only. Stress is now applied on the server with `exports['rsg-hud']:RelieveStress / GainStress`.
- Alcohol level and the drunk state carried over to a new character after switching; they now reset on character unload and on death.
- The drunk walk was lost after a respawn or ped change while still "drunk"; it is re-applied every tick.
- `SleepDuration` was ignored (the player always slept for `FadeOutDuration`); the total sleep time is now `SleepDuration`.
- Passing out no longer leaves the screen faded out or the ped frozen if the player dies during it.
- A failed animation or dying mid-use now refunds the item instead of applying the effects.

### Changed
- Drunkenness scales with the alcohol level (`AlcoholSystem.ScaleDrunkness`, `MinDrunkLevel`, `MaxDrunkLevel`).
- Drunk / pass-out reacts immediately after drinking instead of at the next 5 s tick.
- Eating and drinking is refused (item refunded, with a notice) while swimming, ragdolled, falling or climbing. New locale key `cannot_now` in all 11 languages.
- The passed-out player is frozen in place during the sleep.

## 3.1.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
