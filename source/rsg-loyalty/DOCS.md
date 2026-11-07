# rsg-loyalty – Developer Docs

## Dependencies
- rsg-core (locales, notify, model loading), rsg-target, rsg-inventory, oxmysql
- **No ox_lib dependency** – fully migrated to rsg-core.

## Locales
Loaded by `@rsg-core/shared/locale.lua` from `locales/*.json`. Set the language with the convar `setr rsg:locale <code>` (en, de, el, es, fr, ja, nl, pl, pt-br, ro).

## Notifications
Server → client notifications use `TriggerClientEvent('RSGCore:Client:Notify', src, { title, description, type, duration })`.

## NPCs
Loyalty NPCs spawn when a player is within `Config.Performance.NpcSpawnDistance` (via rsg-core `points.new`, loaded from `@rsg-core/client/points.lua`), optionally fading in/out, and expose an rsg-target option "open loyalty shop".

## Database
The `rsg_loyalty` table is created automatically on start. `installation/rsg_loyalty.sql` is kept for manual installs.

## Changelog
- ox_lib removed: `lib.locale` → rsg-core locale, `ox_lib:notify` → `RSGCore:Client:Notify`, `lib.requestModel` → `RSGCore.Functions.RequestModel`, `lib.points` → rsg-core `points.new`, `cache.ped` → `PlayerPedId()`, ox_target → rsg-target.
