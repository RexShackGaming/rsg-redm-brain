-- Run from the feather-weapons directory: lua tests/ammunition.lua
-- Tests real server services with an in-memory transactional inventory.
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

GetGameTimer = function() return 100 end
vector3 = function(x, y, z) return { x = x, y = y, z = z } end
SetTimeout = function(_delay, _callback) end
AddEventHandler = function(_eventName, _callback) end
RegisterNetEvent = function(_eventName, _callback) end
TriggerClientEvent = function(_eventName, _target, ...) end
FeatherCore = { RPC = { Register = function(_route, _callback, _options) end } }
for _, file in ipairs({ 'config.lua', 'shared/constants.lua', 'shared/errors.lua',
    'shared/definitions/ammunition.lua', 'shared/definitions/attachments.lua',
    'shared/definitions/weapons.lua', 'shared/validation.lua',
    'server/services/definition_registry.lua', 'server/services/metadata.lua',
    'tests/archive/server/services/runtime.lua', 'tests/archive/server/services/equip.lua', 'tests/archive/server/services/ammo.lua',
    'tests/archive/server/services/reconciliation.lua' }) do
    dofile(file)
end
Config.DevMode = false
assert(DefinitionRegistry.Start().ok)
local items, stock, rejectBatch, rejectTransaction
local context = { characterId = 1, sessionId = 'test', correlationId = 'test' }
local TestInventoryAdapter = {}
InventoryAdapter = TestInventoryAdapter
function TestInventoryAdapter.GetItemForCharacter(_, id)
    return items[id] and WeaponResult.Ok(copy(items[id]))
        or WeaponResult.Error('missing', 'Missing item')
end
function TestInventoryAdapter.MutateWeaponMetadataBatch(_, mutations)
    if rejectBatch then return WeaponResult.Error('conflict', 'Injected conflict') end
    for _, mutation in ipairs(mutations) do
        if items[mutation.itemInstanceId].metadataRevision ~= mutation.expectedRevision then
            return WeaponResult.Error('conflict', 'Stale revision')
        end
    end
    for _, mutation in ipairs(mutations) do
        local item = items[mutation.itemInstanceId]
        item.metadata = copy(mutation.metadata)
        item.metadataRevision = item.metadataRevision + 1
    end
    return WeaponResult.Ok(true)
end
function TestInventoryAdapter.Transaction(_, callback)
    local staged, quantities = copy(items), copy(stock)
    local tx = {}
    function tx:GetItemForUpdate(id) return staged[id] end
    function tx:GetQuantity(name) return quantities[name] or 0 end
    function tx:RemoveQuantity(name, amount)
        if self:GetQuantity(name) < amount then return false end
        quantities[name] = self:GetQuantity(name) - amount
        return true
    end
    function tx:AddQuantity(name, amount)
        quantities[name] = self:GetQuantity(name) + amount
        return true
    end
    function tx:SetMetadata(id, metadata, revision)
        if staged[id].metadataRevision ~= revision then return false end
        staged[id].metadata = copy(metadata)
        staged[id].metadataRevision = revision + 1
        return true
    end
    local result = callback(tx)
    if result.ok == false then return result end
    if rejectTransaction then return WeaponResult.Error('conflict', 'Injected conflict') end
    items, stock = staged, quantities
    return WeaponResult.Ok(result)
end
local function reset(weapon, second, shoulder, back)
    items, stock, rejectBatch, rejectTransaction = {}, {}, false, false
    WeaponRuntime.Begin({ source = 1, characterId = 1, sessionId = 'test' })
    local loadoutSlots = { 'primary', 'offhand', 'shoulder', 'back' }
    for index, id in ipairs({ weapon, second, shoulder, back }) do
        local definition = DefinitionRegistry.Get('weapon', id).value
        local metadata = WeaponMetadata.Build(definition, { serialNumber = 'TEST-' .. index })
        assert(metadata.ok)
        items[index] = { id = index, metadata = metadata.value, metadataRevision = 1 }
        assert(WeaponRuntime.RestoreEquipped(1, 'test', items[index], definition,
            'test', loadoutSlots[index]).ok)
    end
end
local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

