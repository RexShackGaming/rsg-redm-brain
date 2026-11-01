local RES = GetCurrentResourceName()
local modelHash = joaat(Config.Model)

local spawned      = {}    -- machine id -> entity we created
local localBusy    = false
local busyTicket   = 0
local active       = nil   -- { id, coords, entity, isStarter } while a reading plays here
local preloadResult = {}
local handoverProp = nil
local prompt, promptGroup = nil, nil
local usingTarget  = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function debug(...)
    if Config.Debug then print('[' .. RES .. ']', ...) end
end

local function notify(msg, kind)
    lib.notify({ title = locale('machine'), description = msg, type = kind or 'inform', duration = 5000 })
end

local function loadDict(dict, untilMs)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > untilMs then return false end
        Wait(20)
    end
    return true
end

local function loadModel(hash, untilMs)
    if HasModelLoaded(hash) then return true end
    RequestModel(hash, false)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > untilMs then return false end
        Wait(20)
    end
    return true
end

local function findEntity(coords)
    local e = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.5, modelHash, false, false, false)
    if e ~= 0 and DoesEntityExist(e) then return e end
end

-- Machine key + coords for an entity, or nil if it isn't usable.
-- The server re-derives the key itself; this is only for local checks.
local function keyFor(entity)
    local c = GetEntityCoords(entity)
    if Config.UseConfiguredMachines then
        for _, m in ipairs(Config.Machines) do
            if m.enabled ~= false then
                local mc = vector3(m.coords.x, m.coords.y, m.coords.z)
                if #(c - mc) < 1.5 then return m.id, mc end
            end
        end
    end
    if Config.AutoDetectExistingProps then
        return Fortune.WorldKey(c.x, c.y, c.z), c
    end
end

local function priceLabel()
    if Config.Price > 0 then return locale('use', Config.Price) end
    return locale('free')
end

-- ---------------------------------------------------------------------------
-- NUI audio (CustomLines)
-- ---------------------------------------------------------------------------
RegisterNUICallback('preloaded', function(data, cb)
    if type(data) == 'table' and type(data.file) == 'string' then
        preloadResult[data.file] = data.ok and 'ok' or 'fail'
    end
    cb('ok')
end)

local function preload(file, untilMs)
    preloadResult[file] = nil
    SendNUIMessage({ action = 'preload', file = file })
    while not preloadResult[file] and GetGameTimer() < untilMs do Wait(50) end
    return preloadResult[file] == 'ok'
end

-- ---------------------------------------------------------------------------
-- Speech (struct layout from Sarbatore/rdr_natives)
-- ---------------------------------------------------------------------------
local speechParamHash = type(Config.SpeechParam) == 'string' and joaat(Config.SpeechParam) or 0xF85DD899

