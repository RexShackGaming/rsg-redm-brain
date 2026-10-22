# rsg-core

Version 3.0.6. rsg-core

The core framework for RSG RedM servers: players, characters, money, jobs, gangs, permissions, commands, callbacks and shared data. Documentation: https://rsgcore.com/docs - [oxmysql](https://github.com/overextended/oxmysql)

Source: https://github.com/Rexshack-RedM/rsg-core

**Dependencies:** `oxmysql`, `ox_lib`

## Exports (call as exports['rsg-core']:Name)

**server:** `ExploitBan(playerId, origin)`, `GetCoreObject()`, `GetCoreVersion(InvokingResource)`, `SetField(fieldName, data)`, `SetMethod(methodName, handler)`

**client:** `ChangeText`, `DrawText(text, pos)`, `GenerateCSRFToken()`, `GetCoreObject()`, `HideText()`, `KeyPressed`, `createPrompt(name, coords, key, text, options)`, `createPromptGroup(group, label, coords, prompts)`, `deletePrompt(name)`, `deletePromptGroup(name)`, `getPrompt()`, `getPromptGroup()`

**shared:** `GetWeapons()`

## Net events registered

**server:** `RSGCore:CallCommand`, `RSGCore:Server:CloseServer`, `RSGCore:Server:KickCSRF`, `RSGCore:Server:OnPlayerLoaded`, `RSGCore:Server:OpenServer`, `RSGCore:Server:SetMetaData`, `RSGCore:Server:TriggerCallback`, `RSGCore:Server:TriggerCallbackId`, `RSGCore:Server:TriggerClientCallback`, `RSGCore:ToggleDuty`, `RSGCore:UpdatePlayer`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Client:OnSharedUpdate`, `RSGCore:Client:OnSharedUpdateMultiple`, `RSGCore:Client:PvpHasToggled`, `RSGCore:Client:TriggerCallback`, `RSGCore:Client:TriggerCallbackId`, `RSGCore:Client:TriggerClientCallback`, `RSGCore:Command:DeleteVehicle`, `RSGCore:Command:GoToMarker`, `RSGCore:Command:ShowMe3D`, `RSGCore:Command:SpawnVehicle`, `RSGCore:Command:TeleportToCoords`, `RSGCore:Command:TeleportToPlayer`, `RSGCore:Command:ToggleNoClip`, `RSGCore:Notify`, `RSGCore:Player:SetPlayerData`, `RSGCore:Player:UpdatePlayerData`, `rsg-core:client:ChangeText`, `rsg-core:client:DrawText`, `rsg-core:client:HideText`, `rsg-core:client:KeyPressed`

## Event handlers

**server:** `RSGCore:DebugSomething`, `RSGCore:Server:OnMoneyChange`, `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerDropped`, `RSGCore:Server:PlayerLoaded`, `chatMessage`, `playerConnecting`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `RSGCore:Server:SpawnVehicle`

## Commands (RSGCore.Commands.Add)

**server:** `/addpermission`, `/cid`, `/closeserver`, `/dv`, `/dvall`, `/dvo`, `/dvp`, `/gang`, `/givemoney`, `/id`, `/job`, `/me`, `/noclip`, `/ooc`, `/openserver`, `/removepermission`, `/setgang`, `/setjob`, `/setmoney`, `/togglepvp`, `/tp`, `/tpm`, `/vehicle`

## Server events it triggers in other resources

**client:** `RSGCore:Server:KickCSRF`, `RSGCore:Server:TriggerCallbackId`, `RSGCore:Server:TriggerClientCallback`, `RSGCore:UpdatePlayer`

## Public (table) functions

**client/functions.lua:** `RSGCore.Functions.CreateClientCallback(name, cb)`, `RSGCore.Functions.TriggerClientCallback(name, cb, ...)`, `RSGCore.Functions.TriggerCallback(name, cb, ...)`, `RSGCore.Debug(...)`, `RSGCore.Functions.GetPlayerData(cb)`, `RSGCore.Functions.GetCoords(entity)`, `RSGCore.Functions.HasItem(items, amount)`, `RSGCore.Functions.LookAtEntity(entity, timeout, speed)`, `RSGCore.Functions.PlayAnim(animDict, animName, upperbodyOnly, duration)`, `RSGCore.Functions.GetVehicles()`, `RSGCore.Functions.GetObjects()`, `RSGCore.Functions.GetPlayers()`, `RSGCore.Functions.GetPlayersFromCoords(coords, distance)`, `RSGCore.Functions.GetClosestPlayer(coords)`, `RSGCore.Functions.GetPeds(ignoreList)`, `RSGCore.Functions.GetClosestPed(coords, ignoreList)`, `RSGCore.Functions.GetClosestVehicle(coords)`, `RSGCore.Functions.GetClosestObject(coords)`, `RSGCore.Functions.SpawnVehicle(model, cb, coords, isnetworked, teleportInto)`, `RSGCore.Functions.DeleteVehicle(vehicle)`, `RSGCore.Functions.DrawText(x, y, width, height, scale, r, g, b, a, text)`, `RSGCore.Functions.DrawText3D(x, y, z, text)`, `RSGCore.Functions.GetClosestBone(entity, list)`, `RSGCore.Functions.GetBoneDistance(entity, boneType, boneIndex)`, `RSGCore.Functions.AttachProp(ped, model, boneId, x, y, z, xR, yR, zR, vertex)`, `RSGCore.Functions.SpawnClear(coords, radius)`, `RSGCore.Functions.StartParticleAtCoord(dict, ptName, looped, coords, rot, scale, alpha, color, duration)`, `RSGCore.Functions.StartParticleOnEntity(dict, ptName, looped, entity, bone, offset, rot, scale, alpha, color, evolution, duration)`, `RSGCore.Functions.GetCardinalDirection(entity)`, `RSGCore.Functions.GetCurrentTime()`, `RSGCore.Functions.GetGroundZCoord(coords)`, `RSGCore.Functions.GetGroundHash(entity)`, `RSGCore.Functions.Notify(title, text, notifyType, duration, icon)`

**server/commands.lua:** `RSGCore.Commands.Add(name, help, arguments, argsrequired, callback, permission, ...)`, `RSGCore.Commands.Refresh(source)`

**server/debug.lua:** `RSGCore.Debug(tbl, indent)`, `RSGCore.ShowError(resource, msg)`, `RSGCore.ShowSuccess(resource, msg)`

**server/exports.lua:** `api.add(name, data)`, `api.addMany(entries)`, `api.update(name, data)`, `api.remove(name)`

**server/functions.lua:** `RSGCore.Functions.GetCoords(entity)`, `RSGCore.Functions.GetIdentifier(source, idtype)`, `RSGCore.Functions.GetSource(identifier)`, `RSGCore.Functions.GetPlayer(source)`, `RSGCore.Functions.GetPlayerByCitizenId(citizenid)`, `RSGCore.Functions.GetOfflinePlayerByCitizenId(citizenid)`, `RSGCore.Functions.GetPlayerByLicense(license)`, `RSGCore.Functions.GetPlayerByAccount(account)`, `RSGCore.Functions.GetPlayerByCharInfo(property, value)`, `RSGCore.Functions.GetPlayers()`, `RSGCore.Functions.GetRSGPlayers()`, `RSGCore.Functions.GetPlayersOnDuty(job)`, `RSGCore.Functions.GetDutyCount(job)`, `RSGCore.Functions.GetClosestPlayer(source, coords)`, `RSGCore.Functions.GetClosestObject(source, coords)`, `RSGCore.Functions.GetClosestVehicle(source, coords)`, `RSGCore.Functions.GetClosestPed(source, coords)`, `RSGCore.Functions.GetBucketObjects()`, `RSGCore.Functions.SetPlayerBucket(source, bucket)`, `RSGCore.Functions.SetEntityBucket(entity, bucket)`, `RSGCore.Functions.GetPlayersInBucket(bucket)`, `RSGCore.Functions.GetEntitiesInBucket(bucket)`, `RSGCore.Functions.SpawnVehicle(source, model, coords, warp)`, `RSGCore.Functions.CreateVehicle(source, model, vehtype, coords, warp)`, `RSGCore.Functions.Notify(source, text, notifyType, duration)`, `RSGCore.Functions.ClientCallbackKey(source, name)`, `RSGCore.Functions.TriggerClientCallback(name, source, cb, ...)`, `RSGCore.Functions.CreateCallback(name, cb)`, `RSGCore.Functions.TriggerCallback(name, source, cb, ...)`, `RSGCore.Functions.CreateUseableItem(item, data)`, `RSGCore.Functions.CanUseItem(item)`, `RSGCore.Functions.UseItem(source, item)`, `RSGCore.Functions.Kick(source, reason, setKickReason, deferrals)`, `RSGCore.Functions.SetServerClosed(closed, reason)`, `RSGCore.Functions.IsWhitelisted(source)`, `RSGCore.Functions.IsValidPermission(permission)`, `RSGCore.Functions.AddPermission(source, permission)`, `RSGCore.Functions.RemovePermission(source, permission)`, `RSGCore.Functions.HasPermission(source, permission)`, `RSGCore.Functions.GetPermission(source)`, `RSGCore.Functions.IsOptin(source)`, `RSGCore.Functions.ToggleOptin(source)`, `RSGCore.Functions.IsPlayerBanned(source)`, `RSGCore.Functions.GetDatabaseInfo()`, `RSGCore.Functions.IsLicenseInUse(license)`, `RSGCore.Functions.HasItem(source, items, amount)`, `RSGCore.Functions.PrepForSQL(source, data, pattern)`, `RSGCore.Functions.ChangeWeight(source, weight)`, `RSGCore.Functions.ChangeSlots(source, slots)`, `RSGCore.Functions.CanCarryItem(source, item, amount)`

**server/player.lua:** `RSGCore.Player.Login(source, citizenid, newData)`, `RSGCore.Player.GetOfflinePlayer(citizenid)`, `RSGCore.Player.GetPlayerByLicense(license)`, `RSGCore.Player.GetOfflinePlayerByLicense(license)`, `RSGCore.Player.CheckPlayerData(source, PlayerData)`, `RSGCore.Player.Logout(source)`, `RSGCore.Player.CreatePlayer(PlayerData, Offline)`, `Player.Functions.UpdatePlayerData()`, `Player.Functions.SetJob(job, grade)`, `Player.Functions.SetGang(gang, grade)`, `Player.Functions.HasItem(items, amount)`, `Player.Functions.SetJobDuty(onDuty)`, `Player.Functions.SetPlayerData(key, val)`, `Player.Functions.SetMetaData(meta, val)`, `Player.Functions.GetMetaData(meta)`, `Player.Functions.AddRep(rep, amount)`, `Player.Functions.RemoveRep(rep, amount)`, `Player.Functions.GetRep(rep)`, `Player.Functions.AddMoney(moneytype, amount, reason)`, `Player.Functions.RemoveMoney(moneytype, amount, reason)`, `Player.Functions.SetMoney(moneytype, amount, reason)`, `Player.Functions.GetMoney(moneytype)`, `Player.Functions.Save()`, `Player.Functions.Logout()`, `Player.Functions.AddMethod(methodName, handler)`, `Player.Functions.AddField(fieldName, data)`, `Player.Functions.PersistStateBags()`, `Player.Functions.InitializeStateBags()`, `RSGCore.Functions.AddPlayerMethod(ids, methodName, handler)`, `RSGCore.Functions.AddPlayerField(ids, fieldName, data)`, `RSGCore.Player.Save(source)`, `RSGCore.Player.SaveOffline(PlayerData)`, `RSGCore.Player.DeleteCharacter(source, citizenid)`, `RSGCore.Player.ForceDeleteCharacter(citizenid)`, `RSGCore.Player.SaveInventory(source)`, `RSGCore.Player.SaveOfflineInventory(PlayerData)`, `RSGCore.Player.GetTotalWeight(items)`, `RSGCore.Player.GetSlotsByItem(items, itemName)`, `RSGCore.Player.GetFirstSlotByItem(items, itemName)`, `RSGCore.Player.CreateCitizenId()`, `RSGCore.Functions.CreateAccountNumber()`, `RSGCore.Player.CreateFingerId()`, `RSGCore.Player.CreateWalletId()`, `RSGCore.Player.CreateSerialNumber()`

**shared/main.lua:** `RSGShared.RandomStr(length)`, `RSGShared.RandomInt(length)`, `RSGShared.SplitStr(str, delimiter)`, `RSGShared.Trim(value)`, `RSGShared.FirstToUpper(value)`, `RSGShared.Round(value, numDecimalPlaces)`
