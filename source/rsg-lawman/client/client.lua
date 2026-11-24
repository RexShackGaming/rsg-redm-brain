local RSGCore = exports['rsg-core']:GetCoreObject()

local isHandcuffed = false
local cuffHard = false
local isEscorted = false
local draggerId = nil
local badge = false
local lastAlertTime = 0

local officeBlips = {}
local alerts = {} -- [id] = { coords, blips = {}, expires = ms }
local alertSeq = 0
local alertWatcher = false

local function notify(title, description, ntype, duration)
    RSGCore.Functions.Notify({ title = title, description = description, type = ntype or 'inform', duration = duration or 5000 })
end

------------------------------------------
-- NUI (menus / input) with push-to-talk support
------------------------------------------
local uiFocus = false
local menuActions = {}
local inputPromise = nil

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function closeUI()
    uiFocus = false
    applyNuiFocus(false)
end

local function openUI(data)
    data.confirm = data.confirm or locale('cl_confirm')
    data.cancel = data.cancel or locale('cl_cancel')
    SendNUIMessage(data)
    uiFocus = true
    applyNuiFocus(true)
end

local function inputDialog(title, label)
    if inputPromise then return nil end
    inputPromise = promise.new()
    openUI({ action = 'openInput', title = title, label = label, max = Config.MaxJailTime })
    local value = Citizen.Await(inputPromise)
    inputPromise = nil
    return value
end

RegisterNUICallback('menuSelect', function(data, cb)
    closeUI()
    cb('ok')
    local fn = menuActions[data and data.id]
    menuActions = {}
    if fn then fn() end
end)

RegisterNUICallback('inputSubmit', function(data, cb)
    closeUI()
    cb('ok')
    local v = tonumber(data and data.value)
    if v then v = math.floor(v) end
    if v and v <= 0 then v = nil end
    if inputPromise then inputPromise:resolve(v) end
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    menuActions = {}
    cb('ok')
end)

-- while the NUI has focus: block game controls but keep push-to-talk
CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, ctrl in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, ctrl, true)
                EnableControlAction(1, ctrl, true)
                EnableControlAction(2, ctrl, true)
            end
        else
            Wait(250)
        end
    end
end)

