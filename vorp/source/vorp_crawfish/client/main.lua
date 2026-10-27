local Core = exports.vorp_core:GetCore()
local searching, showprompt, nearest = false, false, 0
local harvesting = false
local progressbarType = tonumber(Config.ProgressBarType or 0)
local progressbar

local function RegisterPrompts()
	local _promptGroup = GetRandomIntInRange(0, 0xffffff)
	local _prompt = UiPromptRegisterBegin()
	UiPromptSetControlAction(_prompt, 0x760A9C6F) -- G key
	local str = CreateVarString(10, 'LITERAL_STRING', _U("hole"))
	UiPromptSetText(_prompt, str)
	UiPromptSetEnabled(_prompt, true)
	UiPromptSetStandardMode(_prompt, true)
	UiPromptSetGroup(_prompt, _promptGroup, 0)
	UiPromptRegisterEnd(_prompt)
	return _prompt, _promptGroup
end

local function TrySearch()
	if harvesting or (not searching) or ((nearest or 0) < 1) then return end
	Core.Callback.TriggerAsync("vorp_crawfish:ServerCB:trySearch", function(resultA)
		if not resultA?.success then
			if resultA?.reason then
				Core.NotifyObjective(resultA.reason, 5000)
			end
			searching, nearest = false, 0
			return
		end

		if IsPedDeadOrDying(PlayerPedId(), false) then
			TriggerServerEvent("vorp_crawfish:Server:cancelSearch")
			searching, nearest = false, 0
			return
		end

		CreateThread(function()
			TaskStartScenarioInPlaceHash(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), resultA.searchTime, true, "", 0, false)
			
			if progressbarType < 2 then
				if progressbarType  == 1 then
					exports['progressBars']:startUI(resultA.searchTime, _U("searching"))
				end
				Wait(resultA.searchTime)

				if IsPedDeadOrDying(PlayerPedId(), false) then
					TriggerServerEvent("vorp_crawfish:Server:cancelSearch")
					searching, nearest = false, 0
					return
				end

				local resultB = Core.Callback.TriggerAwait("vorp_crawfish:ServerCB:doSearch", resultA.holeIndex)
				if not resultB?.success then
					if resultB?.reason then
						Core.NotifyObjective(resultB.reason, 5000)
					end
				end

				ClearPedTasksImmediately(PlayerPedId())
				searching, nearest = false, 0
			elseif (progressbarType == 2) and progressbar then
				progressbar.start(_U("searching"), resultA.searchTime, function()
					if not IsPedDeadOrDying(PlayerPedId(), false) then
						Core.Callback.TriggerAsync("vorp_crawfish:ServerCB:doSearch", function(resultB)
							if not resultB?.success then
								if resultB?.reason then
									Core.NotifyObjective(resultB.reason, 5000)
								end
							end

							ClearPedTasksImmediately(PlayerPedId())
							searching, nearest = false, 0
						end, resultA.holeIndex)
					else
						TriggerServerEvent("vorp_crawfish:Server:cancelSearch")
						searching, nearest = false, 0
					end
				end, Config.ProgressBar.theme, Config.ProgressBar.color, Config.ProgressBar.width, Config.ProgressBar.focus)
			end
		end)
	end, nearest)
end

