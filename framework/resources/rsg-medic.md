# rsg-medic

Version 3.0.2. Death system and medic job for RSG Framework

Death system and doctor job for the RSG Framework (RedM), with a custom NUI in the RDR2 leather & gold theme. **Death** - Downed players see a death screen with a bleed-out timer, the number of doctors on duty and the respawn fee

Source: https://github.com/Rexshack-RedM/rsg-medic

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-medic']:Name)

**server:** `SendAutomedicLog(event, src, extra, description)`

## Net events registered

**server:** `rsg-medic:automedic:server:finished`, `rsg-medic:automedic:server:stage`, `rsg-medic:automedic:server:treated`, `rsg-medic:server:alert`, `rsg-medic:server:bandageDone`, `rsg-medic:server:buy`, `rsg-medic:server:cancelAction`, `rsg-medic:server:finishAction`, `rsg-medic:server:openStash`, `rsg-medic:server:respawn`, `rsg-medic:server:setDead`, `rsg-medic:server:toggleDuty`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Client:SetDuty`, `rsg-medic:automedic:client:callDoctor`, `rsg-medic:client:alert`, `rsg-medic:client:alertSent`, `rsg-medic:client:heal`, `rsg-medic:client:revive`, `rsg-medic:client:useBandage`

## Event handlers

**server:** `rsg-medic:server:reviveInPlace`

**client:** `RSGCore:Client:OnPlayerUnload`

## Callbacks (lib.callback)

**server:** `rsg-medic:server:beginAction`, `rsg-medic:server:getDeathInfo`, `rsg-medic:server:getMenu`, `rsg-medic:server:getPatients`

## Commands (RSGCore.Commands.Add)

**server:** `/revive`
