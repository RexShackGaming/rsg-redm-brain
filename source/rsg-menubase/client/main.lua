MenuData = {}
MenuData.Opened = {}
MenuData.RegisteredTypes = {}
MenuData.LastSelectedIndex = {}
MenuData.LockCount = { movement = 0, inventory = 0 }

MenuData.RegisteredTypes["default"] = {
	open = function(namespace, name, data)
		SendNUIMessage({
			ak_menubase_action = "openMenu",
			ak_menubase_namespace = namespace,
			ak_menubase_name = name,
			ak_menubase_data = data,
		})
	end,
	close = function(namespace, name)
		SendNUIMessage({
			ak_menubase_action = "closeMenu",
			ak_menubase_namespace = namespace,
			ak_menubase_name = name,
		})
	end,
}

function MenuData.Open(type, namespace, name, data, submit, cancel, change, close)
	local menu = {}

	menu.type = type
	menu.namespace = namespace
	menu.name = name
	menu.data = data
	menu.submit = submit
	menu.cancel = cancel
	menu.change = change
	menu.data.selected = MenuData.LastSelectedIndex[menu.type .. "_" .. menu.namespace .. "_" .. menu.name] or 0

	if menu.data.disableMovement then
		MenuData.LockCount.movement = MenuData.LockCount.movement + 1
		FreezeEntityPosition(PlayerPedId(), true)
	end

	if menu.data.lockInventory then
		MenuData.LockCount.inventory = MenuData.LockCount.inventory + 1
        LocalPlayer.state:set("inv_busy", true, true)
    end

	menu.close = function()
		MenuData.RegisteredTypes[type].close(namespace, name)

		if menu.data.disableMovement then
			MenuData.LockCount.movement = math.max(0, MenuData.LockCount.movement - 1)
			if MenuData.LockCount.movement == 0 then
				FreezeEntityPosition(PlayerPedId(), false)
			end
		end

		if menu.data.lockInventory then
			MenuData.LockCount.inventory = math.max(0, MenuData.LockCount.inventory - 1)
			if MenuData.LockCount.inventory == 0 then
				LocalPlayer.state:set("inv_busy", false, true)
			end
        end


		for i = #MenuData.Opened, 1, -1 do
			if
				MenuData.Opened[i]
				and MenuData.Opened[i].type == type
				and MenuData.Opened[i].namespace == namespace
				and MenuData.Opened[i].name == name
			then
				table.remove(MenuData.Opened, i)
			end
		end

		if close then
			close()
		end
	end

	menu.update = function(query, newData)
		for i = 1, #menu.data.elements, 1 do
			local match = true

			for k, v in pairs(query) do
				if menu.data.elements[i][k] ~= v then
					match = false
				end
			end

			if match then
				for k, v in pairs(newData) do
					menu.data.elements[i][k] = v
				end
			end
		end
	end

	menu.addNewElement = function(element)
		menu.data.elements[#menu.data.elements + 1] = element
	end

	menu.removeElementByValue = function(value, stop)
		-- remove element(s) matching value; iterate backwards so
		-- table.remove doesn't skip the element that shifts into place
		for i = #menu.data.elements, 1, -1 do
			if menu.data.elements[i] and menu.data.elements[i].value == value then
				table.remove(menu.data.elements, i)
				if stop then
					break
				end
			end
		end
	end

	menu.removeElementByIndex = function(index, stop)
		if menu.data.elements[index] then
			table.remove(menu.data.elements, index)
		end
	end

	menu.refresh = function()
		MenuData.RegisteredTypes[type].open(namespace, name, menu.data)
	end

	menu.setElement = function(i, key, val)
		menu.data.elements[i][key] = val
	end
	-- override all elements
	menu.setElements = function(newElements)
		menu.data.elements = newElements
	end

	-- change the title of the current menu
	menu.setTitle = function(val)
		menu.data.title = val
	end

	menu.removeElement = function(query)
		for i = #menu.data.elements, 1, -1 do
			local element = menu.data.elements[i]
			if element then
				local match = true
				for k, v in pairs(query) do
					if element[k] ~= v then
						match = false
						break
					end
				end
				if match then
					table.remove(menu.data.elements, i)
				end
			end
		end
	end

	MenuData.Opened[#MenuData.Opened + 1] = menu
	MenuData.RegisteredTypes[type].open(namespace, name, data)
	PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0)
	return menu
end

function MenuData.Close(type, namespace, name)
	-- menu.close() already removes the entry from MenuData.Opened, so
	-- iterate backwards and let it handle removal (avoids double-removal
	-- and index-shift bugs from mutating the array while nil-ing entries)
	for i = #MenuData.Opened, 1, -1 do
		local opened = MenuData.Opened[i]
		if
			opened
			and opened.type == type
			and opened.namespace == namespace
			and opened.name == name
		then
			opened.close()
		end
	end
end

function MenuData.CloseAll()
	for i = #MenuData.Opened, 1, -1 do
		if MenuData.Opened[i] then
			MenuData.Opened[i].close()
		end
	end
end

function MenuData.GetOpened(type, namespace, name)
	for i = 1, #MenuData.Opened, 1 do
		if MenuData.Opened[i] then
			if
				MenuData.Opened[i].type == type
				and MenuData.Opened[i].namespace == namespace
				and MenuData.Opened[i].name == name
			then
				return MenuData.Opened[i]
			end
		end
	end
end

function MenuData.GetOpenedMenus()
    return MenuData.Opened
end

function MenuData.IsOpen(type, namespace, name)
    return MenuData.GetOpened(type, namespace, name) ~= nil
end

function MenuData.ReOpen(oldMenu)
	MenuData.Open(
		oldMenu.type,
		oldMenu.namespace,
		oldMenu.name,
		oldMenu.data,
		oldMenu.submit,
		oldMenu.cancel,
		oldMenu.change,
		oldMenu.close
	)
end

local MenuType = "default"

RegisterNUICallback("menu_submit", function(data, cb)
	PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0)
	local menu = MenuData.GetOpened(MenuType, data._namespace, data._name)
	if menu and menu.submit ~= nil then
		menu.submit(data, menu)
	end
	cb('ok')
end)

