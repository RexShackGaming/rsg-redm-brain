local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local WP      = Config.WellPump
local Pumps   = {}   -- [id] = data
local Spawned = {}   -- [id] = entity

local function getCid()
    local pd = RSGCore.Functions.GetPlayerData()
    return pd and pd.citizenid
end

---------------------------------
-- actions
---------------------------------
-- action = 'fill' | 'pack'
local function pumpAction(action, id, cb, scenario, duration, label)
    local p = Pumps[id]
    if not p or not Utils.canAct() then return end
    Utils.busy = true
    local can, reason = lib.callback.await('rsg-farming:server:pumpPrecheck', false, action, id)
    if not can then
        Utils.notify(reason, 'error')
        Utils.busy = false
        return
    end
    Utils.face(p.x, p.y)
    if Utils.playScenario(scenario, duration, label) then
        local ok, msg = lib.callback.await(cb, false, id)
        Utils.notify(msg, ok and 'success' or 'error')
    else
        Utils.notify(locale('cancelled'), 'error')
    end
    Utils.busy = false
end

---------------------------------
-- spawning
---------------------------------
local function despawn(id)
    local ent = Spawned[id]
    if ent then
        exports.ox_target:removeLocalEntity(ent)
        Utils.deleteProp(ent)
    end
    Spawned[id] = nil
end

local function spawn(p)
    local ent = Utils.spawnProp(WP.prop, p.x, p.y, p.z, p.h + 0.0)
    if not ent then return end
    Spawned[p.id] = ent

    exports.ox_target:addLocalEntity(ent, {
        {
            name = ('rsg_wellpump_fill_%s'):format(p.id),
            label = locale('pump_fill_target'),
            icon = 'fa-solid fa-bucket',
            distance = WP.interactDist,
            canInteract = function() return not Utils.busy end,
            onSelect = function()
                pumpAction('fill', p.id, 'rsg-farming:server:fillBucket', WP.fillScenario, WP.fillTime, locale('pump_filling'))
            end,
        },
        {
            name = ('rsg_wellpump_pack_%s'):format(p.id),
            label = locale('pump_pack_target'),
            icon = 'fa-solid fa-box',
            distance = WP.interactDist,
            canInteract = function()
                return not Utils.busy and (not WP.ownerOnlyPackup or (Pumps[p.id] and Pumps[p.id].citizenid == getCid()))
            end,
            onSelect = function()
                pumpAction('pack', p.id, 'rsg-farming:server:packPump', WP.packScenario, WP.packTime, locale('pump_packing'))
            end,
        },
    })
end

local function applySync(list)
    local fresh = {}
    for _, p in ipairs(list or {}) do fresh[p.id] = p end
    for id in pairs(Spawned) do
        if not fresh[id] then despawn(id) end
    end
    Pumps = fresh
end

RegisterNetEvent('rsg-farming:client:syncPumps', applySync)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    applySync(lib.callback.await('rsg-farming:server:getPumps', false))
end)

CreateThread(function()
    Wait(1000)
    applySync(lib.callback.await('rsg-farming:server:getPumps', false))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Spawned) do despawn(id) end
end)

-- distance streaming
CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for id, p in pairs(Pumps) do
            local near = #(pc - vector3(p.x, p.y, p.z)) < Config.RenderDistance
            if near and not Spawned[id] then spawn(p)
            elseif not near and Spawned[id] then despawn(id) end
        end
        Wait(1000)
    end
end)

---------------------------------
-- placement (same gizmo as crops)
---------------------------------
RegisterNetEvent('rsg-farming:client:placePump', function()
    if not Utils.canAct() then return end
    Utils.busy = true
    local coords, heading = Placement.Start(WP.prop, function(pos)
        for _, p in pairs(Pumps) do
            if #(vector3(p.x, p.y, p.z) - pos) < WP.minDistance then
                return false, locale('pump_too_close')
            end
        end
        return true
    end, locale('pump_place_invalid'))
    if coords then
        Utils.face(coords.x, coords.y)
        if Utils.playScenario(WP.packScenario, WP.packTime, locale('pump_placing')) then
            local ok, msg = lib.callback.await('rsg-farming:server:placePump', false, coords, heading)
            Utils.notify(msg, ok and 'success' or 'error')
        else
            Utils.notify(locale('cancelled'), 'error')
        end
    end
    Utils.busy = false
end)
