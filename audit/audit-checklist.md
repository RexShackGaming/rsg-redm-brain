# Audit checklist

Run these in order. `audit/ai-procedure.md` describes the report format.

## 1. Security (see conventions/security.md)
- [ ] No money or item changes in client files
- [ ] Every net event nil-checks `GetPlayer(src)`
- [ ] Every client argument is validated. Prices and rewards come from server config.
- [ ] Permission, job or grade checks on privileged events
- [ ] Server-side distance checks for location-based actions
- [ ] Cooldowns on reward events
- [ ] `CanAddItem` before `AddItem`, and the `RemoveMoney` result is checked
- [ ] NUI callbacks are re-validated on the server
- [ ] SQL uses `?` params only

## 2. Notifications
- [ ] Every notification uses rsg-core (`RSGCore.Functions.Notify` / `RSGCore:Client:Notify`), no `lib.notify` / `ox_lib:notify`
- [ ] Every callback uses rsg-core (`CreateCallback` / `TriggerCallback` / `AwaitCallback`), no `lib.callback`

## 3. Locales
- [ ] No hard-coded player-facing strings. `locales/en.json` exists and `'@rsg-core/shared/locale.lua'` is in shared_scripts (not ox_lib).

## 4. Environment
- [ ] No weathersync, rsg-horses, rsg-multijob or `RSGCore.Shared.Jobs` job definitions
- [ ] Targeting uses `exports['rsg-target']` with `rsg-target` in dependencies (not `exports.ox_target` / `ox_target`)
- [ ] Item names match `server/environment.md`

## 5. Lifecycle and performance
- [ ] Entities, blips, prompts and zones are removed on `onResourceStop`
- [ ] No unnecessary `Wait(0)` loops. Loops are distance-gated.

## 6. NUI
- [ ] Matches ui/design-standard.md (Roboto, monochrome palette, no vignette)
- [ ] `SetNuiFocus(false, false)` on close and on resource stop
