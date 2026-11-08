local RSGCore = exports['rsg-core']:GetCoreObject()

local Boards, Spawned, Blips = {}, {}, {}
local nuiOpen = false
local uiLocale -- ui_* strings sent to the NUI once

-- locale(key) only returns single strings, so read the json directly to hand the NUI its strings
local function getUiLocale()
    if uiLocale then return uiLocale end
    local res = GetCurrentResourceName()
    local function load(lang)
        local raw = LoadResourceFile(res, ('locales/%s.json'):format(lang))
        return raw and json.decode(raw) or {}
    end
    local strings = load('en')
    local lang = GetConvar('rsg:locale', GetConvar('ox:locale', 'en'))
    if lang ~= 'en' then for k, v in pairs(load(lang)) do strings[k] = v end end
    uiLocale = {}
    for k, v in pairs(strings) do if k:sub(1, 3) == 'ui_' then uiLocale[k] = v end end
    return uiLocale
end

---------------------------------
-- placed boards
---------------------------------
local function clearBoards()
    for id, obj in pairs(Spawned) do if DoesEntityExist(obj) then DeleteEntity(obj) end Spawned[id] = nil end
    for id, blip in pairs(Blips) do RemoveBlip(blip) Blips[id] = nil end
end

local function setBoards(list)
    clearBoards()
    Boards = list or {}
    for _, b in ipairs(Boards) do b.coords = vector3(b.x, b.y, b.z) end
    if Config.ShowBlips then
        for _, b in ipairs(Boards) do
            local blip = BlipAddForCoords(1664425300, b.x, b.y, b.z)
            SetBlipSprite(blip, Config.BlipSprite, true)
            SetBlipScale(blip, Config.BlipScale)
            SetBlipName(blip, b.label)
            Blips[b.id] = blip
        end
    end
end

RegisterNetEvent('rsg-noticeboard:client:syncBoards', setBoards)

CreateThread(function()
    setBoards(RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getBoards', 10000))
    local model = joaat(Config.PlacedBoardModel)
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, b in ipairs(Boards) do
            local dist = #(pos - b.coords)
            if dist < Config.SpawnDistance and not Spawned[b.id] then
                RSGCore.Functions.RequestModel(model)
                local obj = CreateObject(model, b.x, b.y, b.z, false, false, false)
                SetEntityHeading(obj, b.heading + 0.0)
                FreezeEntityPosition(obj, true)
                SetEntityInvincible(obj, true)
                Spawned[b.id] = obj
            elseif dist >= Config.SpawnDistance and Spawned[b.id] then
                DeleteEntity(Spawned[b.id]); Spawned[b.id] = nil
            end
        end
        SetModelAsNoLongerNeeded(model)
        Wait(2000)
    end
end)

---------------------------------
-- NUI
---------------------------------
local function openNui(action, data)
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = action, data = data, locale = getUiLocale() })
end

local function openBoard()
    local data = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getBoardData', 10000)
    if not data then return end
    openNui('openBoard', data)
end

local function openAdmin()
    local data = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getAdminData', 10000)
    if not data then RSGCore.Functions.Notify({ title = locale('title'), description = locale('sv_no_permission'), type = 'error' }) return end
    openNui('openAdmin', data)
end

RegisterNetEvent('rsg-noticeboard:client:openAdmin', openAdmin)

RegisterNUICallback('close', function(_, cb)
    nuiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getBoardData', 10000) or {})
end)
RegisterNUICallback('refreshAdmin', function(_, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getAdminData', 10000) or {})
end)
RegisterNUICallback('createNotice', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:createNotice', 10000, data) })
end)
RegisterNUICallback('renewNotice', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:renewNotice', 10000, data.id, data.duration) })
end)
RegisterNUICallback('deleteOwnNotice', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:deleteOwnNotice', 10000, data.id) })
end)
RegisterNUICallback('adminDeleteNotice', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:adminDeleteNotice', 10000, data.id) })
end)
RegisterNUICallback('adminExtendNotice', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:adminExtendNotice', 10000, data.id, data.duration) })
end)
RegisterNUICallback('adminDeleteBoard', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:deleteBoard', 10000, data.id) })
end)
RegisterNUICallback('adminRenameBoard', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:renameBoard', 10000, data.id, data.label) })
end)
RegisterNUICallback('adminTeleport', function(data, cb)
    cb('ok')
    local b
    for _, v in ipairs(Boards) do if v.id == data.id then b = v break end end
    if not b then return end
    nuiOpen = false; SetNuiFocus(false, false)
    DoScreenFadeOut(400); Wait(450)
    -- stand 2m in front of the board
    local h = math.rad(b.heading)
    SetEntityCoords(PlayerPedId(), b.x - math.sin(h) * 2.0, b.y + math.cos(h) * 2.0, b.z, false, false, false, false)
    Wait(500); DoScreenFadeIn(400)
end)
RegisterNUICallback('adminPlaceBoard', function(data, cb)
    cb('ok')
    nuiOpen = false; SetNuiFocus(false, false)
    Placer.Start(Config.PlacedBoardModel, function(pos)
        if not pos then
            RSGCore.Functions.Notify({ title = locale('title'), description = locale('cl_place_cancel'), type = 'inform' })
        else
            pos.label = data.label
            RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:saveBoard', 10000, pos)
        end
        openAdmin()
    end)
end)

---------------------------------
-- target
---------------------------------
CreateThread(function()
    exports['rsg-target']:addModel(Config.BoardModels, {
        {
            name = 'rsg_noticeboard_read',
            icon = 'fa-solid fa-scroll',
            label = locale('cl_target_read'),
            distance = Config.TargetDistance,
            onSelect = openBoard,
        },
    })
end)

---------------------------------
-- expiry warning + quick renew
---------------------------------
local function formatTime(sec)
    sec = math.max(0, sec)
    local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
    if h > 0 then return ('%dh %dm'):format(h, m) end
    return ('%dm'):format(m)
end

RegisterNetEvent('rsg-noticeboard:client:expiryWarning', function(n)
    RSGCore.Functions.Notify({ title = locale('cl_expiry_title'), description = locale('sv_warn'):format(n.title), type = 'warning', duration = 10000 })
    if nuiOpen then return end
    -- renew prompt runs in our own NUI (replaces ox_lib alertDialog + context menu)
    openNui('expiryRenew', {
        id = n.id,
        title = locale('cl_expiry_title'),
        text = locale('cl_expiry_text'):format(n.title, formatTime(n.expires_at - n.now)),
        chooseTitle = locale('cl_renew_choose'),
        durations = Config.Localize('dur_', Config.Durations),
    })
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBoards()
    Placer.Stop()
    exports['rsg-target']:removeModel(Config.BoardModels, 'rsg_noticeboard_read')
    if nuiOpen then SetNuiFocus(false, false) end
end)
