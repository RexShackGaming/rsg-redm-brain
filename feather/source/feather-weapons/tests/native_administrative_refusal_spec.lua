Config={DevMode=true,Ownership={trustedResources={['feather-weapons']=true}}}
WeaponResult={Ok=function(value) return {ok=true,value=value} end,
 Error=function(code,message,details,correlationId) return {ok=false,error={code=code,message=message,details=details},correlationId=correlationId} end}
WeaponErrors={AUTHORIZATION_INVALID='unauthorized',ITEM_INVALID='invalid',OPERATION_CONFLICT='conflict'}
CoreAdapter={NormalizeCharacterId=function(value) return value end}
AddEventHandler=function() end
local legacyReads=0
InventoryAdapter={GetItemForCharacter=function() legacyReads=legacyReads+1; return {ok=false,error={code='legacy-read'}} end,
 Transaction=function() legacyReads=legacyReads+1; return {ok=false,error={code='legacy-transaction'}} end}
WeaponRuntime={FindLeaseByItem=function() return nil end}
WeaponProvenanceService={Record=function() error('refused action must not write provenance') end}
exports=setmetatable({},{__index=function() error('refused action must not invoke external mutation/authorization') end})
dofile('server/services/ownership.lua'); dofile('server/services/evidence.lua')
local request={characterId='Jane',itemInstanceId=135,serialNumber='SERIAL'}
local function checkNative()
 local context={correlationId='refusal'}
 for _,action in ipairs({WeaponEvidenceService.Hold,WeaponEvidenceService.Release,WeaponOwnershipService.Destroy}) do
  local result=action(context,request,'feather-weapons')
  assert(not result.ok and result.error.code=='conflict' and result.error.details.reason:find('native_',1,true))
  assert(context.characterId==nil and context.reason==nil and context.resource==nil,'native refusal cannot rewrite caller context')
  assert(result.correlationId=='refusal')
  assert(action({},request,'untrusted').error.code=='unauthorized','trust boundary remains first')
  assert(action({},{},'feather-weapons').error.code=='invalid')
 end
end
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true; checkNative()
Config.CharacterAmmoTransportEnabled=false; checkNative()
Config.CharacterAmmunitionEnabled=false; Config.CharacterAmmoTransportEnabled=true; checkNative()
assert(legacyReads==0)
Config.CharacterAmmoTransportEnabled=false
assert(WeaponOwnershipService.Destroy({},request,'feather-weapons').error.code=='conflict')
assert(WeaponEvidenceService.Hold({},request,'feather-weapons').error.code=='conflict')
assert(legacyReads==0,'disabled flags must not restore obsolete administrative writes')
for _,id in ipairs({-1,0,1.5,math.huge,0/0}) do
 local invalid={characterId='Jane',itemInstanceId=id,serialNumber='SERIAL'}
 assert(WeaponOwnershipService.Destroy({},invalid,'feather-weapons').error.code=='invalid')
 assert(WeaponEvidenceService.Release({},invalid,'feather-weapons').error.code=='invalid')
end
exports=function() end
dofile('shared/constants.lua')
DefinitionRegistry={Counts=function() return {} end}
WeaponCharacterAmmoInventoryProvider={Status=function() return 'ready' end}
WeaponNativeOwnershipReader={IsReady=function() return true end}
WeaponProvenanceService.IsReady=function() return true end
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaRuntime=true
dofile('server/services/api.lua')
local caps=WeaponAPI.GetCapabilities()
assert(caps.ready and caps.features.durableProvenance and caps.features.ownershipTransitionEvents)
assert(caps.features.evidenceHolds==false and caps.features.destruction==false
 and caps.features.administrativeHoldGuards and caps.features.productionReady==false)
assert(caps.features.scopedCharacterOnly==false and caps.features.productionReady==false)
print('Native administrative refusal PASS (hold/release/destroy, flags off cannot select old writes, trust/context preserved)')
