# rsg-bossmenu

Version 3.0.0. rsg-bossmenu

**Boss management menu for RedM servers using RSG Core.** > ox_lib–based menu system allowing **job bosses** to manage employees, funds, and storage. Works seamlessly with RSG Core job data and optional map blips. - [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠

Source: https://github.com/Rexshack-RedM/rsg-bossmenu

**Dependencies:** `rsg-core`, `ox_lib`

## Net events registered

**server:** `rsg-bossmenu:server:FireEmployee`, `rsg-bossmenu:server:GradeUpdate`, `rsg-bossmenu:server:HireEmployee`, `rsg-bossmenu:server:depositMoney`, `rsg-bossmenu:server:openinventory`, `rsg-bossmenu:server:withdrawMoney`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `rsg-bossmenu:client:HireMenu`, `rsg-bossmenu:client:ManageEmployee`, `rsg-bossmenu:client:SocietyMenu`, `rsg-bossmenu:client:employeelist`, `rsg-bossmenu:client:mainmenu`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-bossmenu:getplayers`, `rsg-bossmenu:server:GetAccount`, `rsg-bossmenu:server:GetEmployees`
