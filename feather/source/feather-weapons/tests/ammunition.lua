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

-- Every catalog combination loads, persists its native type and unloads the
for _, slot in ipairs({ 'throwable_quaternary', 'throwable_quinary', 'throwable_senary', 'throwable_septenary', 'throwable_octonary', 'throwable_nonary', 'throwable_denary' }) do
    check(WeaponRuntime.NormalizeSlot(slot) == slot and WeaponConstants.ThrowableSlots[slot],
        'New throwable position is recognized: ' .. slot)
    check(Config.Inventory.equipmentSlots[slot] == 'weapon_' .. slot,
        'New throwable Inventory mapping: ' .. slot)
end
local slotMappings = {}
for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
    local mapped = Config.Inventory.equipmentSlots[slot]
    check(type(mapped) == 'string' and not slotMappings[mapped], 'Unique equipment mapping: ' .. slot)
    slotMappings[mapped] = true
end

-- Every catalog combination loads, persists its native type and unloads the
-- exact inventory item. Native rendering/firing still needs in-game testing.
for _, definition in ipairs(DefinitionRegistry.List('weapon').value) do
    for _, ammoId in ipairs(definition.ammunitionTypes) do
        reset(definition.id)
        local ammo = DefinitionRegistry.Get('ammunition', ammoId).value
        stock[ammo.itemName] = 10
        local result = AmmoService.Escrow(1, context, 10, ammoId)
        check(result.ok, definition.id .. '/' .. ammoId .. ' load: '
            .. tostring(result.error and result.error.message))
        check(items[1].metadata.ammo.type == ammoId, 'Persist selected type')
        check(WeaponRuntime.Get(1).equipped.nativeAmmoName == ammo.nativeAmmoName, 'Native type')
        local restored = WeaponRuntime.RestoreEquipped(1, 'test', items[1], definition, 'test')
        check(restored.ok and restored.value.ammunitionType == ammoId, 'Restore selected type')
        check(AmmoService.Unload(1, context).ok and stock[ammo.itemName] == 10, 'Exact unload')
    end
end

reset('throwable_bolas')
stock.ammo_bolas_regular = 5
local bolasLoad = AmmoService.Escrow(1, context, 5, 'ammo_bolas_regular')
check(bolasLoad.ok and bolasLoad.value.total == 3
    and bolasLoad.value.loaded == 1 and bolasLoad.value.reserve == 2
    and stock.ammo_bolas_regular == 2, 'Bolas candidate cap preserves excess stock')
check(not AmmoService.Escrow(1, context, 1, 'ammo_tomahawk_regular').ok,
    'Bolas rejects foreign-family ammunition')
check(AmmoService.Unload(1, context).ok and stock.ammo_bolas_regular == 5,
    'Bolas unload returns exact ammo definition')

reset('revolver_cattleman')
stock.ammo_revolver_express = 20
check(AmmoService.Escrow(1, context, 10, 'ammo_revolver_express').ok, 'Express load')
check(not AmmoService.Escrow(1, context, 10, 'ammo_revolver_regular').ok, 'Loaded switch rejected')
check(not AmmoService.Escrow(1, context, 10, 'ammo_pistol_regular').ok, 'Wrong family rejected')
check(stock.ammo_revolver_express == 10 and items[1].metadata.ammo.type == 'ammo_revolver_express',
    'Rejected requests preserve stock and type')
local lease = copy(WeaponRuntime.Get(1).equipped)
check(AmmoService.SyncConsumption(1, context, {
    itemInstanceId = lease.itemInstanceId, generation = lease.generation, total = 9, loaded = 5
}).ok, 'Special ammo shot checkpoint')
check(AmmoService.Unload(1, context).ok and stock.ammo_revolver_express == 19, 'Shot consumes one round')

reset('repeater_lancaster')
stock.ammo_repeater_explosive = 20
local cappedExplosive = AmmoService.Escrow(1, context, 20, 'ammo_repeater_explosive')
check(cappedExplosive.ok and cappedExplosive.value.total == 10
    and cappedExplosive.value.loaded == 10 and cappedExplosive.value.reserve == 0
    and stock.ammo_repeater_explosive == 10,
    'Native-capped explosive load preserves excess inventory ammunition')
check(AmmoService.Unload(1, context).ok and stock.ammo_repeater_explosive == 20,
    'Native-capped explosive unload conserves ammunition')

reset('rifle_springfield')
stock.ammo_rifle_explosive = 20
local cappedRifleExplosive = AmmoService.Escrow(1, context, 20, 'ammo_rifle_explosive')
check(cappedRifleExplosive.ok and cappedRifleExplosive.value.total == 10
    and cappedRifleExplosive.value.loaded == 1 and cappedRifleExplosive.value.reserve == 9
    and stock.ammo_rifle_explosive == 10,
    'Native-capped rifle explosive load preserves excess inventory ammunition')
check(AmmoService.Unload(1, context).ok and stock.ammo_rifle_explosive == 20,
    'Native-capped rifle explosive unload conserves ammunition')

for _, cappedSidearm in ipairs({
    { weapon = 'revolver_cattleman', ammunition = 'ammo_revolver_explosive' },
    { weapon = 'pistol_volcanic', ammunition = 'ammo_pistol_explosive' }
}) do
    reset(cappedSidearm.weapon)
    stock[cappedSidearm.ammunition] = 20
    local cappedLoad = AmmoService.Escrow(1, context, 20, cappedSidearm.ammunition)
    check(cappedLoad.ok and cappedLoad.value.total == 10
        and stock[cappedSidearm.ammunition] == 10,
        cappedSidearm.ammunition .. ' native cap preserves excess inventory ammunition')
    check(AmmoService.Unload(1, context).ok and stock[cappedSidearm.ammunition] == 20,
        cappedSidearm.ammunition .. ' native-capped unload conserves ammunition')
end

for _, cappedShotgunAmmo in ipairs({
    { ammunition = 'ammo_shotgun_buckshot_incendiary', maximum = 14 },
    { ammunition = 'ammo_shotgun_slug_explosive', maximum = 10 }
}) do
    reset('shotgun_pump')
    stock[cappedShotgunAmmo.ammunition] = 20
    local cappedLoad = AmmoService.Escrow(1, context, 20, cappedShotgunAmmo.ammunition)
    local expectedLoaded = math.min(5, cappedShotgunAmmo.maximum)
    check(cappedLoad.ok and cappedLoad.value.total == cappedShotgunAmmo.maximum
        and cappedLoad.value.loaded == expectedLoaded
        and cappedLoad.value.reserve == cappedShotgunAmmo.maximum - expectedLoaded
        and stock[cappedShotgunAmmo.ammunition] == 20 - cappedShotgunAmmo.maximum,
        cappedShotgunAmmo.ammunition .. ' native cap preserves excess inventory ammunition')
    check(AmmoService.Unload(1, context).ok and stock[cappedShotgunAmmo.ammunition] == 20,
        cappedShotgunAmmo.ammunition .. ' native-capped unload conserves ammunition')
end

