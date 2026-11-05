dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane',CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,Ownership={trustedResources={admin=true},authorization={holdAction='hold',releaseAction='release'}}}
local function clone(v) if type(v)~='table' then return v end; local t={}; for k,x in pairs(v) do t[k]=clone(x) end; return t end
WeaponResult={Ok=function(v) return {ok=true,value=v} end,Error=function(c,m,d) return {ok=false,error={code=c,message=m,details=d}} end}
WeaponErrors={OPERATION_CONFLICT='conflict',AUTHORIZATION_INVALID='unauthorized',ITEM_INVALID='invalid'}
local optin,permission,current,bound=0,true,true,false
local writes,authorizations,ledgerWrites=0,0,0
local unknown,ledgerFailure=false,false
GetConvarInt=function() return optin end
CoreAdapter={NormalizeCharacterId=function(v) return v end,
 ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='sid'}} end,
 IsSessionCurrent=function() return current end}
WeaponCharacterAmmoService={IsNativeItemBound=function() return bound end}
WeaponCharacterAmmoItem={Validate=function(metadata) return clone(metadata) end}
WeaponDefinitionCatalog={weapons={repeater_carbine={id='repeater_carbine',itemName='weapon_repeater_carbine'}}}
local item={id=135,inventoryId=2,metadataRevision=13,metadata={weaponDefinitionId='repeater_carbine',serialNumber='SERIAL',
 flags={evidence=false},maintenance={dirt=0.2},attachments={}}}
WeaponNativeOwnershipReader={GetInstance=function() return {ok=true,value=clone(item)} end,
 GetCharacterInventory=function() return {ok=true,value={id=2}} end}
WeaponProvenanceService={Record=function() ledgerWrites=ledgerWrites+1; if ledgerFailure then error('ledger failed') end; return {ok=true,value={eventId=ledgerWrites}} end}
TriggerEvent=function() end
local caller='admin'
GetInvokingResource=function() return caller end
local registered={}
local commands={}
RegisterCommand=function(name,fn) commands[name]=fn end
json={encode=function() return 'snapshot' end}
exports=setmetatable({['feather-core']={Authorize=function()
 authorizations=authorizations+1; return {ok=true,value={allowed=permission,code=permission and 'allowed' or 'forbidden',provider='feather-admin'}}
end},['feather-inventory']={ReadNativeEquipmentTransition=function()
 return {ok=true,value={candidate={id=item.id,revision=item.metadataRevision,itemName='weapon_repeater_carbine',metadata=clone(item.metadata)},
 expected={weapon={itemId=112,revision=1}}}}
end,CommitNativeEvidenceTransition=function(_,context,spec)
 caller='feather-inventory'
 assert(registered.ValidateNativeEvidenceCommit(context,spec))
 local forged=clone(spec); forged.held=not forged.held
 assert(not registered.ValidateNativeEvidenceCommit(context,forged),'reservation binds exact intent')
 caller='admin'
 writes=writes+1; item.metadata.flags.evidence=spec.held; item.metadataRevision=item.metadataRevision+1
 if unknown then error('commit acknowledgement lost') end
 return {ok=true,value={revision=item.metadataRevision,inventoryId=2}}
end}},{__call=function(_,name,fn) registered[name]=fn end})
dofile('server/services/evidence.lua')
local context={actorSource=3,sessionId='sid'}
local request={characterId='Jane',itemInstanceId=135,serialNumber='SERIAL'}
local function change(held) return WeaponEvidenceService.SetHold(context,request,'admin',held) end
assert(not change(true).ok and writes==0 and authorizations==0,'defaultoff')
local status=WeaponEvidenceService.NativeStatus(3,135)
assert(status.ok and not status.value.enabled and not status.value.equipped and status.value.permissions.hold
 and status.value.permissions.release and status.value.reservation=='none' and writes==0,'status is available with mutation optin off')
assert(status.value.permissionDetails.hold.code=='allowed' and status.value.permissionDetails.release.provider=='feather-admin')
commands.WeaponNativeEvidenceChange(3,{'3','hold','135','SERIAL'})
assert(writes==0,'player cannot invoke console mutation command')
optin=1; permission=false
status=WeaponEvidenceService.NativeStatus(3,135)
assert(not status.value.permissions.hold and status.value.permissionDetails.hold.code=='forbidden' and writes==0)
assert(not change(true).ok and writes==0)
permission=true; bound=true
assert(not change(true).ok and writes==0,'native lease cannot mutate')
bound=false; current=false
assert(not change(true).ok and writes==0,'stale actor cannot mutate')
current=true
request.expectedRevision=12
assert(not change(true).ok and writes==0,'stale UI revision cannot be replaced with a fresh mutation intent')
request.expectedRevision=nil
assert(change(true).ok and writes==1 and item.metadata.flags.evidence)
assert(not change(true).ok and writes==1,'duplicate state does not replay')
ledgerFailure=true
local released=change(false)
assert(released.ok and released.value.outcome=='committed' and released.value.provenancePersisted==false
 and writes==2 and not item.metadata.flags.evidence,'ledger failure cannot misreport committed item change as retryable')
unknown=true
assert(not change(true).ok and writes==3)
assert(not change(false).ok and writes==3,'unknown outcome blocks competing/retry mutations')
status=WeaponEvidenceService.NativeStatus(3,135)
assert(status.ok and status.value.reservation=='unresolved' and status.value.itemRevision==16
 and writes==3,'status exposes unknown reservation without replaying mutation')
assert(context.characterId==nil and context.resource==nil,'caller context is private')
print('Native evidence binding PASS (optin/current authority/lease/exact reservation, hold/release, ledger failure distinct, unknown blocks replay; mocked Inventory)')
