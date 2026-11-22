local RSGCore = exports['rsg-core']:GetCoreObject()

local Boards, Spawned, Blips = {}, {}, {}
local nuiOpen, opening, placing = false, false, false
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

local function notify(text, ntype, title, duration)
    RSGCore.Functions.Notify({ title = title or locale('title'), description = text, type = ntype or 'inform', duration = duration or 5000 })
end

---------------------------------
-- NUI focus (keeps push-to-talk working while the UI is open)
---------------------------------
local function applyNuiFocus(enable)
    nuiOpen = enable
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- KeepInput passes every key to the game, so block all controls except push-to-talk while focused
CreateThread(function()
    while true do
        if nuiOpen and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, c in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, c, true)
                EnableControlAction(1, c, true)
                EnableControlAction(2, c, true)
            end
        else
            Wait(250)
        end
    end
end)

---------------------------------
-- placed boards
---------------------------------
local function removeBoard(id)
    local obj = Spawned[id]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    Spawned[id] = nil
    if Blips[id] then RemoveBlip(Blips[id]) Blips[id] = nil end
end

-- only touches what changed, so boards do not blink out for everyone when an admin edits one
local function setBoards(list)
    Boards = list or {}
    local keep = {}
    for _, b in ipairs(Boards) do
        b.coords = vector3(b.x, b.y, b.z)
        keep[b.id] = true
        if Config.ShowBlips then
            if Blips[b.id] then
                SetBlipName(Blips[b.id], b.label)
            else
                local blip = BlipAddForCoords(1664425300, b.x, b.y, b.z)
                SetBlipSprite(blip, Config.BlipSprite, true)
                SetBlipScale(blip, Config.BlipScale)
                SetBlipName(blip, b.label)
                Blips[b.id] = blip
            end
        end
    end
    for id in pairs(Spawned) do if not keep[id] then removeBoard(id) end end
    for id in pairs(Blips) do if not keep[id] then removeBoard(id) end end
end

RegisterNetEvent('rsg-noticeboard:client:syncBoards', setBoards)

