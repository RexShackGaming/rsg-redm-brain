-- Shared client helpers: handover animation (NPC bag sales + brick export) and the proximity NPC spawner.
-- Anim settings: Config.Addiction.Selling.Anim
-- paired handover: both face each other, then play the player/NPC halves of the same anim
-- frozen = true for our own frozen NPCs (brick buyer), so they don't try to turn
function DrugsHandover(ped, frozen)
    local A = Config.Addiction.Selling.Anim
    if not A or not A.Enabled or not DoesEntityExist(ped) then return end
    if not lib.requestAnimDict(A.Dict, 5000) then return end
    local me = cache.ped
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

-- Spawns a frozen, invincible ox_target NPC while the player is within cfg.spawnDistance.
-- cfg = { coords = vector4, model, spawnDistance, targetDistance }; option = ox_target option table (needs name).
-- Returns a getter for the current ped handle (nil while despawned). Cleans itself up on resource stop.
function DrugsProximityNpc(cfg, option)
    local npc
    option.distance = option.distance or cfg.targetDistance

    local function spawn()
        local c = cfg.coords
        if not lib.requestModel(cfg.model, 10000) then return end
        npc = CreatePed(cfg.model, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
        Citizen.InvokeNative(0x283978A15512B2FE, npc, true) -- SetRandomOutfitVariation
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetModelAsNoLongerNeeded(cfg.model)
        exports.ox_target:addLocalEntity(npc, { option })
    end

    local function remove()
        if npc and DoesEntityExist(npc) then
            exports.ox_target:removeLocalEntity(npc, option.name)
            DeleteEntity(npc)
        end
        npc = nil
    end

    CreateThread(function()
        local pos = vector3(cfg.coords.x, cfg.coords.y, cfg.coords.z)
        while true do
            local near = #(GetEntityCoords(cache.ped) - pos) < cfg.spawnDistance
            if near and not npc then spawn() elseif not near and npc then remove() end
            Wait(1000)
        end
    end)

    AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then remove() end end)
    return function() return npc end
end
