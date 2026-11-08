# rsg-radialmenu – Developer Docs

## Dependencies
- `rsg-core` only (no ox_lib). Locales via `@rsg-core/shared/locale.lua`, notifications via `RSGCore.Functions.Notify`.

## Language
`setr rsg:locale "<code>"` (falls back to `ox:locale`, then `en`). Supported: en, de, el, es, fr, ja, nl, pl, pt-br, ro (`locales/*.json`).

## Menu entries (config.lua)
- `cmd(id, label, icon, command)` – runs a command
- `cl(id, label, icon, event)` – triggers a client event
- `walk(key, label)` – applies a walk style (validated server-side, synced via the `walkstyle` player state bag)

## Events
- `rsg-radialmenu:client:setWalkstyle` (client) → `rsg-radialmenu:server:setWalkstyle` (server, validated against `Config.Walkstyles`)
- `rsg-radialmenu:client:SendLawmanEmergencyAlert` / `SendMedicEmergencyAlert` – emergency alerts with cooldown

## Changelog
- 3.1.0 – Removed ox_lib dependency (locales and notify now from rsg-core).
