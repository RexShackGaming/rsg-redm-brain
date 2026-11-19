# rsg-mdt — Developer Docs

## Dependencies
- **rsg-core** — callbacks, notify, locales (`@rsg-core/shared/locale.lua`)
- **rsg-target** — fines payment NPC interaction
- **oxmysql** — database
- No ox_lib. The fines payment NPC menu and confirm dialogs are NUI (`web/components/FinesClerk.tsx`).

## ox_lib migration (v2.1.0)
| Was (ox_lib) | Now |
|---|---|
| `@ox_lib/init.lua` + `shared/locale.lua` (`lib.loadJson`) | `@rsg-core/shared/locale.lua`, `setr rsg:locale <lang>` |
| `lib.notify` | `RSGCore.Functions.Notify` |
| `lib.callback.register` (server) | `RegisterCallback(name, fn)` → `RSGCore.Functions.CreateCallback` (see `shared/callbacks.lua`) |
| `lib.callback.register` (client) | `RegisterClientCallback(name, fn)` → `RSGCore.Functions.CreateClientCallback` |
| `lib.callback.await` | `RSGCore.Functions.AwaitCallback(name, nil, ...)` |
| `lib.callback(name, false, cb, ...)` | `RSGCore.Functions.TriggerCallback(name, cb, ...)` |
| `lib.addKeybind` | raw-key thread using `Config.Settings.keybind` (virtual-key code, default `0x76` = F7) |
| `exports.ox_target` | `exports['rsg-target']` |

`shared/callbacks.lua` lets handlers keep `return value` style; the bridge forwards returns to `cb()`.
| `lib.registerContext/showContext/alertDialog` | NUI fines clerk (v2.2.0) |

`shared/locale.lua` is no longer loaded and can be deleted.

## Callbacks
Server callbacks are registered in `server/*.lua` under the `rsg-mdt:server:*` namespace; client callback `rsg-mdt:roleSync:getLocalState` in `client/roleSync.lua`.

## Config
- `Config.Settings.command` — chat command (default `mdt`)
- `Config.Settings.keybind` — virtual-key code or `nil` to disable

## Fines clerk NUI
Client → NUI messages: `openFinesClerk`, `updateFinesClerk`, `closeFinesClerk` with `{ title, fines = [{ id, amount, timeLeft, overdue }], total, labels }` (labels are sent from Lua locales).
NUI → client callbacks: `finesClerkPay { fineId }`, `finesClerkPayAll`, `finesClerkClose`. Payment is validated server-side in `rsg-mdt:server:payFine` (ownership, status, cash).

## Push-to-talk
`Config.AllowPushToTalkWhileOpen` / `Config.PushToTalkControls`. Both MDT (`client/nui.lua` `NUI.SetFocus`) and the fines clerk route focus through a helper that uses `SetNuiFocusKeepInput` and a per-frame control whitelist.

## Building the UI
`cd web && npm install && npm run build` → outputs `web/dist`.

## Locales
`locales/*.json` — en, de, el, es, fr, ja, nl, pl, pt-br, ro (required set) plus pt, it, ru, tr. All files share the same 147 keys.
Plural suffix arguments (`%s` after day/hour/second) are English-only; non-English files consume them with `%.0s` so argument order stays intact.

## rsg-economy integration

`Config.Economy = { Enabled, FineRegion }`. In `rsg-mdt:server:payFine`, after the money is removed and the fine marked paid, the server calls `exports['rsg-economy']:DepositTreasury(region, totalAmount, 'fine #<id>', citizenid)`. `region` is `FineRegion` or `GetRegionAt(player position)`. A player further than the rsg-economy region radius from every town adds nothing to a treasury. Skipped when rsg-economy is not started.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-mdt 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `oxmysql`

### Database

