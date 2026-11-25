local RSGCore = exports['rsg-core']:GetCoreObject()

local Ranges      = Config.Ranges
local rangeCount  = #Ranges
local currentIdx  = 1
local maxRange    = 0.0
local stateMute   = false -- dead / last stand / cuffed
local serverMute  = false -- admin or another resource, enforced by the server
local scriptMutes = {}    -- [reason] = true, client-side mutes from other resources
local ringUntil   = 0
local loaded      = false
local myServerId  = GetPlayerServerId(PlayerId())
local lastRange   = nil   -- last range written to the voiceRange state bag
local radioInputBlocked = false -- a text box in another UI (rsg-radio) has focus: the transmit key must not key the mic
local hudVisible  = GetResourceKvpInt('rsg-voice:hudHidden') ~= 1
local P           = Config.Party
local party       = nil   -- party payload from the server (nil when not in a party)
local RC          = Config.Radio
local radio       = nil   -- { freq, members = { [serverId] = true } } while on a radio channel
local radioTalkers = {}   -- [serverId] = true while they transmit on my channel
local radioTalk   = false -- I am transmitting on the radio
local radioVol    = 1.0   -- how loud radio transmissions are for me (SetRadioVolume, saved per player by rsg-radio)
local radioMuted  = false -- I muted the radio (SetRadioMuted)
local radioSignal = 1.0   -- 1.0 clear ... 0.0 no signal (SetRadioSignal): scales what I hear, 0.0 also blocks my transmit
local callActive  = false -- a phone call is running (SetCallActive, set by rsg-telephone)
local PR          = Config.Priority or {}
local radioTalkStart, radioLocked, radioCooldownUntil = 0, false, 0 -- transmit time limit

-- NUI focus owners: only release focus when nothing needs it
local focus = { edit = false, menu = false, invite = false }
local function updateFocus()
    local on = focus.edit or focus.menu or focus.invite
    if on then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- While a window of this resource has focus, block the game's controls but leave push-to-talk enabled
CreateThread(function()
    while true do
        if Config.AllowPushToTalkWhileOpen and (focus.edit or focus.menu or focus.invite) then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            local list = Config.PushToTalkControls or {}
            for i = 1, #list do
                EnableControlAction(0, list[i], true)
                EnableControlAction(1, list[i], true)
                EnableControlAction(2, list[i], true)
            end
        else
            Wait(250)
        end
    end
end)

for i, r in ipairs(Ranges) do
    if r.default then currentIdx = i end
    if r.range > maxRange then maxRange = r.range end
end

-- Saved range (per client)
if Config.SaveRange then
    local saved = GetResourceKvpString('rsg-voice:range')
    for i, r in ipairs(Ranges) do
        if r.name == saved then currentIdx = i break end
    end
end

local isTalking = MumbleIsPlayerTalking or NetworkIsPlayerTalking
local function talking(ply)
    local t = isTalking(ply)
    return t == true or t == 1
end

local function isMuted() return stateMute or serverMute or next(scriptMutes) ~= nil end

local function rangeLabel(i)
    local key = 'range_' .. Ranges[i].name
    local txt = locale(key)
    return (txt and txt ~= key) and txt or Ranges[i].name
end

local function notify(key, nType, ...)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale(key, ...), type = nType, duration = 3000 })
end

local function sendHud()
    if not Config.ShowHud then return end
    SendNUIMessage({
        action = 'update',
        show   = loaded and hudVisible,
        label  = rangeLabel(currentIdx),
        index  = currentIdx,
        total  = rangeCount,
        muted  = isMuted(),
    })
end

local function applyVoice()
    local range = Ranges[currentIdx].range
    MumbleSetAudioInputDistance(isMuted() and 0.0 or range)
    MumbleSetTalkerProximity(range)
    MumbleSetAudioOutputDistance(maxRange) -- always hear shouting players
    if lastRange ~= range then
        lastRange = range
        LocalPlayer.state:set('voiceRange', range, true)
    end
    sendHud()
end

-- Rebindable key: rsg-core RegisterKey (3.5.0+) when it exists, otherwise a plain key mapping
local function bindKey(name, description, key, onPress, onRelease, opts)
    if RSGCore.Functions.RegisterKey then
        return RSGCore.Functions.RegisterKey(name, description, key, onPress, onRelease, opts)
    end
    RegisterCommand('+' .. name, function() if onPress then onPress() end end, false)
    RegisterCommand('-' .. name, function() if onRelease then onRelease() end end, false)
    RegisterKeyMapping('+' .. name, description, 'keyboard', key)
    return true
end

local function setRange(i, showFeedback)
    if not Ranges[i] then return end
    currentIdx = i
    applyVoice()
    if Config.SaveRange then SetResourceKvp('rsg-voice:range', Ranges[i].name) end
    if showFeedback then
        if Config.ShowRangeRing then ringUntil = GetGameTimer() + Config.RingDuration end
        notify('cl_range_set', 'inform', rangeLabel(i))
    end