CreateThread(function()
    setBoards(RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getBoards', 10000))
    local model = joaat(Config.PlacedBoardModel)
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local loaded = false
        for _, b in ipairs(Boards) do
            local dist = #(pos - b.coords)
            if dist < Config.SpawnDistance and not Spawned[b.id] then
                RSGCore.Functions.RequestModel(model)
                loaded = true
                local obj = CreateObject(model, b.x, b.y, b.z, false, false, false)
                if obj ~= 0 then
                    SetEntityHeading(obj, b.heading + 0.0)
                    FreezeEntityPosition(obj, true)
                    SetEntityInvincible(obj, true)
                    Spawned[b.id] = obj
                end
            elseif dist >= Config.SpawnDistance and Spawned[b.id] then
                DeleteEntity(Spawned[b.id]); Spawned[b.id] = nil
            end
        end
        if loaded then SetModelAsNoLongerNeeded(model) end
        Wait(2000)
    end
end)

---------------------------------
-- NUI
---------------------------------
local function openNui(action, data)
    applyNuiFocus(true)
    SendNUIMessage({ action = action, data = data, locale = getUiLocale() })
end

local function openBoard()
    if opening or nuiOpen then return end
    opening = true
    local data = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getBoardData', 10000)
    opening = false
    if not data then return end
    openNui('openBoard', data)
end

local function openAdmin()
    local data = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getAdminData', 10000)
    if not data then notify(locale('sv_no_permission'), 'error') return end
    openNui('openAdmin', data)
end

RegisterNetEvent('rsg-noticeboard:client:openAdmin', openAdmin)

RegisterNUICallback('close', function(_, cb)
    applyNuiFocus(false)
    cb('ok')
end)

-- thin bridges: every one of these is re-validated on the server
-- action callbacks answer { ok = result }; data callbacks hand the server's table straight to the NUI
local function bridge(nuiName, callbackName, ...)
    local fields = { ... }
    RegisterNUICallback(nuiName, function(data, cb)
        local args = {}
        for i, f in ipairs(fields) do args[i] = data[f] end
        cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:' .. callbackName, 10000, table.unpack(args, 1, #fields)) })
    end)
end

local function dataBridge(nuiName, callbackName, ...)
    local fields = { ... }
    RegisterNUICallback(nuiName, function(data, cb)
        local args = {}
        for i, f in ipairs(fields) do args[i] = data[f] end
        cb(RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:' .. callbackName, 10000, table.unpack(args, 1, #fields)) or {})
    end)
end

-- browsing
RegisterNUICallback('getNotices', function(data, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:getNotices', 10000, data) or {})
end)
dataBridge('getNotice', 'getNotice', 'id')
dataBridge('getMyNotices', 'getMyNotices')
dataBridge('refreshAdmin', 'getAdminData')

-- posting and own notices
RegisterNUICallback('createNotice', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:createNotice', 10000, data) })
end)
RegisterNUICallback('editNotice', function(data, cb)
    cb({ ok = RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:editNotice', 10000, data.id, data) })
end)
bridge('renewNotice', 'renewNotice', 'id', 'duration')
bridge('deleteOwnNotice', 'deleteOwnNotice', 'id')
bridge('featureNotice', 'featureNotice', 'id')
bridge('setPin', 'setPin', 'id', 'enable')
bridge('toggleReminder', 'toggleReminder', 'id')
bridge('reportNotice', 'reportNotice', 'id', 'reason')

-- admin
bridge('adminDeleteNotice', 'adminDeleteNotice', 'id')
bridge('adminExtendNotice', 'adminExtendNotice', 'id', 'duration')
bridge('adminDeleteBoard', 'deleteBoard', 'id')
bridge('adminRenameBoard', 'renameBoard', 'id', 'label')
bridge('adminDismissReports', 'adminDismissReports', 'id')
bridge('adminRemoveReported', 'adminRemoveReported', 'id', 'ban')
bridge('adminBanPoster', 'adminBanPoster', 'id')
bridge('adminUnban', 'adminUnban', 'citizenid')

-- "Show on map": sets the game waypoint to a notice's pin
RegisterNUICallback('setWaypoint', function(data, cb)
    cb('ok')
    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y then return end
    SetNewWaypoint(x + 0.0, y + 0.0)
    notify(locale('cl_waypoint'), 'success')
end)

RegisterNUICallback('adminTeleport', function(data, cb)
    cb('ok')
    local b
    for _, v in ipairs(Boards) do if v.id == data.id then b = v break end end
    if not b then return end
    applyNuiFocus(false)
    DoScreenFadeOut(400); Wait(450)
    -- stand 2m in front of the board
    local h = math.rad(b.heading)
    SetEntityCoords(PlayerPedId(), b.x - math.sin(h) * 2.0, b.y + math.cos(h) * 2.0, b.z, false, false, false, false)
    Wait(500); DoScreenFadeIn(400)
end)

RegisterNUICallback('adminPlaceBoard', function(data, cb)
    cb('ok')
    if placing then return end
    applyNuiFocus(false)
    placing = true
    -- rsg-gizmo's Place blocks until the admin confirms or cancels
    CreateThread(function()
        local res = exports['rsg-gizmo']:Place(Config.PlacedBoardModel, { rotation = 'z', maxDistance = Config.PlaceMaxDistance })
        placing = false
        if res then
            RSGCore.Functions.AwaitCallback('rsg-noticeboard:server:saveBoard', 10000,
                { x = res.coords.x, y = res.coords.y, z = res.coords.z, heading = res.heading, label = data.label })
        else
            notify(locale('cl_place_cancel'))
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
    notify(locale('sv_warn'):format(n.title), 'warning', locale('cl_expiry_title'), 10000)
    -- never grab the mouse from another menu, a dead player or a placement in progress
    if not Config.ExpiryPopup or nuiOpen or placing or IsPedDeadOrDying(PlayerPedId(), true) then return end
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
    for id in pairs(Spawned) do removeBoard(id) end
    for id in pairs(Blips) do removeBoard(id) end
    if placing then exports['rsg-gizmo']:Cancel() end
    exports['rsg-target']:removeModel(Config.BoardModels, 'rsg_noticeboard_read')
    if nuiOpen then applyNuiFocus(false) end
end)
