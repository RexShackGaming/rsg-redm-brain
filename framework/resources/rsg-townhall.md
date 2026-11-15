# rsg-townhall

Version 3.1.1. rsg-townhall - Town Hall job vacancies, applications and approvals

**Version 3.0.0** · Dependencies: `rsg-core` (multi-job built in), `rsg-target`, `oxmysql` A Town Hall employment office for RSG Framework. Players walk up to a clerk NPC, open the Town Hall from the target menu and browse **vacant whitelisted jobs**. They apply with a form, a manager or admin reviews the application, and an approval grants the job and rank (with feedback). Rejections give feedbac

Source: https://github.com/Rexshack-RedM/rsg-townhall

**Dependencies:** `rsg-core`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-townhall']:Name)

**server:** `GetOpenVacancyCount(job)`, `HasPendingApplication(citizenid, job)`, `IsBlacklisted(citizenid, job)`

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-townhall:client:syncLocations`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-townhall:server:addBlacklist`, `rsg-townhall:server:addManager`, `rsg-townhall:server:apply`, `rsg-townhall:server:closePosting`, `rsg-townhall:server:deleteTemplate`, `rsg-townhall:server:editApplication`, `rsg-townhall:server:editPosting`, `rsg-townhall:server:getLocations`, `rsg-townhall:server:getManageData`, `rsg-townhall:server:getMessages`, `rsg-townhall:server:getMyApplications`, `rsg-townhall:server:getMyJobs`, `rsg-townhall:server:getPerms`, `rsg-townhall:server:getTemplates`, `rsg-townhall:server:getVacancies`, `rsg-townhall:server:markSeen`, `rsg-townhall:server:postJob`, `rsg-townhall:server:removeBlacklist`, `rsg-townhall:server:removeManager`, `rsg-townhall:server:reopenPosting`, `rsg-townhall:server:requestInterview`, `rsg-townhall:server:resign`, `rsg-townhall:server:review`, `rsg-townhall:server:saveTemplate`, `rsg-townhall:server:sendMessage`, `rsg-townhall:server:withdraw`

## Database tables

`townhall_applications`, `townhall_blacklist`, `townhall_locations`, `townhall_managers`, `townhall_messages`, `townhall_postings`, `townhall_resignations`, `townhall_templates`