reset('revolver_cattleman', 'revolver_schofield')
stock.ammo_revolver_regular = 50
stock.ammo_revolver_express = 7
local availability = AmmoService.GetInventoryAvailability(1, context)
check(availability.ok and availability.value.quantities.ammo_revolver_regular == 50
    and availability.value.quantities.ammo_revolver_express == 7
    and availability.value.quantities.ammo_revolver_explosive == nil,
    'Managed ammunition availability returns only owned stacks')
local managedRuntime = WeaponRuntime.Get(1)
local managedOffhand = managedRuntime.slots.offhand
local managedLoad = AmmoService.LoadSlot(1, context, {
    slot = 'offhand', ammunitionType = 'ammo_revolver_regular', amount = 50,
    itemInstanceId = managedOffhand.itemInstanceId, generation = managedOffhand.generation
})
check(managedLoad.ok and items[1].metadata.ammo.loaded == 0
    and items[2].metadata.ammo.loaded == 6 and items[2].metadata.ammo.reserve == 44,
    'Managed load targets only the requested weapon slot')
local managedUnload = AmmoService.Unload(1, context, 10, 'offhand', {
    slot = 'offhand', itemInstanceId = managedOffhand.itemInstanceId,
    generation = managedOffhand.generation
})
check(managedUnload.ok and items[2].metadata.ammo.loaded == 6
    and items[2].metadata.ammo.reserve == 34 and stock.ammo_revolver_regular == 10,
    'Managed unload returns ammunition from only the requested slot')
local switchLease = WeaponRuntime.Get(1).slots.offhand
local managedSwitch = AmmoService.SwitchSlot(1, context, {
    slot = 'offhand', ammunitionType = 'ammo_revolver_express', amount = 50,
    itemInstanceId = switchLease.itemInstanceId, generation = switchLease.generation
})
check(managedSwitch.ok and managedSwitch.reconcile == true
    and managedSwitch.value.moved == 7 and managedSwitch.value.returned == 40
    and items[2].metadata.ammo.type == 'ammo_revolver_express'
    and items[2].metadata.ammo.loaded == 6 and items[2].metadata.ammo.reserve == 1
    and stock.ammo_revolver_regular == 50 and stock.ammo_revolver_express == 0,
    'Managed ammunition switch is atomic and slot scoped')

for _, second in ipairs({ 'revolver_schofield', 'revolver_cattleman' }) do
    reset('revolver_cattleman', second)
    local oldGeneration = WeaponRuntime.Get(1).equipped.generation
    stock.ammo_revolver_express = 30
    check(AmmoService.Escrow(1, context, 10, 'ammo_revolver_express').ok, 'Pair first load')
    check(items[1].metadata.ammo.type == 'ammo_revolver_express'
        and items[2].metadata.ammo.type == 'ammo_revolver_express', 'Atomic pair selection')
    check(not WeaponRuntime.MatchesLease(1, 'test', 1, oldGeneration), 'Old lease invalidated')
    check(AmmoService.Escrow(1, context, 10, 'ammo_revolver_express').ok, 'Pair second load')
    local runtime = WeaponRuntime.Get(1)
    check(AmmoService.SyncPair(1, context, { total = 18, slots = {
        primary = { itemInstanceId = 1, generation = runtime.slots.primary.generation, loaded = 5, consumed = 1 },
        offhand = { itemInstanceId = 2, generation = runtime.slots.offhand.generation, loaded = 5, consumed = 1 }
    } }).ok, 'Special ammo pair firing checkpoint')
    check(not AmmoService.Escrow(1, context, 10, 'ammo_revolver_explosive').ok, 'Loaded pair switch rejected')
    check(AmmoService.Unload(1, context, nil, 'primary').ok
        and AmmoService.Unload(1, context, nil, 'offhand').ok
        and stock.ammo_revolver_express == 28, 'Pair unload conserves ammo after two shots')
    stock.ammo_revolver_high_velocity = 10
    check(AmmoService.Escrow(1, context, 10, 'ammo_revolver_high_velocity').ok, 'Empty pair switches')
end

-- Different native ammo pools coexist without requiring both weapons to
-- select or consume the same Inventory ammunition definition.
reset('revolver_cattleman', 'pistol_volcanic')
stock.ammo_revolver_regular = 10
stock.ammo_pistol_regular = 10
check(AmmoService.Escrow(1, context, 10, 'ammo_revolver_regular').ok,
    'Mixed pair loads revolver ammunition')
check(items[1].metadata.ammo.loaded + items[1].metadata.ammo.reserve == 10
    and items[2].metadata.ammo.loaded + items[2].metadata.ammo.reserve == 0,
    'Revolver ammunition changes only compatible slot')
check(AmmoService.Escrow(1, context, 10, 'ammo_pistol_regular').ok,
    'Mixed pair loads pistol ammunition')
check(items[1].metadata.ammo.type == 'ammo_revolver_regular'
    and items[2].metadata.ammo.type == 'ammo_pistol_regular',
    'Mixed pair retains independent ammunition types')
local mixedRuntime = WeaponRuntime.Get(1)
local mixedCheckpoint = AmmoService.SyncPair(1, context, { total = 18, slots = {
    primary = { itemInstanceId = 1, generation = mixedRuntime.slots.primary.generation,
        loaded = 5, consumed = 1 },
    offhand = { itemInstanceId = 2, generation = mixedRuntime.slots.offhand.generation,
        loaded = 7, consumed = 1 }
} })
check(mixedCheckpoint.ok,
    ('Mixed ammo pair checkpoint conserves both pools (%s: %s)'):format(
        tostring(mixedCheckpoint.error and mixedCheckpoint.error.code),
        tostring(mixedCheckpoint.error and mixedCheckpoint.error.message)))
check(AmmoService.Unload(1, context, nil, 'primary').ok
    and AmmoService.Unload(1, context, nil, 'offhand').ok
    and stock.ammo_revolver_regular == 9 and stock.ammo_pistol_regular == 9,
    'Mixed pair unload returns exact ammunition families')

reset('revolver_cattleman', 'pistol_volcanic', 'rifle_springfield', 'shotgun_pump')
check(EquipService.ValidateConfiguration().ok, 'Mixed loadout configuration valid')
local fullRuntime = WeaponRuntime.Get(1)
check(fullRuntime.slots.primary ~= nil and fullRuntime.slots.offhand ~= nil
    and fullRuntime.slots.shoulder ~= nil and fullRuntime.slots.back ~= nil,
    'Four sidearm and long-gun runtime slots coexist')
reset('revolver_cattleman', 'pistol_volcanic', 'repeater_carbine', 'repeater_evans')
assert(WeaponRuntime.Unequip(1, 'test', 'test', 'back').ok)
local sharedLonggun = EquipService.Request(1, context, 4, 'back')
check(sharedLonggun.ok,
    'Second different-model long gun accepts a shared native ammunition type')
assert(WeaponRuntime.RestoreEquipped(1, 'test', items[4],
    DefinitionRegistry.Get('weapon', 'repeater_evans').value, 'test', 'back').ok)
