# rsg-gangmenu

Version 3.0.1. rsg-gangmenu

A gang boss management menu for **RedM** servers running the **RSG Framework**. Gang bosses can manage members, recruit nearby players, use a shared gang stash and manage a shared gang bank account. All actions are validated on the server. - **Member management** — view online/offline members, promote/demote, fire with confirmation - **Recruitment** — nearby players (configurable range) must accep

Source: https://github.com/Rexshack-RedM/rsg-gangmenu

**Dependencies:** `rsg-core`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-gangmenu:server:FireMember`, `rsg-gangmenu:server:GradeUpdate`, `rsg-gangmenu:server:HireMember`, `rsg-gangmenu:server:depositMoney`, `rsg-gangmenu:server:openinventory`, `rsg-gangmenu:server:withdrawMoney`

**client:** `RSGCore:Client:OnGangUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-gangmenu:client:mainmenu`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-gangmenu:server:GetAccount`, `rsg-gangmenu:server:GetEmployees`, `rsg-gangmenu:server:GetNearbyPlayers`

## Commands (RSGCore.Commands.Add)

**server:** `/removegang`

## Commands (RegisterCommand)

**client:** `/gangmenu`
