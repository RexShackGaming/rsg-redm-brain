# rsg-housing – Developer Docs

## Framework dependencies
rsg-housing has **no ox_lib dependency**. Everything comes from rsg-core:

| Feature | Used |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` + `locale('key')`, language from the `rsg:locale` convar |
| Notify (client) | `RSGCore.Functions.Notify({...})` |
| Notify (server) | `TriggerClientEvent('RSGCore:Client:Notify', src, {...})` |
| Callbacks (server) | `RSGCore.Functions.CreateCallback` via local `registerCallback(name, handler)` wrapper – handlers simply `return` values, the wrapper passes them to `cb(...)` |
| Callbacks (client) | `RSGCore.Functions.AwaitCallback(name, nil, ...)` (default 10 s timeout, `nil` on timeout) |
| Assets | `RSGCore.Functions.RequestModel` / `RequestAnimDict` |
| Player ped | `PlayerPedId()` |
| Scheduled rent check | `RSGCore.Functions.CreateCron` |

## Rent check scheduler
The rent check (reminders and evictions) runs on rsg-core's scheduler: `RSGCore.Functions.CreateCron(Config.RentCheckCronJob, job)`. `Config.RentCheckCronJob` is a standard 5-field cron expression (default `'0 * * * *'`, hourly). See rsg-core DOCS.md for the supported syntax.

## Server callbacks
`getState`, `getHouseStatus`, `rentHouse`, `payRent`, `setHome`, `upgradeStorage`, `renameHouse`, `endTenancy`, `addGuest`, `setGuestPermission`, `searchPlayers`, `removeGuest`, `outfits`, `mailbox`, `toggleDoor`, `admin` – all prefixed `rsg-housing:server:` and validated server-side.
