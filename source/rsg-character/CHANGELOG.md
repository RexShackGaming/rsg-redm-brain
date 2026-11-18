# Changelog

All notable changes to rsg-character. Newest first. Versions follow `fxmanifest.lua`.

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
