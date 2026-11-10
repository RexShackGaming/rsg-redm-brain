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
local fixture=dofile('tests/support/guid_creation_fixture.lua')
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
-- LeMat fresh reconnect must use explicit GUID target points even with zero
-- permanent wear. Legacy slot activation is deliberately unsupported here:
-- a model-based pair can leave both copies in hands with no holster entities.
local lematAdapter,lematItems,lematState=fixture(nil,{0,0},'WEAPON_REVOLVER_LEMAT')
local lematRecords=assert(lematAdapter.createPair(lematItems,identity))
local _,lematGrants,_,lematOrder=lematState()
assert(lematGrants==0 and lematOrder[1]==2 and lematOrder[2]==3)
assert(lematRecords[1].entity~=lematRecords[2].entity)
assert(lematAdapter.remove(lematRecords[2]) and lematAdapter.remove(lematRecords[1]))
for _,mode in ipairs({'record','update','update-readback','activate','duplicate-guid','getter','maintenance','cleanup','insert','move','lifecycle'}) do
 local adapter,items,state=fixture(mode,{0.1,0.25})
 local result,why,partial=adapter.createPair(items,identity)
 assert(not result and type(why)=='string' and partial,mode)
 if mode=='cleanup' or mode=='insert' or mode=='move' then
  assert(not partial.cleanupComplete and #partial.handles>0,'uncertain resources retained: '..mode)
 else assert(partial.cleanupComplete,'exact GUID compensation expected: '..mode) end
 local _,grants=state(); assert(grants==0)
end
-- Cold startup can acknowledge Primary activation before its entity exists.
-- Offhand must not be attempted until that exact Primary GUID is observable.
local delayedAdapter,delayedItems,delayedState=fixture('delayed-primary',{0,0},'WEAPON_REVOLVER_LEMAT')
local delayedRecords=assert(delayedAdapter.createPair(delayedItems,identity))
local _,_,_,delayedOrder=delayedState()
assert(delayedOrder[1]==2 and delayedOrder[2]==3)
assert(delayedAdapter.remove(delayedRecords[2]) and delayedAdapter.remove(delayedRecords[1]))
local wrongAdapter,wrongItems,wrongState=fixture('wrong-primary-guid',{0,0},'WEAPON_REVOLVER_LEMAT')
local wrongResult,wrongReason=wrongAdapter.createPair(wrongItems,identity)
local _,_,_,wrongOrder=wrongState()
assert(not wrongResult and wrongReason:find('guid_entities_not_settled',1,true) and #wrongOrder==1,
 'a foreign Primary GUID must time out without ever activating Offhand')
-- The zero-permanent LeMat path keeps the same failure/compensation contract.
for _,mode in ipairs({'record','update','update-readback','activate','duplicate-guid','maintenance','cleanup','insert','lifecycle'}) do
 local adapter,items=fixture(mode,{0,0},'WEAPON_REVOLVER_LEMAT')
 local result,why,partial=adapter.createPair(items,identity)
 assert(not result and type(why)=='string' and partial,'LeMat '..mode)
 if mode=='cleanup' or mode=='insert' or mode=='move' then
  assert(not partial.cleanupComplete and #partial.handles>0,'uncertain LeMat resources stay held')
 else assert(partial.cleanupComplete,'exact LeMat compensation: '..mode) end
end
-- The production GUID factory covers singles and mixed carry points.
for _,point in ipairs({2,9,10}) do
 local adapter,items,state=fixture(nil,{0,0},'WEAPON_REPEATER_CARBINE')
 items[1].point=point
 local record=assert(adapter.createSingle(items[1],0,identity))
 assert(record.guid and record.entity and adapter.finish({record},identity))
 assert(adapter.remove(record));local _,grants=state();assert(grants==0)
end
local adapter,items,state=fixture(nil,{0.1,0.2},nil)
local primary=assert(adapter.createSingle(items[1],0,identity))
local offhand=assert(adapter.createSingle(items[2],0,identity))
assert(primary.entity~=offhand.entity and N.GuidKey(primary.guid)~=N.GuidKey(offhand.guid))
assert(adapter.remove(offhand) and adapter.remove(primary))
local broken,items=fixture('insert',{0,0},nil)
local record,why,partial=broken.createSingle(items[1],0,identity)
assert(not record and partial and not partial.cleanupComplete and partial.handles[1].pairGrantPending,
 'unconfirmed single insertion retains opaque ownership; no model fallback')
local input=N.GuidOptions(rawGuid(10),100,10,752097756)
assert(input and string.unpack('<I4',input,49)==10 and not N.PairOptions(rawGuid(10),100,10,752097756),
 'candidate carry points do not expand the production pair ABI')
-- Failed adapters must pass unidentified residuals through the executor.
local opaque={pairGrantPending=true}
local executor=WeaponCharacterAmmoLoadout.New({current=function() return true end,prepareDual=function() return true end,
 createPair=function() return nil,'unknown',{handles={opaque},cleanupComplete=false} end,
 createSingle=function() error('unexpected single') end,remove=function() return false end,finish=function() return true end})
local plan={identity=identity,dual=true,sameModel=true,items={{creation='native_inventory_guid',point=2},{creation='native_inventory_guid',point=3}}}
local result,why,partial=executor.Create(plan)
assert(not result and not partial.cleanupComplete and partial.handles[1]==opaque)
print('Worn pair production creation PASS (real GUID identity, independent/reversed/zero wear, no model grants, record/activation/getter/maintenance failure compensation and uncertainty retention; mocked natives)')