RegisterNUICallback("playsound", function(data, cb)
	PlaySoundFrontend("NAV_LEFT", "PAUSE_MENU_SOUNDSET", true, 0)
	cb('ok')
end)

RegisterNUICallback("menu_cancel", function(data, cb)
	PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0)
	local menu = MenuData.GetOpened(MenuType, data._namespace, data._name)
	if menu and menu.cancel ~= nil then
		menu.cancel(data, menu)
	end
	cb('ok')
end)

RegisterNUICallback("menu_change", function(data, cb)
	local menu = MenuData.GetOpened(MenuType, data._namespace, data._name)

	if menu then
		for i = 1, #data.elements, 1 do
			menu.setElement(i, "value", data.elements[i].value)
			menu.setElement(i, "selected", data.elements[i].selected and true or false)
		end

		if menu.change ~= nil then
			menu.change(data, menu)
		end
	end

	cb('ok')
end)

RegisterNUICallback("update_last_selected", function(data, cb)
	local menu = MenuData.GetOpened(MenuType, data._namespace, data._name)
	if menu and data.selected ~= nil then
		local menuKey = menu.type .. "_" .. menu.namespace .. "_" .. menu.name
		MenuData.LastSelectedIndex[menuKey] = data.selected
	end
	cb('ok')
end)

RegisterNUICallback("closeui", function(data, cb)
	TriggerEvent("menuapi:closemenu")
	cb('ok')
end)

CreateThread(function()
	local PauseMenuState = false
	local MenusToReOpen = {}
	while true do
		Wait(#MenuData.Opened > 0 and 0 or 200)
		if #MenuData.Opened > 0 then
			if IsControlJustReleased(0, 0x43DBF61F) or IsDisabledControlJustReleased(0, 0x43DBF61F) then
				SendNUIMessage({ ak_menubase_action = "controlPressed", ak_menubase_control = "ENTER" })
			end

			if IsControlJustReleased(0, 0x308588E6) or IsDisabledControlJustReleased(0, 0x308588E6) then
				SendNUIMessage({ ak_menubase_action = "controlPressed", ak_menubase_control = "BACKSPACE" })
			end

			if IsControlJustReleased(0, 0x911CB09E) or IsDisabledControlJustReleased(0, 0x911CB09E) then
				SendNUIMessage({ ak_menubase_action = "controlPressed", ak_menubase_control = "TOP" })
			end

			if IsControlJustReleased(0, 0x4403F97F) or IsDisabledControlJustReleased(0, 0x4403F97F) then
				SendNUIMessage({ ak_menubase_action = "controlPressed", ak_menubase_control = "DOWN" })
			end

			if IsControlJustReleased(0, 0xAD7FCC5B) or IsDisabledControlJustReleased(0, 0xAD7FCC5B) then
				SendNUIMessage({ ak_menubase_action = "controlPressed", ak_menubase_control = "LEFT" })
			end

			if IsControlJustReleased(0, 0x65F9EC5B) or IsDisabledControlJustReleased(0, 0x65F9EC5B) then
				SendNUIMessage({ ak_menubase_action = "controlPressed", ak_menubase_control = "RIGHT" })
			end

			if IsPauseMenuActive() then
				if not PauseMenuState then
					PauseMenuState = true
					for k, v in pairs(MenuData.GetOpenedMenus()) do
						table.insert(MenusToReOpen, v)
					end
					MenuData.CloseAll()
				end
			end
		else
			if PauseMenuState and not IsPauseMenuActive() then
				PauseMenuState = false
				Citizen.Wait(1000)
				for k, v in pairs(MenusToReOpen) do
					MenuData.ReOpen(v)
				end
				MenusToReOpen = {}
			end
		end
	end
end)

AddEventHandler("rsg-menubase:getData", function(cb)
	return cb(MenuData)
end)

AddEventHandler("onClientResourceStart", function(resourceName)
	if resourceName == GetCurrentResourceName() then
		MenuData.LastSelectedIndex = {}
	end
end)

exports("GetMenuData", function()
	return MenuData
end)
