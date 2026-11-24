# Changelog

All notable changes to rsg-moonshine. Newest first.

## 3.7.1

### Fixed
- **Exploit:** a taste sample could be repeated to re-roll the poison chance. It now rolls once per cut for as long as the tank stays the same.
- The menu showed fuel, batch, second run and fermentation timers in game seconds. They now show real time, so a hot fire or cold weather no longer makes the countdown wrong.

### Changed
- DOCS.md: events, integration examples (proof, poison, ingredient quality, still lookup), security model and troubleshooting cover everything added in 3.4.0 to 3.7.0.

## 3.7.0

### Added
- **Still materials:** a cheap `moonshine_still_tin` item (-8 quality, 1.6x grime, 1.5x explosion risk) next to the standard copper still (`Config.Materials`). Existing stills stay copper.
- **Ingredient quality:** `info.quality` on loaded ingredients feeds the batch quality, carried through fermentation, wash items and distilling (`Config.Ingredients`).
- **Law inspection:** on duty law can inspect a still for a read only report of material, grime, fire and tank (`Config.Inspect`, webhook event `inspect`).
- Database columns `material`, `mash_q`, `ferment_q`, `wash_q`, `batch_q`; 12 new locale keys in all 11 languages.

## 3.6.0

### Added
- **Wear and cleaning:** runs leave grime that lowers quality and raises explosion risk; scrub the still with a `fullbucket` (`Config.Wear`, action `clean`).
- **Cooling water:** distilling needs cooling water; a dry condenser loses spirit and quality and adds risk (`Config.Cooling`, action `addWater`).
- **Taste test:** sample the tank with a cut to learn whether it is poisonous, and the result stands when you bottle with that cut (`Config.Taste`, action `sample`).
- Database columns `wear`, `water`, `dry`; 16 new locale keys in all 11 languages.

## 3.5.0

### Added
- **Fermenting barrels:** placeable barrels (`moonshine_barrel`, rsg-gizmo placement) that ferment mash into wash without fuel (`Config.Barrel`).
- **Wash items:** `moonshine_wash` (one per batch, `info.recipe`) can be drawn from a barrel and poured into any still with the same recipe.
- New actions `collectWash` and `loadWash`; database column `kind`; 13 new locale keys in all 11 languages.
- `kind` in the public still, still data and NUI state.

## 3.4.0

### Added
- **Fermentation:** ingredients ferment into wash first (no fuel, slower in the cold) before the still distils them (`Config.Ferment`, per recipe `ferment`).
- **Heat control:** low, medium or high fire changes distilling speed, fuel use, quality, proof, explosion risk and the smoke size (`Config.Heat`).
- **Proof and second run:** bottles carry `info.proof`, a second run makes stronger spirit with less volume, price follows proof (`Config.Proof`, `Config.Rerun`).
- **Heads, hearts and tails:** a tight, normal or loose cut when bottling; loose cuts can poison a batch, toxic bottles look normal and bootleggers refuse them (`Config.Cuts`, `info.meta.tainted`).
- **Oak cask ageing:** new `moonshine_cask` item fitted to a still, quality grows with time and some evaporates (`Config.Cask`).
- **Weather and night:** rain, cold and night change fermentation, fuel burn and how far smoke and smell carry (`Config.Environment`, reads rsg-weather).
- New actions `setHeat`, `rerun`, `installCask`, `age`, `collectCask`; `collect` takes `{ cut }`.
- 13 new database columns (created and upgraded automatically); 45 new locale keys in all 11 languages.

### Changed
- Ingredients are consumed when fermenting starts, not when distilling starts. Stills saved by 3.3.0 keep working (a running batch finishes as before).
- Recipe change and pick up need the mash tub, wash, pot, tank and cask to be empty; picking up returns the cask.
- Exports: `GetBottleInfo` adds `proof` and `tainted`, `GetBottlePrice(item, quality?, proof?)`, still data adds `proof, heat, wash, cask, caskVolume`.

## 3.3.0

### Added
- Server exports: `GetBottleInfo`, `GetBottlePrice`, `GetStillAt`, `GetStills`, `DestroyStill`, `GetSkillLevel` (see DOCS.md section 9).
- Webhook field `Reason` (locale key `wh_field_reason`, all 11 languages).

### Changed
- Raids, pickups, explosions and `DestroyStill` share one removal path; bootlegger prices use the same function as `GetBottlePrice`.

## 3.2.0

### Added
- **Trusted access:** owners can trust up to `Config.TrustedMax` people per still from the menu (`Config.OwnerOnly` now defaults to `true`).
- **Quality:** bottles carry `info.quality` from the moonshiner's level; it shows in the tank and changes the sale price.
- **Explosion risk:** a finished batch can blow the still up (`Config.Risk`, falls to 0 at `safeLevel`; map stills are safe).
- **Mash smell:** on-duty law near a brewing still get a hint (`Config.Smell`).
- **Bootlegger buyers:** sell bottles for cash at every speakeasy cellar or custom spots (`Config.Buyers`), with a chance to tip off law.
- **rsg-skills / rsg-reputation:** moonshining is now an rsg-skills skill (imports old rep xp, `sell_bonus` perk); sales and raids change honor. Both fall back or switch off cleanly (`Config.UseSkills`, `Config.Reputation`).
- Recipes have a `price`; webhook events `explosion` and `sell`; new database columns `quality`, `op_level`, `trusted` (added automatically).

### Also in 3.2.0
- **Bottle labels:** whoever can use a still can name its moonshine (`Config.Label`); stored on the still and put on collected bottles as `info.label`. Map stills have no label.
- Fixed: menu strings for the new sections were missing from the NUI locale list; stop handler called a function before it existed.
- Cleanup: removed unused code, deterministic order for capped sales, random seed at start.

### Changed
- The server only sends stills within `Config.SyncDist` to each player, so far still locations are no longer exposed.
- Picking up a still returns leftover fuel.

## 3.1.0

### Security
- World stills can no longer be created without limit: per-player cooldown, `WorldStills.maxTotal` cap and optional `WorldStills.locations` allow-list.
- Discord webhook queue is capped and out-of-range alerts are rate limited per player.
- `getStills` requires a loaded player; unloading ingredients now gives items before clearing the hopper.

### Changed
- Still placement now uses rsg-gizmo (new dependency) with server-side `IsPlacementValid`.
- Menu focus keeps push-to-talk working (`Config.AllowPushToTalkWhileOpen`).
- Database upgrade checks `INFORMATION_SCHEMA` (works on MySQL 8) and respects `Config.AutoDatabase`.

### Removed
- Custom placement loop, `cl_place_help` locale key (all 11 languages), unused NUI state fields.

### Fixed
- Prop model released after spawning, duplicate streaming threads, teleport fade timeout, silent failure when the still item is missing.

## 3.0.3

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
