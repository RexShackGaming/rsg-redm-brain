-- ===================== HORSE ACTIONS =====================
-- Rest, sleep, graze, roll, rear up and stay on command for the player's active horse.
-- Scenarios: RDR3 decompiled scripts (1436, player_horse.c / ambient scenario tables) and
-- rdr3_discoveries animations/scenarios/scenario_types_with_conditional_anims.lua.
-- Horse action ids: rdr3_discoveries tasks/TASK_HORSE_ACTION. Natives: rsg-redm-brain natives/db.
lib.locale()

local CFG = Config.HorseActions
if not (CFG and CFG.enabled) then return end

local current = nil -- { id, horse, regen }

local function horseNearby()
    local horse = GetActiveHorseEntity and GetActiveHorseEntity()
    if not horse then
        lib.notify({ description = locale('no_active_horse'), type = 'error' })
        return nil
    end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(horse)) > (CFG.maxDistance or 6.0) then
        lib.notify({ description = locale('must_be_near_horse'), type = 'error' })
        return nil
    end
    return horse
end

local function loadDict(dict)
    if not dict then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(50) end
    return HasAnimDictLoaded(dict)
end

-- TaskPlayAnim(ped, dict, clip, blendIn, blendOut, duration, flag, playbackRate, ...) — flag 1 = loop, 2 = hold last frame
local function playAnim(horse, dict, clip, loop)
    if not loadDict(dict) then return 0 end
    TaskPlayAnim(horse, dict, clip, 2.0, -2.0, -1, loop and 1 or 2, 0.0, false, 0, false, '', false)
    return math.floor((GetAnimDuration(dict, clip) or 0) * 1000)
end

local function stopAction(silent)
    if current and DoesEntityExist(current.horse) then
        local a = current.anim
        if a and a.exitDict and IsEntityPlayingAnim(current.horse, a.dict, a.base, 3) then
            local horse, ms = current.horse, playAnim(current.horse, a.exitDict, a.exit, false)
            current = nil
            CreateThread(function()
                Wait(ms > 0 and ms or 2000)
                if DoesEntityExist(horse) then ClearPedTasks(horse, true, true) end
            end)
        else
            ClearPedTasks(current.horse, true, true)
        end
        if not silent then lib.notify({ description = locale('action_stopped'), type = 'inform' }) end
    end
    current = nil
end

local function regenLoop(token)
    local r = CFG.restRegen
    if not (r and r.enabled) then return end
    CreateThread(function()
        while current == token do
            Wait(r.interval or 5000)
            if current ~= token or not DoesEntityExist(token.horse) then return end
            for core, add in pairs({ [0] = r.health or 0, [1] = r.stamina or 0 }) do
                if add > 0 then
                    local v = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, token.horse, core)) or 0 -- _GET_ATTRIBUTE_CORE_VALUE
                    Citizen.InvokeNative(0xC6258F41D86676E0, token.horse, core, math.min(100, v + add)) -- _SET_ATTRIBUTE_CORE_VALUE
                end
            end
        end
    end)
end

-- drop our state once the horse is ridden, whistled or otherwise re-tasked
local function watchLoop(token)
    CreateThread(function()
        Wait(3000) -- give the scenario time to start
        while current == token do
            local h = token.horse
            if not DoesEntityExist(h) or IsEntityDead(h) or GetMount(cache.ped) == h then current = nil return end
            if token.scenario and not IsPedUsingAnyScenario(h) then current = nil return end
            if token.anim and token.animReady and not IsEntityPlayingAnim(h, token.anim.dict, token.anim.base, 3) then current = nil return end
            Wait(1000)
        end
    end)
end

local function startAction(action)
    local horse = horseNearby()
    if not horse then return end
    if current then stopAction(true) end

    if action.scenario then
        ClearPedTasks(horse, true, true)
        TaskStartScenarioInPlaceHash(horse, joaat(action.scenario), -1, true, 0, GetEntityHeading(horse), false)
    elseif action.anim then
        ClearPedTasks(horse, true, true)
        local token = { id = action.id, horse = horse, anim = action.anim }
        current = token
        lib.notify({ description = locale('action_' .. action.id .. '_started'), type = 'success' })
        CreateThread(function()
            local a = action.anim
            if a.enterDict then
                local ms = playAnim(horse, a.enterDict, a.enter, false)
                Wait(ms > 0 and ms or 2500)
            end
            if current ~= token or not DoesEntityExist(horse) then return end
            playAnim(horse, a.dict, a.base, true)
            Wait(500)
            token.animReady = true
            if action.regen then regenLoop(token) end
            watchLoop(token)
        end)
        return
    elseif action.horseAction then
        Citizen.InvokeNative(0xA09CFD29100F06C3, horse, action.horseAction, 0, 0) -- TASK_HORSE_ACTION
        return -- one-shot, nothing to track
    elseif action.follow then
        local f = action.follow
        ClearPedTasks(horse, true, true)
        local function task()
            -- TASK_FOLLOW_TO_OFFSET_OF_ENTITY(ped, entity, x, y, z, speed, timeout, stoppingRange, persist, p9, walkOnly, p11, p12, p13)
            Citizen.InvokeNative(0x304AE42E357B8C7E, horse, cache.ped, f.offset.x, f.offset.y, f.offset.z,
                f.speed or 3.0, -1, f.stoppingRange or 1.0, true, false, false, false, false, false)
        end
        task()
        local token = { id = action.id, horse = horse }
        current = token
        lib.notify({ description = locale('action_follow_started'), type = 'success' })
        watchLoop(token)
        CreateThread(function()
            while current == token and DoesEntityExist(horse) do
                Wait(2000)
                if current ~= token then return end
                local d = #(GetEntityCoords(cache.ped) - GetEntityCoords(horse))
                if d > (f.teleportDistance or 60.0) and not IsPedOnMount(cache.ped) then
                    local p = GetOffsetFromEntityInWorldCoords(cache.ped, f.offset.x, f.offset.y - 3.0, 0.0)
                    SetEntityCoords(horse, p.x, p.y, p.z, false, false, false, true)
                    task()
                end
            end
        end)
        return
    elseif action.stay then
        ClearPedTasks(horse, true, true)
        TaskStandStill(horse, -1)
    end

    current = { id = action.id, horse = horse, scenario = action.scenario ~= nil }
    lib.notify({ description = locale('action_' .. action.id .. '_started'), type = 'success' })
    if action.regen then regenLoop(current) end
    watchLoop(current)
