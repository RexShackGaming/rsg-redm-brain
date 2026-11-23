local RSGCore = exports['rsg-core']:GetCoreObject()

local uiFocus  = false
local adminOpen = false -- true while the staff panel (not the radio) is the open UI
local radioKey = nil -- rsg-voice transmit key, kept enabled while the radio is open

---------------------------------------------------------------------
-- NUI focus (push-to-talk keeps working while the radio is open)
---------------------------------------------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    for i = 1, #list do
        EnableControlAction(0, list[i], true)
        EnableControlAction(1, list[i], true)
        EnableControlAction(2, list[i], true)
    end
    if radioKey then
        EnableControlAction(0, radioKey, true)
        EnableControlAction(1, radioKey, true)
        EnableControlAction(2, radioKey, true)
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

---------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------
local function notify(key, nType, ...)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale(key, ...), type = nType, duration = 3000 })
end

local function getStrings()
    return {
        title = locale('ui_title'), subtitle = locale('ui_subtitle'),
        on = locale('ui_status_on'), off = locale('ui_status_off'),
        frequency = locale('ui_frequency'), connect = locale('ui_connect'), disconnect = locale('ui_disconnect'),
        channels = locale('ui_channels'), noChannels = locale('ui_no_channels'),
        active = locale('ui_active'), join = locale('ui_join'),
        hint = locale('ui_hint', Config.TransmitKeyLabel), members = locale('ui_members', '%s'),
        close = locale('ui_close'), move = locale('ui_move'),
        favorites = locale('ui_favorites'), noFavorites = locale('ui_no_favorites'), favAdd = locale('ui_fav_add'),
        favRemove = locale('ui_fav_remove'), favLabel = locale('ui_fav_label'),
        range = locale('ui_range', '%s', '%s'), restricted = locale('ui_restricted'), outOfRange = locale('ui_out_of_range', '%s', '%s'),
        private = locale('ui_private'), privateList = locale('ui_private_list'), code = locale('ui_code'),
        pname = locale('ui_pname'), privCreate = locale('ui_priv_create'), privUpdate = locale('ui_priv_update'),
        privDelete = locale('ui_priv_delete'), privCost = locale('ui_priv_cost', '%s'), privYours = locale('ui_priv_yours'), locked = locale('ui_locked'),
        search = locale('ui_search'), recents = locale('ui_recents'), noMatch = locale('ui_no_match'), rangeOpen = locale('ui_range_open'),
        compact = locale('ui_compact'), mute = locale('ui_mute'), muted = locale('ui_muted'),
    }
end

local function closeRadio()
    if not uiFocus then return end
    uiFocus, adminOpen = false, false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('rsg-radio:server:panelClosed')
end

local function openRadio(state)
    if uiFocus then return end
    if not state then return notify('cl_no_radio', 'error') end
    local ok, key = pcall(function() return exports['rsg-voice']:GetRadioTalkKey() end)
    radioKey = ok and key or nil
    uiFocus = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', strings = getStrings(), state = state })
end

local opening = false -- a state request is in flight (stops key/command spam from asking the server again)
local function requestOpen()
    if uiFocus or opening then return end
    opening = true
    RSGCore.Functions.TriggerCallback('rsg-radio:server:getState', function(state)
        opening = false
        openRadio(state)
    end)
end

RegisterCommand(Config.Command, requestOpen, false)

-- Sent by the server when the radio item is used
RegisterNetEvent('rsg-radio:client:open', function()
    if GetInvokingResource() then return end
    requestOpen()
end)

-- Fresh state from the server (after joining/leaving, or nil when the radio was lost)
RegisterNetEvent('rsg-radio:client:state', function(state)
    if GetInvokingResource() then return end
    if not uiFocus then return end
    if not state then return closeRadio() end
    SendNUIMessage({ action = 'state', state = state })
end)

---------------------------------------------------------------------
-- NUI callbacks (the server validates everything again)
---------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    closeRadio()
    cb('ok')
end)

-- NUI callback that forwards a frequency (and optionally a favorite name) to a server event
local function forwardFreq(name, event, withLabel)
    RegisterNUICallback(name, function(data, cb)
        cb('ok')
        local freq = tonumber(data and data.freq)
        if not freq then return end
        if withLabel then TriggerServerEvent(event, freq, tostring(data.label or '')) else TriggerServerEvent(event, freq) end
    end)
