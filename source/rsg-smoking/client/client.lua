local RSGCore = exports['rsg-core']:GetCoreObject()

local session = nil -- the active smoking session (nil while idle)
local props = {}    -- every prop this resource spawned (entity -> model hash), removed again on resource stop

-- prop model per kind (also preloaded before the server takes the item, see canSmoke)
local PROP_MODELS = {
    cigarette      = 'P_CIGARETTE01X',
    cigar          = 'P_CIGAR01X',
    pipe           = 'P_PIPE01X',
    chewingtobacco = 'S_TOBACCOTIN01X',
}

local ALL_PROMPTS = { 'drop', 'use', 'stance' }
local ACTION_PROMPTS = { 'use', 'stance' }

---------------------------------
-- helpers
---------------------------------
local function logError(message)
    print(('^1[rsg-smoking]^7 %s'):format(message))
end

-- some RedM natives return 1/0 instead of true/false, and 0 is truthy in Lua (same helper as rsg-core)
local function yes(v)
    return v == true or v == 1
end

-- why the player cannot smoke right now (reason code for the server), or nil when they can
local function blockReason()
    local ped = PlayerPedId()
    if yes(IsEntityDead(ped)) or yes(IsPedRagdoll(ped)) or yes(IsPedCuffed(ped)) or yes(IsPedHogtied(ped)) then return 'now' end
    if yes(IsPedOnMount(ped)) then return 'mounted' end
    if yes(IsPedInAnyVehicle(ped, false)) then return 'vehicle' end
    if yes(IsPedSwimming(ped)) then return 'swimming' end
    return nil
end

-- true when the player can no longer keep smoking (dead, ragdolled, cuffed, on a horse, in a wagon, swimming)
local function interrupted()
    return blockReason() ~= nil
end

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            logError(('animation dictionary failed to load: %s'):format(dict))
            return false
        end
        Wait(10)
    end
    return true
end

-- loads a dictionary and remembers it so it is released when the session ends
local function useDict(dict)
    if not loadAnimDict(dict) then return false end
    session.dicts[dict] = true
    return true
end

local function loadModel(name)
    local hash = GetHashKey(name)
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            logError(('model failed to load: %s'):format(name))
            return nil
        end
        Wait(10)
    end
    return hash
end

local function play(dict, name, duration, flag, intro)
    if not useDict(dict) then return false end
    TaskPlayAnim(PlayerPedId(), dict, name, intro or 1.0, 1.0, duration or -1, flag or 1, 1, false, false, false, 0, true)
    return true
end

local function waitForAnim(dict, name)
    local timeout = GetGameTimer() + 5000
    while not IsEntityPlayingAnim(PlayerPedId(), dict, name, 3) do
        if GetGameTimer() > timeout or interrupted() then return false end
        Wait(50)
    end
    return true
end

-- waits `ms`; returns false early when the player presses drop or is interrupted
local function waitOrCancel(ms)
    local untilTime = GetGameTimer() + ms
    local nextCheck = 0
    while GetGameTimer() < untilTime do
        Wait(0)
        if IsControlJustReleased(0, Config.Prompts.DropKey) then
            session.dropRequested = true
            return false
        end
        local now = GetGameTimer()
        if now >= nextCheck then -- the state checks do not need to run every frame
            nextCheck = now + 250
            if interrupted() then return false end
        end
    end
    return true
end

---------------------------------
-- coughing (cosmetic): worn-out players sometimes cough after a drag
-- gestures: ai_gestures@gen_male|gen_female@standing@speaker (rdr3_discoveries ingameanims)
-- cores: _GET_ATTRIBUTE_CORE_VALUE 0x36731AC041289BB1 (0 = health, 1 = stamina)
---------------------------------
local COUGH_ANIMS = { 'cough_high_l_001', 'cough_high_r_001', 'cough_low_l_001', 'cough_low_r_001', 'cough_medium_l_002', 'cough_medium_r_002' }

local function shouldCough()
    local cfg = Config.Cough
    if not cfg.Enabled or math.random(100) > cfg.Chance then return false end
    local ped = PlayerPedId()
    local health = Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger()) or 100
    local stamina = Citizen.InvokeNative(0x36731AC041289BB1, ped, 1, Citizen.ResultAsInteger()) or 100
    return health <= cfg.HealthBelow or stamina <= cfg.StaminaBelow
end