end

local function cycleRange()
    if not loaded then return end
    if isMuted() then return notify('cl_muted', 'error') end
    setRange(currentIdx % rangeCount + 1, true)
end

if Config.UseKeyMapping then
    bindKey('rsgvoice_cycle', locale('key_cycle'), Config.CycleKeyName or 'RBRACKET', function()
        if not focus.menu and not focus.invite then cycleRange() end
    end, nil, { canTrigger = function() return not IsPauseMenuActive() end })
end

local function refreshStateMute(md)
    md = md or {}
    local should = (Config.MuteWhenDead and (md.isdead or md.inlaststand))
        or (Config.MuteWhenCuffed and md.ishandcuffed) or false
    if should ~= stateMute then
        stateMute = should
        applyVoice()
    end
end

local function init()
    loaded = true
    myServerId = GetPlayerServerId(PlayerId())
    serverMute = RSGCore.Functions.AwaitCallback('rsg-voice:server:isMuted', 5000) or false
    stateMute = false
    refreshStateMute((RSGCore.Functions.GetPlayerData() or {}).metadata)
    setRange(currentIdx, false)
    if Config.ShowHud then
        SendNUIMessage({ action = 'locale', hint = locale('cl_hud_hint') })
    end
end

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
RegisterCommand(Config.CycleCommand, cycleRange, false)

RegisterCommand(Config.HudEditCommand, function()
    if not Config.ShowHud or not loaded then return end
    if not hudVisible then return notify('cl_hud_hidden_edit', 'error', Config.HudToggleCommand) end
    sendHud()
    focus.edit = true
    updateFocus()
    SendNUIMessage({ action = 'edit' })
end, false)

RegisterCommand(Config.HudToggleCommand, function()
    if not Config.ShowHud or not loaded then return end
    hudVisible = not hudVisible
    SetResourceKvpInt('rsg-voice:hudHidden', hudVisible and 0 or 1)
    sendHud()
    notify(hudVisible and 'cl_hud_on' or 'cl_hud_off', 'inform')
end, false)

RegisterNUICallback('closeEdit', function(_, cb)
    focus.edit = false
    updateFocus()
    cb('ok')
end)

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    init()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    loaded = false
    radioVol, radioMuted, radioSignal, callActive, radioInputBlocked = 1.0, false, 1.0, false, false
    sendHud()
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(data)
    if loaded then refreshStateMute(data and data.metadata) end
end)

-- Server-enforced mute state (notifications are sent by the server)
RegisterNetEvent('rsg-voice:client:muteState', function(state)
    if GetInvokingResource() then return end -- only accept from server
    serverMute = state == true
    applyVoice()
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then init() end
end)

---------------------------------------------------------------------
-- Threads
---------------------------------------------------------------------
-- Range ring, and the range key when Config.UseKeyMapping is off. Per-frame only while one of them needs it.
CreateThread(function()
    local poll = not Config.UseKeyMapping
    while true do
        if loaded and (poll or GetGameTimer() < ringUntil) then
            if poll and not focus.menu and not focus.invite and IsControlJustReleased(0, Config.CycleKey) then cycleRange() end
            if GetGameTimer() < ringUntil then
                local c   = GetEntityCoords(PlayerPedId())
                local d   = Ranges[currentIdx].range * 2.0
                local col = Config.RingColour
                -- DrawMarker
                Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, c.x, c.y, c.z - 0.95,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, 0.25, col.r, col.g, col.b, col.a,
                    false, false, 2, false, nil, nil, false)
            end
            Wait(0)
        else
            Wait(loaded and 100 or 500)
        end
    end
end)

-- HUD talking indicator (no need to poll every frame)
if Config.ShowHud then
    CreateThread(function()
        local last
        while true do
            if loaded then
                local t = talking(PlayerId())
                if t ~= last then
                    last = t
                    SendNUIMessage({ action = 'talking', state = t })
                end
                Wait(100)
            else
                last = nil
                Wait(500)
            end
        end
    end)
end

---------------------------------------------------------------------
-- Party helpers (party stays nil when parties are disabled)
---------------------------------------------------------------------
local function isMember(sid)
    if not party then return false end
    for _, m in ipairs(party.members) do if m.id == sid then return true end end
    return false
end

local function inTalkRange(sid)
    local ply = GetPlayerFromServerId(sid)
    if ply == -1 then return false end -- not streamed in = too far
    local ped = GetPlayerPed(ply)
    if ped == 0 then return false end
    return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped)) <= P.TalkRange
end