RegisterNetEvent("vorp_crawfish:Client:tryHarvest", function()
	if harvesting then return end
	harvesting = true
	CreateThread(function()
		local resultA = Core.Callback.TriggerAwait("vorp_crawfish:ServerCB:tryHarvest")
		if not resultA?.success then
			if resultA?.reason then
				Core.NotifyObjective(resultA.reason, 5000)
			end
			harvesting = false
			return
		end

		local playerPed = PlayerPedId()

		if IsPedDeadOrDying(playerPed) then
			TriggerServerEvent("vorp_crawfish:Server:cancelHarvest")
			harvesting = false
			return
		end

		local dict, anim = "mech_skin@chicken@field_dress", "success"
		RequestAnimDict(dict)
		while not HasAnimDictLoaded(dict) do
			Wait(0)
		end
		TaskPlayAnim(playerPed, dict, anim, 1.0, 1.0, 4000, 16, 0.0, false, 0, false, '', false)

		if progressbarType < 2 then
			if progressbarType == 1 then
				exports['progressBars']:startUI(5000, _U("harvesting"))
			end
			Wait(5000)
			
			if not IsPedDeadOrDying(PlayerPedId(), false) then
				local resultB = Core.Callback.TriggerAwait("vorp_crawfish:ServerCB:doHarvest")
				if not resultB?.success then
					if resultB?.reason then
						Core.NotifyObjective(resultB.reason, 5000)
					end
				end
				ClearPedTasksImmediately(playerPed)
			else
				TriggerServerEvent("vorp_crawfish:Server:cancelHarvest")
			end
			RemoveAnimDict(dict)
			harvesting = false
		elseif (progressbarType == 2) and progressbar then
			progressbar.start(_U("harvesting"), 5000, function()
				if not IsPedDeadOrDying(PlayerPedId(), false) then
					Core.Callback.TriggerAsync("vorp_crawfish:ServerCB:doHarvest", function(resultB)
						if not resultB?.success then
							if resultB?.reason then
								Core.NotifyObjective(resultB.reason, 5000)
							end
						end

						ClearPedTasksImmediately(playerPed)
						RemoveAnimDict(dict)
						harvesting = false
					end)
				else
					TriggerServerEvent("vorp_crawfish:Server:cancelHarvest")
					ClearPedTasksImmediately(playerPed)
					RemoveAnimDict(dict)
					harvesting = false
				end
			end, Config.ProgressBar.theme, Config.ProgressBar.color, Config.ProgressBar.width, Config.ProgressBar.focus)
		end
	end)
end)

local function Init()
	if progressbarType == 2 then
		if GetResourceState("vorp_progressbar") == "started" then
			progressbar = exports.vorp_progressbar:initiate()
		end
	end

	CreateThread(function()
		repeat Wait(2000) until LocalPlayer.state.IsInSession
		local _prompt, _promptGroup = RegisterPrompts()

		while true do
			showprompt = false
			local sleep = 1000
			local pedID = PlayerPedId()
			local DeadOrDying = IsPedDeadOrDying(pedID, false)
			if not (IsPedOnMount(pedID) or IsPedInAnyVehicle(pedID, true)) then
				if (not searching) and (not DeadOrDying) and (not harvesting) then
					local coords = GetEntityCoords(pedID)
					for index, pos in ipairs(Config.CrawfishHoles) do
						local distance = #(coords - pos)
						if distance <= 1.5 then
							sleep = 0
							showprompt = true
							nearest = index
							break
						end
					end
				elseif (searching or harvesting) and DeadOrDying then
					searching = false
					showprompt = false
					harvesting = false
					if (progressbarType == 2) and progressbar then
						exports.vorp_progressbar:CancelAll()
					end
					TriggerServerEvent("vorp_crawfish:Server:cancelSearch")
					TriggerServerEvent("vorp_crawfish:Server:cancelHarvest")
				end
				if showprompt and (not searching) and (nearest > 0) and (not DeadOrDying) and (not harvesting) then
					sleep = 0
					local label = CreateVarString(10, 'LITERAL_STRING', _U("search_hole"))
					UiPromptSetActiveGroupThisFrame(_promptGroup, label, 0, 0, 0, 0)

					if UiPromptHasStandardModeCompleted(_prompt, 0) then
						searching = true
						TrySearch()
					end
				end
			else
				if searching then
					searching = false
					if (progressbarType == 2) and progressbar then
						exports.vorp_progressbar:CancelAll()
					end
					TriggerServerEvent("vorp_crawfish:Server:cancelSearch")
				end
				sleep = 2000
			end
			nearest = 0

			Wait(sleep)
		end
	end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		Init()
	end
end)
