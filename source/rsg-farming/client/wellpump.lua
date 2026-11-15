local RSGCore = exports['rsg-core']:GetCoreObject()

local WP      = Config.WellPump
local Pumps   = {}   -- [id] = data (no citizenid)
local Mine    = {}   -- [id] = true for pumps this character placed (sent by the server)
local Spawned = {}   -- [id] = entity

---------------------------------
-- actions
---------------------------------
-- action = 'fill' | 'pack'
local function pumpAction(action, id, cb, scenario, duration, label)
    local p = Pumps[id]
    if not p or not Utils.canAct() then return end

    Utils.guard(function()
        local can, reason = RSGCore.Functions.AwaitCallback('rsg-farming:server:pumpPrecheck', nil, action, id)
        if not can then
            Utils.notify(reason, 'error')
            return
        end
        Utils.face(p.x, p.y)
        if Utils.playScenario(scenario, duration, label) then
            local ok, msg = RSGCore.Functions.AwaitCallback(cb, nil, id)
            Utils.notify(msg, ok and 'success' or 'error')
        else
            Utils.notify(locale('cancelled'), 'error')
        end
    end)
end

---------------------------------
-- spawning
---------------------------------
local function despawn(id)
    local ent = Spawned[id]
    if ent then
        exports['rsg-target']:removeLocalEntity(ent)
        Utils.deleteProp(ent)
    end
    Spawned[id] = nil
end

local function spawn(p)
    local ent = Utils.spawnProp(WP.prop, p.x, p.y, p.z, p.h + 0.0)
    if not ent then return end
    Spawned[p.id] = ent

    exports['rsg-target']:addLocalEntity(ent, {
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
                return not Utils.busy and (not WP.ownerOnlyPackup or Mine[p.id] == true)
            end,
            onSelect = function()
                pumpAction('pack', p.id, 'rsg-farming:server:packPump', WP.packScenario, WP.packTime, locale('pump_packing'))
            end,
        },
    })
end

local function applySync(list, mine)
    local fresh = {}
    for _, p in ipairs(list or {}) do fresh[p.id] = p end
    for id in pairs(Spawned) do
        if not fresh[id] then despawn(id) end
    end
    Pumps = fresh
    Mine = {}
    for _, id in ipairs(mine or {}) do Mine[id] = true end
end

local function loadPumps()
    local list, mine = RSGCore.Functions.AwaitCallback('rsg-farming:server:getPumps', nil)
    applySync(list, mine)
end

RegisterNetEvent('rsg-farming:client:syncPumps', applySync)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    for id in pairs(Spawned) do despawn(id) end
    Pumps, Mine = {}, {}
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadPumps)

CreateThread(function()
    Wait(1000)
    loadPumps()
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
-- placement (rsg-gizmo, same as crops)
---------------------------------
RegisterNetEvent('rsg-farming:client:placePump', function()
    if not Utils.canAct() then return end

    Utils.guard(function()
        local coords, heading = Utils.place(WP.prop, function(pos)
            local minSq = WP.minDistance * WP.minDistance
            for _, p in pairs(Pumps) do
                local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
                if dx * dx + dy * dy + dz * dz < minSq then
                    return false, locale('pump_too_close')
                end
            end
            return true
        end)
        if not coords then return end

        Utils.face(coords.x, coords.y)
        if Utils.playScenario(WP.packScenario, WP.packTime, locale('pump_placing')) then
            local ok, msg = RSGCore.Functions.AwaitCallback('rsg-farming:server:placePump', nil, coords, heading)
            Utils.notify(msg, ok and 'success' or 'error')
        else
            Utils.notify(locale('cancelled'), 'error')
        end
    end)
end)
