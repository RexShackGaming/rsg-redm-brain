# rsg-hud

Version 3.0.0. rsg-hud

Player and horse HUD for RSG-Core (RedM): health, stamina, hunger, thirst, cleanliness, stress, temperature, voice, mail and outlaw badges, a money pop-up, and a drag-and-resize edit mode. - [rsg-core](https://github.com/Rexshack-RedM/rsg-core) - [ox_lib](https://github.com/overextended/ox_lib)

Source: https://github.com/Rexshack-RedM/rsg-hud

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-hud']:Name)

**server:** `GainStress(src, amount)`, `GetNeeds(src)`, `RelieveStress(src, amount)`, `SetNeed(src, key, value)`, `ShowAccount(src, account)`

**client:** `AddNeed(key, amount)`, `GainStress(amount)`, `GetCurrentTemperature()`, `GetNeed(key)`, `GetNeeds()`, `GetOutlawStatus()`, `IsEditMode()`, `IsHudVisible()`, `RelieveStress(amount)`, `SetHudVisible(visible)`, `SetNeed(key, value)`, `ToggleEditMode(enabled)`

## Net events registered

**client:** `HideAllUI`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `hud:client:GainStress`, `hud:client:OnMoneyChange`, `hud:client:RelieveStress`, `hud:client:ShowAccounts`, `hud:client:ToggleEditMode`, `hud:client:UpdateCleanliness`, `hud:client:UpdateHunger`, `hud:client:UpdateNeeds`, `hud:client:UpdateStress`, `hud:client:UpdateThirst`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `hud:server:getoutlawstatus`

## Commands (RegisterCommand)

**client:** `/edithud`, `/resethud`, `/togglehudpct`
