# rsg-samples — Developer Docs

## Dependencies
`rsg-core`, `rsg-target`, `oxmysql`, OneSync. **No ox_lib** (removed in 2.1.1).

## Framework usage
| Feature | Provided by |
|---|---|
| Locales (`locale(key, ...)`) | `@rsg-core/shared/locale.lua`, files in `locales/*.json`, convar `rsg:locale` |
| Client notify | `exports['rsg-core']:Notify({ title, description, type, duration })` |
| Server notify | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` (local `notify()` helper in `server/main.lua`) |
| Leaderboard interaction | `exports['rsg-target']:addSphereZone` (`client/target.lua`) |
| Player ped | `PlayerPedId()` |
| Database | oxmysql; `player_samples` table auto-created (`Config.AutoInstallDB`), manual SQL in `install/rsg-samples.sql` |

## Languages
en, de, el, es, fr, ja, nl, pl, pt-br, ro — add more by copying `locales/en.json`.

## Commands
- `/samplesmenu` — open the samples UI
- `/samplecert` — show your certificate
- `/setfeatured <animal>` — admin: set/clear the featured animal

## Security
Sample payouts are validated server-side (model, health, distance, duplicate checks) before any reward is paid.
