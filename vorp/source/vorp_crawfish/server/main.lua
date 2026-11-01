local Core = exports.vorp_core:GetCore()
local holes_searched, holes_searching, harvesting = {}, {}, {}

local function CheckDistance(_source, holeIndex)
	return #(GetEntityCoords(GetPlayerPed(_source)) - Config.CrawfishHoles[holeIndex]) <= 1.5
end

local function CancelSearch(_source)
	for k, v in ipairs(holes_searching) do
		if (v?.source or -1) == _source then
			holes_searching[k] = false
		end
	end
end

local function CancelHarvest(_source)
	if harvesting[_source] then
		TriggerClientEvent('vorp_inventory:blockInventory', _source, false)
	end
	harvesting[_source] = nil
end

Core.Callback.Register("vorp_crawfish:ServerCB:trySearch", function(_source, callback, holeIndex)
	local result = {success = true}
	if CheckDistance(_source, holeIndex) then
		if not holes_searching[holeIndex] then
			holes_searching[holeIndex] = {source = _source}
			local ostime = os.time()
			local searched = false
			if holes_searched[holeIndex] then
				if ostime < (holes_searched[holeIndex] + Config.SearchDelay) then
					searched = true
				end
			end
			if not searched then
				local itemCount
				if type(Config.SearchRewardCount) == "table" then
					itemCount = math.random(Config.SearchRewardCount[1], Config.SearchRewardCount[2])
				else
					itemCount = Config.SearchRewardCount
				end
				holes_searching[holeIndex].itemCount = math.max(0, itemCount)
				result.holeIndex = holeIndex
				result.searchTime = math.random(Config.SearchTimeMin, Config.SearchTimeMax)
			else
				holes_searching[holeIndex] = false
				result.success, result.reason = false, _U("search_recent")
			end
		else
			result.success, result.reason = false, _U("search_current")
		end
	else
		result.success, result.reason = false, _U("search_too_far")
	end
	return callback(result)
end)

