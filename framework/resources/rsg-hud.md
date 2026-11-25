# rsg-hud

Version 3.4.0. rsg-hud

**Version 3.4.0** · full technical reference in [DOCS.md](DOCS.md) Player and horse HUD for RSG-Core (RedM): health, stamina, dead eye, hunger, thirst, cleanliness, stress, temperature, voice, mail and outlaw badges, horse health/stamina/cleanliness/bonding/hunger/thirst, a money pop-up, and a drag-and-resize edit mode. - **Server-owned needs** (`Config.ServerNeeds`): the server decays hunger, thi

Source: https://github.com/Rexshack-RedM/rsg-hud

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-hud']:Name)

**server:** `GainStress(src, amount)`, `GetNeeds(src)`, `RelieveStress(src, amount)`, `SetNeed(src, key, value)`, `ShowAccount(src, account)`

**client:** `AddNeed(key, amount)`, `AddWarmth(amount, duration)`, `GainStress(amount)`, `GetCurrentTemperature()`, `GetNeed(key)`, `GetNeeds()`, `GetOutlawStatus()`, `IsEditMode()`, `IsHudVisible()`, `OpenSettings()`, `RelieveStress(amount)`, `SetHudVisible(visible)`, `SetNeed(key, value)`, `ToggleEditMode(enabled)`, `ToggleHud()`

## Net events registered

**server:** `hud:server:setDefaultLayout`

**client:** `HideAllUI`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `hud:client:DefaultLayoutChanged`, `hud:client:GainStress`, `hud:client:OnMoneyChange`, `hud:client:RelieveStress`, `hud:client:SendDefaultLayout`, `hud:client:ShowAccounts`, `hud:client:ToggleEditMode`, `hud:client:UpdateCleanliness`, `hud:client:UpdateHunger`, `hud:client:UpdateNeeds`, `hud:client:UpdateStress`, `hud:client:UpdateThirst`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `hud:server:getDefaultLayout`, `hud:server:getoutlawstatus`

## Commands (RegisterCommand)

**client:** `/+`, `/-`, `/edithud`, `/resethud`, `/resethudlayout`, `/togglehudpct`

## Server events it triggers in other resources

**client:** `hud:server:setDefaultLayout`
