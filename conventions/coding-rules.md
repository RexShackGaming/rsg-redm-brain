# Coding rules

## Structure
- Folders: `client/`, `server/`, `shared/config.lua`, optional `server/sv_config.lua` (secrets, webhooks), `html/` (NUI), `locales/`, `install.sql`.
- Get the core with `local RSGCore = exports['rsg-core']:GetCoreObject()`.
- Config lives in `Config = {}` in `shared/config.lua`. Coords, timers, prices, rewards and toggles all go there.

## Naming
- Events: `<resource>:client:<action>` and `<resource>:server:<action>`
- Callbacks: `<resource>:server:<name>`
- Locale keys: snake_case

## Performance
- Prefer locals to globals. Keep functions small and single-purpose.
- Be event-driven rather than polling. Use `Wait(0)` only when drawing or reading controls each frame. Distance-gate loops so they sleep longer when the player is far away.
- Cache the player ped, the core object and config.
- Register each event and usable item once.

## Lifecycle
- Track every spawned entity, blip, prompt, zone and thread, and clean them all up in `onResourceStop`.
- After spawning, call `SetModelAsNoLongerNeeded`.
- Spawn networked entities on the server where possible, and share them by netId or state bags.

## RedM specifics
- Don't use GTA V natives. Use RedM prompts, scenarios (`TaskStartScenarioInPlace`) and the RedM blip API.
- Prefer native names to raw `Citizen.InvokeNative(0x...)`. If you must use a hash, comment the native's name next to it.

## Database
- oxmysql with `?` params: `MySQL.query.await`, `MySQL.insert.await`, `MySQL.update.await`, `MySQL.scalar.await`, `MySQL.prepare.await`. Never concatenate SQL.
- Ship `install.sql` with `CREATE TABLE IF NOT EXISTS`.

## Output
- Code must be complete and runnable, with no `-- logic here` placeholders.
- Split code blocks by file path.
