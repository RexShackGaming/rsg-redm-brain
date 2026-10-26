# rsg-radialmenu

Version 3.0.0. rsg-radialmenu

**Radial interaction menu for RedM using RSG Core.** A fast, themed radial menu with nested submenus, job-specific actions, synced walk styles and an export API so other resources can add their own options. - [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core)

Source: https://github.com/Rexshack-RedM/rsg-radialmenu

**Dependencies:** `rsg-core`, `ox_lib`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-radialmenu']:Name)

**client:** `AddOption(data, id)`, `RemoveOption(id)`

## Net events registered

**server:** `rsg-radialmenu:server:setWalkstyle`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-radialmenu:client:SendLawmanEmergencyAlert`, `rsg-radialmenu:client:SendMedicEmergencyAlert`, `rsg-radialmenu:client:noPlayers`, `rsg-radialmenu:client:reapplyWalkstyle`, `rsg-radialmenu:client:setWalkstyle`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

## Server events it triggers in other resources

**client:** `RSGCore:CallCommand`, `rsg-lawman:server:lawmanAlert`, `rsg-medic:server:medicAlert`
