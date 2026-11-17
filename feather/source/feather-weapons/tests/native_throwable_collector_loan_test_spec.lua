Config={AmmunitionPools={enabled=false}}
for _,path in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/native_acceptance_view.lua',
 'client/native_throwable_owner.lua','client/native_throwable_collector_loan_test.lua'}) do dofile(path) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local limits=WeaponCharacterAmmoPolicy.Limits();limits.ammo_tomahawk_regular=3
local registry=assert(WeaponNativeThrowablePolicy.RegistryFromLimits(WeaponDefinitionCatalog,limits))
local identity={characterId='collector',sessionId='collector-sid',epoch='collector-native-loan'}
local origin={characterId='thrower',sessionId='thrower-sid',epoch='thrower-native-loan'}
local function scenario(mode)
 local pools={};for id in pairs(limits) do pools[id]=0 end;pools.ammo_repeater_regular=2
 local clock,captured,removed,ready,present=0,0,0,0,false
 if mode=='prefunded' then pools.ammo_tomahawk_regular=1 end
 local competing=mode=='competing' or mode=='competing-partial' or mode=='competing-present'
 local api={unitCount=competing and 2 or nil,current=function() return mode~='scope' or clock<200 end,now=function() return clock end,
  pools=function() return copy(pools) end,quantity=function() return pools.ammo_tomahawk_regular end,
  ready=function() ready=ready+1 end,cancelled=function() return mode=='cancel' end,
  events=function() return mode=='no-event' and {} or (competing and {{kind='ai_pickup',collectorIsLocal=true},{kind='ai_pickup',collectorIsLocal=true}} or {{kind='ai_pickup',collectorIsLocal=true}}) end}
 if mode=='ammo-only' or competing then api.present=function() return present end end
 api.wait=function()
  clock=clock+(mode=='slow-switch' and 30000 or 100)
  if mode=='timeout' then clock=180001;return end
  if clock==100 then pools.ammo_tomahawk_regular=mode=='two' and 2 or 1;present=mode~='ammo-only' and not competing end
  if competing and clock==300 and mode~='competing-partial' then pools.ammo_tomahawk_regular=2;present=mode=='competing-present' end
  if mode=='competing-partial' and clock>=1000 then clock=180001 end
  if mode=='slow-switch' and clock==120000 then pools.ammo_tomahawk_regular=1;present=true end
  if mode=='foreign-pool' then pools.ammo_repeater_regular=1 end
 end
 api.owner=function(sealed)
  return WeaponNativeThrowableOwner.New({current=api.current,sealed=sealed,present=function() return present end,quantity=api.quantity,
   createFunded=function(approval,preserve)
    assert((mode=='ammo-only' or competing) and preserve==true and pools.ammo_tomahawk_regular==(competing and 2 or 1),'collector must never create ammunition')
    present=true;captured=captured+1;return {entity=0,inventoryOnly=true,guid=string.rep('1',32),itemId=approval.row.id,itemRevision=approval.row.revision}
   end,
   releaseSpent=function() error('collector has no spent entry') end,
   rebindPhysicalPickup=function(_,approval)
    captured=captured+1
    if mode=='capture-fail' then return nil end
    assert(approval.row.id==900000001 and approval.identity.characterId=='collector')
    return {entity=0,inventoryOnly=true,guid=string.rep('1',32),itemId=approval.row.id,itemRevision=approval.row.revision}
   end,
   removeOwned=function()
    removed=removed+1;if mode=='cleanup-fail' then return false end
    pools.ammo_tomahawk_regular=0;present=false;return true
   end},WeaponDefinitionCatalog,identity,limits)
 end
 return WeaponNativeThrowableCollectorLoanTest.Run(api,identity,origin,registry),captured,removed,ready
end
local r,captured,removed,ready=scenario('success')
assert(r.phase=='passed' and r.cleanupComplete and r.captured and r.economicWrites==0 and captured==1 and removed==1 and ready==1,tostring(r.reason))
for _,mode in ipairs({'prefunded','timeout','cancel','scope','capture-fail','cleanup-fail','foreign-pool','two'}) do
 local r=scenario(mode);assert(r.phase=='failed' and not r.cleanupComplete,mode)
end
local r=scenario('no-event');assert(r.phase=='failed' and r.cleanupComplete,'captured unit is still retired if event evidence is absent')
assert(scenario('slow-switch').phase=='passed','sequential client switching can take more than ninety seconds')
local r,captured,removed=scenario('ammo-only')
assert(r.phase=='passed' and r.captureMode=='zero_ammo_carrier' and captured==1 and removed==1)
print('PASS foreign collector loan: real owner idle recapture, no creation, exact cleanup and full pool conservation, prefunded/ambiguous/context/timeout/readback failures')

local r,captured,removed=scenario('competing')
assert(r.phase=='passed' and r.cleanupComplete and r.expectedUnits==2 and r.quantityAtCapture==2 and captured==1 and removed==1,tostring(r.reason))
assert(not scenario('competing-partial').cleanupComplete)
assert(not scenario('competing-present').cleanupComplete,'uncaptured existing competing carrier retained')
