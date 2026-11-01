---------------------------------------------------------------
-- TRAIN STORAGE (per-deployment stash)
--
-- Each deployed train gets an rsg-inventory stash whose identifier is
-- generated FRESH on every deploy:  train_<citizenid>_<token>
--
-- Why per-deployment rather than per-train:
-- rsg-inventory stashes are persistent rows in the `inventories` table
-- (see ClearStash in rsg-inventory/server/functions.lua -- it does an
-- UPDATE against that table). If the stash were keyed on the train id,
-- its contents would survive park/despawn/restart and a parked train
-- would become unlimited free storage. Regenerating the identifier each
-- deploy means any leftover row is permanently unreachable.
--
-- It also sidesteps a real problem: V2 config-spawned trains all report
-- trainId = 0, so the train id is NOT unique and every player would
-- otherwise share a single stash.
--
-- SECURITY: the client never sends a stash identifier. It asks to open
-- "my train storage" and the server resolves the id from this registry.
-- Without that, any player could open any stash by guessing an id.
---------------------------------------------------------------

local RSGCore = exports['rsg-core']:GetCoreObject()

-- [src] = { stashId = string, model = string, warned = boolean }
local TrainStashes = {}

-- Exposed to server/main.lua
TrainStorage = {}

---------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------
local function GenerateToken()
    return ('%06x%04x'):format(math.random(0, 0xFFFFFF), math.random(0, 0xFFFF))
end

local function GetCapacity(model)
    local cfg = Config.TrainStorage
    local override = model and cfg.Models and cfg.Models[model] or nil
    return
        (override and override.slots) or cfg.DefaultSlots or 20,
        (override and override.maxweight) or cfg.DefaultMaxWeight or 150000
end

-- Number of occupied slots (stacks) in a stash. Returns 0 when the stash has
-- never been opened, since rsg-inventory only materialises it on first use.
local function CountStacks(stashId)
    if not stashId then return 0 end
    local inv = exports['rsg-inventory']:GetInventory(stashId)
    if not inv or not inv.items then return 0 end
    local count = 0
    for _, item in pairs(inv.items) do
        if item then count = count + 1 end
    end
    return count
end

TrainStorage.CountStacks = CountStacks

---------------------------------------------------------------
-- LIFECYCLE
---------------------------------------------------------------
-- Called when a train is deployed.
-- If this source already has a stash we KEEP it. That matters for the
-- 'Reverse Direction' option, which destroys and recreates the train
-- entity and re-fires setTrainSpawned -- it must not cost the player
-- their load.
function TrainStorage.OnSpawn(src, model)
    if not Config.TrainStorage or not Config.TrainStorage.Enabled then return end
    if not src then return end

    local existing = TrainStashes[src]
    if existing then
        existing.model = model or existing.model
        return existing.stashId
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local stashId = ('train_%s_%s'):format(citizenid, GenerateToken())

    TrainStashes[src] = { stashId = stashId, model = model, warned = false }
    return stashId
end

-- Called whenever the train leaves the world for any reason.
-- STRICT POLICY: the stash is destroyed, not preserved.
function TrainStorage.OnPutAway(src, silent)
    if not src then return end
    local entry = TrainStashes[src]
    if not entry then return end

    local stacks = CountStacks(entry.stashId)

    -- Close it first so the player is not left looking at a dead UI.
    pcall(function()
        exports['rsg-inventory']:CloseInventory(src, entry.stashId)
    end)

    -- Wipe in-memory + the persisted row, then delete the row outright so the
    -- inventories table does not accumulate one dead row per deployment.
    pcall(function()
        exports['rsg-inventory']:ClearStash(entry.stashId)
    end)
    MySQL.query('DELETE FROM inventories WHERE identifier = ?', { entry.stashId })

    TrainStashes[src] = nil

    if stacks > 0 and not silent then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('notify_title'),
            description = locale('storage_wiped', stacks),
            type = 'error',
            duration = 7000,
        })
    end

    if Config.Debug then
        print(('[rsg-railroad] Train stash wiped for %s (%s stacks)'):format(src, stacks))
    end
end

---------------------------------------------------------------
-- OPEN STORAGE
-- The client sends NO identifier -- it is resolved here.
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:openTrainStorage', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Config.TrainStorage or not Config.TrainStorage.Enabled then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('notify_title'), description = locale('storage_disabled'),
            type = 'error', duration = 5000,
        })
        return
    end

    local entry = TrainStashes[src]
    if not entry then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('notify_title'), description = locale('storage_no_train'),
            type = 'error', duration = 5000,
        })
        return
    end

    local slots, maxweight = GetCapacity(entry.model)

    exports['rsg-inventory']:OpenInventory(src, entry.stashId, {
        label     = locale('storage_label'),
        maxweight = maxweight,
        slots     = slots,
    })

    -- Warn once per deployment that this storage is temporary.
    if Config.TrainStorage.WarnOnFirstOpen and not entry.warned then
        entry.warned = true
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('notify_title'),
            description = locale('storage_temp_warning'),
            type = 'warning',
            duration = 9000,
        })
    end
end)

---------------------------------------------------------------
-- STATE QUERY (for client-side confirm dialogs and distance warnings)
---------------------------------------------------------------
lib.callback.register('rsg-railroad:getTrainStorageState', function(source)
    local entry = TrainStashes[source]
    if not entry then return { active = false, stacks = 0 } end
    return { active = true, stacks = CountStacks(entry.stashId) }
end)

---------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------
AddEventHandler('playerDropped', function()
    TrainStorage.OnPutAway(source, true)
end)

-- Trains are client-spawned and never survive a restart, so no train stash
-- should outlive the resource. Sweep on both ends:
--   * onResourceStop  -- wipe stashes for anyone currently deployed
--   * onResourceStart -- delete orphans left by a crash or hard restart
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(TrainStashes) do
        TrainStorage.OnPutAway(src, true)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Startup diagnostics. If you click "Train Storage" in game and nothing at
    -- all happens, check for these lines -- their absence means this file was
    -- never loaded (usually it wasn't copied to the server, or fxmanifest.lua
    -- is stale and needs a `refresh`).
    print('[rsg-railroad] train storage module loaded')
    if not Config.TrainStorage then
        print('[rsg-railroad] WARNING: Config.TrainStorage is missing -- config is out of date, storage will not appear')
    elseif not Config.TrainStorage.Enabled then
        print('[rsg-railroad] train storage is DISABLED in config')
    end
    if GetResourceState('rsg-inventory') ~= 'started' then
        print(('[rsg-railroad] WARNING: rsg-inventory is "%s" (expected "started") -- train storage cannot open'):format(GetResourceState('rsg-inventory')))
    end

    if not Config.TrainStorage or not Config.TrainStorage.Enabled then return end
    -- Backslash escapes the '_' so it is a literal, not a single-char wildcard.
    MySQL.update('DELETE FROM inventories WHERE identifier LIKE ?', { 'train\\_%' }, function(affected)
        if type(affected) == 'table' then affected = affected.affectedRows end
        if (tonumber(affected) or 0) > 0 then
            print(('[rsg-railroad] Cleared %s orphaned train storage stash(es)'):format(affected))
        end
    end)
end)