------------------------------------
-- prompts and blips
------------------------------------
CreateThread(function()
    for _, v in pairs(Config.LawOfficeLocations) do
        exports['rsg-core']:createPrompt(v.prompt, v.coords, RSGCore.Shared.Keybinds[Config.Keybind], locale('cl_open'),
            {
                type = 'client',
                event = 'rsg-lawman:client:mainmenu',
                args = { v.jobaccess, v.prompt },
            })
        if v.showblip == true then
            local blip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(blip, joaat(v.blipsprite), true)
            SetBlipScale(blip, v.blipscale)
            SetBlipName(blip, v.name)
            officeBlips[#officeBlips + 1] = blip
        end
    end
end)

------------------------------------------
-- main job menu
------------------------------------------
RegisterNetEvent('rsg-lawman:client:mainmenu', function(jobaccess, name)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData.job.name ~= jobaccess then
        notify(locale('cl_no_job'), nil, 'error')
        return
    end

    local canArmoury = PlayerData.job.type == 'leo' and PlayerData.job.grade.level >= Config.ArmouryAccessGrade
    menuActions = {
        duty = function() TriggerEvent('rsg-lawman:client:ToggleDuty') end,
        armoury = function() TriggerEvent('rsg-lawman:client:openarmoury', name) end,
        storage = function() TriggerEvent('rsg-lawman:client:openstorage') end,
    }
    openUI({
        action = 'openMenu',
        title = locale('cl_menu'),
        subtitle = PlayerData.job.label or '',
        options = {
            { id = 'duty', title = locale('cl_duty'), description = PlayerData.job.onduty and locale('cl_on_duty') or locale('cl_off_duty'), icon = 'fa-solid fa-shield-heart' },
            { id = 'armoury', title = locale('cl_armo'), description = canArmoury and locale('cl_armo_a') or locale('cl_no_rank'), icon = 'fa-solid fa-person-rifle', disabled = not canArmoury },
            { id = 'storage', title = locale('cl_storage'), description = locale('cl_storage_a'), icon = 'fa-solid fa-box-archive' },
        }
    })
end)

------------------------------------------
-- law office armoury
------------------------------------------
-- NOTE: the shop resource that owns 'rsg-shops:server:openstore' must verify job / grade itself;
-- a client can trigger that event directly.
RegisterNetEvent('rsg-lawman:client:openarmoury', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData.job.type == 'leo' and PlayerData.job.grade.level >= Config.ArmouryAccessGrade then
        TriggerServerEvent('rsg-shops:server:openstore', 'armoury', 'armoury', locale('cl_shop'))
    else
        notify(locale('cl_no_rank'), nil, 'error', 7000)
    end
end)

------------------------------------------
-- toggle on-duty
------------------------------------------
AddEventHandler('rsg-lawman:client:ToggleDuty', function()
    if RSGCore.Functions.GetPlayerData().job.type == 'leo' then
        TriggerServerEvent('RSGCore:ToggleDuty')
    end
end)

------------------------------------------
-- law storage
------------------------------------------
RegisterNetEvent('rsg-lawman:client:openstorage', function()
    if RSGCore.Functions.GetPlayerData().job.type == 'leo' then
        TriggerServerEvent('rsg-lawman:server:storage')
    end
end)

------------------------------------------
-- send player to jail
------------------------------------------
local JAIL_CLIENT_DISTANCE = 1.5

RegisterNetEvent('rsg-lawman:client:jailplayer', function(playerId, time)
    if playerId and time then
        TriggerServerEvent('rsg-lawman:server:jailplayer', playerId, tonumber(time))
        return
    end

    -- jail the closest player
    if IsPedRagdoll(PlayerPedId()) then return end
    local player, distance = RSGCore.Functions.GetClosestPlayer()
    if player == -1 or distance >= JAIL_CLIENT_DISTANCE then
        notify(locale('cl_nearby'), nil, 'error')
        return
    end

    local targetId = GetPlayerServerId(player)
    local minutes = inputDialog(locale('jail_player_header', targetId), locale('jail_player_time_label'))
    if not minutes then return end

    -- the dialog can stay open for a while, so check the target is still the one next to us
    local again, dist = RSGCore.Functions.GetClosestPlayer()
    if again == -1 or dist >= JAIL_CLIENT_DISTANCE or GetPlayerServerId(again) ~= targetId then
        notify(locale('cl_nearby'), nil, 'error')
        return
    end
    TriggerServerEvent('rsg-lawman:server:jailplayer', targetId, minutes)
end)

-- also used by rsg-bountyhunter and rsg-mdt
RegisterNetEvent('rsg-lawman:client:sendtojail', function(time)
    TriggerServerEvent('rsg-lawman:server:sethandcuffstatus', false)
    TriggerServerEvent('rsg-lawman:server:setescortstatus', false)
    isHandcuffed = false
    isEscorted = false
    draggerId = nil
    DetachEntity(PlayerPedId(), true, false)
    ClearPedTasks(PlayerPedId())
    SetEnableHandcuffs(PlayerPedId(), false)
    DisplayRadar(true)
    TriggerEvent('rsg-prison:client:Enter', time)
end)

------------------------------------------
-- lawman alert blips
------------------------------------------
local function refreshRoute()
    if not Config.AddGPSRoute then return end
    ClearGpsMultiRoute()
    local newest
    for id in pairs(alerts) do
        if not newest or id > newest then newest = id end
    end
    if newest then
        local c = alerts[newest].coords
        StartGpsMultiRoute(`COLOR_GREEN`, true, true)
        AddPointToGpsMultiRoute(c.x, c.y, c.z)
        SetGpsMultiRouteRender(true)
    end
end

local function removeAlert(id)
    local a = alerts[id]
    if not a then return end
    for _, blip in ipairs(a.blips) do RemoveBlip(blip) end
    alerts[id] = nil
    refreshRoute()
end

-- one watcher for every alert: removes them when they expire or a lawman gets there
local function startAlertWatcher()
    if alertWatcher then return end
    alertWatcher = true
    CreateThread(function()
        while next(alerts) do
            Wait(1000)
            local now = GetGameTimer()
            local pcoords = GetEntityCoords(PlayerPedId())
            for id, a in pairs(alerts) do
                if now >= a.expires or #(a.coords - pcoords) < 5.0 then
                    removeAlert(id)
                end
            end
        end
        alertWatcher = false
    end)
end

-- also called from other resources (rsg-farming, rsg-lockpick)
RegisterNetEvent('rsg-lawman:client:lawmanAlert', function(coords, text, alertType)
    if RSGCore.Functions.GetPlayerData().job.type ~= 'leo' then return end
    if not coords or not coords.x then return end
    coords = vector3(coords.x, coords.y, coords.z)
    text = tostring(text or '')
    local T = Config.AlertTypes[alertType] or Config.AlertTypes.default

    local blip = BlipAddForCoords(joaat('BLIP_STYLE_CREATOR_DEFAULT'), coords.x, coords.y, coords.z)
    local blip2 = BlipAddForCoords(joaat('BLIP_STYLE_COP_PERSISTENT'), coords.x, coords.y, coords.z)
    local blipText = locale('cl_alert') .. ' - ' .. text
    SetBlipSprite(blip, joaat(T.sprite or 'blip_ambient_law'))
    SetBlipSprite(blip2, joaat('blip_overlay_ring'))
    BlipAddModifier(blip, joaat('BLIP_MODIFIER_AREA_PULSE'))
    BlipAddModifier(blip2, joaat('BLIP_MODIFIER_AREA_PULSE'))
    SetBlipScale(blip, T.scale or 0.8)
    SetBlipScale(blip2, T.ringScale or 2.0)
    SetBlipName(blip, blipText)
    SetBlipName(blip2, blipText)

    alertSeq = alertSeq + 1
    alerts[alertSeq] = { coords = coords, blips = { blip, blip2 }, expires = GetGameTimer() + (T.timer or Config.AlertTimer) * 1000 }
    refreshRoute()
    notify(text, nil, T.notify or 'inform', 7000)
    startAlertWatcher()
end)

------------------------------------------
-- handcuffs
------------------------------------------
local function setCuffed(hard)
    isHandcuffed = true
    cuffHard = hard == true or Config.CuffFreezePlayer
    TriggerServerEvent('rsg-lawman:server:sethandcuffstatus', true)
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    if GetPedCurrentHeldWeapon(ped) ~= joaat('WEAPON_UNARMED') then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    end
    notify(locale('cl_cuffed'), not cuffHard and locale('cl_cuffed_a') or nil)
end

local function setUncuffed()
    isHandcuffed = false
    cuffHard = false
    isEscorted = false
    draggerId = nil
    TriggerServerEvent('rsg-lawman:server:sethandcuffstatus', false)
    TriggerServerEvent('rsg-lawman:server:setescortstatus', false)
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    ClearPedTasksImmediately(ped)
    SetEnableHandcuffs(ped, false)
    DisablePlayerFiring(PlayerId(), false)
    SetPedCanPlayGestureAnims(ped, true)
    DisplayRadar(true)
    FreezeEntityPosition(ped, false)
    notify(locale('cl_uncuffed'))
end

RegisterNetEvent('rsg-lawman:client:cuffplayer', function(hard)
    if IsPedRagdoll(PlayerPedId()) then return end
    local player, distance = RSGCore.Functions.GetClosestPlayer()
    if player == -1 or distance >= 1.5 then
        notify(locale('cl_nearby'), nil, 'error')
        return
    end
    if not RSGCore.Functions.HasItem('handcuffs') then
        notify(locale('cl_handcuffs'), locale('cl_handcuffs_a'), 'error')
        return
    end
    if IsPedInAnyVehicle(GetPlayerPed(player)) or IsPedInAnyVehicle(PlayerPedId()) then
        notify(locale('cl_failed'), locale('cl_failed_a'), 'error')
        return
    end
    TriggerServerEvent('rsg-lawman:server:cuffplayer', GetPlayerServerId(player), false, hard == true)
end)

-- (lawmanSrc, isSoftcuff [unused], state, hard): the server sends the wanted state; other resources
-- (rsg-adminmenu) trigger it without one, which toggles
RegisterNetEvent('rsg-lawman:client:getcuffed', function(_, _, state, hard)
    local want = state
    if want == nil then want = not isHandcuffed end
    if want == isHandcuffed then return end
    if want then setCuffed(hard) else setUncuffed() end
end)

-- restrictions while cuffed or escorted
CreateThread(function()
    local nextReassert = 0
    while true do
        if isEscorted or isHandcuffed then
            Wait(0)
            DisableControlAction(0, 0x295175BF, true) -- break
            DisableControlAction(0, 0x6E9734E8, true) -- suicide
            DisableControlAction(0, 0xD8F73058, true) -- aim in air
            DisableControlAction(0, 0x4CC0E2FE, true) -- B
            DisableControlAction(0, 0xDE794E3E, true) -- cover
            DisableControlAction(0, 0x06052D11, true) -- cover
            DisableControlAction(0, 0x5966D52A, true) -- cover
            DisableControlAction(0, 0xCEFD9220, true) -- cover
            DisableControlAction(0, 0xC75C27B0, true) -- cover
            DisableControlAction(0, 0x41AC83D1, true) -- cover
            DisableControlAction(0, 0xADEAF48C, true) -- cover
            DisableControlAction(0, 0x9D2AEA88, true) -- cover
            DisableControlAction(0, 0xE474F150, true) -- cover
            DisableControlAction(0, 0xB2F377E8, true) -- attack
            DisableControlAction(0, 0xC1989F95, true) -- attack 2
            DisableControlAction(0, 0x07CE1E61, true) -- melee attack 1
            DisableControlAction(0, 0xF84FA74F, true) -- mouse 2
            DisableControlAction(0, 0xCEE12B50, true) -- mouse 3
            DisableControlAction(0, 0x8FFC75D6, true) -- shift
            DisableControlAction(0, 0xD9D0E1C0, true) -- space
            DisableControlAction(0, 0xF3830D8E, true) -- J
            DisableControlAction(0, 0x80F28E95, true) -- L
            DisableControlAction(0, 0xDB096B85, true) -- ctrl
            DisableControlAction(0, 0xE30CD707, true) -- R

            if isHandcuffed then
                DisablePlayerFiring(PlayerId(), true)
                local now = GetGameTimer()
                if now >= nextReassert then -- other scripts may reset these, so re-apply once a second
                    nextReassert = now + 1000
                    local ped = PlayerPedId()
                    SetEnableHandcuffs(ped, true)
                    SetPedCanPlayGestureAnims(ped, false)
                    DisplayRadar(false)
                    FreezeEntityPosition(ped, cuffHard and not isEscorted) -- a frozen player cannot be dragged, so release while escorted
                end
            end
        else
            Wait(500)
        end
    end
end)

------------------------------------------
-- escort
------------------------------------------
RegisterNetEvent('rsg-lawman:client:escortplayer', function()
    if isHandcuffed or isEscorted then return end
    local player, distance = RSGCore.Functions.GetClosestPlayer()
    if player == -1 or distance >= 2.5 then
        notify(locale('cl_nearby'), nil, 'error')
        return
    end
    TriggerServerEvent('rsg-lawman:server:escortplayer', GetPlayerServerId(player))
end)

local function stopEscort()
    isEscorted = false
    draggerId = nil
    DetachEntity(PlayerPedId(), true, false)
    TriggerServerEvent('rsg-lawman:server:setescortstatus', false)
end

-- (playerId, state): explicit state from the server, toggle when none is given
RegisterNetEvent('rsg-lawman:client:getescorted', function(playerId, state)
    local want = state
    if want == nil then want = not isEscorted end
    if not want then
        if isEscorted then stopEscort() end
        return
    end
    if isEscorted then return end

    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not (PlayerData.metadata['isdead'] or isHandcuffed) then return end

    local dragger = GetPlayerPed(GetPlayerFromServerId(playerId))
    if not dragger or dragger == 0 or not DoesEntityExist(dragger) then return end

    isEscorted = true
    FreezeEntityPosition(PlayerPedId(), false)
    draggerId = playerId
    TriggerServerEvent('rsg-lawman:server:setescortstatus', true)
    SetEntityCoords(PlayerPedId(), GetOffsetFromEntityInWorldCoords(dragger, 0.0, 0.45, 0.0))
    AttachEntityToEntity(PlayerPedId(), dragger, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

    -- let go when the lawman disconnects, dies or leaves the area
    CreateThread(function()
        while isEscorted and draggerId == playerId do
            Wait(500)
            local d = GetPlayerPed(GetPlayerFromServerId(playerId))
            if not d or d == 0 or not DoesEntityExist(d) or IsEntityDead(d) then
                stopEscort()
                break
            end
        end
    end)
end)

------------------------------------------
-- restore / reset state after login or resource restart
------------------------------------------
local function restoreState()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local meta = PlayerData and PlayerData.metadata
    if not meta then return end
    if meta.isescorted then TriggerServerEvent('rsg-lawman:server:setescortstatus', false) end -- the attachment is gone
    if meta.ishandcuffed and not isHandcuffed then setCuffed() end -- still cuffed after a relog
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    restoreState()
end)

CreateThread(function()
    Wait(1000)
    restoreState()
end)

------------------------------------------
-- law badge
------------------------------------------
RegisterNetEvent('rsg-lawman:client:lawbadge', function()
    if RSGCore.Functions.GetPlayerData().job.type ~= 'leo' then
        RSGCore.Functions.Notify({ title = locale('cl_only_law'), type = 'inform', position = 'center-right', duration = 5000 })
        return
    end

    local ped = PlayerPedId()
    local female = not IsPedMale(ped)
    local hash = female and 0x0929677D or 0xDB4C451D
    if not badge then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, not female, true) -- ApplyShopItemToPed
    else
        Citizen.InvokeNative(0x0D7FFA1B2F69ED82, ped, hash, 0, 0)                   -- RemoveShopItemFromPed
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)                -- UpdatePedVariation
    badge = not badge
    RSGCore.Functions.Notify({ title = badge and locale('cl_badge_on') or locale('cl_badge_off'), type = 'inform', position = 'center-right', duration = 5000 })
