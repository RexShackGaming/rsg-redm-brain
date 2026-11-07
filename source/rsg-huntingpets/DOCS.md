# rsg-huntingpets — Developer Docs

## Dependencies
- `rsg-core` (locales, notifications, core object)
- `rsg-target` (pet shop NPC and dog interaction targets)
- `oxmysql`

`ox_lib` is **not** used (migrated to rsg-core in 3.1.x).

## Locales
`fxmanifest.lua` loads `@rsg-core/shared/locale.lua` in `shared_scripts`; strings live in `locales/*.json`
(en, de, el, es, fr, ja, nl, pl, pt-br, ro) and are read with `locale('key', ...)`.
Language: `setr rsg:locale "<code>"` in server.cfg (falls back to `ox:locale`, then `en`).
The NUI receives a resolved string bundle from `client/client_shop.lua` (`GetUiLocale()`).

## Notifications
- Client: `Notify(title, message, template, duration)` in `client/client_shop.lua` wraps
  `RSGCore.Functions.Notify`. Templates `ERROR`, `SUCCESS`, `TIP` (inform), `WARNING`.
- Server: `TriggerClientEvent('RSGCore:Client:Notify', src, { title, description, duration, type })`.

## Files
| Path | Purpose |
|---|---|
| `client/client_shop.lua` | Shop NUI, notify helper, locale bundle |
| `client/npcs.lua` | Shop NPCs + rsg-target |
| `client/client_dogs.lua` / `client_birds.lua` | Pet behaviour, prompts, hunt modes |
| `server/server_dogs.lua` / `server_birds.lua` | Buying/selling/feeding, validation |
| `server/database.lua` | Auto-creates tables (manual SQL in `installation/rsg_huntingpets.sql`) |
| `shared/config_*.lua` | Config |