-- Opt in only inside this test; production firearm definitions remain disabled.
WeaponDefinitionCatalog.weapons.revolver_cattleman.multiTypeAmmunition = true
WeaponDefinitionCatalog.weapons.revolver_schofield.multiTypeAmmunition = true
assert(DefinitionRegistry.Start().ok)
reset('revolver_cattleman', 'revolver_schofield')
stock.ammo_revolver_regular, stock.ammo_revolver_express = 40, 40
for _, slot in ipairs({ 'primary', 'offhand' }) do
    for _, id in ipairs({ 'ammo_revolver_regular', 'ammo_revolver_express' }) do
        local state = WeaponRuntime.GetSlot(1, slot)
        check(AmmoService.LoadSlot(1, context, {
            slot = slot, itemInstanceId = state.itemInstanceId, generation = state.generation,
            ammunitionType = id, amount = 10
        }).ok, 'Multi-type load preserves other funded types: ' .. slot .. '/' .. id)
    end
end
local reports = {}
for _, slot in ipairs({ 'primary', 'offhand' }) do
    local state = WeaponRuntime.GetSlot(1, slot)
    reports[slot] = { itemInstanceId = state.itemInstanceId, generation = state.generation,
        ammunitionType = 'ammo_revolver_express', loaded = slot == 'primary' and 5 or 6, pools = {} }
    for _, id in ipairs(WeaponDefinitionCatalog.weapons[state.definitionId].ammunitionTypes) do
        reports[slot].pools[id] = state.ammoPools[id] or 0
    end
end
reports.primary.pools.ammo_revolver_express = 9
local committed = AmmoService.SyncPoolBatch(1, context, { slots = reports })
check(committed.ok and items[1].metadata.ammo.pools.ammo_revolver_express == 9
    and items[2].metadata.ammo.pools.ammo_revolver_express == 10
    and items[1].metadata.ammo.pools.ammo_revolver_regular == 10,
    'Atomic pool batch charges only the firing instance and preserves Regular')
check(items[1].metadata.ammo.loaded == 5 and items[1].metadata.ammo.reserve == 4,
    'Pool checkpoint does not refill a partial cylinder')
local revision = items[1].metadataRevision
reports.offhand.generation = reports.offhand.generation - 1
check(not AmmoService.SyncPoolBatch(1, context, { slots = reports }).ok
    and items[1].metadataRevision == revision, 'Stale second lease prevents entire batch')
reports.offhand.generation = WeaponRuntime.GetSlot(1, 'offhand').generation
reports.primary.pools.ammo_revolver_express = 10
check(not AmmoService.SyncPoolBatch(1, context, { slots = reports }).ok
    and items[1].metadataRevision == revision, 'Batch cannot mint ownership')
reports.primary.pools.ammo_revolver_express = 8
reports.primary.loaded = 4
rejectTransaction = true
check(not AmmoService.SyncPoolBatch(1, context, { slots = reports }).ok
    and items[1].metadataRevision == revision
    and WeaponRuntime.GetSlot(1, 'primary').ammo == 9, 'Rejected batch preserves metadata and runtime')
rejectTransaction = false
reset('revolver_cattleman', 'revolver_schofield', 'repeater_carbine', 'repeater_lancaster')
stock.ammo_repeater_regular, stock.ammo_repeater_express = 40, 40
local longgunReports = {}
for _, slot in ipairs({ 'shoulder', 'back' }) do
    local state = WeaponRuntime.GetSlot(1, slot)
    for _, id in ipairs({ 'ammo_repeater_regular', 'ammo_repeater_express' }) do
        check(AmmoService.LoadSlot(1, context, { slot = slot, itemInstanceId = state.itemInstanceId,
            generation = state.generation, ammunitionType = id, amount = 10 }).ok,
            'Longgun multi-type load: ' .. slot .. '/' .. id)
    end
    local definition = WeaponDefinitionCatalog.weapons[state.definitionId]
    longgunReports[slot] = { itemInstanceId = state.itemInstanceId, generation = state.generation,
        ammunitionType = 'ammo_repeater_express', loaded = slot == 'shoulder' and 6 or 10, pools = {} }
    for _, id in ipairs(definition.ammunitionTypes) do
        longgunReports[slot].pools[id] = state.ammoPools[id] or 0
    end
end
longgunReports.shoulder.pools.ammo_repeater_express = 9
check(AmmoService.SyncPoolBatch(1, context, { slots = longgunReports }).ok
    and items[3].metadata.ammo.pools.ammo_repeater_express == 9
    and items[4].metadata.ammo.pools.ammo_repeater_express == 10,
    'Shoulder shot debits only shoulder, preserving back and inactive types')
print(('Ammunition regression checks: %d passed'):format(passed))
