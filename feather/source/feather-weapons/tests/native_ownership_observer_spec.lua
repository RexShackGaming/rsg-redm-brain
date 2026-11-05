Config={DevMode=false}
local registered,records,emitted={},{},{}
AddEventHandler=function(name,fn) registered[name]=fn end
TriggerEvent=function(name,fact) emitted[#emitted+1]=fact end
GetPlayers=function() return {} end
WeaponResult={Ok=function(value) return {ok=true,value=value} end,
 Error=function(code,message) return {ok=false,error={code=code,message=message}} end}
WeaponErrors={ITEM_INVALID='invalid'}
local metadata={weaponDefinitionId='repeater_carbine',serialNumber='SERIAL',
 maintenance={dirt=0.2},attachments={{definitionId='carbine_wide_sight',slot='sight'}}}
WeaponNativeOwnershipReader={ResolveWeaponDefinitionId=function(id) return id==39 and 'repeater_carbine' or nil end,
 GetInstance=function() return {ok=true,value={metadata=metadata,metadataRevision=12}} end,
 GetCharacterInventory=function() return {ok=true,value={id=2}} end}
CoreAdapter={NormalizeCharacterId=function(value) return value end}
WeaponRuntime={FindLeaseByItem=function() return nil end}
local nativeBound=false
WeaponCharacterAmmoService={IsNativeItemBound=function(id) assert(id==135); return nativeBound end}
ReconciliationService={Force=function() error('native observer must not trigger legacy restoration') end}
WeaponProvenanceService={Record=function(fact) records[#records+1]=fact; return {ok=true,value={eventId=#records}} end}
dofile('server/services/ownership.lua')
local function move(from,to,reason)
 return WeaponOwnershipService.HandleCommittedMove({instanceId=135,definitionId=39,
  fromInventoryId=from,toInventoryId=to,actorCharacterId='Jane',revision=13,reason=reason})
end
assert(move(2,8,'storage').value.transitionType=='deposit')
assert(move(8,2,'storage').value.transitionType=='pickup')
assert(move(2,8,'ground_drop').value.transitionType=='drop')
assert(move(2,8,'give').value.transitionType=='transfer')
assert(move(8,2,'container_recovery').value.transitionType=='recovery')
local count=#records
assert(move(2,2,'slot_move')==nil and #records==count,'internal slot reorder is not ownership transfer')
nativeBound=true
local result=move(2,8,'storage')
assert(result.ok and result.value.nativeLeaseViolation and result.value.activeLeaseViolation)
assert(WeaponOwnershipService.GetDiagnostics().leaseViolations==1)
assert(result.value.serialNumber=='SERIAL' and result.value.revision==13)
assert(metadata.maintenance.dirt==0.2 and metadata.attachments[1].definitionId=='carbine_wide_sight')
assert(#records==#emitted and registered['Feather:Inventory:ItemMoved'])
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
InventoryAdapter=setmetatable({},{__index=function() error('native observer may not use legacy provider') end})
local later=move(2,8,'storage')
assert(later.ok and later.value.revision==13 and later.value.observedRevision==12
 and later.value.observationMatchesCommittedRevision==false,'later read is not represented as exact committed snapshot')
print('Native ownership observer PASS (classification, native violation diagnostic, no legacy restoration, unchanged metadata; mocked reader/ledger)')