end)

------------------------------------------
-- search other players inventory
------------------------------------------
-- IsPedHogtied (0x3AA24CCC0D451379) and IsPedLassoed (0x9682F850056C9ADE) need a result marker to return a value
local function isRestrained(ped)
    return IsEntityDead(ped)
        or IsPedCuffed(ped)
        or IsPedRagdoll(ped)
        or Citizen.InvokeNative(0x3AA24CCC0D451379, ped, Citizen.ResultAsInteger()) == 1
        or Citizen.InvokeNative(0x9682F850056C9ADE, ped, Citizen.ResultAsInteger()) == 1
        or IsEntityPlayingAnim(ped, 'script_proc@robberies@homestead@lonnies_shack@deception', 'hands_up_loop', 3)
end

-- the server asks the searched player's own client about states only that client can see
RSGCore.Functions.CreateClientCallback('rsg-lawman:client:isSearchable', function(cb)
    cb(isHandcuffed or isRestrained(PlayerPedId()))
end)

RegisterNetEvent('rsg-lawman:client:searchplayer', function()
    if IsPedRagdoll(PlayerPedId()) then
        RSGCore.Functions.Notify({ title = locale('cl_no_be_able'), type = 'error', position = 'center-right', duration = 5000 })
        return
    end
    local player, distance = RSGCore.Functions.GetClosestPlayer()
    if player == -1 or distance >= Config.SearchDistance then
        RSGCore.Functions.Notify({ title = locale('cl_nearby'), type = 'error', position = 'center-right', duration = 5000 })
        return
    end
    if Config.SearchRequireRestrained and not isRestrained(GetPlayerPed(player)) then
        RSGCore.Functions.Notify({ title = locale('cl_search'), type = 'error', position = 'center-right', duration = 5000 })
        return
    end

    local targetId = GetPlayerServerId(player)
    CreateThread(function()
        if (Config.SearchTime or 0) > 0 then
            local done = RSGCore.Functions.ProgressBar({
                duration = Config.SearchTime,
                label = locale('cl_searching'),
                canCancel = true,
            })
            if not done then return end
            local again, dist = RSGCore.Functions.GetClosestPlayer()
            if again == -1 or dist >= Config.SearchDistance or GetPlayerServerId(again) ~= targetId then
                notify(locale('cl_nearby'), nil, 'error')
                return
            end
        end
        TriggerServerEvent('rsg-lawman:server:SearchPlayer')
    end)
end)

