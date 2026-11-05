dofile('shared/constants.lua')
for i=1,300 do
 local id=('00000000-0000-4000-8000-%012x'):format(i)
 assert(WeaponNativeEnrollment.Allows({},id))
end
local _,_,status=WeaponNativeEnrollment.Validate({})
assert(status.mode=='all')
print('All-player admission PASS (300 independent characters, no configurable cap or mode)')
