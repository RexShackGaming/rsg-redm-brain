# rsg-moonshine

Version 3.0.1. rsg-moonshine

Placeable moonshine stills for **RedM** on the **RSG Framework**. Players set up a still in the wild, load a mash, keep the fire fed and bottle their shine, while the law hunts the stills down. Brewing runs on the server in real time, so stills keep cooking while the owner is away and carry on through restarts. - **Placeable stills:** use the still item to get a see-through preview. Rotate it, the

Source: https://github.com/Rexshack-RedM/rsg-moonshine

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-moonshine:server:destroy`, `rsg-moonshine:server:placeStill`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-moonshine:client:placeStill`, `rsg-moonshine:client:removeStill`, `rsg-moonshine:client:syncStill`

## Callbacks (lib.callback)

**server:** `rsg-moonshine:server:action`, `rsg-moonshine:server:getState`, `rsg-moonshine:server:getStills`, `rsg-moonshine:server:getWorldStill`

## Commands (RegisterCommand)

**client:** `/moonshine_unfocus`

## Database tables

`rsg_moonshine_stills`
