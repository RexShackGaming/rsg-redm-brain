# rsg-mdt

Version 3.0.0. Mobile Data Terminal for RSG Framework

Mobile Data Terminal for RSG Framework (RedM) - **Criminal Records** — Search, create, and manage citizen criminal records - **Warrants** — Issue and manage active/served/expired warrants

Source: https://github.com/Rexshack-RedM/rsg-mdt

**Dependencies:** `rsg-core`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-mdt']:Name)

**server:** `createOrUpdateFine(citizenid, citizenName, chargeIds, totalAmount, officerName, officerCid)`, `forceRefreshRoles()`, `getAllPlayerRoles()`, `getChargeAttachments(chargeId)`, `getChargeTemplates()`, `getCitizenFines(citizenid)`, `getConfigVersion()`, `getLawJobs()`, `getPermissions(source)`, `getPlayerRole(source)`, `getReportsWithCharges(reportId)`, `getSettings()`, `getStaffPermissions(citizenid)`, `getUnpaidFines(citizenid)`, `getValidatedLawJobs()`, `hasAccess(source)`, `hasAdminPermission(source)`, `hasPermission(source, permission)`, `isAdmin(source)`, `isLawJob(jobName)`, `isStaffMember(citizenid)`, `reloadConfig()`

**client:** `attemptLocalOverride(newRole)`, `getAllRoles()`, `getConfigVersion()`, `getJobInfo()`, `getJobLabel()`, `getMyRole()`, `getPermissions()`, `getPlayerFines()`, `getTotalFinesAmount()`, `hasAccess()`, `hasPermission(permission)`, `hasRolePermission(permission)`, `hasUnpaidFines()`, `isAdmin()`, `isLawOfficer()`, `refreshAccess()`, `requestRoleSync()`, `validateLocalState()`

## Net events registered

**server:** `RSGCore:Server:OnJobUpdate`, `RSGCore:Server:PlayerLoaded`, `rsg-mdt:roleSync:adminForceRefresh`, `rsg-mdt:roleSync:requestMyRole`, `rsg-mdt:roleSync:requestRoles`, `rsg-mdt:roleSync:validateLocalState`, `rsg-mdt:server:checkAccess`, `rsg-mdt:server:checkPermission`, `rsg-mdt:server:getConfig`, `rsg-mdt:server:reloadConfig`, `rsg-mdt:server:syncPlayerFines`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Player:SetPlayerData`, `rsg-mdt:client:accessResult`, `rsg-mdt:client:chargesUpdated`, `rsg-mdt:client:configUpdated`, `rsg-mdt:client:departmentUpdated`, `rsg-mdt:client:finePaid`, `rsg-mdt:client:finePaymentResult`, `rsg-mdt:client:fineStatusUpdated`, `rsg-mdt:client:jobAssigned`, `rsg-mdt:client:notify`, `rsg-mdt:client:permissionResult`, `rsg-mdt:client:playerFinePaid`, `rsg-mdt:client:receiveConfig`, `rsg-mdt:client:rolesUpdated`, `rsg-mdt:client:staffUpdated`, `rsg-mdt:client:updatePlayerFines`, `rsg-mdt:roleSync:forceRefresh`, `rsg-mdt:roleSync:receiveMyRole`, `rsg-mdt:roleSync:receiveRoles`, `rsg-mdt:roleSync:refreshComplete`, `rsg-mdt:roleSync:roleUpdated`, `rsg-mdt:roleSync:stateMismatch`

## Commands (RegisterCommand)

**client:** `/mdt`

## Public (table) functions

**client/nui.lua:** `NUI.SetStateCallback(cb)`, `NUI.SendMessage(action, data)`, `NUI.SetVisibility(visible)`, `NUI.SetFocus(hasFocus, hasCursor)`, `NUI.Open(data)`, `NUI.Close()`, `NUI.GetWindowState()`, `NUI.SetWindowState(state)`

## Database tables

`mdt_audit_logs`, `mdt_bolos`, `mdt_charge_attachments`, `mdt_charge_templates`, `mdt_citizen_profiles`, `mdt_fines`, `mdt_issued_charges`, `mdt_records`, `mdt_report_comments`, `mdt_reports`, `mdt_roles`, `mdt_staff`, `mdt_warrants`