Tables: `mdt_records`, `mdt_warrants`, `mdt_bolos`, `mdt_reports`, `mdt_report_comments`, `mdt_citizen_profiles`, `mdt_staff`, `mdt_roles`, `mdt_audit_logs`, `mdt_charge_templates`, `mdt_issued_charges`, `mdt_charge_attachments`, `mdt_fines`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `sql/mdt.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import sql/mdt.sql for a manual install) |
| `Config.LawJobs` | `table` | ============================================ |
| `Config.Settings` | `table` | ============================================ |
| `Config.IncidentTypes` | `table` | ============================================ |
| `Config.Defaults` | `table` | ============================================ |
| `Config.Fines` | `table` | ============================================ |
| `Config.Jail` | `table` |  |
| `Config.AllowPushToTalkWhileOpen` | `true` | While NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.Economy` | `table` | A paid fine is deposited into the treasury of the town nearest to the player (rsg-economy GetRegionAt). |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `getChargeAttachments` | `chargeId` | `server/chargeAttachments.lua` |
| `getReportsWithCharges` | `reportId` | `server/chargeAttachments.lua` |
| `getChargeTemplates` | `` | `server/charges.lua` |
| `createOrUpdateFine` | `` | `server/fines.lua` |
| `getCitizenFines` | `` | `server/fines.lua` |
| `getUnpaidFines` | `` | `server/fines.lua` |
| `hasAccess` | `` | `server/main.lua` |
| `hasPermission` | `` | `server/main.lua` |
| `getPermissions` | `` | `server/main.lua` |
| `getLawJobs` | `` | `server/main.lua` |
| `getSettings` | `` | `server/main.lua` |
| `getConfigVersion` | `` | `server/main.lua` |
| `reloadConfig` | `` | `server/main.lua` |
| `getPlayerRole` | `source` | `server/roleSync.lua` |
| `getAllPlayerRoles` | `` | `server/roleSync.lua` |
| `getValidatedLawJobs` | `` | `server/roleSync.lua` |
| `isLawJob` | `jobName` | `server/roleSync.lua` |
| `hasPermission` | `source, permission` | `server/roleSync.lua` |
| `isAdmin` | `source` | `server/roleSync.lua` |
| `forceRefreshRoles` | `` | `server/roleSync.lua` |
| `isStaffMember` | `` | `server/staff.lua` |
| `hasAdminPermission` | `` | `server/staff.lua` |
| `getStaffPermissions` | `citizenid` | `server/staff.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `hasUnpaidFines` | `` | `client/fines.lua` |
| `getTotalFinesAmount` | `` | `client/fines.lua` |
| `getPlayerFines` | `` | `client/fines.lua` |
| `hasAccess` | `` | `client/main.lua` |
| `getPermissions` | `` | `client/main.lua` |
| `hasPermission` | `` | `client/main.lua` |
| `getJobLabel` | `` | `client/main.lua` |
| `refreshAccess` | `` | `client/main.lua` |
| `getMyRole` | `` | `client/roleSync.lua` |
| `getAllRoles` | `` | `client/roleSync.lua` |
| `getConfigVersion` | `` | `client/roleSync.lua` |
| `isLawOfficer` | `` | `client/roleSync.lua` |
| `hasRolePermission` | `` | `client/roleSync.lua` |
| `isAdmin` | `` | `client/roleSync.lua` |
| `getJobInfo` | `` | `client/roleSync.lua` |
| `requestRoleSync` | `` | `client/roleSync.lua` |
| `validateLocalState` | `` | `client/roleSync.lua` |
| `attemptLocalOverride` | `` | `client/roleSync.lua` |

```lua
-- example
local result = exports['rsg-mdt']:getChargeAttachments(chargeId)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-mdt:server:getAvailableReportsForAttachment` | server | `source, searchQuery` | `server/chargeAttachments.lua` |
| `rsg-mdt:server:attachReportsToCharge` | server | `source, data` | `server/chargeAttachments.lua` |
| `rsg-mdt:server:removeAttachmentFromCharge` | server | `source, data` | `server/chargeAttachments.lua` |
| `rsg-mdt:server:getChargeAttachments` | server | `source, chargeId` | `server/chargeAttachments.lua` |
| `rsg-mdt:server:getReportsWithCharges` | server | `source, reportId` | `server/chargeAttachments.lua` |
| `rsg-mdt:server:getChargeTemplates` | server | `source` | `server/charges.lua` |
| `rsg-mdt:server:addChargeTemplate` | server | `source, data` | `server/charges.lua` |
| `rsg-mdt:server:updateChargeTemplate` | server | `source, data` | `server/charges.lua` |
| `rsg-mdt:server:deleteChargeTemplate` | server | `source, id` | `server/charges.lua` |
| `rsg-mdt:server:issueCharges` | server | `source, data` | `server/charges.lua` |
| `rsg-mdt:server:submitCharges` | server | `source, data` | `server/charges.lua` |
| `rsg-mdt:server:getIssuedCharges` | server | `source, citizenid` | `server/charges.lua` |
| `rsg-mdt:server:getAllIssuedCharges` | server | `source, searchQuery` | `server/charges.lua` |
| `rsg-mdt:server:getChargeDetails` | server | `source, chargeId` | `server/charges.lua` |
| `rsg-mdt:server:jailPlayer` | server | `source, data` | `server/charges.lua` |
| `rsg-mdt:server:getJailConfig` | server | `source` | `server/charges.lua` |
| `rsg-mdt:server:getCitizenJailTotals` | server | `source, citizenid` | `server/charges.lua` |
| `rsg-mdt:server:commitCharges` | server | `source, data` | `server/charges.lua` |
| `rsg-mdt:server:getCitizenFines` | server | `source, citizenid` | `server/fines.lua` |
| `rsg-mdt:server:getUnpaidFines` | server | `source, citizenid` | `server/fines.lua` |
| `rsg-mdt:server:payFine` | server | `source, fineId` | `server/fines.lua` |
| `rsg-mdt:server:getPlayerFines` | server | `source` | `server/fines.lua` |
| `rsg-mdt:server:hasUnpaidFines` | server | `source` | `server/fines.lua` |
| `rsg-mdt:server:getUnpaidFinesCount` | server | `source, citizenid` | `server/fines.lua` |
| `rsg-mdt:server:getAllUnpaidFines` | server | `source` | `server/fines.lua` |
| `rsg-mdt:server:markFineOverdue` | server | `source, fineId` | `server/fines.lua` |
| `rsg-mdt:server:markFinePaid` | server | `source, fineId` | `server/fines.lua` |
| `rsg-mdt:server:getAllCitizens` | server | `source` | `server/main.lua` |
| `rsg-mdt:server:searchCitizens` | server | `source, query` | `server/main.lua` |
| `rsg-mdt:server:getCitizen` | server | `source, citizenid` | `server/main.lua` |
| `rsg-mdt:server:setProfilePicture` | server | `source, data` | `server/main.lua` |
| `rsg-mdt:server:getRecords` | server | `source, citizenid` | `server/main.lua` |
| `rsg-mdt:server:addRecord` | server | `source, data` | `server/main.lua` |
| `rsg-mdt:server:deleteRecord` | server | `source, recordId` | `server/main.lua` |
| `rsg-mdt:server:getWarrants` | server | `source` | `server/main.lua` |
| `rsg-mdt:server:addWarrant` | server | `source, data` | `server/main.lua` |
| `rsg-mdt:server:updateWarrant` | server | `source, data` | `server/main.lua` |
| `rsg-mdt:server:deleteWarrant` | server | `source, warrantId` | `server/main.lua` |
| `rsg-mdt:server:getBolos` | server | `source` | `server/main.lua` |
| `rsg-mdt:server:addBolo` | server | `source, data` | `server/main.lua` |
| `rsg-mdt:server:deleteBolo` | server | `source, boloId` | `server/main.lua` |
| `rsg-mdt:server:getReports` | server | `source` | `server/main.lua` |
| `rsg-mdt:server:getReport` | server | `source, reportId` | `server/main.lua` |
| `rsg-mdt:server:createReport` | server | `source, data` | `server/main.lua` |
| `rsg-mdt:server:deleteReport` | server | `source, reportId` | `server/main.lua` |
| `rsg-mdt:server:getReportComments` | server | `source, reportId` | `server/main.lua` |
| `rsg-mdt:server:addReportComment` | server | `source, data` | `server/main.lua` |
| `rsg-mdt:server:getOfficerInfo` | server | `source` | `server/main.lua` |
| `rsg-mdt:server:getStats` | server | `source` | `server/main.lua` |
| `rsg-mdt:server:getIncidentTypes` | server | `source` | `server/main.lua` |
| `rsg-mdt:roleSync:getRoles` | server | `source` | `server/roleSync.lua` |
| `rsg-mdt:roleSync:getMyRole` | server | `source` | `server/roleSync.lua` |
| `rsg-mdt:roleSync:getConfigVersion` | server | `source` | `server/roleSync.lua` |
| `rsg-mdt:roleSync:getValidatedJobs` | server | `source` | `server/roleSync.lua` |
| `rsg-mdt:server:getConfigRoles` | server | `source` | `server/roleSync.lua` |
| `rsg-mdt:server:getStaff` | server | `source` | `server/staff.lua` |
| `rsg-mdt:server:getRoles` | server | `source` | `server/staff.lua` |
| `rsg-mdt:server:addStaff` | server | `source, data` | `server/staff.lua` |
| `rsg-mdt:server:removeStaff` | server | `source, citizenid` | `server/staff.lua` |
| `rsg-mdt:server:updateStaffPermissions` | server | `source, data` | `server/staff.lua` |
| `rsg-mdt:server:createRole` | server | `source, data` | `server/staff.lua` |
| `rsg-mdt:server:updateRole` | server | `source, data` | `server/staff.lua` |
| `rsg-mdt:server:deleteRole` | server | `source, roleName` | `server/staff.lua` |
| `rsg-mdt:server:getAuditLogs` | server | `source, data` | `server/staff.lua` |
| `rsg-mdt:server:searchCitizensForStaff` | server | `source, query` | `server/staff.lua` |
| `rsg-mdt:server:assignLawJob` | server | `source, data` | `server/staff.lua` |
| `rsg-mdt:server:getLawJobs` | server | `source` | `server/staff.lua` |
| `rsg-mdt:server:getJobGrades` | server | `source, jobName` | `server/staff.lua` |
| `rsg-mdt:server:searchPlayersForJob` | server | `source, query` | `server/staff.lua` |
| `rsg-mdt:server:updateOfficerDepartment` | server | `source, data` | `server/staff.lua` |
| `rsg-mdt:server:getOfficers` | server | `source` | `server/staff.lua` |
| `rsg-mdt:server:getJobPlayerCounts` | server | `source` | `server/staff.lua` |
| `rsg-mdt:server:syncStaffFromJobs` | server | `source, filterJob` | `server/staff.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-mdt:server:getAvailableReportsForAttachment', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-mdt:client:updatePlayerFines` | client | `fines` | `client/fines.lua` |
| `rsg-mdt:client:finePaid` | client | `data` | `client/fines.lua` |
| `rsg-mdt:client:finePaymentResult` | client | `data` | `client/fines.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/fines.lua` |
| `rsg-mdt:client:fineStatusUpdated` | client | `data` | `client/fines.lua` |
| `rsg-mdt:client:playerFinePaid` | client | `data` | `client/fines.lua` |
| `rsg-mdt:client:accessResult` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:permissionResult` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:configUpdated` | client | `version` | `client/main.lua` |
| `rsg-mdt:client:notify` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:receiveConfig` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:staffUpdated` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:rolesUpdated` | client | `data` | `client/main.lua` |
| `RSGCore:Player:SetPlayerData` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:jobAssigned` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:departmentUpdated` | client | `data` | `client/main.lua` |
| `rsg-mdt:client:chargesUpdated` | client | `data` | `client/main.lua` |
| `rsg-mdt:roleSync:receiveRoles` | client | `data` | `client/roleSync.lua` |
| `rsg-mdt:roleSync:receiveMyRole` | client | `roleData` | `client/roleSync.lua` |
| `rsg-mdt:roleSync:roleUpdated` | client | `data` | `client/roleSync.lua` |
| `rsg-mdt:roleSync:forceRefresh` | client | `data` | `client/roleSync.lua` |
| `rsg-mdt:roleSync:stateMismatch` | client | `data` | `client/roleSync.lua` |
| `rsg-mdt:roleSync:refreshComplete` | client | `data` | `client/roleSync.lua` |
| `rsg-mdt:server:syncPlayerFines` | server | `` | `server/fines.lua` |
| `rsg-mdt:server:checkAccess` | server | `` | `server/main.lua` |
| `rsg-mdt:server:checkPermission` | server | `permission` | `server/main.lua` |
| `rsg-mdt:server:reloadConfig` | server | `` | `server/main.lua` |
| `rsg-mdt:server:getConfig` | server | `` | `server/main.lua` |
| `rsg-mdt:roleSync:requestRoles` | server | `` | `server/roleSync.lua` |
| `rsg-mdt:roleSync:requestMyRole` | server | `` | `server/roleSync.lua` |
| `rsg-mdt:roleSync:validateLocalState` | server | `localRole` | `server/roleSync.lua` |
| `rsg-mdt:roleSync:adminForceRefresh` | server | `` | `server/roleSync.lua` |
| `RSGCore:Server:PlayerLoaded` | server | `Player` | `server/roleSync.lua` |
| `RSGCore:Server:OnJobUpdate` | server | `job` | `server/roleSync.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-mdt:server:syncPlayerFines')
-- from a server script
TriggerClientEvent('rsg-mdt:client:updatePlayerFines', source, fines)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/mdt` |  | `client/main.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt`, `pt-br`, `ro`, `ru`, `tr`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