stock.ammo_repeater_express = 10
local ambiguousLonggunAmmo = AmmoService.Escrow(1, context, 10, 'ammo_repeater_express')
check(not ambiguousLonggunAmmo.ok
    and ambiguousLonggunAmmo.error.code == WeaponErrors.OPERATION_CONFLICT,
    'Generic ammunition loading rejects two compatible long guns')
reset('revolver_cattleman', 'pistol_volcanic', 'repeater_carbine', 'repeater_evans')
for index, values in pairs({ [3] = { loaded = 7, reserve = 100 },
        [4] = { loaded = 26, reserve = 70 } }) do
    items[index].metadata.ammo.type = 'ammo_repeater_express'
    items[index].metadata.ammo.loaded = values.loaded
    items[index].metadata.ammo.reserve = values.reserve
    WeaponRuntime.SetSlotAmmunitionType(1, 'test', index == 3 and 'shoulder' or 'back',
        'ammo_repeater_express')
    WeaponRuntime.SetSlotAmmo(1, 'test', index == 3 and 'shoulder' or 'back',
        values.loaded + values.reserve, values.loaded, 'test')
end
stock.ammo_repeater_express = 0
check(AmmoService.NormalizeSharedPools(1, context).ok
    and items[3].metadata.ammo.loaded + items[3].metadata.ammo.reserve
        + items[4].metadata.ammo.loaded + items[4].metadata.ammo.reserve == 200
    and stock.ammo_repeater_express == 3,
    'Shared loaded overflow returns to Inventory during recovery')
local longgunRuntime = WeaponRuntime.Get(1)
local longgunReload = AmmoService.SyncPair(1, context, {
    total = 200,
    slotNames = { 'shoulder', 'back' },
    slots = {
        shoulder = { itemInstanceId = 3, generation = longgunRuntime.slots.shoulder.generation,
            loaded = 26, consumed = 0 },
        back = { itemInstanceId = 4, generation = longgunRuntime.slots.back.generation,
            loaded = 14, consumed = 0 }
    }
})
check(not longgunReload.ok
    and items[3].metadata.ammo.loaded == 7
    and items[3].metadata.ammo.reserve == 100
    and items[4].metadata.ammo.loaded == 26
    and items[4].metadata.ammo.reserve == 67,
    'Distinct long guns reject native reload redistribution across escrow')
local longgunShot = AmmoService.SyncPair(1, context, {
    total = 199,
    slotNames = { 'shoulder', 'back' },
    slots = {
        shoulder = { itemInstanceId = 3, generation = longgunRuntime.slots.shoulder.generation,
            loaded = 6, consumed = 1 },
        back = { itemInstanceId = 4, generation = longgunRuntime.slots.back.generation,
            loaded = 26, consumed = 0 }
    }
})
check(longgunShot.ok
    and items[3].metadata.ammo.loaded == 6
    and items[3].metadata.ammo.reserve == 100
    and items[4].metadata.ammo.loaded == 26
    and items[4].metadata.ammo.reserve == 67,
    'Distinct long-gun shared pool preserves per-item reserve ownership')

-- A capped RedM pistol pool is only a runtime window. Pair checkpoints use
-- Feather ownership minus confirmed shots, not the smaller native pool total.
reset('pistol_m1899', 'pistol_m1899')
for index, values in ipairs({ { loaded = 0, reserve = 99 }, { loaded = 8, reserve = 93 } }) do
    items[index].metadata.ammo.type = 'ammo_pistol_express'
    items[index].metadata.ammo.loaded = values.loaded
    items[index].metadata.ammo.reserve = values.reserve
    local slot = index == 1 and 'primary' or 'offhand'
    WeaponRuntime.SetSlotAmmunitionType(1, 'test', slot, 'ammo_pistol_express')
    assert(WeaponRuntime.SetSlotAmmo(1, 'test', slot,
        values.loaded + values.reserve, values.loaded, 'test').ok)
end
local pistolRuntime = WeaponRuntime.Get(1)
local pistolReload = AmmoService.SyncPair(1, context, { total = 200, slots = {
    primary = { itemInstanceId = 1, generation = pistolRuntime.slots.primary.generation,
        loaded = 8, consumed = 0 },
    offhand = { itemInstanceId = 2, generation = pistolRuntime.slots.offhand.generation,
        loaded = 8, consumed = 0 }
} })
check(pistolReload.ok
    and items[1].metadata.ammo.loaded == 8
    and items[2].metadata.ammo.loaded == 8,
    'Capped pistol window persists native reload without reducing ownership')
local pistolShot = AmmoService.SyncPair(1, context, { total = 199, slots = {
    primary = { itemInstanceId = 1, generation = pistolRuntime.slots.primary.generation,
        loaded = 7, consumed = 1 },
    offhand = { itemInstanceId = 2, generation = pistolRuntime.slots.offhand.generation,
        loaded = 8, consumed = 0 }
} })
check(pistolShot.ok
    and items[1].metadata.ammo.loaded + items[1].metadata.ammo.reserve
        + items[2].metadata.ammo.loaded + items[2].metadata.ammo.reserve == 199,
    'Capped pistol window subtracts only confirmed GUID shots')

reset('revolver_cattleman', 'revolver_schofield')
rejectBatch = true
stock.ammo_revolver_express = 10
check(not AmmoService.Escrow(1, context, 10, 'ammo_revolver_express').ok, 'Failed batch rejected')
check(items[1].metadata.ammo.type == 'ammo_revolver_regular'
    and items[2].metadata.ammo.type == 'ammo_revolver_regular'
    and stock.ammo_revolver_express == 10, 'Failed batch changes nothing')
rejectBatch, rejectTransaction = false, true
local failed = AmmoService.Escrow(1, context, 10, 'ammo_revolver_express')
check(not failed.ok and failed.reconcile, 'Failed refill still refreshes committed selection')
check(stock.ammo_revolver_express == 10 and items[1].metadata.ammo.loaded == 0, 'Failed refill preserves stock')
local definition = DefinitionRegistry.Get('weapon', 'rifle_elephant').value
check(not WeaponValidation.AcceptsAmmunition(definition, 'ammo_rifle_regular'), 'Elephant rejects regular rifle ammo')
definition.ammunitionTypes = 'invalid'
check(not WeaponValidation.Definition(definition, 'weapon'), 'Malformed allowlist returns validation failure')

local cattlemanDefinition = DefinitionRegistry.Get('weapon', 'revolver_cattleman').value
check(WeaponValidation.Definition(cattlemanDefinition, 'weapon'),
    'Declared attachment defaults accepted')
cattlemanDefinition.attachmentDefaults.invalid = 'Invalid slot'
check(not WeaponValidation.Definition(cattlemanDefinition, 'weapon'),
    'Attachment default rejects undeclared slot')