Core.Callback.Register("vorp_crawfish:ServerCB:doSearch", function(_source, callback, holeIndex)
	local result = {success = true}
	if CheckDistance(_source, holeIndex) then
		if (holes_searching[holeIndex]?.source or -1) == _source then
			local ostime = os.time()
			if (not holes_searched[holeIndex]) or (holes_searched[holeIndex] and (ostime >= (holes_searched[holeIndex] + Config.SearchDelay))) then
				local itemCount = math.floor(holes_searching[holeIndex].itemCount)
				holes_searched[holeIndex] = ostime
				holes_searching[holeIndex] = false
				
				local found_crawfish, found_other = false, false
				
				if itemCount > 0 then
					if exports.vorp_inventory:canCarryItem(_source, Config.CrawfishItemName, itemCount) then
						exports.vorp_inventory:addItem(_source, Config.CrawfishItemName, itemCount)
						found_crawfish = true
					else
						result.success, result.reason = false, _U("inv_nospace")
					end
				end

				if Config.CanFindOtherItems and (#Config.OtherItems > 0) then
					if math.random(1,100) <= Config.OtherItemsChance then
						local lootpool = ShuffleTableCopy(Config.OtherItems)
						local loot = {}
						for i = 1, math.random(1, Config.MaxOtherItems) do
							if #lootpool < 1 then break end
							local r = math.random(1, #lootpool)
							local amount
							if type(lootpool[r].amount) == "table" then
								amount = math.random(lootpool[r].amount[1], lootpool[r].amount[2])
							else
								amount = lootpool[r].amount
							end
							if amount > 0 then
								table.insert(loot, {item = lootpool[r].item, amount = amount})
							end
							table.remove(lootpool, r)
						end
						if #loot > 0 then
							for k, v in ipairs(loot) do
								if exports.vorp_inventory:canCarryItem(_source, v.item, v.amount) then
									exports.vorp_inventory:addItem(_source, v.item, v.amount)
									found_other = true
								end
							end
						end
					end
				end

				if result.success then
					if found_crawfish or found_other then
						if found_crawfish then
							Core.NotifyObjective(_source, _UP("search_found", { count = itemCount, item = Config.CrawfishItemLabel }), 5000)
						end
						if found_other then
							Core.NotifyRightTip(_source, _U("search_found_other"), 5000)
						end
					else
						result.success, result.reason = false, _U("search_found_nothing")
					end
				else
					if found_other then
						Core.NotifyRightTip(_source, _U("search_found_other"), 5000)
						result.success = true
					end
				end
			else
				holes_searching[holeIndex] = false
				result.success, result.reason = false, _U("search_recent")
			end
		else
			result.success, result.reason = false, _U("not_searching")
		end
	else
		result.success, result.reason = false, _U("search_too_far")
	end
	return callback(result)
end)

RegisterServerEvent("vorp_crawfish:Server:cancelSearch", function()
	local _source = source
	CancelSearch(_source)
end)

Core.Callback.Register('vorp_crawfish:ServerCB:tryHarvest', function(_source, callback)
	local result = {success = true, reason = ''}
	if not harvesting[_source] then
		harvesting[_source] = true
		local itemCount = exports.vorp_inventory:getItemCount(_source, nil, Config.CrawfishItemName)
		if itemCount < 1 then
			harvesting[_source] = nil
			result.success, result.reason = false, _U("nothing_to_harvest")
		end
	else
		result.success, result.reason = false, _U("already_harvesting")
	end
	if not result.success then
		TriggerClientEvent('vorp_inventory:blockInventory', _source, false)
	end
	return callback(result)
end)

Core.Callback.Register('vorp_crawfish:ServerCB:doHarvest', function(_source, callback)
	local result = {success = true, reason = ''}
	if harvesting[_source] then
		if exports.vorp_inventory:subItem(_source, Config.CrawfishItemName, 1) then
			local giveCount
			if type(Config.CrawfishGivenItemAmount) == "table" then
				giveCount = math.random(Config.CrawfishGivenItemAmount[1], Config.CrawfishGivenItemAmount[2])
			else
				giveCount = Config.CrawfishGivenItemAmount
			end
			if exports.vorp_inventory:canCarryItem(_source, Config.CrawfishGivenItemName, giveCount) then
				exports.vorp_inventory:addItem(_source, Config.CrawfishGivenItemName, giveCount)
				Core.NotifyObjective(_source, _UP("harvested", { count = giveCount, item = Config.CrawfishGivenItemLabel }), 5000)
			else
				exports.vorp_inventory:addItem(_source, Config.CrawfishItemName, 1)
				result.success, result.reason = false, _U("inv_nospace")
			end
			harvesting[_source] = nil
		else
			harvesting[_source] = nil
			result.success, result.reason = false, _U("nothing_to_harvest")
		end
	else
		result.success, result.reason = false, _U("not_harvesting")
	end
	TriggerClientEvent('vorp_inventory:blockInventory', _source, false)
	return callback(result)
end)

RegisterServerEvent('vorp_crawfish:Server:cancelHarvest',function()
	local _source = source
	CancelHarvest(_source)
end)

local function Init()
	for k, v in ipairs(Config.CrawfishHoles) do
		holes_searched[k] = false
		holes_searching[k] = false
	end

	if not Config.CrawfishCustomUseFunction then
		exports.vorp_inventory:registerUsableItem(Config.CrawfishItemName, function(data)
			if harvesting[data.source] then
				Core.NotifyObjective(data.source, _U("already_harvesting"), 5000)
				return
			end
			exports.vorp_inventory:closeInventory(data.source)
			TriggerClientEvent('vorp_inventory:blockInventory', data.source, true)
			TriggerClientEvent("vorp_crawfish:Client:tryHarvest", data.source)
		end)
	end
end

AddEventHandler("playerDropped", function(reason)
	local _source = source
	CancelSearch(_source)
	CancelHarvest(_source)
end)

AddEventHandler("onServerResourceStart", function(resourceName)
	if resourceName == GetCurrentResourceName() then
		Init()
	end
end)