---------------------------------------------------------------------
-- Volume manager: party talk (full volume at range) and muffling (other interior)
---------------------------------------------------------------------
local overrides = {}   -- [serverId] = volume currently applied
local nearby    = {}   -- players within TalkIcon.Distance: { ply, ped, sid }

local function setVolume(sid, vol)
    if overrides[sid] == vol then return end
    MumbleSetVolumeOverrideByServerId(sid, vol or -1.0)
    overrides[sid] = vol
end

local function clearOverrides()
    for sid in pairs(overrides) do MumbleSetVolumeOverrideByServerId(sid, -1.0) end
    overrides = {}
end

-- a running phone call takes priority over radio and party voice (Config.Priority.Call)
local function callBlocks(key)
    return callActive and PR.Call ~= nil and PR.Call.Enabled ~= false and PR.Call[key] ~= false
end

-- volume of radio transmissions for me: 0.0 when muted, during a call that mutes them, or without signal
local function radioGain()
    if radioMuted or radioSignal <= 0.0 or callBlocks('MuteIncomingRadio') then return 0.0 end
    return radioVol * radioSignal
end

local function desiredVolume(sid, ped, myPos, myInterior)
    if radioTalkers[sid] then return radioGain() end
    if party and Player(sid).state.partyTalk and isMember(sid)
        and #(myPos - GetEntityCoords(ped)) <= P.TalkRange then
        if callBlocks('MutePartyVoice') then return 0.0 end
        return 1.0
    end
    if Config.Muffle.Enabled and GetInteriorFromEntity(ped) ~= myInterior
        and #(myPos - GetEntityCoords(ped)) <= maxRange + 2.0 then
        return Config.Muffle.Volume
    end
    return nil
end

