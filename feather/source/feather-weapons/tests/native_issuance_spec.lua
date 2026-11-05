Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaCharacterId='Jane',AmmunitionPools={enabled=false},Escrow={maxTotal=200},
 Issuance={trustedResources={['feather-weapons']=true},allowedPurposes={development_grant=true}}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/validation.lua','shared/character_ammunition_item.lua'}) do dofile(p) end
local function clone(v) if type(v)~='table' then return v end; local t={}; for k,x in pairs(v) do t[k]=clone(x) end; return t end
WeaponResult={Ok=function(v) return {ok=true,value=v} end,Error=function(c,m,d) return {ok=false,error={code=c,message=m,details=d}} end}
WeaponErrors={ITEM_INVALID='invalid',AUTHORIZATION_INVALID='denied',OPERATION_CONFLICT='conflict'}
local enabled,stopping,current=1,false,true
GetConvarInt=function() return enabled end
GetGameTimer=function() return 100 end
GetResourceState=function() return 'stopped' end
GetPlayers=function() return {'1'} end
CoreAdapter={NormalizeCharacterId=function(v) return type(v)=='string' and v or nil end,
 ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end,
 IsSessionCurrent=function() return current end}
WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity={characterId='Jane',sessionId='s',epoch='e'}} end}
WeaponNativeEquipmentBindings={IsStopping=function() return stopping end}
WeaponCharacterAmmoInventoryProvider={Status=function() return 'ready' end}
WeaponCharacterAmmoPolicy={Build=function() return {weapons={revolver_cattleman={}}} end}
DefinitionRegistry={Get=function(_,id) return WeaponResult.Ok(WeaponDefinitionCatalog.weapons[id]) end,
 ValidateAttachmentSet=function() return WeaponResult.Ok(true) end}
dofile('server/services/metadata.lua')
local recorded,readFails=0,false
WeaponProvenanceService={IsReady=function() return true end,
 FindIssuanceEvent=function() if readFails then return WeaponResult.Error('unavailable','read failed') end
  return WeaponResult.Ok({eventId=recorded>0 and 1 or nil}) end,
 Record=function() recorded=recorded+1; return WeaponResult.Ok({eventId=1}) end}
