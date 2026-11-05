-- Run from resource root: lua tests/unfunded_ammo.lua
joaat = function(name) return name end
local pools = { regular = 6, express = 20, poison = 8 }
GetPedAmmoByType = function(_, hash) return pools[hash] or 0 end
Citizen = { InvokeNative = function(native, _, hash, amount)
    assert(native == 0xB6CFEC32E3742779)
    pools[hash] = pools[hash] - amount
end }
dofile('tests/archive/client/native_weapon_coordinator.lua')
local catalog = {
    weapons = { revolver = { ammunitionTypes = { 'regular', 'express' } },
        knives = { ammunitionTypes = { 'poison' } } },
    ammunition = { regular = { nativeAmmoName = 'regular' },
        express = { nativeAmmoName = 'express' }, poison = { nativeAmmoName = 'poison' } }
}
local slots = { primary = { definitionId = 'revolver', nativeAmmoName = 'express', ammo = 20 },
    throwable = { definitionId = 'knives', ammoPools = { poison = 8 } } }
local cleanup = FeatherNativeWeaponCoordinator.ClearUnfundedPools
cleanup(1, slots, catalog)
assert(pools.regular == 0 and pools.express == 20 and pools.poison == 8)
pools.regular = 6
slots.offhand = { definitionId = 'revolver', nativeAmmoName = 'regular', ammo = 6 }
cleanup(1, slots, catalog)
assert(pools.regular == 6, 'Another equipped weapon funds the regular pool')
cleanup(1, {}, catalog)
assert(pools.regular == 6, 'Empty/transition loadout must not clear unrelated pools')
slots.offhand = nil
slots.primary.ammoPools = { express = 20 }
pools.regular = 6
local restored = FeatherNativeWeaponCoordinator.RestorePoolTotals(1, slots, catalog)
assert(restored.regular == 0, 'Sparse metadata must include an approved zero for regular ammo')
assert(pools.regular == 0 and pools.express == 20 and pools.poison == 8,
    'Restore must remove default rounds without touching funded or unrelated types')
slots.offhand = { definitionId = 'revolver', nativeAmmoName = 'regular', ammo = 6 }
pools.regular = 6
FeatherNativeWeaponCoordinator.RestorePoolTotals(1, slots, catalog)
assert(pools.regular == 6, 'Sparse zero must not erase another instance contribution')
slots.offhand = nil
slots.primary.ammoPools = { regular = 8, express = 10 }
pools.regular, pools.express = 14, 10
FeatherNativeWeaponCoordinator.RestorePoolTotals(1, slots, catalog)
assert(pools.regular == 8 and pools.express == 10,
    'Post-holster restore removes duplicate clip rounds from a funded pool')
slots.offhand = { definitionId = 'revolver', nativeAmmoName = 'express', ammo = 10,
    ammoPools = { regular = 10, express = 10 } }
pools.regular, pools.express = 8, 10
SetPedAmmoByType = function(_, hash, amount) pools[hash] = amount end
FeatherNativeWeaponCoordinator.RestorePoolTotals(1, slots, catalog)
assert(pools.regular == 18 and pools.express == 20,
    'Distinct selections must restore both weapons inactive pools as well')
print('Unfunded pool cleanup and sparse restore tests passed')