-- plays a cough gesture; false when the player cancelled or was interrupted during it
local function cough()
    local dict = yes(IsPedMale(PlayerPedId())) and 'ai_gestures@gen_male@standing@speaker' or 'ai_gestures@gen_female@standing@speaker'
    local anim = COUGH_ANIMS[math.random(#COUGH_ANIMS)]
    if not play(dict, anim, -1, 30, 0.0) then return true end
    return waitOrCancel(math.max(GetAnimDuration(dict, anim) * 1000, 1000))
end

---------------------------------
-- props
---------------------------------
local function spawnProp(model)
    local hash = loadModel(model)
    if not hash then return nil end
    local x, y, z = table.unpack(GetEntityCoords(PlayerPedId(), true))
    local prop = CreateObject(hash, x, y, z + 0.2, true, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not prop or prop == 0 then return nil end
    props[prop] = hash
    return prop
end

local function attach(prop, bone, o)
    AttachEntityToEntity(prop, PlayerPedId(), bone, o[1], o[2], o[3], o[4], o[5], o[6], true, true, false, true, 1, true)
end

-- the model check stops a recycled entity handle from deleting someone else's entity
local function deleteProp(prop)
    local hash = props[prop]
    props[prop] = nil
    if hash and DoesEntityExist(prop) and GetEntityModel(prop) == hash then
        DeleteEntity(prop)
    end
end

-- lets a prop fall to the ground and removes it again after Config.DropDespawnTime
local function releaseProp(prop, push)
    if not prop or not DoesEntityExist(prop) then return end
    DetachEntity(prop, true, true)
    if push then SetEntityVelocity(prop, 0.0, 0.0, -1.0) end
    if Config.DropDespawnTime > 0 then
        SetTimeout(Config.DropDespawnTime, function() deleteProp(prop) end)
    else
        deleteProp(prop)
    end
end

---------------------------------
-- prompts (created per session, deleted when it ends)
---------------------------------
local function addPrompt(slot, key, label)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, key)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', label))
    PromptSetEnabled(prompt, false)
    PromptSetVisible(prompt, false)
    PromptSetHoldMode(prompt, false)
    PromptRegisterEnd(prompt)
    session.prompts[slot] = prompt
end

local function showPrompts(slots, show)
    for _, slot in ipairs(slots) do
        local prompt = session.prompts[slot]
        if prompt then
            PromptSetEnabled(prompt, show)
            PromptSetVisible(prompt, show)
        end
    end
end

-- Shared control loop. Runs until the player drops the item, is interrupted or the base animation stops.
-- onStance / onUse return false when the player dropped the item or was interrupted mid animation.
local function interact(isPlaying, onDrop, onStance, onUse)
    showPrompts(ALL_PROMPTS, true)
    local pressedAt, nextCheck = nil, 0

    local function finish()
        if session.dropRequested then onDrop() end
    end

    while true do
        Wait(0)

        local now = GetGameTimer()
        if now >= nextCheck then
            nextCheck = now + 250
            if interrupted() or not isPlaying() then return end
        end

        if IsControlJustReleased(0, Config.Prompts.DropKey) then
            onDrop()
            return
        end

        if IsControlJustReleased(0, Config.Prompts.ChangeKey) then
            showPrompts(ACTION_PROMPTS, false)
            if not onStance() then return finish() end
            showPrompts(ACTION_PROMPTS, true)
        elseif IsControlJustPressed(0, Config.Prompts.SmokeKey) then
            pressedAt = now
        elseif IsControlJustReleased(0, Config.Prompts.SmokeKey) then
            local held = pressedAt ~= nil and (now - pressedAt) >= Config.LongDragHoldTime
            pressedAt = nil
            showPrompts(ACTION_PROMPTS, false)
            if not onUse(held) then return finish() end
            showPrompts(ACTION_PROMPTS, true)
        end
    end
end

---------------------------------
-- cigarette
---------------------------------
local CIGARETTE = {
    male = {
        start = 'c',
        order = { 'c', 'b', 'd', 'a' },
        stances = {
            c = {
                base = { 'amb_rest@world_human_smoking@male_c@base', 'base' },
                tap  = { 'amb_rest@world_human_smoking@male_c@idle_a', 'idle_a', 8500 },
                hold = { 'amb_rest@world_human_smoking@male_c@idle_a', 'idle_b', 21166 },
            },
            b = {
                base = { 'amb_rest@world_human_smoking@nervous_stressed@male_b@base', 'base' },
                tap  = { 'amb_rest@world_human_smoking@nervous_stressed@male_b@idle_a', 'idle_a', 3199 },
                hold = { 'amb_rest@world_human_smoking@nervous_stressed@male_b@idle_c', 'idle_g', 13433 },
            },
            d = {
                base  = { 'amb_rest@world_human_smoking@male_d@base', 'base' },
                tap   = { 'amb_rest@world_human_smoking@male_d@idle_c', 'idle_g', 7866 },
                hold  = { 'amb_rest@world_human_smoking@male_d@idle_a', 'idle_b', 7366 },
                trans = { 'amb_rest@world_human_smoking@male_d@trans', 'd_trans_a', 4000 },
            },
            a = {
                base  = { 'amb_wander@code_human_smoking_wander@male_a@base', 'base' },
                tap   = { 'amb_rest@world_human_smoking@male_a@idle_a', 'idle_a', 8200 },
                hold  = { 'amb_rest@world_human_smoking@male_a@idle_a', 'idle_b', 12533 },
                trans = { 'amb_rest@world_human_smoking@male_a@trans', 'a_trans_c', 4233 },
            },
        },
        exit = { dict = 'amb_rest@world_human_smoking@male_a@stand_exit', anim = 'exit_back', before = 2800, after = 1500, push = true },
    },
    female = {
        start = 'c',
        order = { 'c', 'b', 'a' },
        stances = {
            c = {
                base = { 'amb_rest@world_human_smoking@female_c@base', 'base' },
                tap  = { 'amb_rest@world_human_smoking@female_c@idle_b', 'idle_f', 8133 },
                hold = { 'amb_rest@world_human_smoking@female_c@idle_a', 'idle_a', 9566 },
            },
            b = {
                base  = { 'amb_rest@world_human_smoking@female_b@base', 'base' },
                tap   = { 'amb_rest@world_human_smoking@female_b@idle_a', 'idle_b', 4266 },
                hold  = { 'amb_rest@world_human_smoking@female_b@idle_b', 'idle_f', 8033 },
                trans = { 'amb_rest@world_human_smoking@female_b@trans', 'b_trans_a', 5733 },
            },
            a = {
                base = { 'amb_rest@world_human_smoking@female_a@base', 'base' },
                tap  = { 'amb_rest@world_human_smoking@female_a@idle_a', 'idle_b', 6100 },
                hold = { 'amb_rest@world_human_smoking@female_a@idle_b', 'idle_d', 14566 },
            },
        },
        exit = { dict = 'amb_rest@world_human_smoking@female_b@trans', anim = 'b_trans_fire_stand_a', before = 3800, after = 800 },
    },
}

local function playBase(set, stance, afterTransition)
    local base = set.stances[stance].base
    play(base[1], base[2], -1, 30, afterTransition and 0.0 or nil)
end

local function maleIntro(set, prop, mouth, hand)
    attach(prop, mouth, { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 })
    play('amb_rest@world_human_smoking@male_c@stand_enter', 'enter_back_rf', 5400, 0)
    if not waitOrCancel(1000) then return false end
    attach(prop, hand, { 0.03, -0.01, 0.0, 0.0, 90.0, 0.0 })
    if not waitOrCancel(1000) then return false end
    attach(prop, mouth, { -0.017, 0.1, -0.01, 0.0, 90.0, -90.0 })
    if not waitOrCancel(3000) then return false end
    attach(prop, hand, { 0.017, -0.01, -0.01, 0.0, 120.0, 10.0 })
    if not waitOrCancel(1000) then return false end
    playBase(set, set.start)
    return waitOrCancel(1000)
end

local function femaleIntro(set, prop, mouth, hand)
    attach(prop, mouth, { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 })
    playBase(set, set.start)
    if not waitOrCancel(1000) then return false end
    attach(prop, hand, { 0.01, 0.0, 0.01, 0.0, -160.0, -130.0 })
    return waitOrCancel(2500)
end

local function nextStance(set, stance)
    for i, name in ipairs(set.order) do
        if name == stance then return set.order[i % #set.order + 1] end
    end
    return set.start
end

local function changeCigaretteStance(set)
    local current = set.stances[session.stance]
    local target = nextStance(set, session.stance)

    if current.trans then
        play(current.trans[1], current.trans[2], -1, 30)
        if not waitOrCancel(current.trans[3]) then return false end
        playBase(set, target, true)
    else
        playBase(set, target)
        if not waitOrCancel(1000) then return false end
    end

    local base = set.stances[target].base
    if not waitForAnim(base[1], base[2]) then return false end
    session.stance = target
    return true
end

local function drag(set, long)
    local stance = set.stances[session.stance]
    local d = long and stance.hold or stance.tap
    play(d[1], d[2], -1, 30, 0.0)
    if not waitOrCancel(d[3]) then return false end
    if shouldCough() and not cough() then return false end
    playBase(set, session.stance, true)
    return waitForAnim(stance.base[1], stance.base[2])
end

local function dropCigarette(set)
    showPrompts(ALL_PROMPTS, false)
    local exit = set.exit
    ClearPedSecondaryTask(PlayerPedId())
    play(exit.dict, exit.anim, -1, 1)
    Wait(exit.before)
    releaseProp(session.prop, exit.push)
    session.prop = nil
    Wait(exit.after)
end

local function runCigarette()
    local ped = PlayerPedId()
    local male = yes(IsPedMale(ped))
    local set = male and CIGARETTE.male or CIGARETTE.female

    local prop = spawnProp(PROP_MODELS.cigarette)
    if not prop then return end
    session.prop, session.propMode = prop, 'drop'
    session.stance = set.start

    local mouth = GetEntityBoneIndexByName(ped, 'skel_head')
    local hand = GetEntityBoneIndexByName(ped, 'SKEL_R_Finger13')
    local intro = male and maleIntro or femaleIntro
    if not intro(set, prop, mouth, hand) then return end

    local base = set.stances[set.start].base
    if not waitForAnim(base[1], base[2]) then return end

    addPrompt('drop', Config.Prompts.DropKey, locale('prompt_drop'))
    addPrompt('use', Config.Prompts.SmokeKey, locale('prompt_smoke'))
    addPrompt('stance', Config.Prompts.ChangeKey, locale('prompt_stance'))

    interact(
        function()
            local current = set.stances[session.stance].base
            return IsEntityPlayingAnim(PlayerPedId(), current[1], current[2], 3)
        end,
        function() dropCigarette(set) end,
        function() return changeCigaretteStance(set) end,
        function(long) return drag(set, long) end
    )
end

---------------------------------
-- cigar
---------------------------------
local CIGAR_DICT = 'amb_rest@world_human_smoke_cigar@male_a@idle_b'
local CIGAR_ANIM = 'idle_d'
local CIGAR_BLOCKED_CONTROLS = { 0x07CE1E61, 0xF84FA74F, 0xCEE12B50, 0xB2F377E8, 0x8FFC75D6, 0xD9D0E1C0 }

local function playCigarAnim()
    TaskPlayAnim(PlayerPedId(), CIGAR_DICT, CIGAR_ANIM, 8.0, -8.0, -1, 31, 0, true, 0, false, 0, false)
end

local function runCigar()
    if not useDict(CIGAR_DICT) then return end

    local prop = spawnProp(PROP_MODELS.cigar)
    if not prop then return end
    session.prop, session.propMode = prop, 'delete'

    attach(prop, GetEntityBoneIndexByName(PlayerPedId(), 'SKEL_R_Finger12'), { 0.01, -0.005, 0.0155, 0.024, 300.0, -40.0 })
    playCigarAnim()
    if not waitOrCancel(1000) then return end

    addPrompt('drop', Config.Prompts.DropKey, locale('prompt_drop'))
    showPrompts({ 'drop' }, true)

    local nextCheck = 0
    while true do
        Wait(0)
        for _, control in ipairs(CIGAR_BLOCKED_CONTROLS) do
            DisableControlAction(0, control, true)
        end

        if IsControlJustReleased(0, Config.Prompts.DropKey) then return end

        local now = GetGameTimer()
        if now >= nextCheck then
            nextCheck = now + 250
            if interrupted() then return end
            if not IsEntityPlayingAnim(PlayerPedId(), CIGAR_DICT, CIGAR_ANIM, 3) then
                playCigarAnim()
            end
        end
    end
end

---------------------------------
-- pipe
---------------------------------
local PIPE_TRANS = 'amb_wander@code_human_smoking_wander@male_b@trans'
local PIPE_BASE = 'amb_rest@world_human_smoking@male_b@base'
local PIPE_IDLE = 'amb_rest@world_human_smoking@male_b@idle_a'
local PIPE_WIP = 'amb_rest@world_human_smoking@pipe@proper@male_d@wip_base'

local function runPipe()
    local prop = spawnProp(PROP_MODELS.pipe)
    if not prop then return end
    session.prop, session.propMode = prop, 'delete'

    attach(prop, GetEntityBoneIndexByName(PlayerPedId(), 'SKEL_R_Finger13'), { 0.005, -0.045, 0.0, -170.0, 10.0, -15.0 })
    play(PIPE_TRANS, 'nopipe_trans_pipe', -1, 30)
    if not waitOrCancel(9000) then return end
    play(PIPE_BASE, 'base', -1, 31)
    if not waitForAnim(PIPE_BASE, 'base') then return end

    addPrompt('drop', Config.Prompts.DropKey, locale('prompt_put_away'))
    addPrompt('use', Config.Prompts.SmokeKey, locale('prompt_smoke'))
    addPrompt('stance', Config.Prompts.ChangeKey, locale('prompt_stance'))

    interact(
        function() return IsEntityPlayingAnim(PlayerPedId(), PIPE_BASE, 'base', 3) end,
        function()
            showPrompts(ALL_PROMPTS, false)
            play(PIPE_TRANS, 'pipe_trans_nopipe', -1, 30)
            Wait(6066)
        end,
        function()
            play(PIPE_WIP, 'wip_base', -1, 30)
            if not waitOrCancel(5000) then return false end
            play(PIPE_BASE, 'base', -1, 31)
            return waitForAnim(PIPE_BASE, 'base')
        end,
        function()
            play(PIPE_IDLE, 'idle_a', -1, 30, 0.0)
            if not waitOrCancel(22600) then return false end
            if shouldCough() and not cough() then return false end
            play(PIPE_BASE, 'base', -1, 31, 0.0)
            return waitForAnim(PIPE_BASE, 'base')
        end
    )
end

---------------------------------
-- chewing tobacco
---------------------------------
local CHEW = {
    A = { prefix = 'amb_misc@world_human_chew_tobacco@male_a', next = 'B', trans = { 'a_trans_b', 7333 } },
    B = { prefix = 'amb_misc@world_human_chew_tobacco@male_b', next = 'A', trans = { 'b_trans_a', 5833 } },
}

local CHEW_IDLES = {
    a = { 'idle_a', 'idle_b', 'idle_c' },
    b = { 'idle_d', 'idle_e', 'idle_f' },
    c = { 'idle_g', 'idle_h', 'idle_i' },
    d = { 'idle_j', 'idle_k', 'idle_l' },
}

local function buildChewIdles(prefix)
    local list = {}
    for suffix, anims in pairs(CHEW_IDLES) do
        for _, anim in ipairs(anims) do
            list[#list + 1] = { dict = prefix .. '@idle_' .. suffix, anim = anim }
        end
    end
    return list
end

local function runChewing()

    local idles = { A = buildChewIdles(CHEW.A.prefix), B = buildChewIdles(CHEW.B.prefix) }
    local requested = {}
    for _, list in pairs(idles) do
        for _, idle in ipairs(list) do
            if not requested[idle.dict] then -- several idle animations share one dictionary
                requested[idle.dict] = true
                RequestAnimDict(idle.dict)
                session.dicts[idle.dict] = true
            end
        end
    end

    local stance = 'A'
    local function baseDict() return CHEW[stance].prefix .. '@base' end

    play(CHEW.A.prefix .. '@stand_enter', 'enter_back', -1, 30)
    if not waitOrCancel(2500) then return end

    local tin = spawnProp(PROP_MODELS.chewingtobacco)
    if not tin then return end
    session.prop, session.propMode = tin, 'delete'
    attach(tin, GetEntityBoneIndexByName(PlayerPedId(), 'SKEL_R_Finger13'), { 0.0, -0.05, 0.02, 30.0, 180.0, 0.0 })
    if not waitOrCancel(6000) then return end
    deleteProp(tin)
    session.prop = nil
    if not waitOrCancel(3500) then return end

    play(baseDict(), 'base', -1, 31, 0.0)
    if not waitForAnim(baseDict(), 'base') then return end

    addPrompt('drop', Config.Prompts.DropKey, locale('prompt_spit'))
    addPrompt('use', Config.Prompts.SmokeKey, locale('prompt_chew'))
    addPrompt('stance', Config.Prompts.ChangeKey, locale('prompt_stance'))

    interact(
        function() return IsEntityPlayingAnim(PlayerPedId(), baseDict(), 'base', 3) end,
        function()
            showPrompts(ALL_PROMPTS, false)
            play(CHEW.B.prefix .. '@idle_b', 'idle_d', 5500, 30)
            Wait(5500)
        end,
        function()
            local current = CHEW[stance]
            play(current.prefix .. '@trans', current.trans[1], -1, 30)
            if not waitOrCancel(current.trans[2]) then return false end
            stance = current.next
            play(baseDict(), 'base', -1, 30, 0.0)
            return waitForAnim(baseDict(), 'base')
        end,
        function()
            local list = idles[stance]
            local idle = list[math.random(#list)]
            if not useDict(idle.dict) then return true end
            local duration = math.max(GetAnimDuration(idle.dict, idle.anim) * 1000, 1000)
            play(idle.dict, idle.anim, -1, 30, 0.0)
            if not waitOrCancel(duration) then return false end
            play(baseDict(), 'base', -1, 31, 0.0)
            return waitForAnim(baseDict(), 'base')
        end
    )
end

---------------------------------
-- session handling
---------------------------------
local KINDS = {
    cigarette      = runCigarette,
    cigar          = runCigar,
    pipe           = runPipe,
    chewingtobacco = runChewing,
}

local function cleanup()
    local ped = PlayerPedId()

    for _, prompt in pairs(session.prompts) do
        PromptDelete(prompt)
    end

    if session.prop then
        if session.propMode == 'drop' then
            releaseProp(session.prop)
        else
            deleteProp(session.prop)
        end
    end

    ClearPedSecondaryTask(ped)
    for dict in pairs(session.dicts) do
        RemoveAnimDict(dict)
    end

    if not yes(IsEntityDead(ped)) then
        Wait(100)
        ClearPedTasks(ped)
    end

    session = nil
end

local function startSession(kind)
    if session then return end
    session = { dicts = {}, prompts = {} }

    local ok, err = pcall(KINDS[kind])
    if not ok then logError(('%s session failed: %s'):format(kind, err)) end

    -- never leave a stale session behind, or the player could not smoke again until a restart
    local cleaned, cleanErr = pcall(cleanup)
    if not cleaned then logError(('cleanup failed: %s'):format(cleanErr)) end
    session = nil
end

for kind in pairs(KINDS) do
    RegisterNetEvent('rsg-smoking:client:' .. kind, function()
        startSession(kind)
    end)
end

-- the server asks before it consumes anything, so items are not wasted when the player cannot smoke
RSGCore.Functions.CreateClientCallback('rsg-smoking:client:canSmoke', function(cb, kind)
    if session then return cb('busy') end
    local reason = blockReason()
    if reason then return cb(reason) end

    -- a smoke whose prop cannot be created would waste the item, so make sure the model loads first
    local model = PROP_MODELS[kind]
    if model then
        local hash = loadModel(model)
        if not hash then return cb('now') end
        SetModelAsNoLongerNeeded(hash)
    end
    cb('ok')
end)

---------------------------------
-- share a light: players who asked for one get an "Offer a light" option (rsg-target)
---------------------------------
local LIGHT_TARGET = 'rsg-smoking:giveLight'

local function hasLighter()
    for _, name in ipairs(Config.LighterItems) do
        if exports['rsg-inventory']:HasItem(name, 1) then return true end
    end
    return false
end

CreateThread(function()
    if not Config.ShareLight.Enabled then return end
    exports['rsg-target']:addGlobalPlayer({
        {
            name = LIGHT_TARGET,
            icon = 'fa-solid fa-fire',
            label = locale('target_give_light'),
            distance = 2.0,
            canInteract = function(entity)
                local player = NetworkGetPlayerIndexFromPed(entity)
                if not player or player == -1 then return false end
                return Player(GetPlayerServerId(player)).state.smokingNeedsLight == true and hasLighter()
            end,
            onSelect = function(data)
                local player = NetworkGetPlayerIndexFromPed(data.entity)
                if player and player ~= -1 then
                    TriggerServerEvent('rsg-smoking:server:offerLight', GetPlayerServerId(player))
                end
            end,
        },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if Config.ShareLight.Enabled then exports['rsg-target']:removeGlobalPlayer(LIGHT_TARGET) end

    if session then
        for _, prompt in pairs(session.prompts) do
            PromptDelete(prompt)
        end
        ClearPedTasks(PlayerPedId())
    end

    for prop, hash in pairs(props) do
        if DoesEntityExist(prop) and GetEntityModel(prop) == hash then DeleteEntity(prop) end
    end
end)
