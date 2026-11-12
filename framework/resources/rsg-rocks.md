# rsg-rocks

Version 3.0.1. Mining system for RSG Framework

Mining system for RSG Framework (rsg-core 3.x). Mine rocks and salt rocks, drill them into ores and gems at mining camps, and smelt ores into bars. - Any player can mine, drill and smelt (no job lock) - Database rock nodes with in-game admin place (rsg-gizmo: move + rotate, heading saved) / delete / toggle

Source: https://github.com/Rexshack-RedM/rsg-rocks

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-rocks:server:AdminAddRock`, `rsg-rocks:server:CancelWork`, `rsg-rocks:server:FinishDrill`, `rsg-rocks:server:FinishSmelt`, `rsg-rocks:server:MineReward`, `rsg-rocks:server:StartDrill`, `rsg-rocks:server:StartMining`, `rsg-rocks:server:StartSmelt`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Player:SetPlayerData`, `rsg-rocks:client:SetCooldown`, `rsg-rocks:client:SetZones`, `rsg-rocks:client:StartPlaceRock`, `rsg-rocks:client:StopDrillBatch`, `rsg-rocks:client:ToggleMiningHat`, `rsg-rocks:client:ZoneDepleted`

## Event handlers

**client:** `rsg-rocks:client:HatWorn`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-rocks:server:GetZones`

## Commands (RSGCore.Commands.Add)

**server:** `/addrock`, `/delrock`, `/miningxp`, `/nearbrocks`, `/reloadrocks`, `/rockadmin`, `/togglerock`

## Database tables

`rsg_rocks_zones`
