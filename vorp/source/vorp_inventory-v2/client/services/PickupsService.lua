local WORLD_PICKUPS <const> = {}
local PickUpPrompt          = 0
local group <const>         = GetRandomIntInRange(0, 0xffffff)

local pickups <const>       = {

	GET_UNIQUE_ID = function()
		local index = GetRandomIntInRange(0, 0xffffff)
		while WORLD_PICKUPS[index] do
			index = GetRandomIntInRange(0, 0xffffff)
		end
		return index
	end,

	CREATE_OBJECT = function(objectHash, position, itemType, rotation)
		if itemType == "item_standard" then
			local model <const> = CONFIG.PICKUPS.DROP_MODELS[objectHash] or CONFIG.PICKUPS.DROP_MODELS.default_box
			UTILS.LOAD_MODEL(model)
			local zPos = not rotation and position.z - 1 or position.z
			local entityHandle <const> = CreateObject(joaat(model), position.x, position.y, zPos, false, false, false, false)
			if not entityHandle then return 0 end

			if not rotation then
				PlaceObjectOnGroundProperly(entityHandle, false)
			end

			FreezeEntityPosition(entityHandle, true)
			if CONFIG.PICKUPS.USE_LIGHT then
				SetPickupLight(entityHandle, true)
			end

			SetEntityCollision(entityHandle, false, true)
			SetModelAsNoLongerNeeded(model)
			if rotation then
				SetEntityRotation(entityHandle, rotation.x, rotation.y, rotation.z, 0, true)
			end

			return entityHandle
		else
			if not SHARED_DATA.WEAPONS[objectHash] then
				return PICKUP_SERVICE.CREATE_OBJECT("default_box", position, "item_standard")
			end

			if not CONFIG.PICKUPS.USE_WEAPON_MODELS then
				return PICKUP_SERVICE.CREATE_OBJECT("default_box", position, "item_standard")
			end

			if not Citizen.InvokeNative(0xFF07CF465F48B830, joaat(objectHash)) then
				Citizen.InvokeNative(0x72D4CB5DB927009C, joaat(objectHash), 1, true) -- request weapon asset
				repeat Wait(0) until Citizen.InvokeNative(0xFF07CF465F48B830, joaat(objectHash))
			end

			local object <const> = CreateWeaponObject(joaat(objectHash), 0, position.x, position.y, position.z, true, 1.0)
			if object == 0 then return 0 end
			if not rotation then
				PlaceObjectOnGroundProperly(object, true)
			end

			if CONFIG.PICKUPS.USE_LIGHT then
				SetPickupLight(object, true)
			end

			SetEntityVisible(object, true)
			if CONFIG.PICKUPS.WEAPON_ADJUSTMENTS[objectHash] then
				SetEntityRotation(object, CONFIG.PICKUPS.WEAPON_ADJUSTMENTS[objectHash], 0.0, 0.0, 0, true)
			end

			if rotation then
				SetEntityRotation(object, rotation.x, rotation.y, rotation.z, 0, true)
			end

			SetEntityCollision(object, false, false)
			SetEntityInvincible(object, true)
			SetEntityProofs(object, 1, true)
			FreezeEntityPosition(object, true)

			return object
		end
	end,

	SHARE_PICKUP = function(data, value)
		if value == 1 then
			if WORLD_PICKUPS[data.obj] then return end
			local id = 1

			if data.type == "item_standard" then
				local item <const> = PLAYER_INVENTORY.ITEMS[data.id]
				if item then
					item:quitCount(data.amount)
					if item:getCount() == 0 then
						PLAYER_INVENTORY.ITEMS[data.id] = nil
					end
				end
				id = 2
			end

			local label <const> = UTILS.INVENTORY.GET_ITEM_LABEL(id, data.name, data.metadata)
			if not label then
				print(("label not found for %s %s"):format(data.name, id))
			end
			local pickup <const> = {
				label    = (label or data.name) .. " x " .. tostring(data.amount),
				entityId = 0,
				coords   = data.position,
				uid      = data.uid,
				type     = data.type,
				name     = data.name,
				rotation = data.rotation,
			}
			WORLD_PICKUPS[data.obj] = pickup

			NUI_SERVICE.INVENTORY.GET_LOAD()
		else
			local pickup <const> = WORLD_PICKUPS[data.obj]
			if pickup then
				if pickup.entityId and DoesEntityExist(pickup.entityId) then
					DeleteEntity(pickup.entityId)
				end
				WORLD_PICKUPS[data.obj] = nil
			end
		end
	end,

	SHARE_MONEY = function(handle, amount, position, uuid, value, rotation)
		if value == 1 then
			if not WORLD_PICKUPS[handle] then
				local pickup <const> = {
					label = LANG.money .. " (" .. tostring(amount) .. ")",
					entityId = 0,
					amount = amount,
					isMoney = true,
					isGold = false,
					isRoll = false,
					coords = position,
					uuid = uuid,
					type = "item_standard",
					name = "money_bag",
					rotation = rotation,
				}
				WORLD_PICKUPS[handle] = pickup
			end
		else
			local pickup <const> = WORLD_PICKUPS[handle]
			if pickup then
				if pickup.entityId and DoesEntityExist(pickup.entityId) then
					DeleteEntity(pickup.entityId)
				end

				WORLD_PICKUPS[handle] = nil
			end
		end
	end,

	SHARE_GOLD = function(handle, amount, position, uuid, value, rotation)
		if value == 1 then
			if not WORLD_PICKUPS[handle] then
				local pickup <const> = {
					label = LANG.gold .. " (" .. tostring(amount) .. ")",
					entityId = 0,
					amount = amount,
					isMoney = false,
					isGold = true,
					isRoll = false,
					coords = position,
					uuid = uuid,
					type = "item_standard",
					name = "gold_bag",
					rotation = rotation,
				}

				WORLD_PICKUPS[handle] = pickup
			end
		else
			local pickup <const> = WORLD_PICKUPS[handle]
			if pickup then
				if pickup.entityId and DoesEntityExist(pickup.entityId) then
					DeleteEntity(pickup.entityId)
				end

				WORLD_PICKUPS[handle] = nil
			end
		end
	end,

	SHARE_ROLL = function(handle, amount, position, uuid, value, rotation)
		if value == 1 then
			if not WORLD_PICKUPS[handle] then
				local rollLbl <const> = LANG.inventoryrolllabel or "Roll"
				local pickup <const> = {
					label = rollLbl .. " (" .. tostring(amount) .. ")",
					entityId = 0,
					amount = amount,
					isMoney = false,
					isGold = false,
					isRoll = true,
					coords = position,
					uuid = uuid,
					type = "item_standard",
					name = "rol_bag",
					rotation = rotation,
				}

				WORLD_PICKUPS[handle] = pickup
			end
		else
			local pickup <const> = WORLD_PICKUPS[handle]
			if pickup then
				if pickup.entityId and DoesEntityExist(pickup.entityId) then
					DeleteEntity(pickup.entityId)
				end

				WORLD_PICKUPS[handle] = nil
			end
		end
	end,

	PLAY_ANIM = function(animation)
		UTILS.PLAY_ANIM(animation)
	end,
}

