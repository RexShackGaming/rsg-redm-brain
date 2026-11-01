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
local hudVisible  = GetResourceKvpInt('rsg-voice:hudHidden') ~= 1
local P           = Config.Party
local party       = nil   -- party payload from the server (nil when not in a party)

-- NUI focus owners: only release focus when nothing needs it
local focus = { edit = false, menu = false, invite = false }
local function updateFocus()
    local on = focus.edit or focus.menu or focus.invite
    SetNuiFocus(on, on)
end

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
    LocalPlayer.state:set('voiceRange', range, true)
    sendHud()
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
-- Key input + range ring (per-frame only while logged in)
CreateThread(function()
    while true do
        if loaded then
            if not focus.menu and not focus.invite and IsControlJustReleased(0, Config.CycleKey) then cycleRange() end
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
            Wait(500)
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
local myServerId = GetPlayerServerId(PlayerId())

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

local function desiredVolume(sid, ped, myPos, myInterior)
    if party and Player(sid).state.partyTalk and isMember(sid)
        and #(myPos - GetEntityCoords(ped)) <= P.TalkRange then
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
                for i = 1, #list do
                    local n = list[i]
                    if talking(n.ply) and DoesEntityExist(n.ped) and IsEntityVisible(n.ped) then
                        local c = GetEntityCoords(n.ped)
                        local onScreen, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + T.ZOffset)
                        if onScreen then
                            local scale = 1.0 - (#(myPos - c) / T.Distance) * 0.5
                            local w = T.Size * scale
                            local pt = n.sid == myServerId and LocalPlayer.state.partyTalk or (party and Player(n.sid).state.partyTalk and isMember(n.sid))
                            local col = pt and T.PartyColour or T.Colour
                            DrawSprite(T.Dict, T.Texture, x, y, w, w * 1.77, 0.0, col.r, col.g, col.b, col.a, false)
                        end
                    end
                end
                Wait(0)
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

---------------------------------------------------------------------
-- Riding party
---------------------------------------------------------------------
if not P.Enabled then
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then SetNuiFocus(false, false); clearOverrides() end
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
        MumbleSetVoiceTarget(0)
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
    SetNuiFocus(false, false)
    if partyTalk then
        MumbleSetVoiceTarget(0)
        LocalPlayer.state:set('partyTalk', false, true)
    end
    clearOverrides()
    clearMemberBlips()
    clearWaypoint()
end)

-- Hold-to-talk key
local nextRangeCheck = 0
CreateThread(function()
    while true do
        if loaded and party and #party.members > 1 then
            local held = not focus.menu and not focus.invite and not isMuted() and IsControlPressed(0, P.TalkKey)
            if held ~= partyTalk then setPartyTalk(held) end
            if partyTalk and GetGameTimer() >= nextRangeCheck then
                nextRangeCheck = GetGameTimer() + 1000
                buildTarget() -- members riding in/out of range
            end
            Wait(0)
        else
            if partyTalk then setPartyTalk(false) end
            Wait(500)
        end
    end
end)
