# rsg-hud

Version 3.2.1. rsg-hud

Player and horse HUD for RSG-Core (RedM): health, stamina, dead eye, hunger, thirst, cleanliness, stress, temperature, voice, mail and outlaw badges, horse health/stamina/cleanliness/bonding/hunger/thirst, a money pop-up, and a drag-and-resize edit mode. - **Server-owned needs** (`Config.ServerNeeds`): the server decays hunger, thirst and stress and reverts state bag tampering. Clients can still a

Source: https://github.com/Rexshack-RedM/rsg-hud

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-hud']:Name)

**server:** `GainStress(src, amount)`, `GetNeeds(src)`, `RelieveStress(src, amount)`, `SetNeed(src, key, value)`, `ShowAccount(src, account)`

**client:** `AddNeed(key, amount)`, `GainStress(amount)`, `GetCurrentTemperature()`, `GetNeed(key)`, `GetNeeds()`, `GetOutlawStatus()`, `IsEditMode()`, `IsHudVisible()`, `OpenSettings()`, `RelieveStress(amount)`, `SetHudVisible(visible)`, `SetNeed(key, value)`, `ToggleEditMode(enabled)`

## Net events registered

**client:** `HideAllUI`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `hud:client:GainStress`, `hud:client:OnMoneyChange`, `hud:client:RelieveStress`, `hud:client:ShowAccounts`, `hud:client:ToggleEditMode`, `hud:client:UpdateCleanliness`, `hud:client:UpdateHunger`, `hud:client:UpdateNeeds`, `hud:client:UpdateStress`, `hud:client:UpdateThirst`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `hud:server:getoutlawstatus`

## Commands (RegisterCommand)

**client:** `/edithud`, `/resethud`, `/togglehudpct`
