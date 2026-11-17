dofile('client/native_throwable_pickup_permissions.lua')
local one,two='w_melee_tomahawk01','w_melee_tomahawk02'
local values={[one]=true,[two]=false}
local function setter(k,v) values[k]=v end
local p=WeaponNativeThrowablePickupPermissions.New(setter,values)
assert(p.Suppress() and values[one]==false and values[two]==false)
assert(p.Suppress() and p.Status().active)
assert(p.Restore() and values[one]==true and values[two]==false and not p.Status().restorationPending)
assert(not pcall(WeaponNativeThrowablePickupPermissions.New,setter,{}),'unknown prior policy cannot be guessed')
local calls=0
local p=WeaponNativeThrowablePickupPermissions.New(function(k,v)
 calls=calls+1;values[k]=v;if calls==2 then error('partial native failure') end
end,{[one]=true,[two]=true})
assert(not p.Suppress() and values[one] and values[two] and not p.Status().restorationPending)
local restoreFails=true
local p=WeaponNativeThrowablePickupPermissions.New(function(_,v) if v and restoreFails then error('restore unavailable') end end,{[one]=true,[two]=true})
assert(p.Suppress() and not p.Restore() and p.Status().restorationPending)
restoreFails=false;assert(p.Restore())
print('PASS pickup permission policy: explicit baseline, scoped suppression, partial-failure compensation and retained cleanup')
local failAllow=false
local p=WeaponNativeThrowablePickupPermissions.New(function(k,v)
 values[k]=v;if failAllow and k==two and v then error('partial allow') end
end,{[one]=true,[two]=false})
assert(p.Suppress() and p.Allow() and values[one] and values[two])
assert(p.Suppress() and not values[one] and not values[two])
failAllow=true;assert(not p.Allow() and not values[one] and not values[two])
failAllow=false;assert(p.Restore() and values[one] and not values[two])
