for _,file in ipairs({'server/services/native_throwable_transition_binding.lua','server/services/native_projectile_collection_observation.lua',
 'server/services/native_throwable_collection_handoff.lua','server/services/native_throwable_collection_service.lua',
 'server/services/native_throwable_collection_transport.lua','server/services/native_throwable_collection_inventory.lua',
 'server/services/native_throwable_collection_host.lua'}) do dofile(file) end
Config={NativeThrowableNativeCollectionContract=0}
local gate=0
GetConvarInt=function() return gate end
assert(WeaponNativeThrowableCollectionHost.Start({}),'default-off bootstrap has no dependencies or side effects')
Config.NativeThrowableNativeCollectionContract=1;gate=1
local time=0
GetGameTimer=function() return time end
local later,events,commands,messages={},{},{},{}
SetTimeout=function(_,fn) later[#later+1]=fn end
AddEventHandler=function(name,fn) events[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
RegisterCommand=function(name,fn) commands[name]=fn end
TriggerClientEvent=function(name,source,action,packet) messages[#messages+1]={name=name,source=source,action=action,packet=packet} end
GetPlayers=function() return {'1','2'} end
local nextId=0
DB={value=function() nextId=nextId+1;return tostring(nextId) end}
local actors={[1]={characterId='jane',sessionId='donor',epoch='before',alive=true,bucket=0,position={x=0,y=0,z=0}},
 [2]={characterId='john',sessionId='collector',epoch='before',alive=true,bucket=0,position={x=0,y=0,z=0}}}
local rows={[10]={exists=true,netType=23,networkId=30,owner=1,bucket=0},[20]={exists=true,netType=8,networkId=40,owner=1,bucket=0}}
exports={['feather-inventory']={GetCharacterFirearmRuntimeSnapshot=function(_,context,limits)
 assert(context.actorSource==2 and limits.ammo_tomahawk_regular==3);return {ok=true,value={pools={ammo_tomahawk_regular=0}}}
end}}
local attached
assert(WeaponNativeThrowableCollectionHost.Start({actor=function(source) return actors[source] end,
 attach=function(s) attached=s;return true end,limits=function() return {ammo_tomahawk_regular=3} end,
 read=function(handle) return rows[handle] end,
 challenge=function() return {identity=actors[1],operationId='spend',units={{itemId=109,itemRevision=4}}} end,
 spend=function() return {custody='spent',origin=actors[1],operationId='spend',itemId=109,itemRevision=4,
  metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='PAID'}} end}))
commands.WeaponNativeCollectionTest(0,{'start','1','2'});assert(#messages==2 and attached)
events.entityCreated(10);time=100;rows[10].exists=false;events.entityRemoved(10)
time=150;events.entityCreated(20)
source=2;events['feather-weapons:server:native-collection-hint']({challengeId='challenge',projectileId=30,pickupId=40,position={x=0,y=0,z=0}})
assert(#messages==2,'collector cannot choose a paid origin hint')
source=1;events['feather-weapons:server:native-collection-hint']({challengeId='challenge',projectileId=30,pickupId=40,position={x=0,y=0,z=0}})
assert(#messages==3 and messages[3].action=='arm' and messages[3].source==2)
for _,fn in ipairs(later) do fn() end
assert(#messages==3,'read-only linking callbacks cannot register a second watch or invalidate the first')
print('PASS bounded paid test host: disabled startup, console two-player admission, real lifetime watch, source-bound hint and one collector arm')
