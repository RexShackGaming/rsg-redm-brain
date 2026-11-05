local total, clips, active = 11, {carbine = 7, lancaster = 0}, 'unarmed'
joaat = function(v) return v end
GetCurrentPedWeapon = function() return true, active end
GetPedAmmoByType = function() return total end
GetAmmoInClip = function(_, weapon) return true, clips[weapon] end
SetAmmoInClip = function(_, weapon, amount) clips[weapon] = amount end
SetPedAmmoByType = function(_, _, amount) total = amount end
Citizen = { InvokeNative = function(hash, _, _, amount)
    if hash == 0xAF9D167A5656D6A6 then return 'regular' end
    if hash == 0xB6CFEC32E3742779 then
        total = total - amount
        if total == 0 then clips.carbine = 0 end
    end
end }
-- Capture normalizes hashes numerically.
joaat = function(v) return ({regular = 1, carbine = 2, lancaster = 3, WEAPON_UNARMED = 4})[v] end
GetCurrentPedWeapon = function() return true, joaat(active) end
GetAmmoInClip = function(_, hash) return true, clips[hash == 2 and 'carbine' or 'lancaster'] end
SetAmmoInClip = function(_, hash, amount)
    clips[hash == 2 and 'carbine' or 'lancaster'] = amount
    total = total + amount -- live clip-write artifact, not a pure assignment
end
local native = Citizen.InvokeNative
Citizen.InvokeNative = function(hash, ...)
    if hash == 0xAF9D167A5656D6A6 then return 1 end
    if hash == 0x7FEAD38B326B9F74 then return 1 end
    return native(hash, ...)
end
FeatherGuidWeapons = { ResolveExisting = function(v) return {guid = v} end,
    SelectExistingAmmo = function() return true end }
FeatherNativeWeaponCoordinator = { RestorePoolTotals = function() total = 11 end }
dofile('shared/ammunition_pools.lua')
dofile('tests/archive/client/firearm_pools.lua')
local catalog = {weapons = {}, ammunition = {regular = {nativeAmmoName = 'regular'}}}
local slots = {}
for slot, name in pairs({shoulder = 'carbine', back = 'lancaster'}) do
    catalog.weapons[name] = {slot = 'longgun', capacity = 7, ammunitionTypes = {'regular'}}
    slots[slot] = {definitionId = name, nativeWeaponName = name, nativeAmmoName = 'regular',
        ammunitionType = 'regular', loaded = name == 'carbine' and 7 or 0,
        ammoPools = {regular = name == 'carbine' and 11 or 0}, itemInstanceId = name, generation = 1}
end
assert(FeatherFirearmPools.Restore(1, slots, catalog))
active = 'lancaster'
assert(FeatherFirearmPools.UpdateLonggunWindow(1, 3, catalog))
assert(total == 0 and clips.carbine == 0)
local capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.shoulder.pools.regular == 11 and capture.reports.shoulder.loaded == 7)
FeatherFirearmPools.Accept(capture)
active = 'WEAPON_UNARMED'
assert(FeatherFirearmPools.UpdateLonggunWindow(1, 4, catalog))
assert(total == 11)
active = 'carbine'
assert(FeatherFirearmPools.UpdateLonggunWindow(1, 2, catalog))
assert(clips.carbine == 7 and total == 11)
clips.carbine, total = 6, 10
active = 'lancaster'
assert(not FeatherFirearmPools.UpdateLonggunWindow(1, 3, catalog), 'Pending shot must block exposure changes')
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.shoulder.pools.regular == 10)
FeatherFirearmPools.Accept(capture)
assert(FeatherFirearmPools.UpdateLonggunWindow(1, 3, catalog))
assert(total == 0)
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.shoulder.pools.regular == 10)
FeatherFirearmPools.Accept(capture)
active = 'carbine'
assert(FeatherFirearmPools.UpdateLonggunWindow(1, 2, catalog))
assert(total == 10 and clips.carbine == 6)
for _ = 1, 20 do assert(FeatherFirearmPools.UpdateLonggunWindow(1, 2, catalog)) end
assert(total == 10, 'Repeated frames must not rewrite/add loaded clip ammo')
total = 17
local rejected, reason = FeatherFirearmPools.Capture(1, catalog)
assert(not rejected and reason == 'native_pool_increased')
assert(not FeatherFirearmPools.UpdateLonggunWindow(1, 3, catalog))
print('Longgun escrow window mocked regression PASS')
