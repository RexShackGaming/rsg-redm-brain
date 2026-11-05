dofile('client/character_maintenance_native.lua')
local active,count=true,2
local api={current=function() return active end,category=function() return 123 end,
 count=function(category) assert(category==123); return count end,
 slot=function(_,index) return index+10 end,compatible=function(_,slot) return slot==11 end}
local value=assert(WeaponNativeAttachmentSlots.Read(api))
assert(value.noNativeWrites and value.noSQLWrites and #value.slots==2 and value.slots[2].wideSightCompatible)
count=33; assert(not WeaponNativeAttachmentSlots.Read(api),'bounded native slot count')
count=2; api.slot=function() return 10 end
assert(not WeaponNativeAttachmentSlots.Read(api),'duplicate slot cannot select arbitrary attachment parent')
api.slot=function(_,index) return index+10 end
api.compatible=function() active=false; return true end
assert(not WeaponNativeAttachmentSlots.Read(api),'context change refuses partial discovery')
print('Native attachment slot discovery PASS (read-only bounded slots, compatibility, duplicate and context refusal)')
