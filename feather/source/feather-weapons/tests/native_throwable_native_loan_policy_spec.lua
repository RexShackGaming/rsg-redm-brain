-- Execute the real host pause boundary and permission restoration; no game/SQL.
dofile('client/native_throwable_pickup_permissions.lua')
Config={NativeThrowablePickupContract=1,NativeThrowablePickupPriorPolicy={w_melee_tomahawk01=true,w_melee_tomahawk02=true}}
WeaponNativeThrowablePolicy={UnitsEnabled=function() return true end}
local threads,changes={},{}
RegisterCommand=function() end
RegisterNetEvent=function() end
AddEventHandler=function() end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
joaat=function(v) return v end
SetLocalPlayerPermittedToCollectPickupsWithModel=function(model,value) changes[#changes+1]={model,value} end
WeaponNativeThrowablePickupClientTransport={Install=function() return {} end}
local closed=false
WeaponCharacterAmmoActiveOwner={Status=function() return {ownedCopies=closed and 0 or 1,cleanupComplete=closed,bootstrap={runtime={phase=closed and 'closed' or 'active'}}} end}
GetGameTimer=function() return 0 end
dofile('client/native_throwable_pickup_client.lua')
local host=WeaponNativeThrowablePickupClient
assert(coroutine.resume(threads[2]))
assert(host.Status().permissions.active and #changes==2)
assert(not host.BeginNativeLoan() and host.Status().enabled,'active owner cannot pause paid interaction')
closed=true
assert(host.BeginNativeLoan() and not host.Status().enabled and host.Status().permissions==nil)
assert(#changes==4 and changes[3][2]==true and changes[4][2]==true,'both explicit prior native policies restored before test')
assert(not host.BeginNativeLoan(),'nested loan refused')
host.EndNativeLoan()
assert(host.Status().enabled and not host.Ready(),'normal firing remains blocked until host resumes suppression')
assert(coroutine.resume(threads[2]))
assert(host.Status().permissions.active and #changes==6)
print('PASS native collection loan: closed-owner gate, exact prior permission restoration, overlap refusal and normal suppression reactivation')
