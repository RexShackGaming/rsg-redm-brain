local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false        -- the menu (or an invite) has NUI focus
local menuOpen = false      -- the full menu is on screen
local locations = {}
local promptIds = {}
local blips = {}
local uiStrings

-----------------------------------------------------------------------
-- NUI focus with push-to-talk kept alive
-----------------------------------------------------------------------
local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            EnableControlAction(0, list[i], true)
            EnableControlAction(1, list[i], true)
            EnableControlAction(2, list[i], true)
        end
    end
end

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
            CreateThread(function()
                while uiOpen do
                    runPttWhitelist()
                    Wait(0)
                end
            end)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------
local function notify(msg, nType)
    RSGCore.Functions.Notify({ title = locale('cl_title'), description = msg, type = nType or 'inform', duration = 5000 })
end

--- every 'ui_' string of the player's language (falls back to English), for the NUI
local function loadUiStrings()
    if uiStrings then return uiStrings end
    local lang = GetConvar('rsg:locale', GetConvar('ox:locale', 'en'))
    local function read(code)
        local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(code))
        local ok, data = pcall(json.decode, raw or '')
        return ok and type(data) == 'table' and data or nil
    end
    local en, picked = read('en') or {}, read(lang) or {}
    uiStrings = {}
    for key, value in pairs(en) do
        if key:sub(1, 3) == 'ui_' then uiStrings[key] = picked[key] or value end
    end
    return uiStrings
end

local function closeUI()
    if not uiOpen then return end
    uiOpen, menuOpen = false, false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function showUI(payload)
    payload.action = 'open'
    payload.strings = loadUiStrings()
    uiOpen = true
    applyNuiFocus(true)
    SendNUIMessage(payload)
end

-----------------------------------------------------------------------
-- Opening the menu
-----------------------------------------------------------------------
local function openMenu(ref)
    if uiOpen or IsPauseMenuActive() then return end
    CreateThread(function()
        local res = RSGCore.Functions.AwaitCallback('rsg-society:server:open', 10000, ref)
        if not res then return notify(locale('cl_no_answer'), 'error') end
        if not res.ok then return notify(res.msg or locale('cl_no_answer'), 'error') end
        menuOpen = true
        showUI({ mode = 'menu', view = res.view, create = res.create })
    end)
end

local function activeJob()
    local data = RSGCore.Functions.GetPlayerData()
    return data and data.job and data.job.name
end

local function nearestDesk()
    local pos = GetEntityCoords(PlayerPedId())
    local job = activeJob()
    local best, bestDist
    for _, loc in pairs(locations) do
        local d = #(pos - vector3(loc.x, loc.y, loc.z))
        if d <= Config.InteractDistance and (not bestDist or d < bestDist) and (loc.society == job or not job) then
            best, bestDist = loc, d
        end
    end
    return best
end

local function openNearest()
    local desk = nearestDesk()
    if desk then return openMenu({ society = desk.society }) end
    openMenu({ gang = true })
end

RegisterCommand(Config.Command, openNearest, false)
RegisterCommand(Config.GangCommand, function() openMenu({ gang = true }) end, false)

RegisterNetEvent('rsg-society:client:openDesk', function(society)
    openMenu({ society = society })
end)

-- Names the old resources used (rsg-medic and others still call the boss menu event)
RegisterNetEvent('rsg-bossmenu:client:mainmenu', function()
    local job = activeJob()
    if job then openMenu({ society = job }) end
end)
RegisterNetEvent('rsg-gangmenu:client:mainmenu', function()
    openMenu({ gang = true })
end)

if Config.UseKeyMapping then
    pcall(function()
        RSGCore.Functions.RegisterKey('rsgsociety_open', locale('key_open'), Config.GangKey or '', function()
            openNearest()
        end)
    end)
end

-----------------------------------------------------------------------
-- Desks: prompts and blips
-----------------------------------------------------------------------
local function clearDesks()
    for _, id in ipairs(promptIds) do
        pcall(function() exports['rsg-core']:deletePrompt(id) end)
    end
    promptIds = {}
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end

local function refreshDesks()
    clearDesks()
    local job = activeJob()
    if not job then return end
    local key = RSGCore.Shared.Keybinds[Config.Keybind]
    for _, loc in pairs(locations) do
        if loc.society == job then
            local id = 'rsg_society_' .. loc.id
            local coords = vector3(loc.x, loc.y, loc.z)
            exports['rsg-core']:createPrompt(id, coords, key, ('%s %s'):format(locale('cl_open'), loc.name), {
                type = 'client', event = 'rsg-society:client:openDesk', args = { loc.society },
            })
            promptIds[#promptIds + 1] = id
            if loc.showblip then
                local blip = BlipAddForCoords(1664425300, coords)
                SetBlipSprite(blip, joaat(Config.Blip.sprite), true)
                SetBlipScale(blip, Config.Blip.scale)
                SetBlipName(blip, Config.Blip.name)
                blips[#blips + 1] = blip
            end
        end
    end
end

RegisterNetEvent('rsg-society:client:locations', function(list)
    locations = {}
    for _, loc in ipairs(list or {}) do locations[loc.id] = loc end
    refreshDesks()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('rsg-society:server:requestLocations')
end)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function() refreshDesks() end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetTimeout(1500, function() TriggerServerEvent('rsg-society:server:requestLocations') end)
end)

-----------------------------------------------------------------------
-- Invites
-----------------------------------------------------------------------
RegisterNetEvent('rsg-society:client:invite', function(data)
    if uiOpen and not menuOpen then return end
    if not uiOpen then
        showUI({ mode = 'invite', invite = data })
    else
        SendNUIMessage({ action = 'invite', invite = data, strings = loadUiStrings() })
    end
end)

-----------------------------------------------------------------------
-- NUI callbacks
-----------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({})
end)

RegisterNUICallback('tab', function(data, cb)
    local res = RSGCore.Functions.AwaitCallback('rsg-society:server:tab', 10000, data.society, data.tab, data.arg)
    cb(res or { ok = false, msg = locale('cl_no_answer') })
end)

RegisterNUICallback('act', function(data, cb)
    local res = RSGCore.Functions.AwaitCallback('rsg-society:server:act', 10000, data.society, data.action, data.data)
    res = res or { ok = false, msg = locale('cl_no_answer') }
    cb(res)
    if res.closed then closeUI() end
end)

RegisterNUICallback('createGang', function(data, cb)
    local res = RSGCore.Functions.AwaitCallback('rsg-society:server:createGang', 10000, data.label)
    cb(res or { ok = false, msg = locale('cl_no_answer') })
end)

RegisterNUICallback('reopen', function(_, cb)
    cb({})
    closeUI()
    SetTimeout(200, function() openMenu({ gang = true }) end)
end)

RegisterNUICallback('inviteReply', function(data, cb)
    TriggerServerEvent('rsg-society:server:inviteReply', data.accepted == true)
    cb({})
    if not menuOpen then closeUI() end
end)

-----------------------------------------------------------------------
-- Cleanup
-----------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if uiOpen then
        uiOpen = false
        applyNuiFocus(false)
    end
    clearDesks()
end)
