# rsg-mdt

Version 2.0.10. Mobile Data Terminal for RSG Framework

Mobile Data Terminal for RSG Framework (RedM) - **Criminal Records** — Search, create, and manage citizen criminal records - **Warrants** — Issue and manage active/served/expired warrants

Source: https://github.com/Rexshack-RedM/rsg-mdt

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-mdt']:Name)

**server:** `createOrUpdateFine(citizenid, citizenName, chargeIds, totalAmount, officerName, officerCid)`, `forceRefreshRoles()`, `getAllPlayerRoles()`, `getChargeAttachments(chargeId)`, `getChargeTemplates()`, `getCitizenFines(citizenid)`, `getConfigVersion()`, `getLawJobs()`, `getPermissions(source)`, `getPlayerRole(source)`, `getReportsWithCharges(reportId)`, `getSettings()`, `getStaffPermissions(citizenid)`, `getUnpaidFines(citizenid)`, `getValidatedLawJobs()`, `hasAccess(source)`, `hasAdminPermission(source)`, `hasPermission(source, permission)`, `isAdmin(source)`, `isLawJob(jobName)`, `isStaffMember(citizenid)`, `reloadConfig()`

**client:** `attemptLocalOverride(newRole)`, `getAllRoles()`, `getConfigVersion()`, `getJobInfo()`, `getJobLabel()`, `getMyRole()`, `getPermissions()`, `getPlayerFines()`, `getTotalFinesAmount()`, `hasAccess()`, `hasPermission(permission)`, `hasRolePermission(permission)`, `hasUnpaidFines()`, `isAdmin()`, `isLawOfficer()`, `refreshAccess()`, `requestRoleSync()`, `validateLocalState()`

## Net events registered

