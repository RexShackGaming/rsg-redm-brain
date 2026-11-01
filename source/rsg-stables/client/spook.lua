-- ===================== SPOOKING =====================
-- Gunfire / explosions near your horse can spook it (based on decompiled beat_spooked_horse.c).
-- Natives (rsg-redm-brain natives/db): IS_PED_SHOOTING 0x34616828CD07F1A1, IS_EXPLOSION_IN_SPHERE 0xD62DD846D82CBB90,
-- GET_ATTRIBUTE_RANK 0xA4C8E23E29040DE0, GET_MAX_ATTRIBUTE_RANK 0x704674A0535A471D, TASK_HORSE_ACTION 0xA09CFD29100F06C3
-- (action 5 = rear up, throws a rider; rdr3_discoveries tasks/TASK_HORSE_ACTION), TASK_SMART_FLEE_PED 0x22B0D0E37CCB840D.
-- Calm interaction: Interaction_PositiveLongAgitated (rdr3_discoveries tasks/TASK_ANIMAL_INTERACTION).
local RSGCore = exports['rsg-core']:GetCoreObject()

local cfg = Config.HorseSpook
if not (cfg and cfg.enabled) then
    function IsActiveHorseSkittish() return false end
    function CalmActiveHorse() end
    return
end

local PA_COURAGE = 3
local skittishUntil, calmUntil, nextSpookAt = 0, 0, 0

local function now() return GetGameTimer() end

function IsActiveHorseSkittish()
    return now() < skittishUntil
end

local function spookChance(horse)
    local rank = tonumber(Citizen.InvokeNative(0xA4C8E23E29040DE0, horse, PA_COURAGE)) or 0     -- GET_ATTRIBUTE_RANK
    local max  = tonumber(Citizen.InvokeNative(0x704674A0535A471D, horse, PA_COURAGE)) or 10    -- GET_MAX_ATTRIBUTE_RANK
    if max <= 0 then max = 10 end
    local chance = cfg.baseChance * (1.0 - math.min(1.0, rank / max))
    if IsActiveHorseSkittish() then chance = chance * (cfg.skittishMult or 1.0) end
    return math.max(cfg.minChance or 0.0, math.min(1.0, chance))
end

local function scareNearby(horse)
    local hc = GetEntityCoords(horse)
    if Citizen.InvokeNative(0xD62DD846D82CBB90, -1, hc.x, hc.y, hc.z, cfg.radius) == 1 then return true end -- any explosion
    local r2 = cfg.radius * cfg.radius
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= horse and IsPedHuman(ped) and IsPedShooting(ped) then
            local d = GetEntityCoords(ped) - hc
            if d.x * d.x + d.y * d.y + d.z * d.z <= r2 then return true end
        end
    end
    return false
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = now() + 3000
    while not HasAnimDictLoaded(dict) and now() < t do Wait(25) end
    return HasAnimDictLoaded(dict)
end

local function spook(horse)
    nextSpookAt = now() + (cfg.cooldown or 8000)
    skittishUntil = now() + (cfg.skittishTime or 120) * 1000
    local ped = PlayerPedId()
    local ridden = GetMount(ped) == horse

    if ridden and math.random() >= (cfg.throwChance or 0) then
        -- rear only: play the mounted rearing anims (TASK_HORSE_ACTION would throw the rider)
        local A = Config.HorseActions and Config.HorseActions.rearKey and Config.HorseActions.rearKey.mountedAnim
        if A and A.horse and loadDict(A.horse.dict) then
            TaskPlayAnim(horse, A.horse.dict, A.horse.clip, 4.0, -4.0, -1, A.horse.flag or 8208, 0.0, false, 0, false, '', false)
        end
        if A and A.rider and loadDict(A.rider.dict) then
            TaskPlayAnim(ped, A.rider.dict, A.rider.clip, 4.0, -4.0, -1, 0, 0.0, false, 0, false, '', false)
        end
        RSGCore.Functions.Notify({ description = locale('spook_rear'), type = 'warning' })
        return
    end

    Citizen.InvokeNative(0xA09CFD29100F06C3, horse, 5, 0, 0) -- TASK_HORSE_ACTION rear up (throws the rider)
    RSGCore.Functions.Notify({ description = locale(ridden and 'spook_thrown' or 'spook_bolt'), type = 'error' })
    SetTimeout(1500, function()
        if not DoesEntityExist(horse) or IsEntityDead(horse) or GetMount(PlayerPedId()) == horse then return end
        local b = cfg.bolt or {}
        Citizen.InvokeNative(0x22B0D0E37CCB840D, horse, PlayerPedId(), b.distance or 40.0, b.time or 6000, 0, 3.0, 0) -- TASK_SMART_FLEE_PED
    end)
end

function CalmActiveHorse()
    local horse = GetActiveHorseEntity and GetActiveHorseEntity()
    if not horse or not IsActiveHorseSkittish() then return end
    local ped = PlayerPedId()
    if GetMount(ped) ~= 0 then return end
    ClearPedTasks(horse, true, true)
    TaskAnimalInteraction(ped, horse, joaat('Interaction_PositiveLongAgitated'), 0, 0)
    skittishUntil = 0
    calmUntil = now() + (cfg.calmedTime or 90) * 1000
    RSGCore.Functions.Notify({ description = locale('spook_calmed'), type = 'success' })
end

CreateThread(function()
    while true do
        Wait(cfg.checkInterval or 400)
        local horse = GetActiveHorseEntity and GetActiveHorseEntity()
        if horse and not IsEntityDead(horse) and now() >= nextSpookAt and now() >= calmUntil
            and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(horse)) <= 60.0
            and scareNearby(horse) then
            if math.random() < spookChance(horse) then
                spook(horse)
            else
                nextSpookAt = now() + 2000 -- one roll per burst of gunfire
            end
        end
    end
end)