PICKUP_SERVICE              = pickups


CreateThread(function()
	local function createPrompt()
		PickUpPrompt = UiPromptRegisterBegin()
		UiPromptSetControlAction(PickUpPrompt, CONFIG.PICKUPS.KEY)
		UiPromptSetText(PickUpPrompt, VarString(10, "LITERAL_STRING", LANG.TakeFromFloor))
		UiPromptSetEnabled(PickUpPrompt, true)
		UiPromptSetVisible(PickUpPrompt, true)
		UiPromptSetHoldMode(PickUpPrompt, 1000)
		UiPromptSetGroup(PickUpPrompt, group, 0)
		UiPromptRegisterEnd(PickUpPrompt)
	end

	local function isAnyPlayerNear()
		local playerPed <const>    = PlayerPedId()
		local playerCoords <const> = GetEntityCoords(playerPed, true, true)
		local players <const>      = GetActivePlayers()
		local count                = 0
		for _, player in ipairs(players) do
			local targetPed = GetPlayerPed(player)
			if player ~= PlayerId() then
				local targetCoords <const> = GetEntityCoords(targetPed, true, true)
				local distance <const> = #(playerCoords - targetCoords)
				if distance < 2.0 then
					count = count + 1
				end
			end
		end

		return count
	end

	repeat Wait(2000) until LocalPlayer.state.IsInSession
	createPrompt()
	local pressed = false
	while true do
		local sleep = 1000

		local playerPed <const> = CACHE.Ped
		local isDead <const> = CACHE.IsDead


		for key, pickup in pairs(WORLD_PICKUPS) do
			local dist <const> = #(GetEntityCoords(playerPed) - pickup.coords)

			if dist < 80.0 then
				if pickup.entityId == 0 or not DoesEntityExist(pickup.entityId) then
					pickup.entityId = PICKUP_SERVICE.CREATE_OBJECT(pickup.name, pickup.coords, pickup.type, pickup.rotation)
				end
			else
				if DoesEntityExist(pickup.entityId) then
					DeleteEntity(pickup.entityId)
					pickup.entityId = 0
				end
			end

			UiPromptSetVisible(PickUpPrompt, not isDead)

			if dist <= 1.5 and not IS_INV_OPEN then
				sleep = 0
				local label <const> = VarString(10, "LITERAL_STRING", pickup.label)
				UiPromptSetActiveGroupThisFrame(group, label, 0, 0, 0, 0)

				if UiPromptHasHoldModeCompleted(PickUpPrompt) then
					if pickup.entityId == WORLD_PICKUPS[key].entityId then
						if not pressed then
							pressed = true

							if isAnyPlayerNear() == 0 then
								if pickup.isMoney then
									local pdata = { obj = key, uuid = pickup.uuid }
									TriggerServerEvent("vorpinventory:onPickupMoney", pdata)
								elseif pickup.isGold then
									local pdata = { obj = key, uuid = pickup.uuid }
									TriggerServerEvent("vorpinventory:onPickupGold", pdata)
								elseif pickup.isRoll then
									local pdata = { obj = key, uuid = pickup.uuid }
									TriggerServerEvent("vorpinventory:onPickupRoll", pdata)
								else
									local pdata = { uid = pickup.uid, obj = key }
									TriggerServerEvent("vorpinventory:onPickup", pdata)
								end
								TaskLookAtEntity(playerPed, pickup.entityId, 1000, 2048, 3, 0)
							end

							SetTimeout(4000, function()
								pressed = false
							end)
						end
					end
				end
			end
		end
		Wait(sleep)
	end
end)


-- for debug
AddEventHandler("onResourceStop", function(resourceName)
	if GetCurrentResourceName() ~= resourceName then return end
	if not CONFIG.DEV_MODE then return end
	--delete all entities
	for _, value in pairs(WORLD_PICKUPS) do
		if DoesEntityExist(value.entityId) then
			DeleteEntity(value.entityId)
		end
	end
end)
