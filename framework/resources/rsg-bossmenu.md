# rsg-bossmenu

Version 3.0.1. rsg-bossmenu

Boss management menu for **RSG Framework** (RedM). Job bosses can manage employees, hire nearby players, open job storage, and manage the company bank. - Employee list (online/offline), promote/demote, fire (online or offline) - Hire nearby civilians (server distance check)

Source: https://github.com/Rexshack-RedM/rsg-bossmenu

**Dependencies:** `rsg-core`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-bossmenu:server:FireEmployee`, `rsg-bossmenu:server:GradeUpdate`, `rsg-bossmenu:server:HireEmployee`, `rsg-bossmenu:server:depositMoney`, `rsg-bossmenu:server:openinventory`, `rsg-bossmenu:server:withdrawMoney`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-bossmenu:client:mainmenu`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-bossmenu:server:GetAccount`, `rsg-bossmenu:server:GetEmployees`, `rsg-bossmenu:server:GetNearbyPlayers`
