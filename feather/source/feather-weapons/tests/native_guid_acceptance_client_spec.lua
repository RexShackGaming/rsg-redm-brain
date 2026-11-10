dofile('shared/native_guid_acceptance.lua')
dofile('client/character_ammunition_loadout.lua')
local function fixture(mode,origin)
 local events,output,rows={},nil,{}
 local docs,ids,serial,acknowledgements={},{},0,0
 local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
 local clock,threads,created,removed,live,ammo=0,0,0,0,false,1
 local wear={damage=0,degradation=0,dirt=0,soot=0,permanentDegradation=0}
 local scope={characterId='c',sessionId='s',epoch='e'}
 RegisterNetEvent=function(name,fn) events[name]=fn end
 TriggerServerEvent=function(name,ticket,sequence,raw)
  if name=='feather-weapons:server:guid-suite-chunk' or name=='feather-weapons:server:guid-suite-result' then
   assert(type(raw)=='string' and #raw<=6000)
   local value=copy(docs[raw])
   local kind=name:match('guid%-suite%-(.+)$')
   if kind=='chunk' then
    for i,row in ipairs(value.rows) do rows[value.first+i-1]=row end
   else output=value;output.cases=rows end
   acknowledgements=acknowledgements+1
   if mode=='lost-ack' and acknowledgements==1 or mode=='no-ack' then return end
   local origin=source;source=65535
   events['feather-weapons:client:guid-suite-report-ack'](ticket,kind,sequence)
   source=origin
  end
 end
 CreateThread=function(fn) threads=threads+1;if threads==2 or mode=='transport' then fn() end end -- input loop is independently installed
 GetGameTimer=function() return clock end
 Wait=function() clock=clock+1 end
 PlayerPedId=function() return 42 end
 HasPedGotWeapon=function() return live end
 joaat=function() return 100 end
 Citizen={InvokeNative=function(native)
  if native==0x025A1B1FB03FBF61 then return mode=='phantom' end
  return true
 end}
 WeaponNativeAcceptanceView={Equal=function(a,b) return a and b and a.ammo==b.ammo end,Read=function() return {} end}
 WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId='c',sessionId='s',ped=42}} end}
 WeaponCharacterAmmoActiveOwner={Status=function() return {ownedCopies=0,cleanupComplete=true,
  bootstrap={runtime={phase='closed',runtimeBusy=false,receiving=false}}} end}
 WeaponCharacterAmmoPolicy={Build=function() return {weapons={w={nativeWeaponName='WEAPON_FAKE'}},names={},limits={}} end}
 WeaponDefinitionCatalog={}
 WeaponCharacterAmmoNative={New=function() return {Read=function() return {ammo=ammo} end} end}
 WeaponGuidAcceptance.Matrix=function() return {{id='one'},{id='two'}} end
 WeaponGuidAcceptance.Plan=function(_,_,_,identity)
  return {identity=identity,items={{definitionId='w',creation='native_inventory_guid',point=2,maintenance=wear}}}
 end
 json={encode=function(value)
  if not ids[value] then serial=serial+1;ids[value]=tostring(serial) end
  docs[ids[value]]=copy(value);return ids[value]
 end}
 WeaponCharacterAmmoCreationNative={GuidKey=function() return 'exact-guid' end,Scoped=function(_,_,_,_,current)
  assert(current())
  return {current=current,prepareDual=function() return true end,
   createSingle=function()
    created=created+1;live=true
    if mode=='ammo' then ammo=2 end
    return {entity=101,point=2,guid='exact-guid'}
   end,createPair=function() error('unexpected pair') end,
   finish=function() return true end,readMaintenance=function() return wear end,
   remove=function() removed=removed+1;if mode=='cleanup' then return false end;live=false;return true end,
   cleanupSetup=function() return true end}
 end}
 dofile('client/native_guid_acceptance.lua')
 source=origin or 65535
 if mode=='transport' then events['feather-weapons:client:guid-suite-transport']('ticket',scope,2)
 else events['feather-weapons:client:guid-suite-run']('ticket',scope,2) end
 return output,created,removed,threads,WeaponGuidAcceptanceClient.Delivery,WeaponGuidAcceptanceClient.Report
end
local value,created,removed=fixture(nil)
assert(value.phase=='complete' and value.passed==2 and value.cleanupComplete and created==2 and removed==2)
value,created,removed=fixture('cleanup')
assert(value.phase=='review_required' and not value.cleanupComplete and created==1 and removed==1)
value,created,removed=fixture('phantom')
assert(value.phase=='review_required' and not value.cleanupComplete and created==1 and removed==1,
 'model disappearance does not prove exact GUID removal')
value,created,removed=fixture('ammo')
assert(value.phase=='review_required' and not value.cleanupComplete and created==1 and removed==1,
 'changed pools block further cases; runner never resets or credits ammo')
value,created=fixture(nil,42)
assert(value==nil and created==0,'local/foreign event cannot create temporary copies')
print('GUID client composition PASS (server origin, released owner, candidate-only factory, exact cleanup, first-failure stop, pool mismatch hold; mocked natives)')

local value,created,removed,_,delivery=fixture('lost-ack')
assert(value.phase=='complete' and created==2 and removed==2 and delivery.ok and delivery.retries==1,
 'lost report acknowledgement retries only the same packet, never native creation')
local value,created,removed,_,delivery,retained=fixture('no-ack')
assert(value==nil and created==2 and removed==2 and not delivery.ok and retained.passed==2,
 'delivery failure preserves completed native results without creating any more copies')

local value,created,removed=fixture('transport')
assert(value.phase=='complete' and value.candidate=='report_transport_only' and value.passed==2
 and created==0 and removed==0 and value.cases[1].synthetic,
 'transport-only client generates report data without native creation/removal')