local function literalStringLong(str)
    return Citizen.InvokeNative(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', str, Citizen.ResultAsLong())
end

local function playAmbientSpeech(ped, speechRef, speechName, speechLine, paramHash)
    local buffer = DataView.ArrayBuffer(7 * 8)
        :SetInt64(0 * 8, literalStringLong(speechName))
        :SetInt64(1 * 8, literalStringLong(speechRef))
        :SetInt32(2 * 8, speechLine or 0)
        :SetInt64(3 * 8, paramHash or 0xF85DD899)
        :SetInt32(4 * 8, 0) -- listener
        :SetInt32(5 * 8, 0) -- syncOverNetwork: off, every listener plays it locally
        :SetInt32(6 * 8, 1)
        :Buffer()
    local ok = Citizen.InvokeNative(0x8E04FEDD28D42462, ped, buffer) -- PLAY_PED_AMBIENT_SPEECH_NATIVE
    local success = ok == 1 or ok == true
    debug(('speech ok=%s ref=%s name=%s line=%s'):format(tostring(success), speechRef, speechName, tostring(speechLine)))
    return success
end

local function playMechanicalClick(coords)
    pcall(function()
        local sid = GetSoundId()
        Citizen.InvokeNative(0x6FB1DA3CA9DA7D90, sid, 'fortune_teller', coords.x, coords.y, coords.z, 'fortune_teller_soundset', false, 0, true)
        SetTimeout(3000, function() ReleaseSoundId(sid) end)
    end)
end

local function playLine(line, coords)
    local dist = #(GetEntityCoords(PlayerPedId()) - coords)
    if dist > Config.HearingDistance then return end

    if line.file then
        local vol = (line.volume or 1.0) * Config.Volume * math.max(0.0, 1.0 - dist / Config.HearingDistance)
        SendNUIMessage({ action = 'play', file = line.file, volume = vol })
        return
    end

    local fullName = line.variation and line.variation > 0 and ('%s_%02d'):format(line.speech, line.variation) or line.speech
    local ped = PlayerPedId()

    for _, voice in ipairs(Config.Voices) do
        Citizen.InvokeNative(0x6C8065A3B780185B, ped, voice) -- SET_AMBIENT_VOICE_NAME
        if playAmbientSpeech(ped, voice, fullName, 0, speechParamHash)
            or (line.variation and playAmbientSpeech(ped, voice, line.speech, line.variation, speechParamHash)) then
            return
        end
    end

    playMechanicalClick(coords)
    debug('all voices failed for ' .. fullName .. '; mechanical click only')
end

-- ---------------------------------------------------------------------------
-- Machine anim + handover
-- ---------------------------------------------------------------------------
local function playMachineAnim(entity)
    if not entity then return end
    pcall(PlayEntityAnim, entity, Config.MachineAnim.clip, Config.MachineAnim.dictionary, 1000.0, false, true, false, 0.0, 0)
end

local function clearHandoverProp()
    if handoverProp and DoesEntityExist(handoverProp) then
        DeleteEntity(handoverProp)
    end
    handoverProp = nil
end

local function playHandover()
    local h = Config.Handover
    local ped = PlayerPedId()
    local endsAt = GetGameTimer() + h.durationMs

    if not loadDict(h.dictionary, GetGameTimer() + 5000) then
        debug('handover dict failed to load')
        Wait(math.max(0, endsAt - GetGameTimer())) -- keep the shared timeline in sync
        return
    end

    TaskPlayAnim(ped, h.dictionary, h.clip, h.blendIn, h.blendOut, h.durationMs, h.flag, 0.0, false, false, false)

    if h.prop.enabled then
        local propHash = joaat(h.prop.model)
        if loadModel(propHash, GetGameTimer() + 2000) then
            local c = GetEntityCoords(ped)
            -- Local (non-networked) prop: purely cosmetic, nothing to sync
            handoverProp = CreateObject(propHash, c.x, c.y, c.z, false, false, false)
            SetModelAsNoLongerNeeded(propHash)
            if handoverProp ~= 0 then
                AttachEntityToEntity(handoverProp, ped, GetPedBoneIndex(ped, h.prop.bone), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    false, false, false, false, 2, true, false, false)
                SetEntityVisible(handoverProp, false)
                Wait(h.prop.visibleAfterMs or 300)
                if handoverProp and DoesEntityExist(handoverProp) then SetEntityVisible(handoverProp, true) end
            end
        end
    end

    Wait(math.max(0, endsAt - GetGameTimer()))
    clearHandoverProp()
    RemoveAnimDict(h.dictionary)
end

-- ---------------------------------------------------------------------------
-- Reading playback
-- ---------------------------------------------------------------------------
local function stopReading()
    local a = active
    active = nil
    if a then
        SendNUIMessage({ action = 'stop' })
        if a.entity and DoesEntityExist(a.entity) then
            StopEntityAnim(a.entity, Config.MachineAnim.clip, Config.MachineAnim.dictionary, 0)
        end
        -- Only the paying player was animated; never clear a bystander's tasks
        if a.isStarter then
            clearHandoverProp()
            StopAnimTask(PlayerPedId(), Config.Handover.dictionary, Config.Handover.clip, 1.0)
        end
    end
    localBusy = false
end

local function runReading(id, coords, sequence, isStarter)
    stopReading()
    local entity = findEntity(coords)
    active = { id = id, coords = coords, entity = entity, isStarter = isStarter }
    localBusy = isStarter

    local function alive() return active and active.id == id end

    playMachineAnim(entity)

    if Config.Light.enabled then
        CreateThread(function()
            local lt = Config.Light
            while alive() do
                DrawLightWithRange(coords.x, coords.y, coords.z + 1.0, lt.red, lt.green, lt.blue, lt.range, lt.intensity)
                Wait(0)
            end
        end)
    end

    -- Payer hands over cash; listeners wait the same beat to stay in sync
    if Config.Handover.enabled then
        if isStarter then playHandover() else Wait(Config.Handover.durationMs) end
    end
    if not alive() then return end

    Wait(Config.StartDelayMs)

    for i, line in ipairs(sequence) do
        if not alive() then return end
        playLine(line, coords)
        Wait(math.floor((line.duration + Config.SpeechPaddingSeconds) * 1000))
        if i < #sequence then Wait(math.floor(Config.PauseBetweenLines * 1000)) end
    end

    if alive() then stopReading() end
end

-- Payer walks up to the machine and faces it
local function approachMachine(coords, untilMs)
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local dx, dy = pc.x - coords.x, pc.y - coords.y
    local len = math.sqrt(dx * dx + dy * dy)

    if len > Config.Approach.distance + 0.4 then
        local tx = coords.x + dx / len * Config.Approach.distance
        local ty = coords.y + dy / len * Config.Approach.distance
        TaskGoStraightToCoord(ped, tx, ty, pc.z, 1.0, 3000, GetHeadingFromVector_2d(-dx, -dy), 0.1)
        local stop = math.min(untilMs, GetGameTimer() + 3000)
        while GetGameTimer() < stop do
            local p = GetEntityCoords(ped)
            if #(vector2(p.x, p.y) - vector2(tx, ty)) < 0.35 then break end
            Wait(50)
        end
    end

    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z + Config.Approach.lookHeight, 600)
    Wait(650)
