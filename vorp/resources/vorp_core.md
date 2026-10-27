# vorp_core

Version 3.3. A Tool to build your RedM server and scripts

VORP Core is a comprehensive Lua-based framework for RedM, designed to enhance server functionality and player experience with a wide array of configurable settings and commands. - [oxmysql](https://github.com/overextended/oxmysql/releases): A must-have for database operations, ensuring smooth data handling and integration. 1. **Setup:**

Source: https://github.com/VORPCORE/vorp_core

Has NUI (`ui_page`).

## Exports (call as exports['vorp_core']:Name)

**server:** `GetCore()`, `ServerRpcCall()`, `vorpAPI()`

**client:** `ClientRpcCall()`, `DisplayLeftNotification(title, subTitle, dict, icon, duration, color)`, `DisplayObjective(text, duration)`, `DisplayTip(text, duration)`, `DisplayTipRight(text, duration)`, `DisplayTopCenterNotification(text, location, duration)`, `GetCore()`, `LeftInteractive(title, description, description_2, dict, texture, soundDict, soundName, duration, color)`, `LeftRank(title, subTitle, dict, icon, duration, color)`, `OneSimpleTop(title, duration)`, `ShowAdvancedRightNotification(_text, _dict, icon, text_color, duration, quality, showquality)`, `ShowSimpleCenterText(text, duration, text_color)`, `ShowTopNotification(title, subtext, duration)`, `ThreeSimpleTop(title, subtitle, secondary_subtitle, duration)`, `deadplayerNotifY(title, _audioRef, _audioName, duration)`, `failmissioNotifY(title, subTitle, duration)`, `showBottomRight(text, duration)`, `updatemissioNotify(utitle, umsg, duration)`, `warningNotify(title, msg, _audioRef, _audioName, duration)`

## Net events registered

**server:** `vorp:GetValues`, `vorp:HealthCached`, `vorp:ImDead`, `vorp:SaveHealth`, `vorp:SaveStamina`, `vorp:ServerCallback`, `vorp:SwitchMultiJobMenu`, `vorp:TriggerServerCallback`, `vorp:addNewCallBack`, `vorp:playerSpawn`, `vorp_core:PlayerRespawnInternal`

**client:** `vorp:GetHealthFromCore`, `vorp:Heal`, `vorp:LeftInteractive`, `vorp:LeftRank`, `vorp:NotifyLeft`, `vorp:NotifyTop`, `vorp:OneSimpleTop`, `vorp:OpenPlayerMenu`, `vorp:SelectedCharacter`, `vorp:ServerCallback`, `vorp:ShowAdvancedRightNotification`, `vorp:ShowBottomRight`, `vorp:ShowSimpleCenterText`, `vorp:ShowTopNotification`, `vorp:ThreeSimpleTop`, `vorp:Tip`, `vorp:TipBottom`, `vorp:TipRight`, `vorp:TriggerServerCallback`, `vorp:deadplayerNotifY`, `vorp:delHorse`, `vorp:deleteVehicle`, `vorp:failmissioNotifY`, `vorp:initCharacter`, `vorp:resurrectPlayer`, `vorp:setInstancePlayer`, `vorp:setPVPUi`, `vorp:showUi`, `vorp:teleportWayPoint`, `vorp:updateUi`, `vorp:updatemissioNotify`, `vorp:warningNotify`, `vorp_core:Client:AddTimeToRespawn`, `vorp_core:Client:OnPlayerHeal`, `vorp_core:Client:OnPlayerRespawn`, `vorp_core:Client:OnPlayerRevive`, `vorp_core:respawnPlayer`

## Event handlers

**server:** `getCore`, `getWhitelistTables`, `playerConnecting`, `playerJoining`, `txAdmin:events:healedPlayer`, `vorp:Server:playerLeave`, `vorp:addMoney`, `vorp:addXp`, `vorp:getCharacter`, `vorp:removeMoney`, `vorp:removeXp`, `vorp:setGroup`, `vorp:setJob`, `vorp_core:Server:OnPlayerDeath`, `vorp_core:addWebhook`, `vorp_core:instanceplayers`, `vorp_core:playerRemove`, `vorpbans:addtodb`, `vorpwarns:addtodb`

**client:** `getCore`, `playerSpawned`, `vorp:ExecuteServerCallBack`, `vorp:LeftInteractive`, `vorp:LeftRank`, `vorp:NotifyLeft`, `vorp:NotifyTop`, `vorp:OneSimpleTop`, `vorp:ShowAdvancedRightNotification`, `vorp:ShowBottomRight`, `vorp:ShowSimpleCenterText`, `vorp:ShowTopNotification`, `vorp:ThreeSimpleTop`, `vorp:Tip`, `vorp:TipBottom`, `vorp:TipRight`, `vorp:deadplayerNotifY`, `vorp:delHorse`, `vorp:deleteVehicle`, `vorp:failmissioNotifY`, `vorp:initCharacter`, `vorp:updatemissioNotify`, `vorp:warningNotify`, `vorp_core:Client:AddTimeToRespawn`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp:richpresence:callback:getplayers`

## Server events it triggers in other resources

**client:** `vorp:GetValues`, `vorp:HealthCached`, `vorp:ImDead`, `vorp:PlayerForceRespawn`, `vorp:SaveDate`, `vorp:SaveHealth`, `vorp:SaveStamina`, `vorp:ServerCallback`, `vorp:SwitchMultiJobMenu`, `vorp:TriggerServerCallback`, `vorp:chatSuggestion`, `vorp:playerSpawn`

## Public (table) functions

**client/callbacks.lua:** `ClientRPC:New(name, callback)`, `ClientRPC:TriggerRpcAsync(...)`, `ClientRPC:TriggerRpcAwait(...)`, `ClientRPC.ExecuteRpc(uniqueId, isSync, name, ...)`, `ClientRPC.Callback.TriggerAsync(name, callback, ...)`, `ClientRPC.Callback.TriggerAwait(name, ...)`, `ClientRPC:Trigger(uniqueId, isSync, ...)`, `ClientRPC.Callback.Register(name, callback)`

**client/coreactions.lua:** `CoreAction.Admin.HealPlayer()`, `CoreAction.Admin.DeleteHorse()`, `CoreAction.Admin.DeleteVehicleInRadius(radius)`, `CoreAction.Admin.TeleportToWayPoint()`, `CoreAction.Utils.LoadModel(hash)`, `CoreAction.Utils.LoadTexture(hash)`, `CoreAction.Utils.bigInt(text)`

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`, `DataStream.New(view)`

**client/ref/vorp_notifications.lua:** `VorpNotification:NotifyLeft(title, subtitle, dict, icon, duration, color)`, `VorpNotification:NotifyTip(tipMessage, duration)`, `VorpNotification:NotifyTop(message, location, duration)`, `VorpNotification:NotifyRightTip(tipMessage, duration)`, `VorpNotification:NotifyObjective(message, duration)`, `VorpNotification:NotifySimpleTop(title, subtitle, duration)`, `VorpNotification:NotifyThreeSimpleTop(title, subtitle, secondary_subtitle, duration)`, `VorpNotification:NotifyOneSimpleTop(title, duration)`, `VorpNotification:NotifyAdvanced(text, dict, icon, text_color, duration, quality, showquality)`, `VorpNotification:NotifyCenter(text, duration, text_color)`, `VorpNotification:NotifyBottomRight(text, duration)`, `VorpNotification:NotifyFail(title, subtitle, duration)`, `VorpNotification:NotifyDead(title, audioRef, audioName, duration)`, `VorpNotification:NotifyUpdate(title, message, duration)`, `VorpNotification:NotifyWarning(title, message, audioRef, audioName, duration)`, `VorpNotification:NotifyLeftRank(title, subtitle, dict1, texture, duration, color)`, `VorpNotification:NotifyLeftInteractive(title, description, description_2, dict, texture, soundDict, soundName, duration, color)`, `VorpNotification:Test()`

**client/respawnsystem.lua:** `CoreAction.Player.ResurrectPlayer(currentHospital, currentHospitalName, justrevive)`, `CoreAction.Player.RespawnPlayer(allowCleanItems)`

**client/spawnplayer.lua:** `CoreAction.Utils.TogglePVP()`, `CoreAction.Utils.setPVP()`, `CoreAction.Player.TeleportToCoords(coords, heading)`, `CoreAction.Player.MapCheck()`

**client/uicore.lua:** `CoreAction.Utils.ToggleVorpUI()`, `CoreAction.Utils.ToggleAllUI()`

**server/class/callbacks.lua:** `ServerRPC:New(name, callback)`, `ServerRPC:Trigger(_source, uniqueId, isSync, ...)`, `ServerRPC.Callback.Register(name, callback)`, `ServerRPC.Callback.TriggerAsync(name, source, callback, ...)`, `ServerRPC.Callback.TriggerAwait(name, source, ...)`, `ServerRPC:TriggerRpcAsync(source, ...)`, `ServerRPC:TriggerRpcAwait(source, ...)`, `ServerRPC.ExecuteRpc(uniqueId, isSync, name, ...)`

**server/class/whitelisting.lua:** `Whitelist:New(data)`, `Whitelist:Id()`, `Whitelist:Identifier()`, `Whitelist:Status(value)`, `Whitelist:Discord(value)`, `Whitelist:Firstconnection(value)`, `Whitelist:GetEntry()`, `Whitelist.Functions.GetUsersData(userid)`, `Whitelist.Functions.WhitelistUser(id, value)`, `Whitelist.Functions.GetFirstConnection(id)`, `Whitelist.Functions.SetFirstConnection(id, value)`, `Whitelist.Functions.GetUserId(identifier)`, `Whitelist.Functions.InsertWhitelistedUser(data)`

**types/client/callback.lua:** `exports.vorp_core:ClientRpcCall()`

**types/client/notify.lua:** `exports.vorp_core:DisplayTip(text, duration)`, `exports.vorp_core:DisplayLeftNotification(title, subTitle, dict, icon, duration, color)`, `exports.vorp_core:DisplayTopCenterNotification(text, location, duration)`, `exports.vorp_core:DisplayTipRight(text, duration)`, `exports.vorp_core:DisplayObjective(text, duration)`, `exports.vorp_core:ShowTopNotification(title, subtext, duration)`, `exports.vorp_core:ShowAdvancedRightNotification(_text, _dict, icon, text_color, duration, quality, showquality)`, `exports.vorp_core:ShowSimpleCenterText(text, duration, text_color)`, `exports.vorp_core:showBottomRight(text, duration)`, `exports.vorp_core:failmissioNotifY(title, subTitle, duration)`, `exports.vorp_core:deadplayerNotifY(title, _audioRef, _audioName, duration)`, `exports.vorp_core:updateMission(utitle, umsg, duration)`, `exports.vorp_core:warningNotify(title, msg, _audioRef, _audioName, duration)`, `exports.vorp_core:LeftRank(title, subTitle, dict, icon, duration, color)`, `exports.vorp_core:ThreeSimpleTop(title, subtitle, secondary_subtitle, duration)`, `exports.vorp_core:OneSimpleTop(title, duration)`

**types/server/callback.lua:** `exports.vorp_core:ServerRpcCall()`