**server:** `RSGCore:Server:OnJobUpdate`, `RSGCore:Server:PlayerLoaded`, `rsg-mdt:roleSync:adminForceRefresh`, `rsg-mdt:roleSync:requestMyRole`, `rsg-mdt:roleSync:requestRoles`, `rsg-mdt:roleSync:validateLocalState`, `rsg-mdt:server:checkAccess`, `rsg-mdt:server:checkPermission`, `rsg-mdt:server:getConfig`, `rsg-mdt:server:reloadConfig`, `rsg-mdt:server:syncPlayerFines`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Player:SetPlayerData`, `rsg-mdt:client:accessResult`, `rsg-mdt:client:chargesUpdated`, `rsg-mdt:client:configUpdated`, `rsg-mdt:client:departmentUpdated`, `rsg-mdt:client:finePaid`, `rsg-mdt:client:finePaymentResult`, `rsg-mdt:client:fineStatusUpdated`, `rsg-mdt:client:jobAssigned`, `rsg-mdt:client:notify`, `rsg-mdt:client:permissionResult`, `rsg-mdt:client:playerFinePaid`, `rsg-mdt:client:receiveConfig`, `rsg-mdt:client:rolesUpdated`, `rsg-mdt:client:staffUpdated`, `rsg-mdt:client:updatePlayerFines`, `rsg-mdt:roleSync:forceRefresh`, `rsg-mdt:roleSync:receiveMyRole`, `rsg-mdt:roleSync:receiveRoles`, `rsg-mdt:roleSync:refreshComplete`, `rsg-mdt:roleSync:roleUpdated`, `rsg-mdt:roleSync:stateMismatch`

## Callbacks (lib.callback)

**server:** `rsg-mdt:roleSync:getConfigVersion`, `rsg-mdt:roleSync:getMyRole`, `rsg-mdt:roleSync:getRoles`, `rsg-mdt:roleSync:getValidatedJobs`, `rsg-mdt:server:addBolo`, `rsg-mdt:server:addChargeTemplate`, `rsg-mdt:server:addRecord`, `rsg-mdt:server:addReportComment`, `rsg-mdt:server:addStaff`, `rsg-mdt:server:addWarrant`, `rsg-mdt:server:assignLawJob`, `rsg-mdt:server:attachReportsToCharge`, `rsg-mdt:server:commitCharges`, `rsg-mdt:server:createReport`, `rsg-mdt:server:createRole`, `rsg-mdt:server:deleteBolo`, `rsg-mdt:server:deleteChargeTemplate`, `rsg-mdt:server:deleteRecord`, `rsg-mdt:server:deleteReport`, `rsg-mdt:server:deleteRole`, `rsg-mdt:server:deleteWarrant`, `rsg-mdt:server:getAllCitizens`, `rsg-mdt:server:getAllIssuedCharges`, `rsg-mdt:server:getAllUnpaidFines`, `rsg-mdt:server:getAuditLogs`, `rsg-mdt:server:getAvailableReportsForAttachment`, `rsg-mdt:server:getBolos`, `rsg-mdt:server:getChargeAttachments`, `rsg-mdt:server:getChargeDetails`, `rsg-mdt:server:getChargeTemplates`, `rsg-mdt:server:getCitizen`, `rsg-mdt:server:getCitizenFines`, `rsg-mdt:server:getCitizenJailTotals`, `rsg-mdt:server:getConfigRoles`, `rsg-mdt:server:getIncidentTypes`, `rsg-mdt:server:getIssuedCharges`, `rsg-mdt:server:getJailConfig`, `rsg-mdt:server:getJobGrades`, `rsg-mdt:server:getJobPlayerCounts`, `rsg-mdt:server:getLawJobs`, `rsg-mdt:server:getOfficerInfo`, `rsg-mdt:server:getOfficers`, `rsg-mdt:server:getPlayerFines`, `rsg-mdt:server:getRecords`, `rsg-mdt:server:getReport`, `rsg-mdt:server:getReportComments`, `rsg-mdt:server:getReports`, `rsg-mdt:server:getReportsWithCharges`, `rsg-mdt:server:getRoles`, `rsg-mdt:server:getStaff`, `rsg-mdt:server:getStats`, `rsg-mdt:server:getUnpaidFines`, `rsg-mdt:server:getUnpaidFinesCount`, `rsg-mdt:server:getWarrants`, `rsg-mdt:server:hasUnpaidFines`, `rsg-mdt:server:issueCharges`, `rsg-mdt:server:jailPlayer`, `rsg-mdt:server:markFineOverdue`, `rsg-mdt:server:markFinePaid`, `rsg-mdt:server:payFine`, `rsg-mdt:server:removeAttachmentFromCharge`, `rsg-mdt:server:removeStaff`, `rsg-mdt:server:searchCitizens`, `rsg-mdt:server:searchCitizensForStaff`, `rsg-mdt:server:searchPlayersForJob`, `rsg-mdt:server:setProfilePicture`, `rsg-mdt:server:submitCharges`, `rsg-mdt:server:syncStaffFromJobs`, `rsg-mdt:server:updateChargeTemplate`, `rsg-mdt:server:updateOfficerDepartment`, `rsg-mdt:server:updateRole`, `rsg-mdt:server:updateStaffPermissions`, `rsg-mdt:server:updateWarrant`

**client:** `rsg-mdt:roleSync:getLocalState`

## Commands (RegisterCommand)

**client:** `/mdt`

## Public (table) functions

**client/nui.lua:** `NUI.SetStateCallback(cb)`, `NUI.SendMessage(action, data)`, `NUI.SetVisibility(visible)`, `NUI.SetFocus(hasFocus, hasCursor)`, `NUI.Open(data)`, `NUI.Close()`, `NUI.GetWindowState()`, `NUI.SetWindowState(state)`

## Database tables

`mdt_audit_logs`, `mdt_bolos`, `mdt_charge_attachments`, `mdt_charge_templates`, `mdt_citizen_profiles`, `mdt_fines`, `mdt_issued_charges`, `mdt_records`, `mdt_report_comments`, `mdt_reports`, `mdt_roles`, `mdt_staff`, `mdt_warrants`
