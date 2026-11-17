for _,file in ipairs({'client/native_throwable_pickup_permissions.lua','client/native_throwable_collection_client.lua','client/native_throwable_collection_escrow.lua'}) do dofile(file) end
Config={NativeThrowableNativeCollectionContract=1,NativeThrowablePickupPriorPolicy={w_melee_tomahawk01=true,w_melee_tomahawk02=true}}
GetConvarInt=function() return 1 end
local handlers,threads,sends,values={},{},{},{}
RegisterNetEvent=function(n,f) handlers[n]=f end;RegisterCommand=function() end;AddEventHandler=function(n,f) handlers[n]=f end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
GetGameTimer=function() return 100 end
PlayerPedId=function() return 7 end;IsEntityDead=function() return 0 end
joaat=function(s) return s end
SetLocalPlayerPermittedToCollectPickupsWithModel=function(model,allowed) values[model]=allowed end
TriggerServerEvent=function(...) sends[#sends+1]={...} end
local baseline={characterId='john',sessionId='sid',epoch='epoch',revision=0,pools={ammo_tomahawk_regular=0}}
WeaponCharacterAmmoActiveOwner={Status=function() return {bootstrap={runtime={session={ammo={baseline=baseline}}}}} end}
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId='john',sessionId='sid'}} end}
WeaponCharacterAmmoPolicy={Build=function() return {names={},limits={ammo_tomahawk_regular=3}} end}
WeaponCharacterAmmoNative={New=function() return {Read=function() return {ammo_tomahawk_regular=0} end} end}
local starts=0
WeaponNativeThrowableEventProbe={StartReleased=function() starts=starts+1;return true end,LoanStage=function() end,Stop=function() end}
dofile('client/native_throwable_collection_host.lua')
assert(coroutine.resume(threads[1]))
assert(WeaponNativeThrowableCollectionClientHost.Ready() and values.w_melee_tomahawk01==false)
local packet={identity={characterId='john',sessionId='sid',epoch='epoch'},bucket=0,donor=false}
source=1;handlers['feather-weapons:client:native-collection-start'](packet)
assert(coroutine.resume(threads[1]) and starts==0,'client-origin test start is ignored')
source=65535;handlers['feather-weapons:client:native-collection-start'](packet)
assert(coroutine.resume(threads[1]) and starts==1)
source=1;handlers['feather-weapons:client:native-collection']('arm',{ticket='ticket',identity=packet.identity,bucket=0,lifetimeMs=30000})
assert(values.w_melee_tomahawk01==false,'client-origin arm cannot enable engine pickups')
source=65535;handlers['feather-weapons:client:native-collection']('arm',{ticket='ticket',identity=packet.identity,bucket=0,lifetimeMs=30000})
assert(values.w_melee_tomahawk01==true and values.w_melee_tomahawk02==true)
GetCurrentResourceName=function() return 'feather-weapons' end
handlers.onResourceStop('feather-weapons')
assert(values.w_melee_tomahawk01 and values.w_melee_tomahawk02,'owned prior permission policy restored')
print('PASS native collection client bootstrap: numeric BOOL alive, source65535 only, suppressed idle, armed collection and prior permission restoration')