local function updateVolumes()
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local myInterior = GetInteriorFromEntity(myPed)
    local seen, list = {}, {}
    local iconDist = Config.TalkIcon.Distance
    for _, ply in ipairs(GetActivePlayers()) do
        local sid = GetPlayerServerId(ply)
        if sid ~= myServerId then
            local ped = GetPlayerPed(ply)
            if ped ~= 0 then
                seen[sid] = true
                setVolume(sid, desiredVolume(sid, ped, myPos, myInterior))
                if #(myPos - GetEntityCoords(ped)) <= iconDist then
                    list[#list + 1] = { ply = ply, ped = ped, sid = sid }
                end
            end
        end
    end
    for sid in pairs(radioTalkers) do -- radio talkers can be far away / not streamed in
        seen[sid] = true
        setVolume(sid, radioGain())
    end
    for sid in pairs(overrides) do
        if not seen[sid] then setVolume(sid, nil) end -- left the area
    end
    nearby = list
end

CreateThread(function()
    while true do
        if loaded then updateVolumes() end
        Wait(Config.Muffle.Interval)
    end
end)

-- React instantly when a party member starts/stops party talk
AddStateBagChangeHandler('partyTalk', nil, function(bagName)
    if not loaded or not party then return end
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 or GetPlayerServerId(ply) == myServerId then return end
    SetTimeout(0, updateVolumes) -- let the bag value land first
end)

---------------------------------------------------------------------
-- Radio channels
-- Membership is decided by the server (JoinRadio / LeaveRadio exports). Hold RC.TalkKey to transmit.
---------------------------------------------------------------------
local RADIO_TARGET = 3 -- mumble voice target (party talk uses 2)

-- Radio static (played by the HUD page). source: 'in' = someone on your channel, 'self' = you
local function sendRadioStatic(source, on)
    local S = RC.Static
    if not S or not S.Enabled then return end
    if source == 'in' and on and radioGain() <= 0.0 then return end -- muted, no signal or in a call: stay silent
    local vol = S.Volume
    if source == 'in' then vol = math.min(1.0, S.Volume * math.max(0.25, radioVol) + (1.0 - radioSignal) * 0.4) end
    SendNUIMessage({
        action = 'radioStatic', source = source, state = on, volume = vol,
        hiss = source == 'self' and S.SelfHiss or S.Hiss, squelch = S.Squelch,
    })
end

local function sendRadioHud()
    SendNUIMessage({
        action = 'radioHud',
        text   = (loaded and radio) and ('%s %s'):format(locale('ui_radio'), radio.freq) or '',
    })
end

local function buildRadioTarget()
    MumbleClearVoiceTarget(RADIO_TARGET)
    if not radio then return end
    for sid in pairs(radio.members) do
        if sid ~= myServerId then MumbleAddVoiceTargetPlayerByServerId(RADIO_TARGET, sid) end
    end
    if RC.NearbyHear then -- people next to you still hear you speak
        local myPos = GetEntityCoords(PlayerPedId())
        local range = Ranges[currentIdx].range
        for _, ply in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(ply)
            if sid ~= myServerId and not radio.members[sid] then
                local ped = GetPlayerPed(ply)
                if ped ~= 0 and #(myPos - GetEntityCoords(ped)) <= range then
                    MumbleAddVoiceTargetPlayerByServerId(RADIO_TARGET, sid)
                end
            end
        end
    end
end

local function setRadioTalk(state)
    if state == radioTalk then return end
    radioTalk = state
    if state then
        buildRadioTarget()
        MumbleSetVoiceTarget(RADIO_TARGET)
    else
        -- party talk or a phone call may own the voice target now: leave it alone
        if not callActive and not LocalPlayer.state.partyTalk then MumbleSetVoiceTarget(0) end
        MumbleClearVoiceTarget(RADIO_TARGET)
    end
    TriggerServerEvent('rsg-voice:server:radioTalk', state)
    sendRadioStatic('self', state)
    SendNUIMessage({ action = 'radioTalk', state = state })
    TriggerEvent('rsg-voice:client:onRadioTalk', state) -- local event for other resources (animations, sounds)
end

RegisterNetEvent('rsg-voice:client:radioUpdate', function(data)
    if GetInvokingResource() then return end -- only accept from server
    local hadTalkers = next(radioTalkers) ~= nil
    if not data or not data.freq then
        radio = nil
        radioTalkers = {}
        if radioTalk then setRadioTalk(false) end
    else
        local set = {}
        for _, sid in ipairs(data.members or {}) do set[sid] = true end
        radio = { freq = tostring(data.freq), members = set }
        for sid in pairs(radioTalkers) do
            if not set[sid] then radioTalkers[sid] = nil end
        end
    end
    if hadTalkers and next(radioTalkers) == nil then sendRadioStatic('in', false) end
    sendRadioHud()
    SetTimeout(0, updateVolumes)
end)

RegisterNetEvent('rsg-voice:client:radioTalk', function(sid, state)
    if GetInvokingResource() then return end
    if not radio or sid == myServerId or not radio.members[sid] then return end
    local before = next(radioTalkers) ~= nil
    radioTalkers[sid] = state == true or nil
    local after = next(radioTalkers) ~= nil
    if before ~= after then sendRadioStatic('in', after) end
    SetTimeout(0, updateVolumes)
end)

-- Transmit key. Preferred: RegisterKeyMapping (binds by key name, rebindable in the game's key settings, does not
-- depend on a control hash the game may not report). Fallback: the control hash in Config.Radio.TalkKey.
local radioKeyDown = false
local radioTick -- defined below: works out whether the radio should be transmitting
if RC.UseKeyMapping then
    -- allowWhileNui: rsg-radio's panel keeps game input, so the key must keep working while it is open
    bindKey('rsgvoice_radio', locale('ui_radio_key'), RC.Key or 'O',
        function() radioKeyDown = true if radioTick then radioTick() end end,
        function() radioKeyDown = false if radioTick then radioTick() end end,
        { allowWhileNui = true })
end
local function radioKeyHeld()
    if RC.UseKeyMapping then return radioKeyDown end
    return IsControlPressed(0, RC.TalkKey)
end

-- Radio key debug (Config.Radio.Debug): prints in F8 when the transmit key state changes and what blocks it
if RC.Debug then CreateThread(function()
    local last, beat, lastPressed = nil, 0, ''
    while true do
        do
            local down     = radioKeyHeld()
            local disabled = IsDisabledControlPressed(0, RC.TalkKey)
            local why = 'ok'
            if not loaded then why = 'voice not loaded'
            elseif not RC.Enabled then why = 'Config.Radio.Enabled is false'
            elseif not radio then why = 'not on a radio channel'
            elseif focus.menu or focus.invite then why = 'menu has focus'
            elseif isMuted() then why = 'muted'
            elseif LocalPlayer.state.partyTalk then why = 'party talk active'
            end
            local line = ('key %s down=%s disabled-down=%s | %s | transmitting=%s'):format(
                RC.UseKeyMapping and ('"' .. tostring(RC.Key) .. '" (key mapping)') or ('0x%X'):format(RC.TalkKey),
                tostring(down), tostring(disabled), why, tostring(radioTalk))
            local now = GetGameTimer()
            if (line ~= last and (down or disabled or radioTalk or (last and last:find('down=true'))))
                or now >= beat then
                beat = now + 3000 -- status line every 3 s even when nothing is pressed
                print(('^3[rsg-voice radio debug]^7 %s'):format(line))
            end
            last = line
            -- key finder: names of every known key the game currently reports as pressed
            local names = {}
            for name, hash in pairs((RSGCore.Shared and RSGCore.Shared.Keybinds) or {}) do
                if IsControlPressed(0, hash) or IsDisabledControlPressed(0, hash) then names[#names + 1] = name end
            end
            table.sort(names)
            local pressed = table.concat(names, '+')
            if pressed ~= lastPressed then
                lastPressed = pressed
                if pressed ~= '' then print(('^3[rsg-voice radio debug]^7 keys reported pressed: %s'):format(pressed)) end
            end
            Wait(0)
        end
    end
end) end

-- Hold-to-talk key. Runs on every key press/release and, as a safety net, in a loop (every frame when polling the control,
-- ten times a second with the key mapping, because the press and release events do the time-critical part).
local nextRebuild = 0
radioTick = function()
    if loaded and RC.Enabled and radio then
        do
            local now = GetGameTimer()
            local keyDown = radioKeyHeld()
            if not keyDown then radioLocked = false end
            local held = keyDown and not radioLocked and not radioInputBlocked and now >= radioCooldownUntil
                and not focus.menu and not focus.invite and not isMuted()
                and (PR.RadioVsParty == 'radio' or not LocalPlayer.state.partyTalk)
                and not callBlocks('BlockRadioTransmit') and radioSignal > 0.0
            if held and not radioTalk then radioTalkStart = now end
            local maxSec = tonumber(RC.MaxTransmitSeconds) or 0
            if held and radioTalk and maxSec > 0 and now - radioTalkStart >= maxSec * 1000 then
                held = false
                radioLocked = true -- the key has to be released first
                radioCooldownUntil = now + (tonumber(RC.TransmitCooldown) or 0) * 1000
                notify('cl_radio_timeout', 'inform', maxSec)
            end
            if held ~= radioTalk then setRadioTalk(held) end
            if radioTalk and GetGameTimer() >= nextRebuild then
                nextRebuild = GetGameTimer() + 1000
                buildRadioTarget() -- people moving in/out of your voice range
            end
        end
        return true
    end
    if radioTalk then setRadioTalk(false) end
    return false
end

CreateThread(function()
    while true do
        if radioTick() then Wait(RC.UseKeyMapping and 100 or 0) else Wait(500) end
    end
end)

-- The voice target alone does not open the microphone: with push-to-talk, Mumble only sends while the game's push-to-talk
-- control is held. SetControlValueNextFrame lasts a single frame, so it has to be called every frame (the loop above only
-- ticks 10x a second with the key mapping). This thread sleeps unless a radio transmission is active.
CreateThread(function()
    while true do
        if radioTalk and RC.ForcePushToTalk ~= false then
            Citizen.InvokeNative(0xE8A25867FBA3B05E, 0, 0x4BC9DABB, 1.0) -- SetControlValueNextFrame(INPUT_PUSH_TO_TALK)
            Wait(0)
        else
            Wait(200)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if radioTalk then
        MumbleSetVoiceTarget(0)
        MumbleClearVoiceTarget(RADIO_TARGET)
    end
end)

---------------------------------------------------------------------
-- Speaker icon above talking players
---------------------------------------------------------------------
if Config.TalkIcon.Enabled then
    CreateThread(function()
        local T = Config.TalkIcon
        RequestStreamedTextureDict(T.Dict, false)
        local timeout = GetGameTimer() + 5000
        while not HasStreamedTextureDictLoaded(T.Dict) and GetGameTimer() < timeout do Wait(50) end
        if not HasStreamedTextureDictLoaded(T.Dict) then return end
        while true do
            local list = nearby
            if T.ShowSelf then
                list = { { ply = PlayerId(), ped = PlayerPedId(), sid = myServerId } }
                for i = 1, #nearby do list[i + 1] = nearby[i] end
            end
            if loaded and #list > 0 then
                local myPos = GetEntityCoords(PlayerPedId())
                local anyTalking = false
                for i = 1, #list do
                    local n = list[i]
                    local isTalk = talking(n.ply)
                    if isTalk then anyTalking = true end
                    if isTalk and DoesEntityExist(n.ped) and IsEntityVisible(n.ped) then
                        local c = GetEntityCoords(n.ped)
                        local onScreen, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + T.ZOffset)
                        if onScreen then
                            local scale = 1.0 - (#(myPos - c) / T.Distance) * 0.5
                            local w = T.Size * scale
                            local pt = n.sid == myServerId and LocalPlayer.state.partyTalk or (party and Player(n.sid).state.partyTalk and isMember(n.sid))
                            local rt = radioTalkers[n.sid] or (n.sid == myServerId and radioTalk)
                            local col = rt and T.RadioColour or (pt and T.PartyColour or T.Colour)
                            DrawSprite(T.Dict, T.Texture, x, y, w, w * 1.77, 0.0, col.r, col.g, col.b, col.a, false)
                        end
                    end
                end
                Wait(anyTalking and 0 or 100)
            else
                Wait(250)
            end
        end
    end)
end

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('GetVoiceRange', function() return Ranges[currentIdx].range end)
exports('SetVoiceRangeIndex', function(i) setRange(tonumber(i), false) end)
exports('IsMuted', isMuted)
-- IsPlayerTalking() = you, IsPlayerTalking(serverId) = another player (must be streamed in)
exports('IsPlayerTalking', function(sid)
    if not sid then return talking(PlayerId()) end
    local ply = GetPlayerFromServerId(tonumber(sid) or -1)
    return ply ~= -1 and talking(ply)
end)
-- Client-side mute held by another resource (e.g. a gag). Use the server export for anything that must be enforced.
exports('SetMuteOverride', function(state, reason)
    reason = tostring(reason or GetInvokingResource() or 'script')
    scriptMutes[reason] = state and true or nil
    applyVoice()
end)
exports('GetPartyMembers', function()
    if not party then return nil end
    local list = {}
    for i, m in ipairs(party.members) do list[i] = { id = m.id, name = m.name, leader = m.leader } end
    return list
end)
exports('IsInParty', function() return party ~= nil end)
-- GetRadio() = { freq = 'x', members = { serverId, ... } } while on a radio channel, otherwise nil
exports('GetRadio', function()
    if not radio then return nil end
    local list = {}
    for sid in pairs(radio.members) do list[#list + 1] = sid end
    return { freq = radio.freq, members = list }
end)
exports('IsRadioTalking', function() return radioTalk end)
-- Radio listening settings and call priority (rsg-radio and rsg-telephone call these)
local function refreshVolumes() SetTimeout(0, function() if loaded then updateVolumes() end end) end
exports('SetRadioVolume', function(v) v = tonumber(v) if v then radioVol = math.max(0.0, math.min(1.0, v)) refreshVolumes() end end)
exports('GetRadioVolume', function() return radioVol end)
exports('SetRadioMuted', function(state) radioMuted = state == true refreshVolumes() end)
exports('IsRadioMuted', function() return radioMuted end)
exports('SetRadioSignal', function(q) q = tonumber(q) if q then radioSignal = math.max(0.0, math.min(1.0, q)) refreshVolumes() end end)
exports('GetRadioSignal', function() return radioSignal end)
exports('SetCallActive', function(state) callActive = state == true refreshVolumes() end)
exports('IsCallActive', function() return callActive end)
-- Volume test (rsg-radio's play button and /radiotest): plays a simulated incoming transmission through the live
-- settings. The level is radioGain(), the same value applied to real radio talkers, so it shows what the radio
-- volume, mute, signal and call priority really do right now. Returns the values it used and why it was silent.
exports('TestRadioIncoming', function()
    local gain = radioGain()
    local reason = (radioMuted and 'muted') or (radioSignal <= 0.0 and 'signal') or (callBlocks('MuteIncomingRadio') and 'call') or nil
    if RC.Debug then
        print(('[rsg-voice] radio test: gain %.2f (volume %.2f x signal %.2f), muted %s, call %s, silent because %s'):format(
            gain, radioVol, radioSignal, tostring(radioMuted), tostring(callActive), tostring(reason)))
    end
    if gain > 0.0 then SendNUIMessage({ action = 'radioTest', gain = gain, signal = radioSignal }) end
    return { gain = gain, volume = radioVol, signal = radioSignal, muted = radioMuted, call = callActive, reason = reason }
end)
exports('GetRadioTalkKey', function() return RC.TalkKey end) -- so other NUIs can keep the radio key working
-- Default transmit key name for hints ('O'), or nil when the key is read as a control hash (UseKeyMapping = false)
exports('GetRadioKeyLabel', function() if RC.UseKeyMapping then return RC.Key or 'O' end return nil end)
-- rsg-radio calls this while one of its text boxes has focus, so typing an 'o' does not key the mic
exports('SetRadioInputBlocked', function(state)
    radioInputBlocked = state == true
    if radioTick then radioTick() end
end)

---------------------------------------------------------------------
-- Riding party
---------------------------------------------------------------------
if not P.Enabled then
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then SetNuiFocusKeepInput(false); SetNuiFocus(false, false); clearOverrides() end
    end)
    return
end

local partyTalk    = false
local PARTY_TARGET = 2
local memberBlips  = {} -- [serverId] = blip
local waypoint     = nil -- { blip = blip, coords = vector3 }

local function buildTarget()
    MumbleClearVoiceTarget(PARTY_TARGET)
    for _, m in ipairs(party.members) do
        if m.id ~= myServerId and inTalkRange(m.id) then
            MumbleAddVoiceTargetPlayerByServerId(PARTY_TARGET, m.id)
        end
    end
end

local function setPartyTalk(state)
    if state == partyTalk then return end
    partyTalk = state
    if state then
        buildTarget()
        MumbleSetVoiceTarget(PARTY_TARGET)
    else
        if not radioTalk and not callActive then MumbleSetVoiceTarget(0) end
        MumbleClearVoiceTarget(PARTY_TARGET)
    end
    LocalPlayer.state:set('partyTalk', state, true)
    SendNUIMessage({ action = 'partyTalk', state = state })
end

-- Blips -------------------------------------------------------------
local function memberName(sid)
    if party then for _, m in ipairs(party.members) do if m.id == sid then return m.name end end end
    return ('#%s'):format(sid)
end

local function clearMemberBlips()
    for sid, blip in pairs(memberBlips) do RemoveBlip(blip); memberBlips[sid] = nil end
end

RegisterNetEvent('rsg-voice:client:partyPositions', function(list)
    if GetInvokingResource() or not party or not P.Blips.Enabled then return end
    local B, seen = P.Blips, {}
    for _, m in ipairs(list or {}) do
        if m.id ~= myServerId and isMember(m.id) then
            seen[m.id] = true
            local blip = memberBlips[m.id]
            if not blip then
                blip = BlipAddForCoords(1664425300, m.x, m.y, m.z)
                SetBlipSprite(blip, joaat(B.Sprite), true)
                SetBlipScale(blip, B.Scale)
                BlipAddModifier(blip, joaat(B.Modifier))
                SetBlipName(blip, memberName(m.id))
                memberBlips[m.id] = blip
            else
                SetBlipCoords(blip, m.x, m.y, m.z)
            end
        end
    end
    for sid, blip in pairs(memberBlips) do
        if not seen[sid] then RemoveBlip(blip); memberBlips[sid] = nil end
    end
end)

-- Waypoint sharing ----------------------------------------------------
local function clearWaypoint()
    if not waypoint then return end
    RemoveBlip(waypoint.blip)
    ClearGpsMultiRoute()
    waypoint = nil
end

local function setWaypoint(c, fromName)
    clearWaypoint()
    local W = P.Waypoint
    local blip = BlipAddForCoords(1664425300, c.x, c.y, c.z)
    SetBlipSprite(blip, joaat(W.Sprite), true)
    SetBlipName(blip, locale('cl_waypoint_blip', fromName))
    StartGpsMultiRoute(joaat(W.GpsColour), true, true)
    AddPointToGpsMultiRoute(c.x, c.y, c.z)
    SetGpsMultiRouteRender(true)
    waypoint = { blip = blip, coords = vector3(c.x, c.y, c.z) }
end

if P.Waypoint.Enabled then
    RegisterCommand(P.Waypoint.Command, function()
        if not loaded then return end
        if not party or #party.members < 2 then return notify('cl_not_in_party', 'error') end
        local coords
        if Citizen.InvokeNative(0x202B1BBFC6AB5EE4) then -- IS_WAYPOINT_ACTIVE
            local c = Citizen.InvokeNative(0x29B30D07C3F7873B, Citizen.ResultAsVector()) -- _GET_WAYPOINT_COORDS
            coords = { x = c.x, y = c.y, z = c.z }
        end
        TriggerServerEvent('rsg-voice:server:partyWaypoint', coords)
    end, false)

    RegisterNetEvent('rsg-voice:client:partyWaypoint', function(c, fromName)
        if GetInvokingResource() or not party then return end
        if c then
            setWaypoint(c, fromName)
            notify('cl_waypoint_received', 'inform', fromName)
        elseif waypoint then
            clearWaypoint()
            notify('cl_waypoint_cleared', 'inform')
        end
    end)

    -- Clear the shared waypoint on arrival (2D distance: waypoint Z is often 0)
    CreateThread(function()
        while true do
            Wait(1000)
            if waypoint then
                local p = GetEntityCoords(PlayerPedId())
                if #(vector2(p.x, p.y) - vector2(waypoint.coords.x, waypoint.coords.y)) <= P.Waypoint.ArriveDistance then
                    clearWaypoint()
                    notify('cl_waypoint_arrived', 'success')
                end
            end
        end
    end)
end

-- Menu ----------------------------------------------------------------
local function refreshMenu()
    local data = RSGCore.Functions.AwaitCallback('rsg-voice:server:getParty', 5000)
    if focus.menu and data then SendNUIMessage({ action = 'partyData', data = data }) end
end

local function closeMenu()
    focus.menu = false
    updateFocus()
    SendNUIMessage({ action = 'partyClose' })
end

local partyStrings
local function getPartyStrings()
    partyStrings = partyStrings or {
        title = locale('ui_party_title'), subtitle = locale('ui_party_subtitle'),
        members = locale('ui_party_members'), nearby = locale('ui_party_nearby'),
        none = locale('ui_party_none'), noNearby = locale('ui_party_no_nearby'),
        invite = locale('ui_party_invite'), kick = locale('ui_party_kick'),
        leave = locale('ui_party_leave'), leader = locale('ui_party_leader'),
        busy = locale('ui_party_busy'), refresh = locale('ui_party_refresh'),
        hint = locale('ui_party_hint'), close = locale('ui_party_close'),
        share = P.Waypoint.Enabled and locale('ui_party_share') or nil,
        inviteTitle = locale('cl_party_invite_title'),
        accept = locale('cl_party_accept'), decline = locale('cl_party_decline'),
    }
    return partyStrings
end

RegisterCommand(P.Command, function()
    if not loaded or focus.menu then return end
    focus.menu = true
    SendNUIMessage({ action = 'partyOpen', strings = getPartyStrings() })
    updateFocus()
    refreshMenu()
end, false)

RegisterNUICallback('partyClose', function(_, cb) closeMenu(); cb('ok') end)
RegisterNUICallback('partyRefresh', function(_, cb) cb('ok'); refreshMenu() end)
RegisterNUICallback('partyInvite', function(d, cb)
    cb('ok'); TriggerServerEvent('rsg-voice:server:partyInvite', tonumber(d.id)); Wait(1000); refreshMenu()
end)
-- kick/leave trigger a partyUpdate, which refreshes the open menu
RegisterNUICallback('partyKick', function(d, cb)
    cb('ok'); TriggerServerEvent('rsg-voice:server:partyKick', tonumber(d.id))
end)
RegisterNUICallback('partyLeave', function(_, cb)
    cb('ok'); TriggerServerEvent('rsg-voice:server:partyLeave')
end)
RegisterNUICallback('partyShare', function(_, cb)
    cb('ok'); ExecuteCommand(P.Waypoint.Command)
end)

RegisterNetEvent('rsg-voice:client:partyUpdate', function(data)
    if GetInvokingResource() then return end
    party = data
    if not party then
        setPartyTalk(false)
        clearMemberBlips()
        clearWaypoint()
    else
        for sid, blip in pairs(memberBlips) do -- members who left
            if not isMember(sid) then RemoveBlip(blip); memberBlips[sid] = nil end
        end
    end
    updateVolumes()
    SendNUIMessage({ action = 'partyHud', count = party and #party.members or 0 })
    if focus.menu then refreshMenu() end
end)

-- Invite dialog (NUI)
local inviteToken = 0
local function closeInvite()
    focus.invite = false
    updateFocus()
    SendNUIMessage({ action = 'inviteClose' })
end

RegisterNetEvent('rsg-voice:client:partyInvite', function(fromName, timeout)
    if GetInvokingResource() then return end
    inviteToken = inviteToken + 1
    local token = inviteToken
    focus.invite = true
    SendNUIMessage({ action = 'inviteOpen', strings = getPartyStrings(), timeout = timeout,
        body = locale('cl_party_invite_body', fromName) })
    updateFocus()
    SetTimeout(timeout * 1000, function()
        if focus.invite and token == inviteToken then closeInvite() end
    end)
end)

RegisterNUICallback('inviteRespond', function(d, cb)
    cb('ok')
    if not focus.invite then return end
    closeInvite()
    TriggerServerEvent('rsg-voice:server:partyRespond', d.accept == true)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    setPartyTalk(false)
    clearOverrides()
    clearMemberBlips()
    clearWaypoint()
    party = nil
    if focus.menu then closeMenu() end
    if focus.invite then closeInvite() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    if partyTalk then
        MumbleSetVoiceTarget(0)
        LocalPlayer.state:set('partyTalk', false, true)
    end
    clearOverrides()
    clearMemberBlips()
    clearWaypoint()
end)

-- Hold-to-talk key (same scheme as the radio key: press/release events plus a safety-net loop)
local nextRangeCheck = 0
local partyKeyDown = false
local partyTick
if Config.UseKeyMapping then
    bindKey('rsgvoice_party', locale('key_party'), P.Key or 'LBRACKET',
        function() partyKeyDown = true if partyTick then partyTick() end end,
        function() partyKeyDown = false if partyTick then partyTick() end end,
        { allowWhileNui = true })
end

partyTick = function()
    if loaded and party and #party.members > 1 then
        local keyDown = Config.UseKeyMapping and partyKeyDown or (not Config.UseKeyMapping and IsControlPressed(0, P.TalkKey))
        local held = keyDown and not focus.menu and not focus.invite and not isMuted() and (PR.RadioVsParty == 'party' or not radioTalk)
            and not callBlocks('BlockPartyTransmit')
        if held ~= partyTalk then setPartyTalk(held) end
        if partyTalk and GetGameTimer() >= nextRangeCheck then
            nextRangeCheck = GetGameTimer() + 1000
            buildTarget() -- members riding in/out of range
        end
        return true
    end
    if partyTalk then setPartyTalk(false) end
    return false
end

CreateThread(function()
    while true do
        if partyTick() then Wait(Config.UseKeyMapping and 100 or 0) else Wait(500) end
    end
end)
