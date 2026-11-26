# Changelog

All notable changes to rsg-character. Newest first. Versions follow `fxmanifest.lua`.

## 3.4.1

### Fixed
- The nationality picker used a native `<select>`, which can crash RedM. The input dialog now draws its own dropdown.

## 3.4.0

### Added
- **Safer character deletion.** `RSG.Delete`: delete can be switched off (`Enabled`), the player must type the character's first name (`ConfirmName`, also checked on the server), and with `SoftDelete` the character is hidden for `GraceDays` (default 7) instead of being erased. Staff bring it back with `/restorechar [citizenid]` and see pending deletions with `/deletedchars [id]`. Expired characters are purged automatically (`PurgeInterval`). Hidden characters cannot be selected, even with a crafted request.
- **Database-driven extra slots.** New `playerslots` table (one row per license) with `/addslot`, `/setslots`, `/charslots` and the exports `GetExtraSlots`, `AddExtraSlots`, `SetExtraSlots`, so a store or donation system can grant slots without editing ACE rules. `RSG.SlotRules` still works (the larger value wins) and `RSG.Slots.Cap` limits the total.
- `/logout` is blocked while handcuffed (`BlockWhenCuffed`), jailed (`BlockWhenJailed`) and for `CombatCooldown` seconds after taking damage or firing a weapon.
- Name rules in `RSG.NameRules`: accents, apostrophes, hyphens and internal capitals (O'Brien, McGregor, Mary-Jane, José), optional spaces, a substring blocklist and a reserved-name list.
- Birthdate age limits (`RSG.Birthdate.GameYear`, `MinAge`, `MaxAge`) on top of `Min` / `Max`.
- New hook events `characterRestored`, `characterPurged`, `slotsChanged`; `characterDeleted` gets a third argument (`pending`).
- New webhook category `character_restored`; purged characters are logged through `character_deleted`.
- Server-side callback `rsg-character:server:chooseSpawn`: the spawn menu now asks the server for the coordinates.

### Changed
- `playerskins` has a unique key on `citizenid` (older duplicate rows are removed when `RSG.DedupeSkins = true`); `SaveSkin` uses `ON DUPLICATE KEY UPDATE`. `playeroutfit` gets a `(citizenid, is_default)` index.
- Name uniqueness uses the indexed `rsg_character_names` table instead of scanning `players` with `JSON_EXTRACT`. It is filled automatically for existing characters.
- The spawn point of a menu choice is decided by the server (a choice that was not offered is refused).
- All webhook categories ship disabled; enable the ones you fill in.
- `RSG.ProfanityWords` moved to `RSG.NameRules.ProfanityWords` (the old name still points to it). The default list no longer contains `dick`, a normal 1899 first name.
- Delete confirmation text, name-rule messages and `logout.dead` (was untranslated) updated in all 11 languages; 40 new locale keys.

### Upgrading
- With `RSG.AutoDatabase = true` nothing to do: the three new tables and the new keys are created on start. For a manual install see the upgrade notes at the bottom of `install.sql`.
- Existing characters keep working. Deleted characters stay in `players` during the grace period (other resources that list characters by license will still see them); set `RSG.Delete.SoftDelete = false` for the old immediate delete.

## 3.3.0

### Added - Developer API
- **Server exports:** `GetMaxSlots`, `IsInCreator`, `IsNameAvailable`, `GetAppearance`, `GetOutfits`, `SetClothes`, `AddOutfit`, `ResetAppearance`, `ChangeCharacterName`, `LogoutToCharacterSelect`.
- **Server hook events** (local events other resources can listen to): `characterSelected`, `characterCreated`, `characterDeleted`, `characterLoggedOut`, `appearanceSaved`, `appearanceReset`, `nameChanged`, `outfitPurchased`, `outfitShared`.
- **Client exports:** `IsInCreator`, `IsInCharacterSelect`, `OpenWardrobe`.
- **Client hook event:** `rsg-character:client:skinApplied` fires after the player's skin and clothes were applied.
- `server/sv_api.lua` holds the shared helpers (`RSG.ChangeName`, `RSG.ResetAppearance`, `RSG.GetGender`) used by the exports and admin commands.
- `/logout` logic can be forced by other resources (ignores cooldown and dead check) through `LogoutToCharacterSelect`.

### Changed
- DOCS.md: new Developer API section (every export, event, callback and net event with examples), full configuration reference, state bag reference.
- `/changename` and `/resetskin` now use the same code as the exports.

### Removed
- Unused `local RSGCore` in `client/functions.lua`.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.

## 3.2.0

### Added
- Unique character names (`RSG.UniqueNames`): the creator checks right after the identity step, the server checks again on creation.
- Extra character slots by ACE permission (`RSG.SlotRules`), e.g. VIP or queue tiers.
- Admin commands `/charinfo`, `/resetskin`, `/changename` (`RSG.AdminCommands`) with an optional `admin_action` Discord webhook.
- Wardrobe: share a saved outfit with the nearest player, who must accept (`RSG.OutfitSharing`).
- Spawn select: optional "Last Location" card (`RSG.SpawnMenuWithLastLocation`).
- 34 new locale keys in all 10 languages.

## 3.1.4

### Added
- Tables are built automatically (`RSG.AutoDatabase`); `install.sql` added for manual installs.
- Push-to-talk keeps working while character select, creator, clothing store and spawn menus are open (`RSG.AllowPushToTalkWhileOpen`, `RSG.PushToTalkControls`).

### Fixed
- Client stuck on the loading screen when a delete/select/create request was rejected or failed on the server.
- Double-clicking a character fired the select/create request twice; the server now also ignores a second select while one is running.
- `/logout` could run twice at once when the cooldown was 0.
- Routing buckets are restored to the player's previous bucket instead of always bucket 0, and the private bucket is reused.
- Outfit names strip HTML/control characters on the server.

### Removed
- NUI vignette overlay.
- 12 unused locale keys (all 10 languages).

## 3.1.1
- Release baseline. See DOCS.md for the full feature/flow reference.

## 3.0.10
- Notifications use rsg-core notify and callbacks use rsg-core callbacks.
- Locales load through rsg-core's shared loader; ox_lib is no longer a dependency (data files load with rsg-core's `require`).
- Wardrobe props use rsg-target instead of ox_target.
- Removed the unused `rsg-character:server:LoadSkin` net event (could open a free creator session).
- Wearing a saved outfit re-validates its clothes on the server.
- The store checks your cash before you leave the fitting room, so you keep your selection if you can't afford it.
- The client no longer sends its gender when buying clothes (the server uses the character record).
