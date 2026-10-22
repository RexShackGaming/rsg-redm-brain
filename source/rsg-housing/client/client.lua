local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local OwnedHouses    = {} -- [houseid] = { owner, label, home } for every rented house
local MyHouses       = {} -- [houseid] = true for houses this player rents
local DoorStates     = {}
local RegisteredDoors = {}
local HouseBlips     = {}
local HousesById     = {}
local doorPromptGroup = GetRandomIntInRange(0, 0xffffff)
local lockPrompt     = nil
local doorBusy       = false
local uiOpen         = false
local uiHouse        = nil
local uiOpening      = false
local adminOpen      = false
local houseMenuGroup = GetRandomIntInRange(0, 0xffffff)
local houseMenuPrompt = nil

for _, house in ipairs(Config.Houses) do HousesById[house.houseid] = house end

local function defaultHouseName(houseid)
    return HousesById[houseid] and HousesById[houseid].name or houseid
end

-- custom name set by the tenant, otherwise the config name
local function houseName(houseid)
    local rented = OwnedHouses[houseid]
    return rented and rented.label or defaultHouseName(houseid)
end

---------------------------------------
-- house blips
---------------------------------------
local function refreshHouseBlips()
    for i = 1, #HouseBlips do
        if DoesBlipExist(HouseBlips[i]) then RemoveBlip(HouseBlips[i]) end
    end
    HouseBlips = {}

    for _, house in ipairs(Config.Houses) do
        if house.showblip and house.blipcoords then
            local owner = OwnedHouses[house.houseid]
            local isMine = owner and MyHouses[house.houseid]

            if isMine or not Config.OwnedHouseBlips then
                local style, name
                if isMine then
                    style = owner.home and Config.Blips.home or Config.Blips.mine
                    name = owner.label or locale('blip_my_house')
                elseif owner then
                    style = owner.home and Config.Blips.home or Config.Blips.rented
                    name = owner.label or locale('blip_owned_house', owner.owner)
                else
                    style = Config.Blips.vacant
                    name = locale('blip_for_sale', house.name)
                end
                if owner and owner.home then name = locale('blip_home_suffix', name) end

                local blip = BlipAddForCoords(1664425300, house.blipcoords)
                SetBlipSprite(blip, joaat(style.sprite), true)
                BlipAddModifier(blip, joaat(style.colour))
                SetBlipName(blip, name)
                HouseBlips[#HouseBlips + 1] = blip
            end
        end
    end
end

---------------------------------------
-- doors
---------------------------------------
local function applyDoorState(doorid, state)
    local hash = tonumber(doorid)
    if not hash then return end
    if not RegisteredDoors[hash] then
        Citizen.InvokeNative(0xD99229FE93B46286, hash, 1, 1, 0, 0, 0, 0) -- AddDoorToSystemNew
        RegisteredDoors[hash] = true
    end
    Citizen.InvokeNative(0x6BAB9442830C7F53, hash, state) -- DoorSystemSetDoorState
end

-- turn the player to face the door before using the key
local function faceCoords(coords)
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local heading = GetHeadingFromVector_2d(coords.x - pos.x, coords.y - pos.y)
    local diff = math.abs(((GetEntityHeading(ped) - heading + 180.0) % 360.0) - 180.0)
    if diff < 15.0 then return end

    ClearPedTasks(ped)
    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, 1000)
    local timeout = GetGameTimer() + 1200
    while GetGameTimer() < timeout do
        Wait(50)
        diff = math.abs(((GetEntityHeading(ped) - heading + 180.0) % 360.0) - 180.0)
        if diff < 15.0 then break end
    end
    SetEntityHeading(ped, heading)
end

