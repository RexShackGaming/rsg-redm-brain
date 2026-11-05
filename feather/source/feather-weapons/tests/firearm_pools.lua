local hashes = { gun = 1, regular = 2, express = 3, WEAPON_UNARMED = 0 }
GetCurrentPedWeapon = function() return true, 1 end
joaat = function(name) return hashes[name] end
local totals, clip, selected = { [2] = 10, [3] = 20 }, 6, 3
GetPedAmmoByType = function(_, hash) return totals[hash] end
GetAmmoInClip = function() return true, clip end
SetAmmoInClip = function(_, _, amount) clip = amount end
Citizen = { InvokeNative = function(native)
    if native == 0xAF9D167A5656D6A6 then return selected end
end }
FeatherGuidWeapons = { SelectExistingAmmo = function() return true end,
    ResolveExisting = function() return { guid = 'test' } end }
FeatherNativeWeaponCoordinator = { RestorePoolTotals = function() end }
dofile('shared/ammunition_pools.lua')
dofile('tests/archive/client/firearm_pools.lua')
local catalog = { weapons = { gun = { family = 'revolver', capacity = 6,
    ammunitionTypes = { 'regular', 'express' } } },
    ammunition = { regular = { nativeAmmoName = 'regular' }, express = { nativeAmmoName = 'express' } } }
local slots = { primary = { definitionId = 'gun', nativeWeaponName = 'gun', nativeAmmoName = 'express',
    ammunitionType = 'express', ammoPools = { regular = 10, express = 20 },
    itemInstanceId = 1, generation = 2, loaded = 6 } }
assert(FeatherFirearmPools.Restore(1, slots, catalog))
clip, totals[3] = 5, 19
local capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.pools.express == 19 and capture.reports.primary.pools.regular == 10)
local retry = assert(FeatherFirearmPools.Capture(1, catalog))
assert(retry.reports.primary.pools.express == 19, 'Uncommitted observation must not double charge a retry')
FeatherFirearmPools.Accept(capture)
assert(FeatherFirearmPools.Capture(1, catalog).reports.primary.pools.express == 19)
-- A partial native reload only changes the clip projection. The owned total
-- stays fixed, and the next shot is charged exactly once from that total.
clip = 6
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.loaded == 6 and capture.reports.primary.pools.express == 19,
    'Partial reload must not consume or create ownership')
FeatherFirearmPools.Accept(capture)
clip, totals[3] = 5, 18
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.loaded == 5 and capture.reports.primary.pools.express == 18,
    'Post-reload shot must debit the selected pool exactly once')
FeatherFirearmPools.Accept(capture)
selected, clip = 2, 6
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.ammunitionType == 'regular' and capture.reports.primary.pools.regular == 10)
FeatherFirearmPools.Accept(capture)
-- Switching back after a partial reload must preserve both totals. The native
-- clip may rematerialize independently for each selected ammunition type.
selected, clip = 3, 5
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.primary.ammunitionType == 'express'
    and capture.reports.primary.pools.regular == 10
    and capture.reports.primary.pools.express == 18,
    'Switching ammunition after reload must conserve every owned pool')
FeatherFirearmPools.Accept(capture)
selected, clip = 2, 6
capture = assert(FeatherFirearmPools.Capture(1, catalog))
FeatherFirearmPools.Accept(capture)
totals[2] = 9
assert(not FeatherFirearmPools.Capture(1, catalog), 'Unattributed pool decrease must fail closed')
FeatherFirearmPools.Reset()
assert(not FeatherFirearmPools.Capture(1, catalog))
catalog.weapons.legacy = { slot = 'longgun' }
slots.shoulder = { definitionId = 'legacy', ammo = 0 }
totals[2], totals[3], selected, clip = 10, 20, 3, 6
assert(FeatherFirearmPools.Restore(1, slots, catalog), 'Empty legacy firearm may coexist')
slots.shoulder.ammo = 1
local writes = 0
Citizen.InvokeNative = function() writes = writes + 1 end
local restored, failure = FeatherFirearmPools.Restore(1, slots, catalog)
assert(not restored and failure == 'mixed_firearm_pool_modes')
assert(writes == 0, 'Mixed loaded modes must be rejected before native writes')
assert(not FeatherFirearmPools.Capture(1, catalog), 'Rejected restore cannot checkpoint')
slots.shoulder = nil
Citizen.InvokeNative = function(native)
    if native == 0xAF9D167A5656D6A6 then return selected end
end
clip, totals[2], totals[3], selected = 6, 10, 20, 3
assert(FeatherFirearmPools.Restore(1, slots, catalog))
FeatherGuidWeapons.ResolveExisting = function() return nil end
local missing, missingReason = FeatherFirearmPools.Capture(1, catalog)
assert(not missing and missingReason == 'weapon_guid_not_ready', 'Missing GUID must not submit a checkpoint')
FeatherGuidWeapons.ResolveExisting = function() return { guid = 'test' } end
selected = 999
assert(not FeatherFirearmPools.Capture(1, catalog), 'Unknown selection must not submit a checkpoint')
selected = 3
assert(FeatherFirearmPools.Capture(1, catalog).reports.primary.pools.express == 20,
    'Rejected observations preserve the approved baseline')
print('Firearm pool observer checks passed')