local registered={}
local caller='feather-inventory'
GetInvokingResource=function() return caller end
local writes,receipt,lost=0,nil,false
json={encode=function(v)
 local parts={}; for _,x in ipairs(v) do parts[#parts+1]=tostring(x) end; return table.concat(parts,'|')
end}
exports=setmetatable({['feather-inventory']={GetNativeIssuanceContract=function() return {contractVersion=1,ready=true} end,
 IssueNativeFirearmOnce=function(_,ctx,spec)
 assert(registered.ValidateNativeIssuance(ctx,spec))
 local forged=clone(spec); forged.metadata.serialNumber='forged'
 assert(not registered.ValidateNativeIssuance(ctx,forged),'ticket binds exact immutable metadata')
 if receipt then
  if receipt.fingerprint~=spec.fingerprint then return WeaponResult.Error('conflict','payload changed') end
  local v=clone(receipt.value); v.replayed=true; return WeaponResult.Ok(v)
 end
 writes=writes+1
 local v={itemInstanceId=200,inventoryId=2,revision=0,characterId='Jane',definitionId=spec.definitionId,
  itemName=spec.itemName,serialNumber=spec.metadata.serialNumber,metadata=clone(spec.metadata)}
 assert(WeaponMetadata.Validate(v.metadata,WeaponDefinitionCatalog.weapons[spec.definitionId]).ok)
 receipt={fingerprint=spec.fingerprint,value=v}
 if lost then error('reply lost after durable commit') end
 return WeaponResult.Ok(clone(v))
end}}, {__call=function(_,n,f) registered[n]=f end})
dofile('server/services/issuance.lua')
local function issue(overrides,resource)
 local req={characterId='Jane',definitionId='revolver_cattleman',purpose='development_grant',requestId='native-test-v1'}
 for k,v in pairs(overrides or {}) do req[k]=v end
 return IssuanceService.Issue({},req,resource or 'feather-weapons')
end
enabled=0; assert(not issue().ok and writes==0)
enabled=1
Config.CharacterAmmunitionEnabled=false; Config.CharacterAmmoTransportEnabled=false
InventoryAdapter=setmetatable({}, {__index=function() error('obsolete issuer must never be used') end})
assert(not issue().ok and writes==0,'flags off must refuse rather than create an old-format weapon')
Config.CharacterAmmunitionEnabled=true; assert(not issue().ok and writes==0)
Config.CharacterAmmoTransportEnabled=true
enabled=1; stopping=true; assert(not issue().ok and writes==0); stopping=false
current=false; assert(not issue().ok); current=true
assert(not issue(nil,'untrusted').ok)
assert(not issue({loadedAmmo=2}).ok and not issue({quality=90}).ok)
assert(not issue({provenance='malformed'}).ok)
lost=true; assert(not issue().ok and writes==1 and recorded==0)
lost=false; local result=issue(); assert(result.ok and result.value.replayed and writes==1 and recorded==1)
assert(result.value.metadata.ammo.ownership=='character' and result.value.metadata.ammo.loaded==nil)
assert(issue().ok and writes==1 and recorded==1)
readFails=true; assert(not issue().ok and writes==1 and recorded==1,'failed event lookup cannot invent a new issuance event')
readFails=false; assert(issue().ok and writes==1 and recorded==1)
assert(not issue({provenance={reference='changed'}}).ok and writes==1)
caller='untrusted'; assert(not registered.ValidateNativeIssuance({},{}))
print('Native issuance PASS (real metadata validation, gates, immutable ticket, lost-reply durable replay, provenance recovery, payload conflict; mocked Inventory)')
dofile('shared/native_knife.lua')
caller='feather-inventory'
Config.NativeAlphaLifecycleWearEnabled=true
enabled=0
assert(not issue({definitionId='melee_knife',requestId='knife-v1'}).ok)
enabled=1
assert(not issue({definitionId='melee_knife'}).ok,'firearm request key cannot deliver a knife')
receipt=nil; recorded=0; local before=writes
local knife=issue({definitionId='melee_knife',requestId='knife-v1'})
assert(knife.ok and knife.value.metadata.ammo==nil and knife.value.metadata.maintenance==nil and writes==before+1)
assert(knife.value.itemName=='weapon_melee_knife' and recorded==1)
local replay=issue({definitionId='melee_knife',requestId='knife-v1'})
assert(replay.ok and replay.value.replayed and writes==before+1 and recorded==1)
assert(not issue({definitionId='melee_machete',requestId='other'}).ok,'no broad melee admission')
assert(not issue({definitionId='melee_knife',requestId='knife-v1',ammo={}}).ok)
Config.NativeAlphaLifecycleWearEnabled=false
assert(not issue({definitionId='melee_knife',requestId='knife-v1'}).ok,'incomplete knife config refuses even replay')
print('knife issuance PASS (real ammo-free metadata, default-off, durable request replay, definition conflict, single provenance; mocked Inventory)')
dofile('shared/native_melee_catalog.lua')
Config.NativeAlphaLifecycleWearEnabled=true
for _,name in ipairs({'melee_knife','melee_machete','melee_hammer','melee_cleaver','melee_hatchet'}) do
 receipt=nil; recorded=0; local count=writes
 local issued=issue({definitionId=name,requestId='melee-'..name})
 assert(issued.ok and writes==count+1 and issued.value.metadata.weaponDefinitionId==name)
 assert(issued.value.metadata.ammo==nil and issued.value.metadata.maintenance==nil)
 local replayed=issue({definitionId=name,requestId='melee-'..name})
 assert(replayed.ok and replayed.value.replayed and writes==count+1 and recorded==1)
 assert(not issue({definitionId=name,requestId='melee-'..name,ammo={}}).ok)
end
enabled=0; assert(not issue({definitionId='melee_hatchet',requestId='off'}).ok)
print('five-model melee issuance PASS (canonical ammo-free items, receipt replay, pristine-only and gate refusal)')
for _,path in ipairs({'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua'}) do dofile(path) end
enabled=0; assert(not issue({definitionId='throwable_tomahawk',requestId='tom-v1'}).ok)
enabled=1; receipt=nil; recorded=0; local count=writes
local tom=issue({definitionId='throwable_tomahawk',requestId='tom-v1'})
assert(tom.ok and writes==count+1 and tom.value.metadata.ammo.ownership=='character')
assert(tom.value.metadata.ammo.type=='ammo_tomahawk_regular' and tom.value.metadata.ammo.quantity==nil
 and tom.value.metadata.maintenance==nil)
assert(issue({definitionId='throwable_tomahawk',requestId='tom-v1'}).value.replayed and writes==count+1)
assert(not issue({definitionId='throwable_tomahawk_ancient',requestId='ancient-v1'}).ok and writes==count+1)
assert(not issue({definitionId='throwable_tomahawk',requestId='tom-v1',loadedAmmo=1}).ok)
enabled=0; assert(not issue({definitionId='throwable_tomahawk',requestId='tom-v1'}).ok)
print('Tomahawk issuance PASS: exact gated regular carrier, canonical receipt replay, no native/equipment/ammo grant, no variants')
dofile('shared/native_utility_catalog.lua'); dofile('shared/native_utility_item.lua')
assert(not issue({definitionId='utility_lasso',requestId='lasso-v1'}).ok,'utility defaults off')
enabled=1; receipt=nil; recorded=0; local lassoBefore=writes
lost=true
assert(not issue({definitionId='utility_lasso',requestId='lasso-v1'}).ok and writes==lassoBefore+1 and recorded==0,
 'lost utility issuance reply cannot be treated as a missing item')
local originalSerial=receipt.value.serialNumber
assert(receipt.fingerprint:find('native-utility-v1',1,true))
lost=false
local lasso=issue({definitionId='utility_lasso',requestId='lasso-v1'})
assert(lasso.ok and lasso.value.replayed and writes==lassoBefore+1 and recorded==1)
assert(lasso.value.itemName=='weapon_lasso' and lasso.value.itemInstanceId==200
 and lasso.value.serialNumber==originalSerial and lasso.value.metadata.ammo==nil
 and lasso.value.metadata.maintenance==nil)
assert(issue({definitionId='utility_lasso',requestId='lasso-v1'}).ok and writes==lassoBefore+1 and recorded==1)
assert(not issue({definitionId='utility_lasso',requestId='lasso-v1',provenance={reference='changed'}}).ok)
assert(not issue({definitionId='utility_camera',requestId='camera-v1'}).ok)
assert(not issue({definitionId='utility_lasso',requestId='lasso-v1',ammo={}}).ok)
enabled=0; assert(not issue({definitionId='utility_lasso',requestId='lasso-v1'}).ok and writes==lassoBefore+1)
print('lasso issuance PASS: exact default-off utility policy, lost-reply replay preserves item/serial/provenance, no ammo or variant admission; mocked Inventory')
dofile('shared/native_lasso_policy.lua')
local reinforcedGate=0
GetConvarInt=function(name)
 if name=='feather_native_lasso_reinforced' then return reinforcedGate end
 return enabled
end
enabled=1; receipt=nil; recorded=0; local reinforcedBefore=writes
assert(not issue({definitionId='utility_lasso_reinforced',requestId='reinforced-v1'}).ok and writes==reinforcedBefore)
reinforcedGate=1; lost=true
assert(not issue({definitionId='utility_lasso_reinforced',requestId='reinforced-v1'}).ok and writes==reinforcedBefore+1)
local reinforcedSerial=receipt.value.serialNumber
lost=false
local reinforced=issue({definitionId='utility_lasso_reinforced',requestId='reinforced-v1'})
assert(reinforced.ok and reinforced.value.replayed and writes==reinforcedBefore+1 and recorded==1)
assert(reinforced.value.itemName=='weapon_lasso_reinforced' and reinforced.value.serialNumber==reinforcedSerial
 and reinforced.value.metadata.ammo==nil and reinforced.value.metadata.maintenance==nil)
assert(not issue({definitionId='utility_lasso_reinforced',requestId='reinforced-v1',provenance={reference='changed'}}).ok)
reinforcedGate=0
assert(not issue({definitionId='utility_lasso_reinforced',requestId='reinforced-v1'}).ok and writes==reinforcedBefore+1)
print('reinforced lasso issuance PASS: independent gate, exact item/serial lost-reply replay and no new economic grants; mocked Inventory')