local meleeDefinition = {
    id = 'melee_knife', kind = 'weapon', itemName = 'weapon_melee_knife',
    label = 'Knife', nativeWeaponName = 'WEAPON_MELEE_KNIFE', family = 'knife',
    slot = 'melee', usesAmmunition = false, ammunitionTypes = {}, capacity = 0,
    condition = { minimum = 0, maximum = 100, equipMinimum = 1,
        repair = { itemDefinitionId = 'gun_oil', quantity = 1, restore = 25 } },
    attachmentSlots = {}, attachmentDefaults = {},
    policies = { transferable = true, droppable = true, destructible = true,
        serialRequired = true },
    tags = { 'melee', 'knife' }
}
check(WeaponValidation.Definition(meleeDefinition, 'weapon'),
    'Ammunition-free melee definition validates')
meleeDefinition.nativeGrantAmount = -1
check(not WeaponValidation.Definition(meleeDefinition, 'weapon'),
    'Negative native grant amount is rejected')
meleeDefinition.nativeGrantAmount = nil
local meleeMetadata = WeaponMetadata.Build(meleeDefinition, { serialNumber = 'TEST-MELEE' })
check(meleeMetadata.ok and meleeMetadata.value.ammo.loaded == 0
    and meleeMetadata.value.ammo.reserve == 0,
    'Ammunition-free melee metadata remains empty')
items[5] = { id = 5, metadata = meleeMetadata.value, metadataRevision = 1 }
local meleeRuntime = WeaponRuntime.RestoreEquipped(1, 'test', items[5], meleeDefinition,
    'test', 'melee')
check(meleeRuntime.ok and meleeRuntime.value.nativeAmmoName == nil
    and meleeRuntime.value.ammo == 0,
    'Ammunition-free melee runtime occupies its dedicated slot')
local secondMeleeDefinition = copy(meleeDefinition)
secondMeleeDefinition.id = 'melee_machete'
secondMeleeDefinition.nativeWeaponName = 'WEAPON_MELEE_MACHETE'
local secondMeleeMetadata = WeaponMetadata.Build(secondMeleeDefinition,
    { serialNumber = 'TEST-MELEE-SECONDARY' })
items[6] = { id = 6, metadata = secondMeleeMetadata.value, metadataRevision = 1 }
local secondMeleeRuntime = WeaponRuntime.RestoreEquipped(1, 'test', items[6],
    secondMeleeDefinition, 'test', 'melee_secondary')
check(secondMeleeRuntime.ok and WeaponRuntime.Get(1).slots.melee ~= nil
    and WeaponRuntime.Get(1).slots.melee_secondary ~= nil,
    'Distinct melee models coexist in two persistent slots')
local thirdMeleeDefinition = copy(meleeDefinition)
thirdMeleeDefinition.id = 'melee_cleaver'
thirdMeleeDefinition.nativeWeaponName = 'WEAPON_MELEE_CLEAVER'
local thirdMeleeMetadata = WeaponMetadata.Build(thirdMeleeDefinition,
    { serialNumber = 'TEST-MELEE-TERTIARY' })
items[7] = { id = 7, metadata = thirdMeleeMetadata.value, metadataRevision = 1 }
local thirdMeleeRuntime = WeaponRuntime.RestoreEquipped(1, 'test', items[7],
    thirdMeleeDefinition, 'test', 'melee_tertiary')
check(thirdMeleeRuntime.ok and WeaponRuntime.Get(1).slots.melee ~= nil
    and WeaponRuntime.Get(1).slots.melee_secondary ~= nil
    and WeaponRuntime.Get(1).slots.melee_tertiary ~= nil,
    'Distinct melee models coexist in three persistent slots')
local fourthMeleeDefinition = copy(meleeDefinition)
fourthMeleeDefinition.id = 'melee_hatchet'
fourthMeleeDefinition.nativeWeaponName = 'WEAPON_MELEE_HATCHET'
fourthMeleeDefinition.nativeGrantAmount = 1
local fourthMeleeMetadata = WeaponMetadata.Build(fourthMeleeDefinition,
    { serialNumber = 'TEST-MELEE-QUATERNARY' })
items[8] = { id = 8, metadata = fourthMeleeMetadata.value, metadataRevision = 1 }
local fourthMeleeRuntime = WeaponRuntime.RestoreEquipped(1, 'test', items[8],
    fourthMeleeDefinition, 'test', 'melee_quaternary')
check(fourthMeleeRuntime.ok and WeaponRuntime.Get(1).slots.melee ~= nil
    and WeaponRuntime.Get(1).slots.melee_secondary ~= nil
    and WeaponRuntime.Get(1).slots.melee_tertiary ~= nil
    and WeaponRuntime.Get(1).slots.melee_quaternary ~= nil,
    'Distinct melee models coexist in four persistent slots')
local lassoDefinition = WeaponDefinitionCatalog.weapons.utility_lasso
local lassoMetadata = WeaponMetadata.Build(lassoDefinition, { serialNumber = 'TEST-LASSO' })
check(lassoMetadata.ok and lassoMetadata.value.ammo.type == nil
    and lassoMetadata.value.ammo.loaded == 0 and lassoMetadata.value.ammo.reserve == 0,
    'Lasso metadata has no ammunition')
local lassoItem = { id = 9001, metadata = lassoMetadata.value, metadataRevision = 1 }
local lassoRuntime = WeaponRuntime.RestoreEquipped(1, 'test', lassoItem,
    lassoDefinition, 'test', 'utility')
check(lassoRuntime.ok and lassoRuntime.value.nativeAmmoName == nil
    and lassoRuntime.value.ammo == 0 and WeaponRuntime.Get(1).slots.melee ~= nil,
    'Lasso occupies independent utility slot without displacing melee')
local invalidLassoMetadata = copy(lassoMetadata.value)
invalidLassoMetadata.ammo.loaded = 1
check(not WeaponValidation.Metadata(invalidLassoMetadata, lassoDefinition),
    'Lasso rejects invented ammunition')
-- Retain coverage for the legacy single-pool recovery service. The shipped
local reinforcedDefinition = WeaponDefinitionCatalog.weapons.utility_lasso_reinforced
local reinforcedMetadata = WeaponMetadata.Build(reinforcedDefinition,
    { serialNumber = 'TEST-LASSO-REINFORCED' })
check(reinforcedMetadata.ok and reinforcedMetadata.value.ammo.type == nil
    and reinforcedMetadata.value.ammo.loaded == 0 and reinforcedMetadata.value.ammo.reserve == 0,
    'Reinforced Lasso metadata has no ammunition')
local reinforcedItem = { id = 9002, metadata = reinforcedMetadata.value, metadataRevision = 1 }
reinforcedItem.itemName = reinforcedDefinition.itemName
items[9002] = reinforcedItem
local blockedLasso = EquipService.Request(1, context, 9002, 'utility_secondary')
check(not blockedLasso.ok and blockedLasso.error.code == WeaponErrors.OPERATION_CONFLICT,
    'Second Lasso equip rejected while Standard remains equipped')
local blockedRestore = EquipService.Restore(1, { characterId = 1, sessionId = 'test' },
    9002, 'test', 'utility_secondary')
check(not blockedRestore.ok and blockedRestore.error.code == WeaponErrors.OPERATION_CONFLICT,
    'Saved second Lasso restore rejected without deleting its carrier')
