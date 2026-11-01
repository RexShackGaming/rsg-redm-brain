# vorp_utils

Version 1.1.1. A library to help build your scripts for vorp core framework

> [!WARNING] > > **DO NOT USE VORP Utils.**

Source: https://github.com/VORPCORE/vorp_utils

## Exports (call as exports['vorp_utils']:Name)

**server:** `GetUtils()`

**client:** `GetUtils()`

## Net events registered

**client:** `vorp:SelectedCharacter`

## Event handlers

**server:** `getUtils`

**client:** `getUtils`, `vorp:SelectedCharacter`

## Public (table) functions

**client/services/blips.lua:** `BlipAPI:SetBlip(name, sprite, scale, x, y, z, BlipStyle)`, `BlipClass:Get()`, `BlipClass:Remove()`, `BlipClass:AddRadius(radius, hash)`, `BlipAPI:RemoveBlip(blip)`, `BlipAPI:AddRadius(radius, x, y, z, hash)`

**client/services/destruction.lua:** `DestructionAPI:GetMapObject(x, y, z, radius, objectname)`, `destruct:DoesExist()`, `destruct:SetState(state)`, `destruct:GetState()`, `destruct:resetState()`, `DestructionAPI:DoesExist(object)`, `DestructionAPI:SetState(object, state)`, `DestructionAPI:resetState(object)`, `DestructionAPI:GetState(object)`

**client/services/events.lua:** `EventsAPI:RegisterEventListener(eventname, cb)`, `EventsAPI:RemoveEventListener(listener)`, `EventsAPI:DevMode(state, type)`

**client/services/gps.lua:** `GpsApi:SetGps(x, y, z, color)`, `GpsApi:RemoveGps()`

**client/services/objects.lua:** `ObjectAPI:Create(modelhash, x, y, z, heading, networked, method)`, `ObjClass:PickupLight(state)`, `ObjClass:Freeze(state)`, `ObjClass:SetHeading(state)`, `ObjClass:PlaceOnGround(state)`, `ObjClass:SetAsMission(state)`, `ObjClass:SetAsNoLongerNeeded()`, `ObjClass:Invincible(state)`, `ObjClass:SetNotHorseJumpable(state)`, `ObjClass:Remove()`, `ObjClass:GetObj()`

**client/services/peds.lua:** `PedAPI:Create(modelhash, x, y, z, heading, location, safeground, options, outfit, networked, vector4)`, `PedClass:Freeze(state)`, `PedClass:Invincible(state)`, `PedClass:CanBeDamaged(state)`, `PedClass:SetHeading(head)`, `PedClass:SeeingRange(range)`, `PedClass:HearingRange(range)`, `PedClass:CanBeMounted(state)`, `PedClass:SetBlip(bliphash, title)`, `PedClass:GiveWeapon(weaponhash, ammocount, forceinhand, forceinholster, attachpoint, allowmultiplecopies,
                                 ignoreunlocks, permanentdegredation)`, `PedClass:FleeAtribute(flag, enabled)`, `PedClass:SetPedCombatAttributes(attributes, attackrange, abilitylevel, movement)`, `PedClass:SetCombatStyle(combathash, duration)`, `PedClass:ClearCombatStyle()`, `PedClass:AttackTarget(target, style)`, `PedClass:Remove()`, `PedClass:GetPed()`, `PedClass:AddPedToGroup(group)`, `PedClass:FollowToOffsetOfEntity(entity, offsetX, offsetY, offsetZ, movementSpeed, timeout, stoppingRange,
                                             persistFollowing, p9, walkOnly)`, `PedClass:SetRelationshipWithGroup(relationship, group)`, `PedClass:SetAttributePoints(attribute, value)`, `PedClass:AddAttributePoints(attribute, value)`, `PedClass:SetAttributeBaseRank(attribute, value)`, `PedClass:SetAttributeBonousRank(attribute, value)`, `PedClass:SetAttributeOverpower(attribute, value, makesound)`, `PedClass:GetTaskStatus(task)`, `PedClass:ClearTasks()`, `PedClass:IsDead()`, `PedClass:ChangeOutfit(outfit)`

**client/services/prompts.lua:** `PromptsAPI:SetupPromptGroup()`, `GroupsClass:ShowGroup(text)`, `GroupsClass:RegisterPrompt(title, button, enabled, visible, pulsing, mode, options)`, `PromptClass:TogglePrompt(toggle)`, `PromptClass:EnabledPrompt(toggle)`, `PromptClass:DeletePrompt()`, `PromptClass:HasCompleted(hideoncomplete)`, `PromptClass:HasFailed(hideoncomplete)`

**client/services/render.lua:** `RenderAPI:WorldToScreen(pos)`, `RenderAPI:WorldToHud(pos)`, `RenderAPI:DrawSprite(pos, size, rotation, color, textureDict, textureName)`, `RenderAPI:DrawRectangle(pos, size, color)`, `RenderAPI:DrawMarker(type, pos, dir, rot, scale, color, bobeffect, facecamera, rotate, drawonents)`, `RenderAPI:DrawText(pos, text, color, scale, enableShadow)`

**server/services/files.lua:** `FilesAPI:Open(resourcename, filepath)`, `FileClass:Read(mode)`, `FileClass:Save(content, mode, dataLenght)`, `FileClass:Update(content, mode, dataLenght)`, `FilesAPI:Load(resourcename, filepath, mode)`, `FilesAPI:Save(resourcename, filepath, content, mode)`, `FilesAPI:Update(resourcename, filepath, content, mode)`

**shared/helpers/general.lua:** `Shared:LoadModel(modelhash)`

**shared/services/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`

**shared/services/general.lua:** `GeneralAPI:CreateClass(create)`, `_class:constructor(vars)`, `_class:registerFunctions(functions)`

**shared/services/print.lua:** `PrintAPI:initialize(prnt)`
