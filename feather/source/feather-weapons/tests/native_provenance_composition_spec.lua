Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,DevMode=false,
 Ownership={trustedResources={['feather-weapons']=true}}}
WeaponResult={Ok=function(value) return {ok=true,value=value} end,
 Error=function(code,message) return {ok=false,error={code=code,message=message}} end}
WeaponErrors={DEPENDENCY_UNAVAILABLE='unavailable',ITEM_INVALID='invalid',OPERATION_CONFLICT='conflict',AUTHORIZATION_INVALID='unauthorized'}
CoreAdapter={NormalizeCharacterId=function(value) return value end}
InventoryAdapter=setmetatable({},{__index=function() error('legacy provider must remain unused') end})
local metadata={weaponDefinitionId='repeater_carbine',serialNumber='NATIVE-SERIAL',attachments={},maintenance={dirt=0.2}}
WeaponNativeOwnershipReader={ResolveWeaponDefinitionId=function(id) return id==39 and 'repeater_carbine' or nil end,
 GetInstance=function() return {ok=true,value={id=135,inventoryId=8,metadataRevision=14,metadata=metadata}} end,
 GetCharacterInventory=function() return {ok=true,value={id=2}} end}
WeaponCharacterAmmoService={IsNativeItemBound=function() return false end}
WeaponRuntime={FindLeaseByItem=function() return nil end}
GetPlayers=function() return {} end
AddEventHandler=function() end; TriggerEvent=function() end
local saved,failed=false,false
json={encode=function(fact)
 saved={revision=fact.revision,observedRevision=fact.observedRevision,
  observationMatchesCommittedRevision=fact.observationMatchesCommittedRevision,serialNumber=fact.serialNumber}
 return 'snapshot'
end}
DB={exec=function(sql) assert(sql:find('CREATE TABLE IF NOT EXISTS',1,true)) end,
 query=function(sql)
  if sql:find('SHOW COLUMNS',1,true) then return {{Field='existing'}} end
  if sql:find('FROM `feather_weapon_events`',1,true) then
   return {{id=1,item_instance_id=135,serial_number='NATIVE-SERIAL',event_type='deposit'}}
  end
  return {}
 end,
 insert=function(sql,...)
  assert(sql:find('INSERT INTO `feather_weapon_events`',1,true))
  if failed then error('ledger unavailable') end
  return 1
 end}
dofile('server/services/provenance.lua')
dofile('server/services/ownership.lua')
assert(WeaponProvenanceService.Start().ok and WeaponProvenanceService.IsReady())
local payload={instanceId=135,definitionId=39,revision=13,fromInventoryId=2,toInventoryId=8,actorCharacterId='Jane'}
local result=WeaponOwnershipService.HandleCommittedMove(payload)
assert(result.ok and result.value.eventId==1 and saved.serialNumber=='NATIVE-SERIAL')
assert(saved.revision==13 and saved.observedRevision==14 and saved.observationMatchesCommittedRevision==false)
local inspect=WeaponProvenanceService.Inspect({itemInstanceId=135},{},'feather-weapons')
assert(inspect.ok and inspect.value.current.metadataRevision==14 and #inspect.value.events==1)
failed=true
assert(not WeaponProvenanceService.Record(result.value).ok,'storage exception stays a failed ledger acknowledgement')
assert(metadata.maintenance.dirt==0.2,'observer never writes weapon metadata')
print('Native provenance composition PASS (real observer+ledger, mocked storage/read-only reader, no legacy provider, distinct committed/observed revisions, failed insert)')
