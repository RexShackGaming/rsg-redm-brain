local session = nil -- active attempt: { cb, token, startedAt }
local uiFocus = false
local animPlaying = false
local lastSfx = 0

---------------------------------------------------------------------------
-- NUI focus (keeps push-to-talk working while the UI is open)
---------------------------------------------------------------------------
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

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

---------------------------------------------------------------------------
-- Animation (optional, see Config.Animation)
---------------------------------------------------------------------------
local function startAnim()
    local a = Config.Animation
    if not a or not a.Enabled then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return end
    RequestAnimDict(a.Dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(a.Dict) and GetGameTimer() < timeout do Wait(0) end
    if not HasAnimDictLoaded(a.Dict) or not session then return end
    TaskPlayAnim(ped, a.Dict, a.Name, 8.0, -8.0, -1, a.Flag or 1, 0, false, false, false)
    animPlaying = true
end

local function stopAnim()
    if not animPlaying then return end
    animPlaying = false
    local a = Config.Animation
    StopAnimTask(PlayerPedId(), a.Dict, a.Name, 1.0)
    RemoveAnimDict(a.Dict)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function getLabels()
    return {
        title     = locale('title'),
        rotate    = locale('hint_rotate'),
        push      = locale('hint_push'),
        cancel    = locale('hint_cancel'),
        picks     = locale('picks'),
        condition = locale('condition'),
        unlocked  = locale('unlocked'),
        broken    = locale('broken'),
        time      = locale('time'),
        timeUp    = locale('time_up'),
    }
end

local function closeUi()
    SendNUIMessage({ action = 'close' })
    stopAnim()
    uiFocus = false
    applyNuiFocus(false)
end

-- Ends the attempt exactly once, closes the UI, then reports to the caller:
-- callback(success: boolean, outcome: 'success' | 'fail' | 'cancel')
local function finish(outcome)
    local s = session
    if not s then return end
    session = nil
    closeUi()
    if s.cb then
        local ok, err = pcall(s.cb, outcome == 'success', outcome)
        if not ok then
            print(('^1[rsg-lockpick]^7 caller callback error: %s'):format(tostring(err)))
        end
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
-- resolved = true when the options already come from the server (only clamped, presets not applied again)
local function openLockpick(callback, options, resolved)
    if type(callback) ~= 'function' then return false end

    -- one attempt at a time; a refused request is answered "cancel" so callers never hang
    if session or IsEntityDead(PlayerPedId()) then
        pcall(callback, false, 'cancel')
        return false
    end

    local opts
    if resolved then
        opts = Config.Clamp(options)
    else
        opts = Config.Build(type(options) == 'table' and options.preset or nil, options)
    end

    local token = ('%d-%d'):format(GetGameTimer(), math.random(100000, 999999))
    session = { cb = callback, token = token, startedAt = GetGameTimer() }

    uiFocus = true
    applyNuiFocus(true)
    SetCursorLocation(Config.CursorStart.x, Config.CursorStart.y)
    SendNUIMessage({
        action      = 'open',
        token       = token,
        options     = opts,
        labels      = getLabels(),
        resultDelay = Config.ResultDelay,
        controller  = Config.Controller == true,
    })
    CreateThread(startAnim)
    return true
end

-- Event API (backward compatible): TriggerEvent('rsg-lockpick:client:openLockpick', function(success, outcome) end [, options])
-- options may include preset = 'easy' | 'medium' | 'hard'
AddEventHandler('rsg-lockpick:client:openLockpick', function(callback, options)
    openLockpick(callback, options)
end)

-- Blocking export: returns success (boolean), outcome. Call from a thread or event handler.
exports('Lockpick', function(options)
    local p = promise.new()
    openLockpick(function(success, outcome) p:resolve({ success, outcome }) end, options)
    local r = Citizen.Await(p)
    return r[1], r[2]
end)

exports('IsLockpicking', function()
    return session ~= nil
end)

exports('CancelLockpick', function()
    finish('cancel')
end)

---------------------------------------------------------------------------
-- Server-issued attempts: the server decides the difficulty and validates the result
---------------------------------------------------------------------------
RegisterNetEvent('rsg-lockpick:client:ticketStart', function(ticketId, options)
    if type(ticketId) ~= 'string' then return end
    openLockpick(function(_, outcome)
        TriggerServerEvent('rsg-lockpick:server:ticketResult', ticketId, outcome)
    end, options, true)
end)

RegisterNetEvent('rsg-lockpick:client:ticketCancel', function()
    finish('cancel')
end)

---------------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------------
RegisterNUICallback('result', function(data, cb)
    cb('ok')
    if not session or type(data) ~= 'table' or data.token ~= session.token then return end
    local outcome = data.success == true and 'success' or 'fail'
    if outcome == 'success' and (GetGameTimer() - session.startedAt) < Config.MinSolveTime then
        outcome = 'fail'
    end
    finish(outcome)
end)

RegisterNUICallback('exit', function(_, cb)
    cb('ok')
    finish('cancel')
end)

RegisterNUICallback('sfx', function(data, cb)
    cb('ok')
    if not session or type(data) ~= 'table' then return end
    local snds = Config.Sounds
    if not snds or not snds.enabled then return end
    local snd = snds[data.name]
    if type(snd) ~= 'table' then return end
    local now = GetGameTimer()
    if now - lastSfx < 80 then return end
    lastSfx = now
    PlaySoundFrontend(snd.name, snd.set, true, 0)
end)

---------------------------------------------------------------------------
-- Control whitelist + safety watchdog
---------------------------------------------------------------------------
CreateThread(function()
    local nextCheck = 0
    while true do
        if uiFocus then
            Wait(0)
            if Config.AllowPushToTalkWhileOpen then runPttWhitelist() end
            local now = GetGameTimer()
            if now >= nextCheck then
                nextCheck = now + 500
                if session and IsEntityDead(PlayerPedId()) then finish('cancel') end
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if session then
        local s = session
        session = nil
        if s.cb then pcall(s.cb, false, 'cancel') end
    end
    stopAnim()
    if uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
end)