end
-- join may carry a passcode for private channels
RegisterNUICallback('join', function(data, cb)
    cb('ok')
    local freq = tonumber(data and data.freq)
    if not freq then return end
    local code = type(data.code) == 'string' and data.code ~= '' and data.code:sub(1, 32) or nil
    TriggerServerEvent('rsg-radio:server:join', freq, code)
end)
RegisterNUICallback('savePrivate', function(data, cb)
    cb('ok')
    local freq = tonumber(data and data.freq)
    if not freq then return end
    TriggerServerEvent('rsg-radio:server:savePrivate', freq, tostring(data.name or ''), tostring(data.code or ''))
end)
forwardFreq('deletePrivate', 'rsg-radio:server:deletePrivate')
forwardFreq('addFavorite', 'rsg-radio:server:addFavorite', true)
forwardFreq('removeFavorite', 'rsg-radio:server:removeFavorite')

RegisterNUICallback('leave', function(_, cb)
    cb('ok')
    TriggerServerEvent('rsg-radio:server:leave')
end)

-- Favorite hotkeys (rebindable in the game's key settings)
local hk = Config.FavoriteHotkeys
if hk and hk.Enabled then
    RegisterCommand('+rsgradio_nextfav', function() TriggerServerEvent('rsg-radio:server:cycleFavorite', 1) end, false)
    RegisterCommand('-rsgradio_nextfav', function() end, false)
    RegisterCommand('+rsgradio_prevfav', function() TriggerServerEvent('rsg-radio:server:cycleFavorite', -1) end, false)
    RegisterCommand('-rsgradio_prevfav', function() end, false)
    RegisterKeyMapping('+rsgradio_nextfav', locale('ui_key_next_fav'), 'keyboard', hk.Next)
    RegisterKeyMapping('+rsgradio_prevfav', locale('ui_key_prev_fav'), 'keyboard', hk.Prev)
end

---------------------------------------------------------------------
-- Admin panel (staff). The server checks the permission on every call.
---------------------------------------------------------------------
local function adminStrings()
    local s = {}
    for _, k in ipairs({ 'title', 'subtitle', 'tab_channels', 'tab_private', 'tab_blocks', 'tab_log', 'stat_onair', 'stat_channels',
        'stat_private', 'stat_blocks', 'no_members', 'kick', 'mute', 'unmute', 'minutes', 'clear', 'delete', 'refresh', 'kind_public',
        'kind_restricted', 'kind_private', 'owner', 'offline', 'none', 'no_log', 'search', 'confirm_yes', 'confirm_no' }) do
        s[k] = locale('adm_' .. k)
    end
    s.idle = locale('adm_idle', '%s')
    s.left = locale('adm_left', '%s')
    s.members = locale('adm_members', '%s')
    s.confirmClear = locale('adm_confirm_clear', '%s')
    s.confirmDelete = locale('adm_confirm_delete', '%s')
    s.close = locale('ui_close')
    s.move = locale('ui_move')
    return s
end

local function showAdmin(data)
    if uiFocus then return end
    if not data then return notify('staff_no_access', 'error') end
    local ok, key = pcall(function() return exports['rsg-voice']:GetRadioTalkKey() end)
    radioKey = ok and key or nil
    uiFocus, adminOpen = true, true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'adminOpen', strings = adminStrings(), data = data })
end

RegisterNetEvent('rsg-radio:client:admin:open', function()
    if GetInvokingResource() or uiFocus then return end
    RSGCore.Functions.TriggerCallback('rsg-radio:server:admin:getData', showAdmin)
end)

RegisterNetEvent('rsg-radio:client:admin:data', function(data)
    if GetInvokingResource() or not adminOpen or not data then return end
    SendNUIMessage({ action = 'adminData', data = data })
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    cb('ok')
    if not adminOpen then return end
    RSGCore.Functions.TriggerCallback('rsg-radio:server:admin:getData', function(data)
        if data and adminOpen then SendNUIMessage({ action = 'adminData', data = data }) end
    end)
end)

-- name, server event, how to read the payload from the NUI message
local function adminAction(name, event, build)
    RegisterNUICallback(name, function(data, cb)
        cb('ok')
        if not adminOpen or type(data) ~= 'table' then return end
        local a, b = build(data)
        if a == nil then return end
        TriggerServerEvent(event, a, b)
    end)
end
adminAction('adminKick', 'rsg-radio:server:admin:kick', function(d) return tonumber(d.id) end)
adminAction('adminMute', 'rsg-radio:server:admin:mute', function(d) return tonumber(d.id), tonumber(d.minutes) end)
adminAction('adminUnmute', 'rsg-radio:server:admin:unmute', function(d) return type(d.cid) == 'string' and d.cid or nil end)
adminAction('adminDeletePrivate', 'rsg-radio:server:admin:deletePrivate', function(d) return tonumber(d.freq) end)
adminAction('adminClear', 'rsg-radio:server:admin:clearChannel', function(d) return tonumber(d.freq) end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    closeRadio()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
end)