------------------------------------------
-- automatic death alerts (optional)
------------------------------------------
local function getLocationName(coords)
    local closestDist, closest = math.huge, Config.AlertWilderness
    for name, loc in pairs(Config.AlertTowns) do
        local dist = #(coords - loc)
        if dist < closestDist then
            closestDist = dist
            closest = name
        end
    end
    return closest
end

-- GET_IS_ANIMAL (0x9A100F1CF4546629)
local function isAnimal(ped)
    return Citizen.InvokeNative(0x9A100F1CF4546629, ped, Citizen.ResultAsInteger()) == 1
end

local function sendDeathAlert(text, coords)
    local now = GetGameTimer()
    if now - lastAlertTime <= Config.AlertCooldown then return end
    lastAlertTime = now
    TriggerServerEvent('rsg-lawman:server:lawmanAlert', text, coords, 'death')
end

if Config.EnablePlayerDeathAlerts then
    CreateThread(function()
        local wasDead = false
        while true do
            Wait(1000)
            local ped = PlayerPedId()
            local dead = IsEntityDead(ped)
            if dead and not wasDead then
                local coords = GetEntityCoords(ped)
                local location = getLocationName(coords)
                local killer = GetPedSourceOfDeath(ped)
                local alertText = locale('cl_lang_1') .. location
                if killer and DoesEntityExist(killer) and GetEntityType(killer) == 1 then
                    if IsPedAPlayer(killer) then
                        alertText = locale('cl_lang_2') .. location
                    elseif not isAnimal(killer) then
                        alertText = locale('cl_lang_3') .. location
                    end
                end
                sendDeathAlert(alertText, coords)
            end
            wasDead = dead
        end
    end)