local function playKeyAnimation()
    local ped = cache.ped
    local dict = 'script_common@jail_cell@unlock@key'
    local model = joaat('P_KEY02X')
    lib.requestAnimDict(dict)
    lib.requestModel(model)

    local prop = CreateObject(model, GetEntityCoords(ped) + vec3(0, 0, 0.2), false, false, false)
    TaskPlayAnim(ped, dict, 'action', 8.0, -8.0, 2500, 31, 0, true, 0, false, 0, false)
    Wait(750)
    AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Finger12'), 0.02, 0.0120, -0.00850, 0.024, -160.0, 200.0, true, true, false, true, 1, true)

    while IsEntityPlayingAnim(ped, dict, 'action', 3) do Wait(100) end

    DeleteObject(prop)
    RemoveAnimDict(dict)
    SetModelAsNoLongerNeeded(model)
end

local function createDoorPrompt()
    lockPrompt = PromptRegisterBegin()
    PromptSetControlAction(lockPrompt, RSGCore.Shared.Keybinds['ENTER'])
    PromptSetText(lockPrompt, CreateVarString(10, 'LITERAL_STRING', locale('prompt_use_key')))
    PromptSetEnabled(lockPrompt, true)
    PromptSetVisible(lockPrompt, true)
    PromptSetHoldMode(lockPrompt, true)
    PromptSetGroup(lockPrompt, doorPromptGroup)
    PromptRegisterEnd(lockPrompt)
end

CreateThread(function()
    createDoorPrompt()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(cache.ped)
        local nearest, nearestDist

        for i = 1, #Config.HouseDoors do
            local door = Config.HouseDoors[i]
            local dist = #(coords - door.doorcoords)
            if dist < 2.0 and (not nearestDist or dist < nearestDist) then
                nearest, nearestDist = door, dist
            elseif dist < 15.0 and sleep > 250 then
                sleep = 250
            end
        end

        if nearest and not uiOpen and not adminOpen then
            sleep = 0
            local doorid = tostring(nearest.doorid)
            local status
            if not OwnedHouses[nearest.houseid] then
                status = locale('door_viewing_label')
            else
                status = DoorStates[doorid] == 0 and locale('door_unlocked') or locale('door_locked')
            end
            PromptSetActiveGroupThisFrame(doorPromptGroup, CreateVarString(10, 'LITERAL_STRING', houseName(nearest.houseid) .. ': ' .. status))

            if not doorBusy and PromptHasHoldModeCompleted(lockPrompt) then
                doorBusy = true
                local doorCoords = nearest.doorcoords
                CreateThread(function()
                    faceCoords(doorCoords)
                    if lib.callback.await('rsg-housing:server:toggleDoor', false, doorid) then
                        playKeyAnimation()
                    end
                    doorBusy = false
                end)
            end
        end

        Wait(sleep)
    end
end)

---------------------------------------
-- sync from server
---------------------------------------
local function loadState()
    local owned, doors, mine = lib.callback.await('rsg-housing:server:getState', false)
    OwnedHouses = owned or {}
    MyHouses = mine or {}
    DoorStates = doors or {}
    for doorid, state in pairs(DoorStates) do applyDoorState(doorid, state) end
    refreshHouseBlips()
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadState)

RegisterNetEvent('rsg-housing:client:SyncOwnedHouses', function(owned, mine)
    OwnedHouses = owned or {}
    MyHouses = mine or {}
    refreshHouseBlips()
end)

RegisterNetEvent('rsg-housing:client:SyncDoors', function(doors)
    DoorStates = doors or {}
    for doorid, state in pairs(DoorStates) do applyDoorState(doorid, state) end
end)

RegisterNetEvent('rsg-housing:client:SetDoorState', function(doorid, state)
    DoorStates[doorid] = state
    applyDoorState(doorid, state)
end)

CreateThread(function()
    -- resource restarted while already logged in
    if LocalPlayer.state.isLoggedIn then loadState() end
end)

