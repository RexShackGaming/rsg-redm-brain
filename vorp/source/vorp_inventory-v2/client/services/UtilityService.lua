local Utils <const> = {

	PLAY_ANIM = function(animation)
		if not animation or not animation.ENABLE then return end

		local playerPed <const> = CACHE.Ped
		local animDict <const> = animation.AnimDict

		if not DoesAnimDictExist(animDict) then
			print("Animation dictionary is not exist: " .. animDict)
			return
		end

		if not HasAnimDictLoaded(animDict) then
			RequestAnimDict(animDict)
			repeat Wait(0) until HasAnimDictLoaded(animDict)
		end

		TaskPlayAnim(playerPed, animDict, animation.AnimName, animation.Speed or 1.0, animation.SpeedMultiplier or 8.0, animation.Duration or -1, animation.Flag or 1, 0, false, false, false)

		Wait(animation.ClearTaskTime or 1200)
		ClearPedTasks(playerPed, true, true)
	end,
	GET_RANDOM_POSITION_AROUND = function(position, radius)
		local angle <const> = math.random() * 2 * math.pi
		local dx = radius * math.cos(angle)
		local dy = radius * math.sin(angle)

		return vector3(position.x + dx, position.y + dy, position.z)
	end,

	EXPANDO_PROCESSING = function(object)
		local _obj <const> = {}
		for _, row in pairs(object) do
			_obj[_] = row
		end
		return _obj
	end,

	APPLY_POSFX = function()
		local filter <const> = CONFIG.INVENTORY_UI.BACKGROUND_FILTER
		if filter.ENABLE then
			AnimpostfxPlay(filter.FILTER)
			AnimpostfxSetStrength(filter.FILTER, filter.STRENGTH)
		end
	end,

	LOAD_MODEL = function(model)
		if not IsModelValid(model) then
			print(("Model is invalid: %s"):format(model))
			return false
		end

		if not HasModelLoaded(model) then
			RequestModel(model, true)
			local startTime <const> = GetGameTimer()
			repeat Wait(0) until HasModelLoaded(model) or (GetGameTimer() - startTime) > 5000
			if (GetGameTimer() - startTime) > 5000 then
				print(("Failed to load model: %s after 5 seconds"):format(model))
				return false
			end
		end

		return true
	end,

	WEAPONS = {

		GET_DEFAULT_LABEL = function(name)
			return SHARED_DATA.WEAPONS[name]?.Name or name
		end,

		GET_DEFAULT_DESC = function(hash)
			return SHARED_DATA.WEAPONS[hash]?.Desc or hash
		end,

		GET_DEFAULT_WEIGHT = function(hash)
			return SHARED_DATA.WEAPONS[hash]?.Weight or 0.25
		end,

		GET_DEFAULT_NAME = function(hash)
			return SHARED_DATA.WEAPONS[hash]?.HashName or hash
		end,

		GET_DEFAULT_DATA = function(request)
			local weapons = {}
			for _, value in ipairs(request) do
				if SHARED_DATA.WEAPONS[value].HashName == value then
					table.insert(weapons, SHARED_DATA.WEAPONS[value])
				end
			end
			return weapons
		end,

	},

	AMMO = {
		GET_DEFAULT_LABEL = function(ammo)
			if type(ammo) == "string" then
				return SHARED_DATA.AMMO_LABEL[ammo]
			end

			if type(ammo) ~= "number" then
				return false
			end

			for _, value in pairs(SHARED_DATA.AMMO_LABEL) do
				if joaat(value) == ammo then
					return value
				end
			end
		end,
	},

	INVENTORY = {

		GET_WEAPON_ID = function(hash)
			for _, weapon in pairs(PLAYER_INVENTORY.WEAPONS) do
				if weapon:getUsed() then
					if joaat(weapon:getName()) == hash then
						return weapon:getId()
					end
				end
			end
			return 0
		end,

		GET_ITEM = function(name)
			if not PLAYER_INVENTORY.ITEMS or not name then
				return false
			end

			for _, item in pairs(PLAYER_INVENTORY.ITEMS) do
				if name == item:getName() then
					return {
						label = item:getMetadata().label or item:getLabel(),
						count = item:getCount(),
						limit = item:getLimit(),
						weight = item:getMetadata().weight or item:getWeight(),
						metadata = item:getMetadata(),
						name = item:getName(),
						desc = item:getMetadata().description or item:getDesc(),
						degradation = item:getDegradation(),
						maxDegradation = item:getMaxDegradation(),
						durability = item:getDurability(),
					}
				end
			end

			return false
		end,

		GET_ITEMS = function()
			if not PLAYER_INVENTORY.ITEMS then
				return false
			end

			local items <const> = {}
			for _, item in pairs(PLAYER_INVENTORY.ITEMS) do
				table.insert(items, {
					label = item:getMetadata().label or item:getLabel(),
					count = item:getCount(),
					limit = item:getLimit(),
					weight = item:getWeight(),
					metadata = item:getMetadata(),
					name = item:getName(),
					desc = item:getMetadata().description or item:getDesc(),
					degradation = item:getDegradation(),
					maxDegradation = item:getMaxDegradation(),
					durability = item:getDurability(),
				})
			end
			return items
		end,

		GET_ITEM_LABEL = function(id, name, metadata)
			if id == 2 then
				if metadata?.label then
					if type(metadata.label) == "string" then
						return metadata.label
					end
				end
				if CLIENT_ITEMS[name] then
					return CLIENT_ITEMS[name].label
				end
			else
				return UTILS.WEAPONS.GET_DEFAULT_LABEL(name)
			end
		end,

		GET_SERVER_ITEM = function(data)
			if not data then
				return false
			end

			if type(data) == "string" then
				return CLIENT_ITEMS[data]
			end

			if type(data) == "table" then
				local items = {}
				for _, item in ipairs(data) do
					if CLIENT_ITEMS[item] then
						table.insert(items, CLIENT_ITEMS[item])
					end
				end
				return items
			end

			return false
		end,
	}

}

UTILS = Utils