assert(WeaponRuntime.Unequip(1, 'test', 'test', 'utility').ok)
local reinforcedRuntime = WeaponRuntime.RestoreEquipped(1, 'test', reinforcedItem,
    reinforcedDefinition, 'test', 'utility_secondary')
check(reinforcedRuntime.ok and reinforcedRuntime.value.nativeAmmoName == nil
    and reinforcedRuntime.value.ammo == 0 and WeaponRuntime.Get(1).slots.utility == nil,
    'Reinforced Lasso restores after Standard is unequipped')
check(not WeaponRuntime.SetSlotAmmo(1, 'test', 'utility_secondary', 1, 1, 'test').ok,
    'Reinforced Lasso rejects runtime ammunition')
local lanternDefinition = WeaponDefinitionCatalog.weapons.utility_davy_lantern
local lanternMetadata = WeaponMetadata.Build(lanternDefinition, { serialNumber = 'TEST-LANTERN' })
check(lanternMetadata.ok and lanternMetadata.value.ammo.type == nil
    and lanternMetadata.value.ammo.loaded == 0, 'Lantern metadata is ammunition-free')
items[9003] = { id = 9003, itemName = lanternDefinition.itemName,
    metadata = lanternMetadata.value, metadataRevision = 1 }
local lanternRequest = EquipService.Request(1, context, 9003, 'utility')
check(lanternRequest.ok, 'Lantern can equip beside an equipped Lasso')
local lanternCommit = WeaponRuntime.CompleteEquip(1, 'test', lanternRequest.value.token, 'test')
check(lanternCommit.ok and WeaponRuntime.Get(1).slots.utility_secondary ~= nil,
    'Lantern and Lasso occupy independent utility slots')
check(not WeaponRuntime.SetSlotAmmo(1, 'test', 'utility', 1, 1, 'test').ok,
    'Lantern rejects ammunition writes')
local binocularsDefinition = WeaponDefinitionCatalog.weapons.utility_binoculars
local binocularsMetadata = WeaponMetadata.Build(binocularsDefinition, { serialNumber = 'TEST-BINOCULARS' })
items[9004] = { id = 9004, itemName = binocularsDefinition.itemName,
    metadata = binocularsMetadata.value, metadataRevision = 1 }
local binocularsRequest = EquipService.Request(1, context, 9004, 'utility_tertiary')
check(binocularsRequest.ok, 'Binoculars equip alongside Lantern, Lasso and melee')
local binocularsCommit = WeaponRuntime.CompleteEquip(1, 'test', binocularsRequest.value.token, 'test')
check(binocularsCommit.ok and WeaponRuntime.Get(1).slots.utility ~= nil
    and WeaponRuntime.Get(1).slots.utility_secondary ~= nil
    and WeaponRuntime.Get(1).slots.melee_quaternary ~= nil,
    'Three utility carriers and existing melee coexist in saved runtime')
check(not WeaponRuntime.SetSlotAmmo(1, 'test', 'utility_tertiary', 1, 1, 'test').ok,
    'Binoculars reject ammunition writes')
local cameraDefinition = WeaponDefinitionCatalog.weapons.utility_camera
local cameraMetadata = WeaponMetadata.Build(cameraDefinition, { serialNumber = 'TEST-CAMERA' })
items[9005] = { id = 9005, itemName = cameraDefinition.itemName,
    metadata = cameraMetadata.value, metadataRevision = 1 }
local cameraRequest = EquipService.Request(1, context, 9005, 'utility_quaternary')
check(cameraRequest.ok, 'Camera equips in fourth utility position')
local cameraCommit = WeaponRuntime.CompleteEquip(1, 'test', cameraRequest.value.token, 'test')
check(cameraCommit.ok and cameraCommit.value.nativeAmmoName == nil
    and cameraCommit.value.ammo == 0 and WeaponRuntime.Get(1).slots.utility_tertiary ~= nil,
    'Camera remains ammunition-free alongside Binoculars')
check(not WeaponRuntime.SetSlotAmmo(1, 'test', 'utility_quaternary', 1, 1, 'test').ok,
    'Camera rejects ammunition writes')
local advancedDefinition = WeaponDefinitionCatalog.weapons.utility_camera_advanced
local advancedMetadata = WeaponMetadata.Build(advancedDefinition, { serialNumber = 'TEST-ADVANCED-CAMERA' })
items[9006] = { id = 9006, itemName = advancedDefinition.itemName,
    metadata = advancedMetadata.value, metadataRevision = 1 }
local advancedRequest = EquipService.Request(1, context, 9006, 'utility_quinary')
check(advancedRequest.ok, 'Advanced Camera equips beside Standard Camera')
local advancedCommit = WeaponRuntime.CompleteEquip(1, 'test', advancedRequest.value.token, 'test')
check(advancedCommit.ok and advancedCommit.value.nativeAmmoName == nil
    and advancedCommit.value.ammo == 0 and WeaponRuntime.Get(1).slots.utility_quaternary ~= nil,
    'Both Camera carrier identities coexist without ammunition')
check(not WeaponRuntime.SetSlotAmmo(1, 'test', 'utility_quinary', 1, 1, 'test').ok,
    'Advanced Camera rejects ammunition writes')
check(WeaponDefinitionCatalog.weapons.utility_lantern_electric == nil,
    'Failed Electric Lantern is absent from active catalog')
check(WeaponDefinitionCatalog.weapons.utility_torch == nil,
    'Retired Torch is absent from active catalog')
local hammerDefinition = WeaponDefinitionCatalog.weapons.melee_hammer
local hammerMetadata = WeaponMetadata.Build(hammerDefinition, { serialNumber = 'TEST-HAMMER' })
items[9008] = { id = 9008, itemName = hammerDefinition.itemName,
    metadata = hammerMetadata.value, metadataRevision = 1 }
local hammerRequest = EquipService.Request(1, context, 9008, 'melee_quinary')
check(hammerRequest.ok, 'Hammer equips in fifth melee position')
local hammerCommit = WeaponRuntime.CompleteEquip(1, 'test', hammerRequest.value.token, 'test')
check(hammerCommit.ok and hammerCommit.value.nativeAmmoName == nil
    and hammerCommit.value.ammo == 0 and WeaponRuntime.Get(1).slots.melee_quaternary ~= nil,
    'Hammer and four prior melee carriers coexist without ammunition')
check(not WeaponRuntime.SetSlotAmmo(1, 'test', 'melee_quinary', 1, 1, 'test').ok,
    'Hammer rejects ammunition writes')
-- multi-type carrier uses the separate consumption-only pool checkpoint.
WeaponDefinitionCatalog.weapons.throwable_throwing_knives.multiTypeAmmunition = false
assert(DefinitionRegistry.Start().ok)
local throwableDefinition = DefinitionRegistry.Get('weapon', 'throwable_throwing_knives').value
local throwableMetadata = WeaponMetadata.Build(throwableDefinition,
    { serialNumber = 'TEST-THROWABLE' })