---------------------------------------
-- house NUI
---------------------------------------
local UI_STRINGS = {
    'ui_vacant', 'ui_tenant', 'ui_guest', 'ui_per_month', 'ui_rent_terms', 'ui_rent_button',
    'ui_rent_status', 'ui_paid_until', 'ui_overdue_since', 'ui_days_left', 'ui_overdue_days', 'ui_pay_rent',
    'ui_paid_ahead', 'ui_manage', 'menu_guests_title', 'menu_guests_desc', 'menu_storage_title', 'menu_storage_desc',
    'menu_outfits_title', 'menu_outfits_desc', 'menu_mailbox_title', 'menu_mailbox_desc', 'end_tenancy_title',
    'end_tenancy_desc', 'ui_add', 'ui_remove', 'ui_no_guests', 'ui_confirm',
    'ui_cancel', 'confirm_rent_header', 'confirm_rent_content', 'confirm_end_header', 'confirm_end_content',
    'ui_confirm_pay', 'ui_confirm_pay_content', 'ui_rename_title', 'ui_rename_desc', 'ui_rename_content', 'ui_rename_placeholder', 'ui_save', 'ui_search_placeholder', 'ui_search_hint', 'ui_search_none', 'ui_current_guests',
    'perm_doors', 'perm_storage', 'perm_wardrobe', 'perm_mailbox', 'ui_guest_access', 'ui_no_permission',
    'ui_mailbox_unavailable', 'ui_mailbox_empty', 'ui_mailbox_from', 'ui_mailbox_send_hint', 'ui_delete', 'ui_back', 'ui_new',
    'ui_confirm_delete_mail', 'ui_confirm_delete_mail_content', 'ui_close', 'ui_house',
    'ui_storage_title', 'ui_storage_current', 'ui_storage_open', 'ui_storage_warning', 'ui_storage_upgrade', 'ui_storage_included',
    'ui_storage_owned', 'ui_storage_slots', 'ui_storage_weight', 'ui_confirm_upgrade', 'ui_confirm_upgrade_content',
    'storage_tier_small', 'storage_tier_medium', 'storage_tier_large', 'ui_home_title', 'ui_home_desc', 'ui_home_on', 'ui_home_off', 'ui_outfits_empty', 'ui_outfit_default', 'ui_wear', 'ui_outfit_worn', 'ui_outfits_hint', 'ui_confirm_remove', 'ui_confirm_remove_content'
}

local function getStrings()
    local strings = {}
    for _, key in ipairs(UI_STRINGS) do strings[key] = locale(key) end
    return strings
end

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    uiHouse = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function pushStatus(houseid, isUpdate)
    local status = lib.callback.await('rsg-housing:server:getHouseStatus', false, houseid)
    if not status then return closeUI() end

    if status.rented and not status.access then
        closeUI()
        return lib.notify({ title = houseName(houseid), description = locale('house_occupied'), type = 'error' })
    end

    SendNUIMessage({
        action = isUpdate and 'update' or 'open',
        house = { id = houseid, name = houseName(houseid), defaultName = defaultHouseName(houseid) },
        status = status,
        strings = not isUpdate and getStrings() or nil,
        tiers = not isUpdate and Config.StorageTiers or nil,
        searchMin = not isUpdate and Config.GuestSearchMin or nil
    })
    return true
end

local function openHouseUI(houseid)
    if uiOpen or uiOpening or adminOpen then return end
    uiOpening = true
    uiHouse = houseid
    if pushStatus(houseid, false) then
        uiOpen = true
        SetNuiFocus(true, true)
    else
        uiHouse = nil
    end
    uiOpening = false
end

-- run a server action, show the result as a toast and refresh the panel
local function runAction(name, ...)
    local result = lib.callback.await('rsg-housing:server:' .. name, false, ...)
    if result and result.msg then
        SendNUIMessage({ action = 'toast', type = result.type, message = result.msg })
    end
    if uiOpen and uiHouse then pushStatus(uiHouse, true) end
    return result and result.ok
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