end

-- ---------------------------------------------------------------------------
-- Server events
-- ---------------------------------------------------------------------------
RegisterNetEvent(RES .. ':client:deny', function(msgKey, arg)
    notify(locale(msgKey, arg), 'error')
    if not active then localBusy = false end
end)

RegisterNetEvent(RES .. ':client:begin', function(id, coords, sequence)
    CreateThread(function()
        local untilMs = GetGameTimer() + Config.PrepareTimeoutSeconds * 1000

        local function fail(msgKey)
            notify(locale(msgKey), 'error')
            TriggerServerEvent(RES .. ':server:failed', id)
            localBusy = false
        end

        if not findEntity(coords) then return fail('setupFailed') end
        if not loadDict(Config.MachineAnim.dictionary, untilMs) then return fail('setupFailed') end

        for _, line in ipairs(sequence) do
            if line.file and not preload(line.file, untilMs) then return fail('audioFailed') end
        end

        if Config.Handover.enabled then
            loadDict(Config.Handover.dictionary, untilMs) -- optional, reading still plays without it
        end
        approachMachine(coords, untilMs)

        TriggerServerEvent(RES .. ':server:ready', id)
    end)
end)

RegisterNetEvent(RES .. ':client:play', function(id, coords, sequence, starter)
    local isStarter = starter == GetPlayerServerId(PlayerId())
    CreateThread(function() runReading(id, coords, sequence, isStarter) end)
end)

RegisterNetEvent(RES .. ':client:stop', function(id)
    if active and active.id == id then stopReading() end
end)

-- ---------------------------------------------------------------------------
-- Interaction
-- ---------------------------------------------------------------------------
local function startInteraction(entity)
    if localBusy or not entity or not DoesEntityExist(entity) then return end
    local key, c = keyFor(entity)
    if not key then return end

    localBusy = true
    busyTicket = busyTicket + 1
    local ticket = busyTicket
    TriggerServerEvent(RES .. ':server:request', key, c.x, c.y, c.z)

    -- Safety net: if the server never answers, unlock (does not apply once playing)
    SetTimeout((Config.PrepareTimeoutSeconds + 10) * 1000, function()
        if localBusy and not active and busyTicket == ticket then localBusy = false end
    end)
end

local function canUse(entity)
    return not localBusy and not IsPedDeadOrDying(PlayerPedId(), true) and keyFor(entity) ~= nil
end

