# rsg-gangmenu

Version 3.0.0. rsg-gangmenu

A gang boss management menu for **RedM** servers running the **RSG Framework**. Gang bosses can manage members, recruit nearby players, use a shared gang stash and look after a shared gang bank account. All of these actions are checked on the server. - **Member management** - View every gang member, online 🟢 or offline ❌, sorted by rank

Source: https://github.com/Rexshack-RedM/rsg-gangmenu

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`, `rsg-inventory`

## Net events registered

**server:** `rsg-gangmenu:server:FireMember`, `rsg-gangmenu:server:GradeUpdate`, `rsg-gangmenu:server:HireMember`, `rsg-gangmenu:server:depositMoney`, `rsg-gangmenu:server:openinventory`, `rsg-gangmenu:server:withdrawMoney`

**client:** `RSGCore:Client:OnGangUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-gangmenu:client:HireMenu`, `rsg-gangmenu:client:ManageEmployee`, `rsg-gangmenu:client:SocietyMenu`, `rsg-gangmenu:client:employeelist`, `rsg-gangmenu:client:mainmenu`

## Callbacks (lib.callback)

**server:** `rsg-gangmenu:server:GetAccount`, `rsg-gangmenu:server:GetEmployees`, `rsg-gangmenu:server:GetNearbyPlayers`

**client:** `rsg-gangmenu:client:ConfirmInvite`

## Commands (RSGCore.Commands.Add)

**server:** `/removegang`

## Commands (RegisterCommand)

**client:** `/gangmenu`