---------------------------------------
-- wardrobe (saved outfits from rsg-character)
---------------------------------------
local function wearOutfit(clothes)
    if type(clothes) ~= 'table' or not next(clothes) then return end
    if GetResourceState(Config.WardrobeResource) == 'started' then
        -- rsg-wardrobe strips the current pieces first so nothing is left over
        TriggerEvent('rsg-wardrobe:client:dress', clothes)
    else
        TriggerEvent('rsg-character:client:ApplyClothes', clothes, cache.ped)
    end
end

RegisterNUICallback('outfits', function(data, cb)
    if not uiOpen or not uiHouse or type(data) ~= 'table' then return cb({ available = false }) end
    local result = lib.callback.await('rsg-housing:server:outfits', false, uiHouse, data.action, data.id)
    if result and result.wear then
        wearOutfit(result.wear)
        result.wear = nil
        result.worn = true
    end
    cb(result or { skipped = true })
end)

---------------------------------------
-- mailbox (rsg-telegram inbox)
---------------------------------------
RegisterNUICallback('mailbox', function(data, cb)
    if not uiOpen or not uiHouse or type(data) ~= 'table' then return cb({ available = false }) end
    local result = lib.callback.await('rsg-housing:server:mailbox', false, uiHouse, data.action, data.id)
    cb(result or { skipped = true })
end)

RegisterNUICallback('searchPlayers', function(data, cb)
    if not uiOpen or type(data) ~= 'table' or type(data.query) ~= 'string' then return cb({}) end
    local results = lib.callback.await('rsg-housing:server:searchPlayers', false, uiHouse, data.query)
    cb({ results = results or {}, query = data.query, skipped = results == nil })
end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    if not uiOpen or not uiHouse then return end
    local houseid = uiHouse
    local action = data and data.action

    if action == 'rent' then
        runAction('rentHouse', houseid)
    elseif action == 'payRent' then
        runAction('payRent', houseid)
    elseif action == 'addGuest' and type(data.citizenid) == 'string' then
        runAction('addGuest', houseid, string.upper(data.citizenid))
    elseif action == 'removeGuest' and type(data.citizenid) == 'string' then
        runAction('removeGuest', houseid, data.citizenid)
    elseif action == 'setGuestPerm' and type(data.citizenid) == 'string' and type(data.perm) == 'string' then
        runAction('setGuestPermission', houseid, data.citizenid, data.perm, data.allowed == true)
    elseif action == 'home' then
        runAction('setHome', houseid, data.on == true)
    elseif action == 'rename' and type(data.name) == 'string' then
        runAction('renameHouse', houseid, data.name)
    elseif action == 'endTenancy' then
        if runAction('endTenancy', houseid) then closeUI() end
    elseif action == 'storage' then
        closeUI()
        TriggerServerEvent('rsg-housing:server:openStorage', houseid)
    elseif action == 'upgradeStorage' then
        runAction('upgradeStorage', houseid, tonumber(data.level))
    end
end)

