-- Execute the actual read-only projection block without starting CFX services.
local file=assert(io.open('server/services/native_equipment_transition.lua','r'))
local source=file:read('*a'); file:close()
local block=assert(source:match('(local slotOverview={}.-)            if value.candidate.metadata'))
local project=assert(load('return function(value,intent) '..block..' return slotOverview end'))()
local expected={weapon={itemId=155,revision=3},weapon_utility_secondary={itemId=172,revision=0}}
local slots=project({expected=expected},{itemId=172})
assert(#slots==12)
local bySlot={}
for _,slot in ipairs(slots) do
    assert(not bySlot[slot.slot]); bySlot[slot.slot]=slot
end
assert(bySlot.weapon.state=='occupied' and bySlot.weapon.itemId==155)
assert(bySlot.weapon_utility_secondary.state=='selected' and bySlot.weapon_utility_secondary.itemId==172)
assert(bySlot.weapon_utility.state=='open' and bySlot.weapon_utility.itemId==nil)
assert(bySlot.weapon_throwable.state=='open')
slots[1].itemId=999
assert(expected.weapon.itemId==155)
for _,slot in ipairs(project({expected={}},{itemId=172})) do assert(slot.state=='open') end
assert(select(2,source:gsub('slots=slotOverview',''))==5,'all option families include occupancy')
WeaponNativeUtilityCatalog={BinocularsEnabled=function() return true end,CameraEnabled=function() return false end,AdvancedCameraEnabled=function() return false end,ImprovedBinocularsEnabled=function() return false end,MetalDetectorEnabled=function() return false end,FishingRodEnabled=function() return false end}
expected.weapon_utility_tertiary={itemId=174,revision=0}
local expanded=project({expected=expected},{itemId=174})
assert(#expanded==13 and expanded[13].slot=='weapon_utility_tertiary'
    and expanded[13].state=='selected' and expanded[13].itemId==174)
WeaponNativeUtilityCatalog.CameraEnabled=function() return true end
expected.weapon_utility_quaternary={itemId=175,revision=0}
expanded=project({expected=expected},{itemId=175})
assert(#expanded==14 and expanded[14].state=='selected' and expanded[14].itemId==175)
WeaponNativeUtilityCatalog.AdvancedCameraEnabled=function() return true end
expected.weapon_utility_quinary={itemId=176,revision=0}
expanded=project({expected=expected},{itemId=176})
assert(#expanded==15 and expanded[15].state=='selected' and expanded[15].itemId==176)
WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled=function() return true end
expected.weapon_utility_senary={itemId=177,revision=0}
expanded=project({expected=expected},{itemId=177})
assert(#expanded==16 and expanded[16].state=='selected' and expanded[16].itemId==177)
print('Native equipment slot overview PASS')
WeaponNativeUtilityCatalog.MetalDetectorEnabled=function() return true end
WeaponNativeUtilityCatalog.FishingRodEnabled=function() return true end
expected.weapon_utility_septenary={itemId=178,revision=0}
expected.weapon_utility_octonary={itemId=179,revision=0}
expanded=project({expected=expected},{itemId=179})
assert(#expanded==18)
local seen={}; for _,v in ipairs(expanded) do seen[v.slot]=v end
assert(seen.weapon_utility_septenary.state=='occupied' and seen.weapon_utility_octonary.state=='selected')
