local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Ranges      = Config.Ranges
local rangeCount  = #Ranges
local currentIdx  = 1
local maxRange    = 0.0
local stateMute   = false -- dead / last stand / cuffed
local adminMute   = false
local ringUntil   = 0
local loaded      = false
local hudVisible  = GetResourceKvpInt('rsg-voice:hudHidden') ~= 1

for i, r in ipairs(Ranges) do
    if r.default then currentIdx = i end
    if r.range > maxRange then maxRange = r.range end
end

local isTalking = MumbleIsPlayerTalking or NetworkIsPlayerTalking

local function isMuted() return stateMute or adminMute end

local function rangeLabel(i)
    local key = 'range_' .. Ranges[i].name
    local txt = locale(key)
    return (txt and txt ~= key) and txt or Ranges[i].name
end

local function notify(key, nType, ...)
    lib.notify({ title = locale('notify_title'), description = locale(key, ...), type = nType, duration = 3000 })
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
    adminMute = lib.callback.await('rsg-voice:server:isMuted', false) or false
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
    SetNuiFocus(true, true)
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
    SetNuiFocus(false, false)
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

RegisterNetEvent('rsg-voice:client:adminMute', function(state)
    if GetInvokingResource() then return end -- only accept from server
    adminMute = state == true
    applyVoice()
    notify(adminMute and 'cl_admin_muted' or 'cl_admin_unmuted', adminMute and 'error' or 'success')
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then init() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------
-- Threads
---------------------------------------------------------------------
-- Key input + range ring (per-frame only while logged in)
CreateThread(function()
    while true do
        if loaded then
            if IsControlJustReleased(0, Config.CycleKey) then cycleRange() end
            if GetGameTimer() < ringUntil then
                local c   = GetEntityCoords(cache.ped)
                local d   = Ranges[currentIdx].range * 2.0
                local col = Config.RingColour
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

-- Talking indicator (no need to poll every frame)
if Config.ShowHud then
    CreateThread(function()
        local last
        while true do
            if loaded then
                local t = isTalking(cache.playerId)
                local talking = t == true or t == 1
                if talking ~= last then
                    last = talking
                    SendNUIMessage({ action = 'talking', state = talking })
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
-- Exports
---------------------------------------------------------------------
exports('GetVoiceRange', function() return Ranges[currentIdx].range end)
exports('SetVoiceRangeIndex', function(i) setRange(tonumber(i), false) end)
exports('IsMuted', isMuted)

---------------------------------------------------------------------
-- Riding party
---------------------------------------------------------------------
if Config.Party.Enabled then
    local P           = Config.Party
    local party       = nil   -- payload from server
    local partyTalk   = false
    local menuOpen    = false
    local overrides   = {}    -- [serverId] = true while volume override is active
    local PARTY_TARGET = 2

    local function isMember(sid)
        if not party then return false end
        for _, m in ipairs(party.members) do if m.id == sid then return true end end
        return false
    end

    local function clearOverrides()
        for sid in pairs(overrides) do MumbleSetVolumeOverrideByServerId(sid, -1.0) end
        overrides = {}
    end

    local function inTalkRange(sid)
        local ply = GetPlayerFromServerId(sid)
        if ply == -1 then return false end -- not streamed in = too far
        local ped = GetPlayerPed(ply)
        if ped == 0 then return false end
        return #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) <= P.TalkRange
    end

    local function buildTarget()
        MumbleClearVoiceTarget(PARTY_TARGET)
        for _, m in ipairs(party.members) do
            if m.id ~= cache.serverId and inTalkRange(m.id) then
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

    local function refreshMenu()
        local data = lib.callback.await('rsg-voice:server:getParty', false)
        if menuOpen and data then SendNUIMessage({ action = 'partyData', data = data }) end
    end

    local function closeMenu()
        menuOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'partyClose' })
    end

    RegisterCommand(P.Command, function()
        if not loaded or menuOpen then return end
        menuOpen = true
        SendNUIMessage({ action = 'partyOpen', strings = {
            title = locale('ui_party_title'), subtitle = locale('ui_party_subtitle'),
            members = locale('ui_party_members'), nearby = locale('ui_party_nearby'),
            none = locale('ui_party_none'), noNearby = locale('ui_party_no_nearby'),
            invite = locale('ui_party_invite'), kick = locale('ui_party_kick'),
            leave = locale('ui_party_leave'), leader = locale('ui_party_leader'),
            busy = locale('ui_party_busy'), refresh = locale('ui_party_refresh'),
            hint = locale('ui_party_hint'),
        } })
        SetNuiFocus(true, true)
        refreshMenu()
    end, false)

    RegisterNUICallback('partyClose', function(_, cb) closeMenu(); cb('ok') end)
    RegisterNUICallback('partyRefresh', function(_, cb) cb('ok'); refreshMenu() end)
    RegisterNUICallback('partyInvite', function(d, cb)
        cb('ok'); TriggerServerEvent('rsg-voice:server:partyInvite', d.id); Wait(300); refreshMenu()
    end)
    -- kick/leave trigger a partyUpdate, which refreshes the open menu
    RegisterNUICallback('partyKick', function(d, cb)
        cb('ok'); TriggerServerEvent('rsg-voice:server:partyKick', d.id)
    end)
    RegisterNUICallback('partyLeave', function(_, cb)
        cb('ok'); TriggerServerEvent('rsg-voice:server:partyLeave')
    end)

    RegisterNetEvent('rsg-voice:client:partyUpdate', function(data)
        if GetInvokingResource() then return end
        party = data
        if not party then setPartyTalk(false) end
        -- drop overrides for players no longer in the party
        for sid in pairs(overrides) do
            if not isMember(sid) then
                MumbleSetVolumeOverrideByServerId(sid, -1.0)
                overrides[sid] = nil
            end
        end
        SendNUIMessage({ action = 'partyHud', count = party and #party.members or 0 })
        if menuOpen then refreshMenu() end
    end)

    local inviteToken = 0
    RegisterNetEvent('rsg-voice:client:partyInvite', function(fromName, timeout)
        if GetInvokingResource() then return end
        inviteToken = inviteToken + 1
        local token, answered = inviteToken, false
        CreateThread(function()
            local res = lib.alertDialog({
                header   = locale('cl_party_invite_title'),
                content  = locale('cl_party_invite_body', fromName),
                centered = true,
                cancel   = true,
                labels   = { confirm = locale('cl_party_accept'), cancel = locale('cl_party_decline') },
            })
            answered = true
            TriggerServerEvent('rsg-voice:server:partyRespond', res == 'confirm')
        end)
        -- only close our own dialog, never an unrelated one opened later
        SetTimeout(timeout * 1000, function()
            if not answered and token == inviteToken then lib.closeAlertDialog() end
        end)
    end)

    -- Hear party members at any distance while they party-talk
    AddStateBagChangeHandler('partyTalk', nil, function(bagName, _, value)
        local ply = GetPlayerFromStateBagName(bagName)
        if ply == 0 then return end
        local sid = GetPlayerServerId(ply)
        if sid == cache.serverId then return end
        if value and isMember(sid) and inTalkRange(sid) then
            MumbleSetVolumeOverrideByServerId(sid, 1.0)
            overrides[sid] = true
        elseif overrides[sid] then
            MumbleSetVolumeOverrideByServerId(sid, -1.0)
            overrides[sid] = nil
        end
    end)

    RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
        setPartyTalk(false)
        clearOverrides()
        party = nil
        if menuOpen then closeMenu() end
    end)

    AddEventHandler('onResourceStop', function(res)
        if res ~= GetCurrentResourceName() then return end
        if partyTalk then MumbleSetVoiceTarget(0) end
        clearOverrides()
    end)

    -- Re-check range of party members currently talking to us
    CreateThread(function()
        while true do
            Wait(1000)
            if party then
                for _, m in ipairs(party.members) do
                    local sid = m.id
                    if sid ~= cache.serverId then
                        local ply = GetPlayerFromServerId(sid)
                        local talking = ply ~= -1 and Player(sid).state.partyTalk
                        local want = talking and inTalkRange(sid) or false
                        if want and not overrides[sid] then
                            MumbleSetVolumeOverrideByServerId(sid, 1.0); overrides[sid] = true
                        elseif not want and overrides[sid] then
                            MumbleSetVolumeOverrideByServerId(sid, -1.0); overrides[sid] = nil
                        end
                    end
                end
            end
        end
    end)

    -- Hold-to-talk key
    local nextRangeCheck = 0
    CreateThread(function()
        while true do
            if loaded and party and #party.members > 1 then
                local held = IsControlPressed(0, P.TalkKey) and not isMuted() and not menuOpen
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
end