---------------------------------------------------------------------
-- Mute, channel HUD, hogtied report, signal interference
---------------------------------------------------------------------
local HUD = Config.Hud or {}
local IC  = Config.Incapacitated or {}
local INT = Config.Interference or {}

local hudData    = nil -- { freq, unit, members = { { id, name } }, battery } while on a channel (from the server)
local hudTalkers = {}  -- [serverId] = true while that member transmits
local hudHidden  = GetResourceKvpInt('rsg-radio:hudHidden') == 1
local battery    = nil -- 0-100 when Config.Battery.Enabled
local signal     = 1.0 -- 1.0 clear ... 0.0 no signal (Config.Interference)
local function configVolume() return math.max(0, math.min(100, tonumber(Config.Volume) or 50)) end -- Config.Volume, percent
local muted      = false -- radio muted (saved per character)

local function mySid() return GetPlayerServerId(PlayerId()) end

local function sendHud()
    local show = HUD.Enabled and not hudHidden and hudData ~= nil
    local members = {}
    if show then
        for _, m in ipairs(hudData.members) do
            members[#members + 1] = { id = m.id, name = m.name, talk = hudTalkers[m.id] and true or false }
        end
    end
    SendNUIMessage({
        action = 'hud', show = show, freq = hudData and hudData.freq or '', unit = hudData and hudData.unit or '',
        members = members, max = HUD.MaxRows or 8, left = HUD.Left or 18, top = HUD.Top or 18,
        battery = battery, signal = signal, muted = muted, me = mySid(),
        txt = { noSignal = locale('hud_no_signal'), weakSignal = locale('hud_weak_signal') },
    })
end

-- rsg-voice does the audio: Config.Volume, our mute and signal are handed over (older rsg-voice versions just ignore them)
local function applyVoice()
    pcall(function()
        exports['rsg-voice']:SetRadioVolume(configVolume() / 100)
        exports['rsg-voice']:SetRadioMuted(muted)
        exports['rsg-voice']:SetRadioSignal(signal)
    end)
end

local function loadSettings(pd)
    local rs = pd and pd.metadata and pd.metadata.radiosettings
    local saved = type(rs) == 'table' and rs.muted == true or false
    if saved ~= muted then
        muted = saved
        applyVoice()
        sendHud()
    end
end

-- Panel: the mute button applies at once, the server only stores it (saveMute is debounced by the NUI)
RegisterNUICallback('setMute', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    muted = data.muted == true
    applyVoice()
    sendHud()
end)
RegisterNUICallback('saveMute', function(_, cb)
    cb('ok')
    TriggerServerEvent('rsg-radio:server:setSettings', muted)
end)

RegisterNetEvent('rsg-radio:client:hud', function(data)
    if GetInvokingResource() then return end
    hudData = data
    if data then
        battery = data.battery
    else
        hudTalkers, battery = {}, nil
    end
    sendHud()
end)

RegisterNetEvent('rsg-radio:client:battery', function(value)
    if GetInvokingResource() then return end
    battery = tonumber(value)
    sendHud()
    if uiFocus then SendNUIMessage({ action = 'battery', value = battery }) end
end)

-- who is speaking: rsg-voice tells us about other members, and about ourselves through a local event
RegisterNetEvent('rsg-voice:client:radioTalk', function(sid, state)
    if not hudData then return end
    hudTalkers[sid] = state == true or nil
    sendHud()
end)
AddEventHandler('rsg-voice:client:onRadioTalk', function(state)
    if not hudData then return end
    hudTalkers[mySid()] = state == true or nil
    sendHud()
end)

if HUD.Command and HUD.Command ~= '' then
    RegisterCommand(HUD.Command, function()
        hudHidden = not hudHidden
        SetResourceKvpInt('rsg-radio:hudHidden', hudHidden and 1 or 0)
        sendHud()
        notify(hudHidden and 'cl_hud_off' or 'cl_hud_on', 'inform')
    end, false)
end

-- Hogtied is not stored on the server: report it so the radio can be dropped (only affects this player's own radio)
if IC.Hogtied then
    CreateThread(function()
        local last = false
        while true do
            Wait(750)
            local r = IsPedHogtied(PlayerPedId())
            local on = r == true or r == 1
            if on ~= last then
                last = on
                TriggerServerEvent('rsg-radio:server:hogtied', on)
            end
        end
    end)
end

-- Signal interference: the weakest zone the player stands in decides the signal
if INT.Enabled then CreateThread(function()
    while true do
        Wait(1000)
        local q = 1.0
        if hudData and INT.Zones then
            local p = GetEntityCoords(PlayerPedId())
            for _, z in ipairs(INT.Zones) do
                local radius = tonumber(z.radius) or 0.0
                local d = #(p - z.coords)
                if radius > 0.0 and d < radius then
                    local zq = math.max(0.0, math.min(1.0, tonumber(z.signal) or 0.0))
                    if z.falloff then zq = zq + (1.0 - zq) * (d / radius) end
                    if zq < q then q = zq end
                end
            end
        end
        q = math.floor(q * 100 + 0.5) / 100
        if q ~= signal then
            local before = signal
            signal = q
            applyVoice()
            sendHud()
            if hudData then
                if q <= 0.0 and before > 0.0 then notify('cl_signal_lost', 'error')
                elseif before <= 0.0 and q > 0.0 then notify('cl_signal_back', 'success') end
            end
        end
    end
end) end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    SetTimeout(1000, function() loadSettings(RSGCore.Functions.GetPlayerData()) end)
end)
RegisterNetEvent('RSGCore:Player:SetPlayerData', function(pd) loadSettings(pd) end)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    hudData, hudTalkers, battery, signal = nil, {}, nil, 1.0
    muted = false
    applyVoice()
    sendHud()
end)
AddEventHandler('onClientResourceStart', function(res)
    if res == 'rsg-voice' then SetTimeout(1500, applyVoice) end -- rsg-voice restarted: hand our settings over again
end)
CreateThread(function()
    Wait(2000)
    local pd = RSGCore.Functions.GetPlayerData()
    if pd and pd.metadata then loadSettings(pd) end
end)

