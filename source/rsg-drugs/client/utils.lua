local RSGCore = exports['rsg-core']:GetCoreObject()
-- Shared client helpers: handover animation (NPC bag sales + brick export) and the proximity NPC spawner.
-- Anim settings: Config.Addiction.Selling.Anim
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

-- paired handover: both face each other, then play the player/NPC halves of the same anim
-- frozen = true for our own frozen NPCs (brick buyer), so they don't try to turn
function DrugsHandover(ped, frozen)
    local A = Config.Addiction.Selling.Anim
    if not A or not A.Enabled or not DoesEntityExist(ped) then return end
    if not pcall(RSGCore.Functions.RequestAnimDict, A.Dict, 5000) then return end
    local me = PlayerPedId()
    SetBlockingOfNonTemporaryEvents(ped, true)
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(me, ped, 1000)
    if not frozen then TaskTurnPedToFaceEntity(ped, me, 1000) end
    Wait(1000)
    TaskPlayAnim(me, A.Dict, A.Player, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    TaskPlayAnim(ped, A.Dict, A.Ped, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    local ms = math.floor((GetAnimDuration(A.Dict, A.Player) or 3.0) * 1000)
    Wait(ms > 0 and ms or 3000)
    StopAnimTask(me, A.Dict, A.Player, 1.0)
    if DoesEntityExist(ped) then
        StopAnimTask(ped, A.Dict, A.Ped, 1.0)
        SetBlockingOfNonTemporaryEvents(ped, false)
    end
    RemoveAnimDict(A.Dict)
end

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
