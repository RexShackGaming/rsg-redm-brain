local hashes = { regular = 1, express = 2, carbine = 3, lancaster = 4, WEAPON_UNARMED = 0 }
local totals, clips, selected = {[1] = 8, [2] = 4}, {[3] = 7, [4] = 0}, {carbine = 1, lancaster = 1}
local active = 3
local hashSelected = {[3] = 1, [4] = 1}
joaat = function(name) return hashes[name] end
GetCurrentPedWeapon = function() return true, active end
GetPedAmmoByType = function(_, hash) return totals[hash] end
GetAmmoInClip = function(_, hash) return true, clips[hash] end
SetPedAmmoByType = function(_, hash, amount) totals[hash] = amount end
SetAmmoInClip = function(_, hash, amount)
    clips[hash] = amount
    local id = hashSelected[hash] -- clip writes follow hash, not GUID selection
    totals[id] = totals[id] + amount
end
Citizen = {InvokeNative = function(hash, _, value, amount)
    if hash == 0xAF9D167A5656D6A6 then return selected[value] end
    if hash == 0x7FEAD38B326B9F74 then return 1 end -- getter always reports default Regular
    if hash == 0xCC9C4393523833E2 then hashSelected[value] = amount; return end
    if hash == 0xB6CFEC32E3742779 then
        totals[value] = totals[value] - amount
        if totals[value] == 0 and selected.carbine == value then
            clips[3] = 0
            selected.carbine = value == 1 and 2 or 1 -- native auto-selection artifact
        end
    end
end}
FeatherGuidWeapons = {ResolveExisting = function(name) return {guid = name} end,
    SelectExistingAmmo = function(_, name, ammo) selected[name] = hashes[ammo]; return true end}
FeatherNativeWeaponCoordinator = {RestorePoolTotals = function() totals[1], totals[2] = 8, 4 end}
dofile('shared/ammunition_pools.lua')
dofile('tests/archive/client/firearm_pools.lua')
local catalog = {ammunition = {regular = {nativeAmmoName = 'regular'}, express = {nativeAmmoName = 'express'}}, weapons = {}}
local slots = {}
for slot, name in pairs({shoulder = 'carbine', back = 'lancaster'}) do
    catalog.weapons[name] = {slot = 'longgun', capacity = 7, ammunitionTypes = {'regular', 'express'}}
    slots[slot] = {definitionId = name, nativeWeaponName = name, ammunitionType = 'regular',
        nativeAmmoName = 'regular', loaded = name == 'carbine' and 7 or 0,
        ammoPools = {regular = name == 'carbine' and 8 or 0, express = name == 'carbine' and 4 or 0},
        itemInstanceId = name, generation = 1}
end
assert(FeatherFirearmPools.Restore(1, slots, catalog))
active = 4
assert(FeatherFirearmPools.UpdateLonggunWindow(1, active, catalog))
assert(totals[1] == 0 and totals[2] == 0, 'Empty counterpart must see neither compatible pool')
selected.carbine = 2
local capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.shoulder.ammunitionType == 'regular' and capture.reports.shoulder.loaded == 7)
assert(capture.reports.shoulder.pools.regular == 8 and capture.reports.shoulder.pools.express == 4)
FeatherFirearmPools.Accept(capture)
active = 3
assert(FeatherFirearmPools.UpdateLonggunWindow(1, active, catalog))
assert(selected.carbine == 1 and clips[3] == 7)
assert(totals[1] == 8 and totals[2] == 4)
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.shoulder.ammunitionType == 'regular')
FeatherFirearmPools.Accept(capture)
-- An intentional type selection outside the protected window still works.
selected.carbine, hashSelected[3], clips[3] = 2, 2, 4
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.shoulder.ammunitionType == 'express')
FeatherFirearmPools.Accept(capture)
active = 4
assert(FeatherFirearmPools.UpdateLonggunWindow(1, active, catalog))
assert(totals[1] == 0 and totals[2] == 0)
capture = assert(FeatherFirearmPools.Capture(1, catalog))
assert(capture.reports.shoulder.ammunitionType == 'express')
FeatherFirearmPools.Accept(capture)
active = 3
assert(FeatherFirearmPools.UpdateLonggunWindow(1, active, catalog))
assert(hashSelected[3] == 2 and selected.carbine == 2 and clips[3] == 4)
assert(totals[1] == 8 and totals[2] == 4)
-- Restart must accept Express GUID despite the default-Regular getter.
slots.shoulder.ammunitionType, slots.shoulder.nativeAmmoName, slots.shoulder.loaded = 'express', 'express', 4
assert(FeatherFirearmPools.Restore(1, slots, catalog))
assert(hashSelected[3] == 2 and selected.carbine == 2 and clips[3] == 4)
print('Mixed-type longgun window selection regression PASS')