throwableMetadata.value.ammo.loaded = 1
throwableMetadata.value.ammo.reserve = 7
throwableMetadata.value.ammo.chambered = true
items[9] = { id = 9, metadata = throwableMetadata.value, metadataRevision = 1 }
local throwableRuntime = WeaponRuntime.RestoreEquipped(1, 'test', items[9],
    throwableDefinition, 'test', 'throwable')
check(throwableRuntime.ok and WeaponRuntime.Get(1).slots.throwable ~= nil
    and throwableRuntime.value.nativeAmmoName == 'AMMO_THROWING_KNIVES',
    'Throwable weapon occupies its dedicated persistent slot')
local throwableLease = copy(throwableRuntime.value)
local throwableConsumed = AmmoService.SyncConsumption(1, context, {
    slot = 'throwable', itemInstanceId = throwableLease.itemInstanceId,
    generation = throwableLease.generation, total = 6, loaded = 1
})
check(throwableConsumed.ok and throwableConsumed.value.consumed == 2,
    'Throwable throws create bounded recovery credit')
local throwableRecovered = AmmoService.SyncConsumption(1, context, {
    slot = 'throwable', itemInstanceId = throwableLease.itemInstanceId,
    generation = throwableLease.generation, total = 8, loaded = 1
})
check(throwableRecovered.ok and throwableRecovered.value.recovered == 2,
    'Picked-up throwables restore escrow against recovery credit')
check(not AmmoService.SyncConsumption(1, context, {
    slot = 'throwable', itemInstanceId = throwableLease.itemInstanceId,
    generation = throwableLease.generation, total = 9, loaded = 1
}).ok, 'Throwable recovery cannot exceed its native cap or recovery credit')
WeaponDefinitionCatalog.weapons.throwable_throwing_knives.multiTypeAmmunition = true
assert(DefinitionRegistry.Start().ok)

local tomahawkDefinition = DefinitionRegistry.Get('weapon', 'throwable_tomahawk').value
local tomahawkAmmunition = DefinitionRegistry.Get('ammunition', 'ammo_tomahawk_regular').value
local tomahawkMetadata = WeaponMetadata.Build(tomahawkDefinition,
    { serialNumber = 'TEST-TOMAHAWK' })
check(WeaponValidation.Definition(tomahawkDefinition, 'weapon')
    and tomahawkAmmunition.nativeAmmoName == 'AMMO_TOMAHAWK'
    and tomahawkAmmunition.maxTotal == 3,
    'Standard Tomahawk carrier and native pool validate')
check(tomahawkMetadata.ok and tomahawkMetadata.value.ammo.type == 'ammo_tomahawk_regular'
    and tomahawkMetadata.value.ammo.loaded == 0
    and tomahawkMetadata.value.ammo.reserve == 0,
    'Tomahawk metadata starts with an empty regular-ammunition escrow')
tomahawkMetadata.value.ammo.loaded = 1
tomahawkMetadata.value.ammo.reserve = 2
tomahawkMetadata.value.ammo.chambered = true
items[10] = { id = 10, metadata = tomahawkMetadata.value, metadataRevision = 1 }
local tomahawkRuntime = WeaponRuntime.RestoreEquipped(1, 'test', items[10],
    tomahawkDefinition, 'test', 'throwable_secondary')
check(tomahawkRuntime.ok and WeaponRuntime.Get(1).slots.throwable ~= nil
    and WeaponRuntime.Get(1).slots.throwable_secondary ~= nil
    and tomahawkRuntime.value.nativeAmmoName == 'AMMO_TOMAHAWK',
    'Throwing Knives and Tomahawk coexist in persistent throwable positions')

local originalAttachments = copy(WeaponDefinitionCatalog.attachments)
local multiKnife = copy(WeaponDefinitionCatalog.weapons.throwable_throwing_knives)
multiKnife.multiTypeAmmunition = true
multiKnife.ammunitionTypes = { 'ammo_throwing_knives_regular', 'ammo_throwing_knives_poison' }
local multiMetadata = WeaponMetadata.Build(multiKnife, { serialNumber = 'TEST-MULTI',
    loadedAmmo = 1, reserveAmmo = 5, chambered = true }).value
check(multiMetadata.ammo.pools.ammo_throwing_knives_regular == 6,
    'Multi-type carrier imports the existing selected balance once')
multiMetadata.ammo.pools.ammo_throwing_knives_poison = 1
WeaponMetadata.ProjectAmmunitionPool(multiMetadata, multiKnife, 'ammo_throwing_knives_poison')
check(WeaponValidation.Metadata(multiMetadata, multiKnife)
    and multiMetadata.ammo.pools.ammo_throwing_knives_regular == 6,
    'Selecting Poison preserves the separately owned Regular pool')
multiMetadata.ammo.loaded = 0
multiMetadata.ammo.reserve = 0
WeaponMetadata.SaveSelectedAmmunitionPool(multiMetadata, multiKnife)
check(multiMetadata.ammo.pools.ammo_throwing_knives_poison == 0
    and multiMetadata.ammo.pools.ammo_throwing_knives_regular == 6,
    'Selected-pool consumption preserves other ammunition ownership')
multiMetadata.ammo.pools.ammo_throwing_knives_poison = 1
check(not WeaponValidation.Metadata(multiMetadata, multiKnife),
    'Selected projection mismatch is rejected')
multiMetadata.ammo.pools.ammo_throwing_knives_poison = 0
multiMetadata.ammo.pools.ammo_tomahawk_regular = 1
check(not WeaponValidation.Metadata(multiMetadata, multiKnife),
    'Multi-type carrier rejects incompatible pool ownership')
local originalKnife = WeaponDefinitionCatalog.weapons.throwable_throwing_knives
WeaponDefinitionCatalog.weapons.throwable_throwing_knives = multiKnife
assert(DefinitionRegistry.Start().ok)
items, stock, rejectTransaction = {}, { ammo_throwing_knives_poison = 1 }, false
WeaponRuntime.Begin({ source = 1, characterId = 1, sessionId = 'test' })
local ownedKnife = WeaponMetadata.Build(multiKnife, { serialNumber = 'TEST-MULTI-TX',
    loadedAmmo = 1, reserveAmmo = 5, chambered = true }).value
items[11] = { id = 11, metadata = ownedKnife, metadataRevision = 1 }
local multiLease = WeaponRuntime.RestoreEquipped(1, 'test', items[11], multiKnife,
    'test', 'throwable').value
multiLease.ammoPools.ammo_throwing_knives_regular = 5
check(items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 6,
    'Runtime pool snapshot does not alias persistent metadata')
multiLease.ammoPools.ammo_throwing_knives_regular = 6
local loadedPoison = AmmoService.LoadSlot(1, context, {
    slot = 'throwable', ammunitionType = 'ammo_throwing_knives_poison', amount = 1,
    itemInstanceId = 11, generation = multiLease.generation
})
check(loadedPoison.ok and stock.ammo_throwing_knives_poison == 0
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 6
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 1,
    'Loading a second pool conserves the first pool without returning it')
