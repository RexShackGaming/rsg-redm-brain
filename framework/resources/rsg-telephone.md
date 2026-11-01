# rsg-telephone

Version 3.0.0. rsg-telephone - persistent telephone props with private voice calls

Persistent telephone props for the RSG Framework (RedM). Admins place wall or desk phones that survive restarts; each phone gets a number. Players dial from a phone (keypad or directory), the far phone rings for anyone nearby, and answering opens a private voice line between the two callers. Public phones work as coin-operated payphones, and phones can be reserved for a job. - Admin-placed, persis

Source: https://github.com/Rexshack-RedM/rsg-telephone

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-telephone:server:cancelPlace`, `rsg-telephone:server:hangUp`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-telephone:client:addPhone`, `rsg-telephone:client:callConnected`, `rsg-telephone:client:callEnded`, `rsg-telephone:client:credit`, `rsg-telephone:client:openAdmin`, `rsg-telephone:client:removePhone`, `rsg-telephone:client:setRinging`, `rsg-telephone:client:startPlacement`, `rsg-telephone:client:startVoice`, `rsg-telephone:client:syncPhones`, `rsg-telephone:client:updatePhone`

## Callbacks (lib.callback)

**server:** `rsg-telephone:server:adminDelete`, `rsg-telephone:server:adminEndCall`, `rsg-telephone:server:adminList`, `rsg-telephone:server:adminUpdate`, `rsg-telephone:server:answer`, `rsg-telephone:server:createPhone`, `rsg-telephone:server:getDirectory`, `rsg-telephone:server:getPhones`, `rsg-telephone:server:ownerUpdate`, `rsg-telephone:server:pickupPhone`, `rsg-telephone:server:setListed`, `rsg-telephone:server:startCall`

## Commands (RSGCore.Commands.Add)

**server:** `/addphone`, `/phoneadmin`, `/phoneinfo`, `/phonejob`, `/removephone`

## Database tables

`rsg_telephones`
