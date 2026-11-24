# rsg-moonshine

Version 3.7.1. rsg-moonshine

Version 3.7.1 Placeable moonshine stills for **RedM** on the **RSG Framework**. Players set up a still in the wild, load a mash, keep the fire fed and bottle their shine, while the law hunts the stills down. Brewing runs on the server in real time, so stills keep cooking while the owner is away and carry on through restarts.

Source: https://github.com/Rexshack-RedM/rsg-moonshine

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-moonshine']:Name)

**server:** `DestroyStill(id, reason)`, `GetBottleInfo(src, slot)`, `GetBottlePrice(item, quality, proof)`, `GetSkillLevel(src)`, `GetStillAt(coords, radius)`, `GetStills(citizenid)`

## Net events registered

**server:** `rsg-moonshine:server:destroy`, `rsg-moonshine:server:inspect`, `rsg-moonshine:server:placeStill`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-moonshine:client:explode`, `rsg-moonshine:client:placeStill`, `rsg-moonshine:client:removeStill`, `rsg-moonshine:client:syncStill`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-moonshine:server:action`, `rsg-moonshine:server:getState`, `rsg-moonshine:server:getStills`, `rsg-moonshine:server:getWorldStill`, `rsg-moonshine:server:sell`

## Commands (RegisterCommand)

**client:** `/moonshine_unfocus`

## Database tables

`rsg_moonshine_stills`