end

if Config.EnableNPCDeathAlerts then
    CreateThread(function()
        local alive = {} -- [ped] = true while we have seen it alive nearby
        while true do
            Wait(1000)
            local me = PlayerPedId()
            local playerCoords = GetEntityCoords(me)
            for _, ped in ipairs(GetGamePool('CPed')) do
                if ped ~= me and not IsPedAPlayer(ped) and not isAnimal(ped) then
                    if not IsEntityDead(ped) then
                        alive[ped] = true
                    elseif alive[ped] then
                        alive[ped] = nil
                        -- only the client that owns the ped reports it, so a crowd does not send duplicates
                        if NetworkHasControlOfEntity(ped) then
                            local pedCoords = GetEntityCoords(ped)
                            if #(playerCoords - pedCoords) <= Config.AlertDistance then
                                local location = getLocationName(pedCoords)
                                local text = GetPedSourceOfDeath(ped) == me and locale('cl_lang_5') or locale('cl_lang_4')
                                sendDeathAlert(text .. location, pedCoords)
                            end
                        end
                    end
                end
            end
            for ped in pairs(alive) do
                if not DoesEntityExist(ped) then alive[ped] = nil end
            end
        end
    end)
end

------------------------------------------
-- frisk (weapons / contraband, seize from a menu)
------------------------------------------
RegisterNetEvent('rsg-lawman:client:frisk', function()
    if IsPedRagdoll(PlayerPedId()) then return end
    local player, distance = RSGCore.Functions.GetClosestPlayer()
    if player == -1 or distance >= Config.SearchDistance then
        notify(locale('cl_nearby'), nil, 'error')
        return
    end
    TriggerServerEvent('rsg-lawman:server:frisk')
end)