end

local nuiOpen = false

local function closeActionsNui()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'actionsClose' })
end

function OpenHorseActionsMenu()
    if not horseNearby() then return end
    local list = {}
    for _, action in ipairs(CFG.actions) do
        list[#list + 1] = {
            id = action.id,
            glyph = action.glyph,
            label = locale('action_' .. action.id),
            desc = locale('action_' .. action.id .. '_desc'),
        }
    end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'actionsOpen',
        actions = list,
        current = current and current.id or nil,
        horseName = GetActiveHorseName and GetActiveHorseName() or '',
        strings = {
            title = locale('target_actions'), close = locale('ui_close'), active = locale('action_active'),
            stop = locale('action_stop'), stop_desc = locale('action_stop_desc'),
        },
    })
end

RegisterNUICallback('actionsSelect', function(data, cb)
    cb('ok')
    local id = type(data) == 'table' and data.id
    closeActionsNui()
    if id == 'stop' then stopAction(false) return end
    for _, action in ipairs(CFG.actions) do
        if action.id == id then startAction(action) return end
    end
end)

RegisterNUICallback('actionsClose', function(_, cb)
    closeActionsNui()
    cb('ok')
end)

if CFG.command then
    RegisterCommand(CFG.command, function()
        if GetMount(cache.ped) ~= 0 then
            lib.notify({ description = locale('action_dismount'), type = 'error' })
            return
        end
        OpenHorseActionsMenu()
    end, false)
end

-- ===================== PER-ACTION COMMANDS =====================
local function canCommand()
    if GetMount(cache.ped) ~= 0 then
        lib.notify({ description = locale('action_dismount'), type = 'error' })
        return false
    end
    return true
end

if CFG.actionCommands then
    for _, action in ipairs(CFG.actions) do
        local name = action.command or ('horse' .. action.id) -- set command = 'x' on an action to rename it
        RegisterCommand(name, function()
            if canCommand() then startAction(action) end
        end, false)
        TriggerEvent('chat:addSuggestion', '/' .. name, locale('action_' .. action.id .. '_desc'))
    end
end

if CFG.stopCommand then
    RegisterCommand(CFG.stopCommand, function()
        if current then stopAction(false) end
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. CFG.stopCommand, locale('action_stop_desc'))
end

-- ===================== REAR UP KEYBIND =====================
if CFG.rearKey and CFG.rearKey.enabled then
    local K = CFG.rearKey
    local nextRear = 0
    CreateThread(function()
        while true do
            local horse = GetActiveHorseEntity and GetActiveHorseEntity()
            if not (horse and GetMount(cache.ped) == horse) then
                Wait(500)
            else
                Wait(0)
                local held = not K.modifier or IsControlPressed(0, K.modifier) or IsDisabledControlPressed(0, K.modifier)
                if held then
                    DisableControlAction(0, K.control, true) -- stop the key's normal game action firing as well
                    if IsDisabledControlJustPressed(0, K.control) and GetGameTimer() >= nextRear
                        and not IsPauseMenuActive() and not IsNuiFocused() then
                        nextRear = GetGameTimer() + (K.cooldown or 3000)
                        local A = K.mountedAnim or {}
                        if A.horse and loadDict(A.horse.dict) then
                            TaskPlayAnim(horse, A.horse.dict, A.horse.clip, 4.0, -4.0, -1, A.horse.flag or 8208, 0.0, false, 0, false, '', false)
                        end
                        if A.rider and loadDict(A.rider.dict) then
                            TaskPlayAnim(cache.ped, A.rider.dict, A.rider.clip, 4.0, -4.0, -1, 0, 0.0, false, 0, false, '', false)
                        end
                    end
                end
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if nuiOpen then SetNuiFocus(false, false) end
    if current and DoesEntityExist(current.horse) then ClearPedTasks(current.horse, true, true) end
    current = nil
end)