local function setupTarget()
    exports.ox_target:addModel(modelHash, {
        {
            name = 'rsg_fortuneteller',
            icon = Config.TargetIcon,
            label = priceLabel(),
            distance = Config.InteractionDistance,
            canInteract = function(entity) return canUse(entity) end,
            onSelect = function(data) startInteraction(data.entity) end,
        },
    })
end

local function setupPrompt()
    promptGroup = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.PromptKey)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', priceLabel()))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)

    local title = CreateVarString(10, 'LITERAL_STRING', locale('machine'))

    CreateThread(function()
        while true do
            local wait = 1000
            if not localBusy then
                local pc = GetEntityCoords(PlayerPedId())
                local entity = GetClosestObjectOfType(pc.x, pc.y, pc.z, Config.InteractionDistance, modelHash, false, false, false)
                if entity ~= 0 and canUse(entity) then
                    wait = 0
                    PromptSetActiveGroupThisFrame(promptGroup, title)
                    if PromptHasStandardModeCompleted(prompt, 0) then
                        startInteraction(entity)
                    end
                end
            end
            Wait(wait)
        end
    end)
end

CreateThread(function()
    local mode = Config.Interaction
    if mode ~= 'prompt' and GetResourceState('ox_target') ~= 'missing' then
        local tries = 0
        while GetResourceState('ox_target') ~= 'started' and tries < 100 do
            tries = tries + 1
            Wait(100)
        end
        usingTarget = GetResourceState('ox_target') == 'started'
    end
    if usingTarget then setupTarget() else setupPrompt() end
end)

-- ---------------------------------------------------------------------------
-- Spawning configured machines (streamed in/out by distance)
-- ---------------------------------------------------------------------------
local function spawnMachine(m)
    local x, y, z = m.coords.x, m.coords.y, m.coords.z

    -- Don't double up if the map already has a machine here
    if GetClosestObjectOfType(x, y, z, 1.0, modelHash, false, false, false) ~= 0 then return false end

    if not loadModel(modelHash, GetGameTimer() + 5000) then return nil end
    local obj = CreateObject(modelHash, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)
    if obj == 0 then return nil end

    SetEntityHeading(obj, m.coords.w)
    FreezeEntityPosition(obj, true)
    return obj
end

CreateThread(function()
    if not Config.UseConfiguredMachines then return end
    local list = {}
    for _, m in ipairs(Config.Machines) do
        if m.enabled ~= false and m.spawn then
            list[#list + 1] = { m = m, pos = vector3(m.coords.x, m.coords.y, m.coords.z) }
        end
    end
    if #list == 0 then return end

    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for _, entry in ipairs(list) do
            local id = entry.m.id
            local dist = #(pc - entry.pos)
            local ent = spawned[id]
            if ent == nil and dist <= Config.StreamDistance then
                spawned[id] = spawnMachine(entry.m) -- false = map prop already there
            elseif ent ~= nil and dist > Config.StreamDistance + 20.0 then
                if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
                spawned[id] = nil
            end
        end
        Wait(1500)
    end
end)

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------
RegisterCommand(Config.CoordinatesCommand, function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    print(('[%s] vector4(%.2f, %.2f, %.2f, %.2f)'):format(RES, c.x, c.y, c.z, GetEntityHeading(ped)))
    notify(locale('coordinates'))
end, false)

if Config.Debug then
    -- /fortunetest <lineId> — plays one fortune line from your position
    RegisterCommand('fortunetest', function(_, args)
        local want = tonumber(args[1]) or 1
        for _, line in ipairs(Config.Lines) do
            if line.id == want then return playLine(line, GetEntityCoords(PlayerPedId())) end
        end
        print(('[%s] no line with id=%s'):format(RES, tostring(want)))
    end, false)

    -- /fortunespeech — plays a known-working ambient line to prove the native works
    RegisterCommand('fortunespeech', function()
        playAmbientSpeech(PlayerPedId(), '0315_U_M_M_NbxDoctor_01', 'CHAT_PEDTYPE_DIALOG', 0, 0xF85DD899)
    end, false)
end

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    stopReading()
    clearHandoverProp()
    if usingTarget then exports.ox_target:removeModel(modelHash, 'rsg_fortuneteller') end
    if prompt then PromptDelete(prompt) end
    for _, ent in pairs(spawned) do
        if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
end)