RegisterNetEvent('rsg-lawman:client:friskResult', function(list)
    if type(list) ~= 'table' or #list == 0 then
        notify(locale('cl_frisk_none'), nil, 'inform')
        return
    end
    menuActions = {}
    local options = {}
    for i, entry in ipairs(list) do
        local id = 'seize' .. i
        local name = entry.name
        menuActions[id] = function() TriggerServerEvent('rsg-lawman:server:seize', name) end
        options[#options + 1] = { id = id, title = ('%s  x%s'):format(entry.label, entry.amount), icon = 'fa-solid fa-hand-holding' }
    end
    openUI({ action = 'openMenu', title = locale('cl_frisk'), subtitle = locale('cl_frisk_hint'), options = options })
end)

------------------------------------------
-- jail the closest player with a rebindable key (also /jailnear)
------------------------------------------
if Config.UseKeyMapping and Config.JailNearKey ~= nil then
    RSGCore.Functions.RegisterKey('rsglawman_jailnear', locale('key_jailnear'), Config.JailNearKey, function()
        if RSGCore.Functions.GetPlayerData().job.type == 'leo' then
            TriggerEvent('rsg-lawman:client:jailplayer')
        end
    end, nil, { canTrigger = function() return not IsPauseMenuActive() and not isHandcuffed end })
end

------------------------------------------
-- holding cells
------------------------------------------
RegisterNetEvent('rsg-lawman:client:heldInCell', function(cell)
    if not cell then return end
    if isEscorted then stopEscort() end
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(400)
    SetEntityCoords(ped, cell.x, cell.y, cell.z, false, false, false, false)
    if cell.w then SetEntityHeading(ped, cell.w) end
    Wait(400)
    DoScreenFadeIn(400)
    notify(locale('cl_held'), nil, 'inform')
end)

RegisterNetEvent('rsg-lawman:client:releasedFromCell', function(release)
    if release then
        local ped = PlayerPedId()
        DoScreenFadeOut(400)
        Wait(400)
        SetEntityCoords(ped, release.x, release.y, release.z, false, false, false, false)
        if release.w then SetEntityHeading(ped, release.w) end
        Wait(400)
        DoScreenFadeIn(400)
    end
    notify(locale('cl_released'), nil, 'inform')
end)

------------------------------------------
-- gunshot alerts (optional): non-law firing a weapon inside a town
------------------------------------------
if Config.GunshotAlerts.Enabled then
    CreateThread(function()
        local lastShot = 0
        while true do
            Wait(250)
            local ped = PlayerPedId()
            if IsPedShooting(ped) and GetGameTimer() - lastShot > Config.GunshotAlerts.Cooldown
                and RSGCore.Functions.GetPlayerData().job.type ~= 'leo' then
                local coords = GetEntityCoords(ped)
                for name, loc in pairs(Config.AlertTowns) do
                    if #(coords - loc) <= Config.GunshotAlerts.TownRadius then
                        lastShot = GetGameTimer()
                        TriggerServerEvent('rsg-lawman:server:lawmanAlert', locale('cl_gunshot') .. name, coords, 'gunshot')
                        break
                    end
                end
            end
        end
    end)
end

------------------------------------------
-- cleanup
------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end

    if uiFocus then
        SendNUIMessage({ action = 'close' })
        closeUI()
        if inputPromise then inputPromise:resolve(nil) end
    end

    for _, v in pairs(Config.LawOfficeLocations) do
        exports['rsg-core']:deletePrompt(v.prompt)
    end
    for _, blip in ipairs(officeBlips) do RemoveBlip(blip) end
    for id in pairs(alerts) do removeAlert(id) end

    if isHandcuffed or isEscorted then
        local ped = PlayerPedId()
        DetachEntity(ped, true, false)
        SetEnableHandcuffs(ped, false)
        SetPedCanPlayGestureAnims(ped, true)
        FreezeEntityPosition(ped, false)
        DisplayRadar(true)
    end
end)
