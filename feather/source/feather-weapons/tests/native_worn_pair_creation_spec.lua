dofile('client/character_maintenance_native.lua')
dofile('client/character_ammunition_creation_native.lua')
dofile('client/character_ammunition_loadout.lua')
local N=WeaponCharacterAmmoCreationNative
local identity={characterId='c',sessionId='s',epoch='e'}
local function rawGuid(n) return string.pack('<I4I4I4I4I4I4I4I4',n,0,2,0,3,0,4,0)..string.rep('\0',72) end
RegisterCommand=function() end
dofile('tests/support/native_pair_options_probe.lua')
local P=WeaponNativePairOptionsProbe
local abiGuid=rawGuid(20)
assert(N.PairOptions(abiGuid,100,2,752097756)==P.Pack(abiGuid,100,2,752097756),
 'normal factory uses the exact live-verified diagnostic options bytes')
local abiFull=abiGuid:sub(1,32)..string.pack('<I4I4',100,0)..string.rep('\0',136)
assert(N.PairRecord(abiFull,abiGuid,100,0.1)==P.SetTemporaryPermanent(P.EnableInventoryRecord(abiFull,abiGuid,100),abiGuid,100,0.1),
 'normal record update matches the verified enable/permanent-field update')
assert(not N.PairRecord(abiFull,rawGuid(21),100,0.1) and not N.PairRecord(abiFull,abiGuid,101,0.1))
assert(not N.PairRecord(abiFull,abiGuid,100,0/0))
local function fixture(mode,targets)
 local points,entries,applied,order={},{},{},{}
 local sequence,removals,grants=0,0,0
 local current=true
 local function key(raw) return N.GuidKey(raw) end
 PlayerPedId=function() return 10 end
 DoesEntityExist=function() return true end
 IsEntityDead=function() return false end
 joaat=function(name) return name=='WEAPON_UNARMED' and 0 or 100 end
 HasPedGotWeapon=function() return false end
 GetCurrentPedWeapon=function(_,_,point) return points[point]~=nil,points[point] and 100 or 0 end
 GetCurrentPedWeaponEntityIndex=function(_,point) return points[point] and points[point].entity or 0 end
 GetGameTimer=function() return 1 end
 Wait=function() error('unexpected settle wait') end
 SetCurrentPedWeapon=function() end
 GiveWeaponToPed=function() grants=grants+1; error('model grant forbidden for worn pair') end
 GetObjectIndexFromEntityIndex=function(handle) return handle end
 GetWeaponPermanentDegradation=function(handle)
  for _,p in pairs(points) do if p.entity==handle then
   return mode=='getter' and 0 or string.unpack('<f',entries[p.guid],137)
  end end
  error('unowned wear read')
 end
 Citizen={InvokeNative=function(native,_,raw,...)
  if native==0x886DFD3E185C8A89 or native==0x94A3C1B804D291EC then return true end
  if native==0xCB5D11F9508A928D then
   if mode=='insert' then return false end
   entries[key(raw)]=raw:sub(1,32)..string.pack('<I4I4',100,0)..string.rep('\0',136)
   return true
  end
  if native==0xDCCAA7C3BFD88862 then
   local moved=select(4,...)
   entries[key(moved)]=moved:sub(1,32)..entries[key(raw)]:sub(33); entries[key(raw)]=nil
   return true
  end
  if native==0x3E4E811480B3AE79 then
   removals=removals+1
   if mode=='cleanup' then return false end
   entries[key(raw)]=nil; return true
  end
  error('unexpected native '..tostring(native))
 end}
 local pairApi={
  buffer=function() sequence=sequence+1; return rawGuid(sequence) end,
  read=function(record)
   local value=entries[key(record.guid)]
   if mode=='record' then return value:sub(1,32)..string.pack('<I4I4',999,0)..value:sub(41) end
   return value
  end,
  update=function(record,value)
   if mode=='update' then return false end
   local before=entries[key(record.guid)]
   assert(value:sub(1,136)==before:sub(1,136) and value:sub(141,168)==before:sub(141,168))
   if mode~='update-readback' then entries[key(record.guid)]=value end
   return true
  end,
  activate=function(record)
   order[#order+1]=record.point
   assert(record.point~=3 or points[2],'primary must exist before offhand activation')
   if mode=='activate' or mode=='cleanup' then return false end
   points[record.point]={entity=record.point==2 and 202 or 203,guid=key(record.guid)}
   if mode=='duplicate-guid' and record.point==3 then points[3].guid=points[2].guid end
   if mode=='lifecycle' then current=false end
   return true
  end}
 local guid=N -- real identity resolver, mocked native observations
 guid=WeaponNativeGuidIdentity.New({current=function() return current end,hash=joaat,
  exists=function() return true end,point=function(point)
   local p=points[point]; if p then return {entity=p.entity,hash=100,guid=p.guid} end
  end})
 local items={}
 for index,point in ipairs({2,3}) do
  items[index]={nativeWeaponName='WEAPON_REVOLVER_CATTLEMAN',point=point,itemInstanceId=100+index,
   itemRevision=index,serialNumber='serial-'..index,attachments={},cosmetics={},
   maintenance={permanentDegradation=targets[index]}}
 end
 local adapter=N.New(10,function() return current end,function() return true end,
  function(record,scope,maintenance)
   assert(scope==identity and guid.Resolve(record,identity)==record.entity)
   if mode=='maintenance' then return false,'wear_restore_failure' end
   applied[record.itemInstanceId]=maintenance.permanentDegradation; return true
  end,guid,false,pairApi)
 return adapter,items,function() return removals,grants,applied,order end
end
for _,targets in ipairs({{0.1,0.25},{0.25,0.1},{0.1,0},{0,0.1}}) do
 local adapter,items,state=fixture(nil,targets)
 local records=assert(adapter.createPair(items,identity))
 local removed,grants,applied,order=state()
 assert(#records==2 and records[1].entity~=records[2].entity and grants==0)
 assert(applied[101]==targets[1] and applied[102]==targets[2])
 assert(order[1]==2 and order[2]==3)
 assert(adapter.remove(records[1]) and adapter.remove(records[2]))
 assert(state()==2)
end
for _,mode in ipairs({'record','update','update-readback','activate','duplicate-guid','getter','maintenance','cleanup','insert','lifecycle'}) do
 local adapter,items,state=fixture(mode,{0.1,0.25})
 local result,why,partial=adapter.createPair(items,identity)
 assert(not result and type(why)=='string' and partial,mode)
 if mode=='cleanup' or mode=='insert' then
  assert(not partial.cleanupComplete and #partial.handles>0,'uncertain resources retained: '..mode)
 else assert(partial.cleanupComplete,'exact GUID compensation expected: '..mode) end
 local _,grants=state(); assert(grants==0)
end
-- Failed adapters must pass unidentified residuals through the executor.
local opaque={pairGrantPending=true}
local executor=WeaponCharacterAmmoLoadout.New({current=function() return true end,prepareDual=function() return true end,
 createPair=function() return nil,'unknown',{handles={opaque},cleanupComplete=false} end,
 createSingle=function() error('unexpected single') end,remove=function() return false end,finish=function() return true end})
local plan={identity=identity,dual=true,items={{creation='inventory_guid_pair'},{creation='inventory_guid_pair'}}}
local result,why,partial=executor.Create(plan)
assert(not result and not partial.cleanupComplete and partial.handles[1]==opaque)
print('Worn pair production creation PASS (real GUID identity, independent/reversed/zero wear, no model grants, record/activation/getter/maintenance failure compensation and uncertainty retention; mocked natives)')