multiLease = WeaponRuntime.Get(1).slots.throwable
local poolSnapshot = ReconciliationService.Snapshot(1, 'test', 'test')
check(poolSnapshot.ok
    and poolSnapshot.value.slots.throwable.ammoPools.ammo_throwing_knives_regular == 6
    and poolSnapshot.value.slots.throwable.ammoPools.ammo_throwing_knives_poison == 1,
    'Client reconciliation response includes both authoritative ammo pools')
poolSnapshot.value.slots.throwable.ammoPools.ammo_throwing_knives_regular = 0
check(multiLease.ammoPools.ammo_throwing_knives_regular == 6,
    'Client reconciliation pool snapshot cannot mutate runtime ownership')
local selectedRegular = AmmoService.SwitchSlot(1, context, {
    slot = 'throwable', ammunitionType = 'ammo_throwing_knives_regular',
    itemInstanceId = 11, generation = multiLease.generation
})
check(selectedRegular.ok and selectedRegular.value.moved == 0
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 1,
    'Selection uses existing ownership without an Inventory grant or removal')
local unloadedRegular = AmmoService.Unload(1, context, nil, 'throwable')
check(unloadedRegular.ok and stock.ammo_throwing_knives_regular == 6
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 0
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 1,
    'Selected-type unload returns exact ownership and preserves the other pool')
multiLease = WeaponRuntime.Get(1).slots.throwable
check(AmmoService.LoadSlot(1, context, { slot = 'throwable',
    ammunitionType = 'ammo_throwing_knives_regular', amount = 2,
    itemInstanceId = 11, generation = multiLease.generation }).ok,
    'Reload Regular beside the preserved Poison pool')
multiLease = WeaponRuntime.Get(1).slots.throwable
local unloadLease = { slot = 'throwable', itemInstanceId = 11,
    generation = multiLease.generation, allTypes = true }
rejectTransaction = true
check(not AmmoService.Unload(1, context, nil, 'throwable', unloadLease).ok
    and stock.ammo_throwing_knives_regular == 4 and stock.ammo_throwing_knives_poison == 0
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 2
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 1
    and multiLease.ammoPools.ammo_throwing_knives_regular == 2
    and multiLease.ammoPools.ammo_throwing_knives_poison == 1,
    'Failed all-pool commit preserves Inventory, metadata and runtime ownership')
rejectTransaction = false
local unloadedAll = AmmoService.Unload(1, context, nil, 'throwable', unloadLease)
check(unloadedAll.ok and unloadedAll.value.moved == 3
    and unloadedAll.value.returnedPools.ammo_throwing_knives_regular == 2
    and unloadedAll.value.returnedPools.ammo_throwing_knives_poison == 1
    and stock.ammo_throwing_knives_regular == 6 and stock.ammo_throwing_knives_poison == 1
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 0
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 0
    and multiLease.ammoPools.ammo_throwing_knives_regular == 0
    and multiLease.ammoPools.ammo_throwing_knives_poison == 0,
    'All-pool unload returns each exact definition and clears all ownership once')
check(not AmmoService.Unload(1, context, nil, 'throwable', unloadLease).ok
    and stock.ammo_throwing_knives_regular == 6 and stock.ammo_throwing_knives_poison == 1,
    'Repeated all-pool unload cannot duplicate returned ammunition')
WeaponDefinitionCatalog.weapons.throwable_throwing_knives = originalKnife
-- Both native pools are independently conserved and no pickup may mint ammo.
multiLease = WeaponRuntime.Get(1).slots.throwable
check(AmmoService.LoadSlot(1, context, { slot = 'throwable', ammunitionType = 'ammo_throwing_knives_regular',
    amount = 2, itemInstanceId = 11, generation = multiLease.generation }).ok, 'Reload multi-pool checkpoint fixture')
multiLease = WeaponRuntime.Get(1).slots.throwable
check(AmmoService.LoadSlot(1, context, { slot = 'throwable', ammunitionType = 'ammo_throwing_knives_poison',
    amount = 1, itemInstanceId = 11, generation = multiLease.generation }).ok, 'Load Poison beside checkpoint fixture')
multiLease = WeaponRuntime.Get(1).slots.throwable
local checkpoint = { slot = 'throwable', itemInstanceId = 11, generation = multiLease.generation,
    ammunitionType = 'ammo_throwing_knives_poison',
    pools = { ammo_throwing_knives_regular = 2, ammo_throwing_knives_poison = 0 } }
rejectTransaction = true
check(not AmmoService.SyncPools(1, context, checkpoint).ok
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 1
    and multiLease.ammoPools.ammo_throwing_knives_poison == 1, 'Pool checkpoint failure preserves both authoritative states')
rejectTransaction = false
check(AmmoService.SyncPools(1, context, checkpoint).ok
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 2
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 0, 'Poison consumption leaves Regular untouched')
local inflated = copy(checkpoint)
inflated.pools.ammo_throwing_knives_regular = 3
check(not AmmoService.SyncPools(1, context, inflated).ok, 'Unowned Regular pickup cannot increase an owned pool')
local stale = copy(checkpoint)
stale.generation = stale.generation - 1
check(not AmmoService.SyncPools(1, context, stale).ok, 'Multi-pool checkpoint rejects stale lease')
local foreign = copy(checkpoint)
foreign.itemInstanceId = 999
check(not AmmoService.SyncPools(1, context, foreign).ok, 'Multi-pool checkpoint rejects foreign item')
local omitted = copy(checkpoint)
omitted.pools.ammo_throwing_knives_regular = nil
check(not AmmoService.SyncPools(1, context, omitted).ok, 'Multi-pool checkpoint rejects omitted ownership')
checkpoint.ammunitionType = 'ammo_throwing_knives_regular'
check(AmmoService.SyncPools(1, context, checkpoint).ok
    and items[11].metadata.ammo.loaded == 1 and items[11].metadata.ammo.reserve == 1
    and multiLease.generation == checkpoint.generation, 'Wheel selection projects owned pool without renewing the lease')
assert(DefinitionRegistry.Start().ok)
stock.ammo_throwing_knives_poison = 16
multiLease = WeaponRuntime.Get(1).slots.throwable
local fullPoison = AmmoService.LoadSlot(1, context, { slot = 'throwable',
    ammunitionType = 'ammo_throwing_knives_poison', amount = 16,
    itemInstanceId = 11, generation = multiLease.generation })
check(fullPoison.ok and fullPoison.value.moved == 8
    and stock.ammo_throwing_knives_poison == 8
    and items[11].metadata.ammo.pools.ammo_throwing_knives_poison == 8
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 2,
    'Eight-item Poison candidate cap preserves excess Inventory and Regular ownership')
local overCap = copy(items[11].metadata)
overCap.ammo.pools.ammo_throwing_knives_poison = 9
overCap.ammo.reserve = 8
check(not WeaponValidation.Metadata(overCap, originalKnife), 'Poison metadata rejects nine-item pool')
multiLease = WeaponRuntime.Get(1).slots.throwable
local capacityCheckpoint = { slot = 'throwable', itemInstanceId = 11,
    generation = multiLease.generation, ammunitionType = 'ammo_throwing_knives_poison',
    pools = { ammo_throwing_knives_regular = 2, ammo_throwing_knives_poison = 9 } }
