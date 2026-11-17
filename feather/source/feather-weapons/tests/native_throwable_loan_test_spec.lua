Config={AmmunitionPools={enabled=false}}
for _,path in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/native_acceptance_view.lua',
 'client/native_throwable_owner.lua','client/native_throwable_loan_test.lua'}) do dofile(path) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local limits=copy(assert(WeaponNativeThrowablePolicy.Preview(WeaponDefinitionCatalog,
 assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)))).registry.limits)
limits.ammo_tomahawk_regular=3
local registry=assert(WeaponNativeThrowablePolicy.RegistryFromLimits(WeaponDefinitionCatalog,limits))
local identity={characterId='test',sessionId='session',epoch='native-loan:ticket'}
local function scenario(mode)
 local pools={};for id in pairs(limits) do pools[id]=0 end;pools.ammo_repeater_regular=2
 local clock,present,created,removed,rebound=0,false,0,0,0
 local competing=mode=='competing' or mode=='competing-partial'
 local api={unitCount=competing and 2 or nil,now=function() return clock end,current=function() return mode~='changed' or clock<2 end,
 pools=function() return copy(pools) end,quantity=function() return pools.ammo_tomahawk_regular end,
 stage=function(stage) if mode=='stage_fail' and stage=='cleaning' then error('presentation unavailable') end end,
 cancelled=function() return mode=='cancel' or mode=='cancel_after_throw' and clock>=1 end,
 events=function()
  if mode=='objects_only' then return {{kind='tomahawk_object_snapshot',object={entity=50,networkId=5}}} end
  return clock>=(mode=='delayed_event' and 4 or 2) and mode~='no_event' and {{kind='network_pickup',rawSlots={1,2,3}}} or {}
 end}
 api.wait=function()
  clock=clock+1
  if mode=='timeout' or mode=='cancel' then clock=90001;return end
  if clock==1 then pools.ammo_tomahawk_regular=competing and 1 or 0;present=competing end
  if competing and clock==2 and mode~='competing-partial' then pools.ammo_tomahawk_regular=0;present=false end
  if clock==2 and mode~='uncollected' and mode~='foreign_collector' and not competing then pools.ammo_tomahawk_regular=1;present=true end
  if mode=='foreign_pool' and clock==2 then pools.ammo_repeater_regular=1 end
  if clock>3 then clock=90001 end
 end
 api.owner=function(sealed)
  return WeaponNativeThrowableOwner.New({current=api.current,sealed=sealed,present=function() return present end,
   quantity=api.quantity,createFunded=function()
    created=created+1;if mode=='create_fail' then return nil end
    pools.ammo_tomahawk_regular=competing and 2 or 1;present=true;return {entity=1,guid=string.rep('1',32)}
   end,
   rebindPhysicalPickup=function(_,approval)
    rebound=rebound+1;if mode=='rebind_fail' then return nil end
    return {entity=0,inventoryOnly=true,guid=string.rep('2',32),itemId=approval.row.id,itemRevision=approval.row.revision}
   end,
   removeOwned=function()
    removed=removed+1;if mode=='cleanup_exception' then error('native unavailable') end
    pools.ammo_tomahawk_regular=0;present=false;return mode~='cleanup_fail'
   end,releaseSpent=function()
    assert(mode=='foreign_collector' or mode=='competing','A zero ped count must not clean an uncollected world projectile')
    removed=removed+1;return true
   end},
   WeaponDefinitionCatalog,identity,limits)
 end
 if mode=='foreign_collector' or competing then api.remoteCollected=function() return clock>=3 end end
 local result=WeaponNativeThrowableLoanTest.Run(api,identity,registry)
 assert(created==1,'native creation must never replay')
 return result,removed,rebound
end
local r,removed,rebound=scenario('success')
assert(r.phase=='complete' and r.passed==1 and r.cleanupComplete and removed==1 and rebound==1)
assert(r.cases[1].syntheticNativeOnly and r.cases[1].economicWrites==0 and #r.cases[1].observations==2)
for _,mode in ipairs({'uncollected','cancel_after_throw','changed','rebind_fail','create_fail','foreign_pool','cleanup_fail','cleanup_exception'}) do
 local result=scenario(mode)
 assert(result.phase=='review_required' and not result.cleanupComplete,mode)
end
for _,mode in ipairs({'cancel','timeout','no_event','stage_fail','objects_only'}) do
 local result,count=scenario(mode)
 assert(result.phase=='review_required' and result.cleanupComplete and count==1,mode)
end
print('PASS isolated throwable loan: real owner composition, one creation, recapture, exact cleanup and retained failures')

local delayed=scenario('delayed_event');assert(delayed.phase=='complete','pickup events delivered after the native pool increase are captured')
local objects=scenario('objects_only');assert(objects.reason=='pickup_events_not_observed' and #objects.cases[1].worldEvidence==1,'world snapshots never substitute for pickup events')
local foreign,removed,rebound=scenario('foreign_collector')
assert(foreign.phase=='complete' and foreign.cleanupComplete and foreign.cases[1].foreignCollector and removed==1 and rebound==0,
 'server-confirmed foreign collector cleanup permits only spent-entry release, without recapturing/granting the thrower a unit')

local result,removed,rebound=scenario('competing')
assert(result.phase=='complete' and result.cleanupComplete and result.cases[1].expectedUnits==2 and removed==1 and rebound==0)
assert(not scenario('competing-partial').cleanupComplete,'partially thrown competing batch stays retained')
