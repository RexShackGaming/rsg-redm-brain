local RSGCore = exports['rsg-core']:GetCoreObject()
-- Shared client helpers: handover animation (NPC bag sales + brick export) and the proximity NPC spawner.
-- Anim settings: Config.Corner.Anim
-- NUI focus helper used by every panel in this resource (lab, export, addiction).
-- With keep-input on, all keys also reach the game, so a per-frame whitelist blocks every control except
-- push-to-talk. A counter lets two panels overlap without one closing the other's focus.
local focusCount = 0
local function applyFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

function DrugsNuiFocus(enable)
    if enable then
        focusCount = focusCount + 1
        if focusCount == 1 then applyFocus(true) end
    elseif focusCount > 0 then
        focusCount = focusCount - 1
        if focusCount == 0 then applyFocus(false) end
    end
end

CreateThread(function()
    while true do
        if focusCount > 0 and Config.AllowPushToTalkWhileOpen then
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

-- ambient human townsfolk only (excludes animals, players, script/shop NPCs, riders and the dead)
function DrugsIsAmbient(ped)
    return DoesEntityExist(ped) and not IsPedAPlayer(ped)
        and IsPedHuman(ped) and not Citizen.InvokeNative(0x9A100F1CF4546629, ped) -- GET_IS_ANIMAL
        and not IsEntityDead(ped) and not IsEntityAMissionEntity(ped) and not IsPedInAnyVehicle(ped, false)
        and not IsPedOnMount(ped)
end

-- closes a panel when the player walks away from the NPC or dies. close() is called once.
function DrugsWatchPanel(pos, maxDistance, isOpen, close)
    CreateThread(function()
        while isOpen() do
            Wait(500)
            local ped = PlayerPedId()
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - pos) > maxDistance then
                close()
                break
            end
        end
    end)
end

-- the package prop that is in the air during a handover (removed on resource stop if a handover was cut short)
local handoverProp

local function boneOf(ped, P)
    local bone = GetEntityBoneIndexByName(ped, P.Bone)
    if not bone or bone == -1 then bone = GetPedBoneIndex(ped, P.BoneId) end
    return bone
end

local function attachTo(obj, ped, P, o)
    AttachEntityToEntity(obj, ped, boneOf(ped, P), o[1], o[2], o[3], o[4], o[5], o[6], true, true, false, true, 2, true)
end

local function dropHandoverProp()
    if handoverProp and DoesEntityExist(handoverProp) then DeleteEntity(handoverProp) end
    handoverProp = nil
end

-- paired handover: both face each other, then play the player/NPC halves of the same anim.
-- With a prop (Config.Corner.Anim.Prop, pass `Config.Corner.Anim.Prop`) the package starts in the player's hand and
-- moves to the NPC's hand part way through, so it is visibly handed over.
-- frozen = true for our own frozen NPCs (brick buyer), so they don't try to turn
function DrugsHandover(ped, frozen, prop)
    local A = Config.Corner.Anim
    if not A or not A.Enabled or not DoesEntityExist(ped) then return end
    if not pcall(RSGCore.Functions.RequestAnimDict, A.Dict, 5000) then return end
    local me = PlayerPedId()
    SetBlockingOfNonTemporaryEvents(ped, true)
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(me, ped, 1000)
    if not frozen then TaskTurnPedToFaceEntity(ped, me, 1000) end
    Wait(1000)

    -- the package, in the player's hand (skipped quietly if the model won't load)
    dropHandoverProp()
    if prop and prop.Enabled then
        local hash = joaat(prop.Model)
        if pcall(RSGCore.Functions.RequestModel, hash, 5000) then
            local c = GetEntityCoords(me)
            handoverProp = CreateObject(hash, c.x, c.y, c.z + 1.0, true, true, false)
            if handoverProp and handoverProp ~= 0 then
                attachTo(handoverProp, me, prop, prop.Player)
            else
                handoverProp = nil
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end

    TaskPlayAnim(me, A.Dict, A.Player, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    TaskPlayAnim(ped, A.Dict, A.Ped, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    local ms = math.floor((GetAnimDuration(A.Dict, A.Player) or 3.0) * 1000)
    if ms <= 0 then ms = 3000 end

    -- hand the package to the NPC part way through
    local at = prop and math.max(0.0, math.min(1.0, prop.HandoffAt or 0.5)) or 1.0
    local first = math.floor(ms * at)
    Wait(first)
    if handoverProp and DoesEntityExist(handoverProp) and DoesEntityExist(ped) then
        attachTo(handoverProp, ped, prop, prop.Ped)
    end
    Wait(ms - first)

    StopAnimTask(me, A.Dict, A.Player, 1.0)
    dropHandoverProp() -- the NPC pockets it
    if DoesEntityExist(ped) then
        StopAnimTask(ped, A.Dict, A.Ped, 1.0)
        SetBlockingOfNonTemporaryEvents(ped, false)
    end
    RemoveAnimDict(A.Dict)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then dropHandoverProp() end
end)

-- Spawns a frozen, invincible rsg-target NPC while the player is within cfg.spawnDistance.
-- cfg = { coords = vector4, model, spawnDistance, targetDistance }; option = rsg-target option table (needs name) or a list of them.
-- Returns a getter for the current ped handle (nil while despawned). Cleans itself up on resource stop.
function DrugsProximityNpc(cfg, option)
    local npc
    local options = option.name and { option } or option
    local names = {}
    for _, o in ipairs(options) do
        o.distance = o.distance or cfg.targetDistance
        names[#names + 1] = o.name
    end

    local function spawn()
        local c = cfg.coords
        if not pcall(RSGCore.Functions.RequestModel, cfg.model, 10000) then return end
        npc = CreatePed(cfg.model, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
        Citizen.InvokeNative(0x283978A15512B2FE, npc, true) -- SetRandomOutfitVariation
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetModelAsNoLongerNeeded(cfg.model)
        exports['rsg-target']:addLocalEntity(npc, options)
    end

    local function remove()
        if npc and DoesEntityExist(npc) then
            exports['rsg-target']:removeLocalEntity(npc, names)
            DeleteEntity(npc)
        end
        npc = nil
    end

    CreateThread(function()
        local pos = vector3(cfg.coords.x, cfg.coords.y, cfg.coords.z)
        while true do
            local near = #(GetEntityCoords(PlayerPedId()) - pos) < cfg.spawnDistance
            if near and not npc then spawn() elseif not near and npc then remove() end
            Wait(1000)
        end
    end)

    AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then remove() end end)
    return function() return npc end
end