-- close if the player walks away or dies
CreateThread(function()
    while true do
        if uiOpen and uiHouse then
            local house = HousesById[uiHouse]
            if IsEntityDead(cache.ped) or #(GetEntityCoords(cache.ped) - house.menucoords) > Config.InteractDistance then
                closeUI()
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

---------------------------------------
-- admin panel (/houseadmin)
---------------------------------------
local ADMIN_STRINGS = {
    'adm_title', 'adm_subtitle', 'adm_search', 'adm_rented', 'adm_vacant', 'adm_overdue', 'adm_total',
    'adm_rent', 'adm_tenant', 'adm_due', 'adm_storage', 'adm_none',
    'adm_home', 'adm_away', 'adm_locked', 'adm_unlocked', 'adm_save', 'adm_details', 'adm_rent_section',
    'adm_tenancy_section', 'adm_property_section', 'adm_due_minus', 'adm_due_plus', 'adm_set_date',
    'adm_reset_name', 'adm_lock', 'adm_unlock', 'adm_teleport', 'adm_open_storage', 'adm_evict', 'adm_evict_keep',
    'adm_evict_purge', 'adm_confirm_evict', 'adm_confirm_evict_content', 'adm_no_results', 'adm_custom_name',
    'adm_not_in_config', 'adm_guest_list', 'adm_no_guests', 'ui_remove', 'ui_confirm', 'ui_cancel',
    'storage_tier_small', 'storage_tier_medium', 'storage_tier_large', 'adm_doors', 'adm_days_left',
    'adm_overdue_by', 'adm_refresh', 'ui_back', 'ui_close', 'ui_storage_slots', 'ui_storage_weight'
}

local function closeAdmin()
    if not adminOpen then return end
    adminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminClose' })
end

RegisterNetEvent('rsg-housing:client:openAdmin', function()
    if adminOpen or uiOpen then return end
    local result = lib.callback.await('rsg-housing:server:admin', false, 'list')
    if not result or not result.ok then return end

    local strings = {}
    for _, key in ipairs(ADMIN_STRINGS) do strings[key] = locale(key) end

    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'adminOpen',
        houses = result.houses,
        strings = strings,
        tiers = Config.StorageTiers,
        maxRent = Config.MaxRent
    })
end)

RegisterNUICallback('adminClose', function(_, cb)
    closeAdmin()
    cb('ok')
end)

RegisterNUICallback('admin', function(data, cb)
    if not adminOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local result = lib.callback.await('rsg-housing:server:admin', false, data.action, data.houseid, data.data) or { ok = false }

    if result.denied then
        closeAdmin()
        return cb({ ok = false })
    end

    if result.teleport then
        closeAdmin()
        local c = result.teleport
        CreateThread(function()
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do Wait(10) end
            SetEntityCoords(cache.ped, c.x, c.y, c.z, false, false, false, false)
            Wait(500)
            DoScreenFadeIn(500)
        end)
    elseif result.closed then
        closeAdmin()
    end

    cb(result)
end)

---------------------------------------
-- house menu prompt [J] (hidden while the panel is open)
---------------------------------------
CreateThread(function()
    houseMenuPrompt = PromptRegisterBegin()
    PromptSetControlAction(houseMenuPrompt, RSGCore.Shared.Keybinds['J'])
    PromptSetText(houseMenuPrompt, CreateVarString(10, 'LITERAL_STRING', locale('prompt_house_menu')))
    PromptSetEnabled(houseMenuPrompt, true)
    PromptSetVisible(houseMenuPrompt, true)
    PromptSetStandardMode(houseMenuPrompt, true)
    PromptSetGroup(houseMenuPrompt, houseMenuGroup)
    PromptRegisterEnd(houseMenuPrompt)

    while true do
        local sleep = 1000
        if not uiOpen and not adminOpen then
            local coords = GetEntityCoords(cache.ped)
            local nearest, nearestDist
            for i = 1, #Config.Houses do
                local house = Config.Houses[i]
                local dist = #(coords - house.menucoords)
                if dist < Config.MenuPromptDistance and (not nearestDist or dist < nearestDist) then
                    nearest, nearestDist = house, dist
                elseif dist < 25.0 and sleep > 250 then
                    sleep = 250
                end
            end

            if nearest then
                sleep = 0
                PromptSetActiveGroupThisFrame(houseMenuGroup, CreateVarString(10, 'LITERAL_STRING', houseName(nearest.houseid)))
                if PromptHasStandardModeCompleted(houseMenuPrompt) then
                    openHouseUI(nearest.houseid)
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------
-- cleanup
---------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #HouseBlips do RemoveBlip(HouseBlips[i]) end
    if lockPrompt then PromptDelete(lockPrompt) end
    if houseMenuPrompt then PromptDelete(houseMenuPrompt) end
    if uiOpen or adminOpen then SetNuiFocus(false, false) end
end)