---------------------------------------------------------------------
-- Handheld radio: prop and animation while transmitting (Config.Handheld)
-- The prop is a networked object attached to the ped and the animation is a normal ped task, so nearby players see both.
---------------------------------------------------------------------
local HH = Config.Handheld or {}
local handProp = nil
local handAnim = nil -- the clip currently playing { dict, clip }
local handActive = false -- true while the handheld pose is shown (a prop is optional)
local transmitting = false

local function removeHandheld()
    local ped = PlayerPedId()
    if handProp and DoesEntityExist(handProp) then
        if NetworkGetEntityIsNetworked(handProp) and not NetworkHasControlOfEntity(handProp) then
            NetworkRequestControlOfEntity(handProp)
        end
        DetachEntity(handProp, true, true)
        SetEntityAsMissionEntity(handProp, true, true)
        DeleteObject(handProp)
        if DoesEntityExist(handProp) then DeleteEntity(handProp) end
    end
    handProp, handActive = nil, false
    local a = handAnim
    handAnim = nil
    if a and IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then StopAnimTask(ped, a.dict, a.clip, 1.0) end
end

local function canShowHandheld(ped)
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedSwimming(ped) or IsPedClimbing(ped) or IsPedFalling(ped) then return false end
    if not HH.OnMount and IsPedOnMount(ped) then return false end
    if IsPedInAnyVehicle(ped, false) then return false end
    return true
end

local function showHandheld()
    if handActive or not HH.Enabled then return end
    local ped = PlayerPedId()
    if not canShowHandheld(ped) then return end
    handActive = true
    if HH.Model and HH.Model ~= '' then
        local hash = RSGCore.Functions.RequestModel(HH.Model)
        if hash then
            local c = GetEntityCoords(ped)
            local obj = CreateObject(hash, c.x, c.y, c.z, true, true, false)
            SetModelAsNoLongerNeeded(hash)
            if obj and obj ~= 0 then
                SetEntityCollision(obj, false, false)
                local o, r = HH.Offset or vector3(0.0, 0.0, 0.0), HH.Rotation or vector3(0.0, 0.0, 0.0)
                AttachEntityToEntity(obj, ped, GetEntityBoneIndexByName(ped, HH.Bone or 'SKEL_R_Finger00'),
                    o.x, o.y, o.z, r.x, r.y, r.z, true, false, true, false, 0, true)
                handProp = obj
            end
        end
    end
    local a = (not IsPedMale(ped) and HH.AnimFemale) or HH.Anim
    if a and a.dict and a.clip and RSGCore.Functions.RequestAnimDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, a.flag or 18, 0, false, false, false)
        handAnim = { dict = a.dict, clip = a.clip }
    end
    if not transmitting then removeHandheld() end -- the key was released while the model loaded
end

if HH.Enabled then
    AddEventHandler('rsg-voice:client:onRadioTalk', function(state)
        transmitting = state == true
        if transmitting then CreateThread(showHandheld) else removeHandheld() end
    end)

    -- drop it if the player stops being able to hold it (died, mounted, left the channel...)
    CreateThread(function()
        while true do
            if handActive then
                if not hudData or not canShowHandheld(PlayerPedId()) then removeHandheld() end
                Wait(500)
            else
                Wait(1000)
            end
        end
    end)
end

AddEventHandler('RSGCore:Client:OnPlayerUnload', removeHandheld)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeHandheld() end
end)
