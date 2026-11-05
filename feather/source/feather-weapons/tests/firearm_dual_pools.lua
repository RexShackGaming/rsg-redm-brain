local hashes = { cattleman = 1, schofield = 4, regular = 2, express = 3, WEAPON_UNARMED = 0 }
local activeWeapon = 1
GetCurrentPedWeapon = function() return true, activeWeapon end
joaat = function(name) return hashes[name] end
local totals, clips, selected = { [2] = 20, [3] = 20 }, { [1] = 6, [4] = 6 }, { cattleman = 2, schofield = 3 }
GetPedAmmoByType = function(_, hash) return totals[hash] end
GetAmmoInClip = function(_, hash) return true, clips[hash] end
SetAmmoInClip = function(_, hash, amount) clips[hash] = amount end
Citizen = { InvokeNative = function(native, _, guid)
    if native == 0xAF9D167A5656D6A6 then return selected[guid] end
end }
FeatherGuidWeapons = { ResolveExisting = function(name) return { guid = name } end,
    SelectExistingAmmo = function(_, name, ammo) selected[name] = hashes[ammo] return true end }
FeatherNativeWeaponCoordinator = { RestorePoolTotals = function() end }
dofile('shared/ammunition_pools.lua')
dofile('tests/archive/client/firearm_pools.lua')
local catalog = { weapons = {}, ammunition = {
    regular = { nativeAmmoName = 'regular' }, express = { nativeAmmoName = 'express' } } }
local slots = {}
for index, role in ipairs({ 'primary', 'offhand' }) do
    local name = index == 1 and 'cattleman' or 'schofield'
    catalog.weapons[name] = { slot = 'sidearm', family = 'revolver', capacity = 6,
        ammunitionTypes = { 'regular', 'express' } }
    slots[role] = { definitionId = name, nativeWeaponName = name,
        nativeAmmoName = index == 1 and 'regular' or 'express',
        ammunitionType = index == 1 and 'regular' or 'express',
        ammoPools = { regular = 10, express = 10 }, loaded = 6, itemInstanceId = index, generation = index }
end
assert(FeatherFirearmPools.Restore(1, slots, catalog))
clips[1], totals[2] = 5, 19
local capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.pools.regular == 9 and capture.reports.offhand.pools.regular == 10)
assert(capture.reports.offhand.pools.express == 10)
FeatherFirearmPools.Accept(capture)
clips[4], totals[3] = 5, 19
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.pools.express == 10 and capture.reports.offhand.pools.express == 9)
FeatherFirearmPools.Accept(capture)
selected.schofield, clips[4] = 2, 6
capture = assert(FeatherFirearmPools.Capture(1, catalog))
FeatherFirearmPools.Accept(capture)
clips[1], clips[4], totals[2] = 4, 5, 17
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.pools.regular == 8 and capture.reports.offhand.pools.regular == 9)
assert(capture.reports.primary.pools.express == 10 and capture.reports.offhand.pools.express == 9)
slots.primary.ammoPools.regular, slots.primary.loaded = 5, 4
slots.offhand.ammoPools.regular, slots.offhand.loaded = 7, 5
totals[2], totals[3] = 12, 20
assert(FeatherFirearmPools.Restore(1, slots, catalog))
clips[1] = 6
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(clips[1] == 5 and capture.reports.primary.loaded == 5)
assert(capture.reports.primary.pools.regular == 5 and capture.reports.offhand.pools.regular == 7
    and totals[2] == 12, 'Native reload must not borrow another instance ownership')
FeatherFirearmPools.Accept(capture)
clips[1], activeWeapon = 0, 0
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.loaded == 5 and capture.reports.primary.pools.regular == 5,
    'Unarmed zero clip with unchanged pools is presentation, not consumption')
activeWeapon = 1
assert(not FeatherFirearmPools.Capture(1, catalog), 'Armed zero clip must still fail closed')
activeWeapon, totals[2] = 0, 11
assert(not FeatherFirearmPools.Capture(1, catalog), 'Unarmed must not conceal a pool decrease')
slots.offhand.ammoPools = { regular = 0, express = 0 }
slots.offhand.loaded = 0
totals[2], totals[3], activeWeapon = 5, 10, 0
assert(FeatherFirearmPools.Restore(1, slots, catalog))
GetAmmoInClip = function(_, hash)
    if hash == 4 then return false, nil end
    return true, clips[hash]
end
assert(FeatherFirearmPools.Capture(1, catalog), 'An explicitly empty counterpart may lack a clip surface')
GetAmmoInClip = function(_, hash) return true, clips[hash] end
clips[4] = 1
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(clips[4] == 0 and capture.reports.offhand.loaded == 0,
    'Empty counterpart stray native clip must be cleared without granting ownership')
-- Reproduce death immediately after the last offhand round: approved ownership
-- may have accepted the primary shot while the final secondary shot is pending.
-- The shoulder/back reuse fixture has different non-selected clip semantics;
-- this regression specifically targets the native sidearm pair.
if catalog.weapons[slots.primary.definitionId].slot == 'sidearm' then
slots.primary.ammoPools, slots.primary.loaded = {regular = 2, express = 4}, 2
slots.offhand.ammoPools, slots.offhand.loaded = {regular = 1, express = 0}, 1
slots.primary.ammunitionType, slots.primary.nativeAmmoName = 'regular', 'regular'
slots.offhand.ammunitionType, slots.offhand.nativeAmmoName = 'regular', 'regular'
totals[2], totals[3], activeWeapon = 3, 4, 1
assert(FeatherFirearmPools.Restore(1, slots, catalog))
clips[4], totals[2] = 0, 2
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.pools.regular == 2)
assert(capture.reports.offhand.pools.regular == 0 and capture.reports.offhand.loaded == 0)
assert(capture.reports.primary.pools.express == 4, 'Death boundary must preserve inactive pool')
FeatherFirearmPools.Accept(capture)
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.offhand.pools.regular == 0, 'Repeated boundary capture cannot double-charge')
end
print('Distinct dual firearm attribution and final offhand shot regression passed')