check(not AmmoService.SyncPools(1, context, capacityCheckpoint).ok,
    'Poison checkpoint rejects a pool above its candidate capacity')
capacityCheckpoint.pools.ammo_throwing_knives_poison = 7
check(AmmoService.SyncPools(1, context, capacityCheckpoint).ok
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 2,
    'Full Poison pool consumes independently of Regular')
local capacityUnload = AmmoService.Unload(1, context, nil, 'throwable', {
    slot = 'throwable', itemInstanceId = 11, generation = multiLease.generation })
check(capacityUnload.ok and capacityUnload.value.moved == 7
    and stock.ammo_throwing_knives_poison == 15
    and items[11].metadata.ammo.pools.ammo_throwing_knives_regular == 2,
    'Poison unload returns seven exact items after one consumed from the full pool')
local retiredMetadata = copy(items[11].metadata)
retiredMetadata.ammo.type = 'ammo_throwing_knives_regular'
WeaponMetadata.ProjectAmmunitionPool(retiredMetadata, originalKnife, 'ammo_throwing_knives_regular')
retiredMetadata.ammo.pools.ammo_throwing_knives_improved = 0
check(WeaponMetadata.Validate(retiredMetadata, originalKnife, 'test').ok
    and retiredMetadata.ammo.pools.ammo_throwing_knives_improved == nil
    and retiredMetadata.ammo.pools.ammo_throwing_knives_regular == 2,
    'Retired empty Improved key normalizes without erasing supported ownership')
retiredMetadata.ammo.pools.ammo_throwing_knives_improved = 1
check(not WeaponMetadata.Validate(retiredMetadata, originalKnife, 'test').ok
    and retiredMetadata.ammo.pools.ammo_throwing_knives_improved == 1,
    'Nonzero retired Improved ownership is rejected, never silently discarded')
WeaponDefinitionCatalog.attachments.cattleman_wide_sight.prerequisites = { 'cattleman_long_barrel' }
check(DefinitionRegistry.Start().ok, 'Valid attachment prerequisite catalog accepted')
local prerequisiteMissing = DefinitionRegistry.ValidateAttachmentSet('revolver_cattleman', {
    { definitionId = 'cattleman_wide_sight', slot = 'sight' }
})
check(not prerequisiteMissing.ok
    and prerequisiteMissing.error.details.prerequisiteId == 'cattleman_long_barrel',
    'Attachment set rejects missing prerequisite')
check(DefinitionRegistry.ValidateAttachmentSet('revolver_cattleman', {
    { definitionId = 'cattleman_long_barrel', slot = 'barrel' },
    { definitionId = 'cattleman_wide_sight', slot = 'sight' }
}).ok, 'Attachment set accepts installed prerequisite')

WeaponDefinitionCatalog.attachments.cattleman_long_barrel.prerequisites = { 'cattleman_wide_sight' }
check(not DefinitionRegistry.Start().ok, 'Attachment prerequisite cycle rejected at startup')
WeaponDefinitionCatalog.attachments = copy(originalAttachments)
WeaponDefinitionCatalog.attachments.cattleman_wide_sight.prerequisites = { 'missing_attachment' }
check(not DefinitionRegistry.Start().ok, 'Unknown attachment prerequisite rejected at startup')
WeaponDefinitionCatalog.attachments = originalAttachments
assert(DefinitionRegistry.Start().ok)
reset('throwable_bolas_ironspiked')
stock.ammo_bolas_ironspiked = 5
local ironspikedLoad = AmmoService.Escrow(1, context, 5, 'ammo_bolas_ironspiked')
check(ironspikedLoad.ok and ironspikedLoad.value.total == 3
    and stock.ammo_bolas_ironspiked == 2, 'Ironspiked candidate cap preserves excess stock')
check(AmmoService.Unload(1, context).ok and stock.ammo_bolas_ironspiked == 5,
    'Ironspiked unload conserves its exact ammunition')
reset('throwable_bolas_intertwined')
stock.ammo_bolas_intertwined = 5
local brookstoneLoad = AmmoService.Escrow(1, context, 5, 'ammo_bolas_intertwined')
check(brookstoneLoad.ok and brookstoneLoad.value.total == 3
    and brookstoneLoad.value.loaded == 1 and brookstoneLoad.value.reserve == 2
    and stock.ammo_bolas_intertwined == 2, 'Brookstone candidate cap preserves excess stock')
check(not AmmoService.Escrow(1, context, 1, 'ammo_bolas_regular').ok,
    'Brookstone rejects another Bolas variant ammunition')
check(AmmoService.Unload(1, context).ok and stock.ammo_bolas_intertwined == 5,
    'Brookstone unload returns its exact ammunition')
reset('throwable_dynamite')
stock.ammo_dynamite = 10
local dynamiteLoad = AmmoService.Escrow(1, context, 10, 'ammo_dynamite')
check(dynamiteLoad.ok and dynamiteLoad.value.total == 8
    and dynamiteLoad.value.loaded == 1 and dynamiteLoad.value.reserve == 7
    and stock.ammo_dynamite == 2, 'Dynamite candidate ceiling preserves excess stock')
check(not AmmoService.Escrow(1, context, 1, 'ammo_bolas_regular').ok,
    'Dynamite rejects foreign-family ammunition')
check(AmmoService.Unload(1, context).ok and stock.ammo_dynamite == 10,
    'Dynamite unload conserves exact ammunition')
reset('throwable_molotov')
stock.ammo_molotov = 10
local fireBottleLoad = AmmoService.Escrow(1, context, 10, 'ammo_molotov')
check(fireBottleLoad.ok and fireBottleLoad.value.total == 8
    and stock.ammo_molotov == 2, 'Fire Bottle candidate ceiling preserves excess stock')
check(not AmmoService.Escrow(1, context, 1, 'ammo_dynamite').ok,
    'Fire Bottle rejects Dynamite ammunition')
check(AmmoService.Unload(1, context).ok and stock.ammo_molotov == 10,
    'Fire Bottle unload conserves exact ammunition')
reset('throwable_poisonbottle')
stock.ammo_poisonbottle = 10
local poisonBottleLoad = AmmoService.Escrow(1, context, 10, 'ammo_poisonbottle')
check(poisonBottleLoad.ok and poisonBottleLoad.value.total == 8
    and stock.ammo_poisonbottle == 2, 'Poison Bottle candidate ceiling preserves excess stock')
check(not AmmoService.Escrow(1, context, 1, 'ammo_molotov').ok,
    'Poison Bottle rejects Fire Bottle ammunition')
check(AmmoService.Unload(1, context).ok and stock.ammo_poisonbottle == 10,
    'Poison Bottle unload conserves exact ammunition')
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
print(('Ammunition regression checks: %d passed'):format(passed))
