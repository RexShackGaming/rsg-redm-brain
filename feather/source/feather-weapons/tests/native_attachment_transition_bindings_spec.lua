local commands,events,registered={},{},{}
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaCharacterId='Jane',NativeAlphaLifecycleWearEnabled=true}
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_item.lua','shared/character_attachments.lua',
 'shared/character_ammunition_materialization.lua'}) do dofile(file) end
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
RegisterCommand=function(n,fn) commands[n]=fn end
RegisterNetEvent=function(n,fn) events[n]=fn end
AddEventHandler=function(n,fn) events[n]=fn end
SetTimeout=function() end
GetGameTimer=function() return 10 end
GetResourceState=function() return 'stopped' end
local feature,authorized,quantity=1,true,1
GetConvarInt=function() return feature end
GetInvokingResource=function() return 'feather-inventory' end
local identity={characterId='Jane',sessionId='s',epoch='e1'}
local state={phase='active',identity=identity}
local request,writes,starts,policyChecks=nil,0,0,0
local statusSnapshot
local replies={}
json={encode=function(value) statusSnapshot=value; return 'read-only-status' end}
TriggerClientEvent=function(name,_,value,scope,result)
 if name=='feather-weapons:client:native-equipment-result' then replies[#replies+1]={id=value,result=result}
 else request=value end
end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end,
 IsSessionCurrent=function(target,s,c) return target==1 and s=='s' and c=='Jane' end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
WeaponCharacterAmmoPolicy={Build=function() return {weapons={repeater_carbine={nativeWeaponName='WEAPON_REPEATER_CARBINE',
 family='repeater',compatible={ammo_repeater_regular=true}}}} end}
AttachmentService={AuthorizeNativeModification=function()
 policyChecks=policyChecks+1; return authorized and {ok=true} or {ok=false,error={code='station_denied'}}
end}
dofile('shared/character_maintenance.lua')
dofile('shared/character_lifecycle_wear.lua')
local candidate={id=901,revision=2,itemName='weapon_repeater_carbine',metadata={schemaVersion=2,weaponDefinitionId='repeater_carbine',
 serialNumber='ORDINARY-CARBINE-901',condition=100,quality=100,
 maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
 ammo={ownership='character',type='ammo_repeater_regular'},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}}
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function(_,context,itemId)
    return {ok=true,value={characterId='Jane',expected={weapon_shoulder={itemId=candidate.id,revision=candidate.revision}},
        equipment={shoulder=copy(candidate)},candidate=itemId and copy(candidate) or nil}}
 end,
 ReadNativeAttachmentMaterial=function() return {ok=true,value={definitionId=9,itemName='carbine_wide_sight',quantity=quantity}} end,
 CommitNativeAttachmentTransition=function(_,context,spec)
    assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
    assert(request.collectWear and spec.itemRevision==candidate.revision and spec.material.quantity==1)
    assert(spec.attachmentPolicy.definitionId=='carbine_wide_sight' and spec.attachmentPolicy.slot=='sight'
        and spec.attachmentPolicy.weaponItemName=='weapon_repeater_carbine','policy is server-derived in exact reservation')
    local wear=spec.lifecycleWear or {}
    if #wear>0 then
        assert(#wear==1 and wear[1].itemId==candidate.id)
        assert(spec.after.maintenance.dirt==wear[1].after.maintenance.dirt,'attachment must preserve sampled wear')
    end
    writes=writes+1; candidate.metadata=copy(spec.after); candidate.revision=candidate.revision+1+#wear
    return {ok=true,value={revision=candidate.revision}}
 end,
}},{__call=function(_,n,fn) registered[n]=fn end})
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1; identity={characterId='Jane',sessionId='s',epoch='fresh'..starts}
 state={phase='restoring',identity=identity}; return {ok=true,value=identity}
end}
dofile('server/services/native_equipment_transition.lua')
source=1
events['feather-weapons:server:native-equipment-ui']('attachment-options','options',{itemId=901,scope=copy(identity)})
local offered=false
for _,option in ipairs(replies[#replies].result.value.options) do
 if option.kind=='attachment' then assert(option.action=='install' and option.attachmentId=='carbine_wide_sight'); offered=true end
end
assert(offered and not request and writes==0,'read-only equipment preview offers authorized paid attachment action')
quantity=0
events['feather-weapons:server:native-equipment-ui']('no-material-options','options',{itemId=901,scope=copy(identity)})
for _,option in ipairs(replies[#replies].result.value.options) do assert(option.kind~='attachment','no install button without material') end
quantity=1
commands.WeaponNativeAttachmentStatus(0,{'1','901'})
assert(statusSnapshot.itemRevision==2 and statusSnapshot.materialQuantity==1 and statusSnapshot.noSQLWrites
    and statusSnapshot.noNativeWrites and writes==0 and not request,'attachment status reads without release/payment')
feature=0; commands.WeaponNativeAttachmentChange(0,{'1','install','901'}); assert(not request and writes==0)
feature=1; authorized=false; commands.WeaponNativeAttachmentChange(0,{'1','install','901'}); assert(not request and writes==0)
authorized=true
quantity=0; commands.WeaponNativeAttachmentChange(0,{'1','install','901'}); assert(not request and writes==0,'missing material refuses before native release')
quantity=1
local function report(old,dirt)
 local maintenance=copy(candidate.metadata.maintenance)
 if dirt then maintenance.dirt=dirt end
 return {epoch=old.epoch,items={{itemInstanceId=candidate.id,itemRevision=candidate.revision,maintenance=maintenance}}}
end
local function change(action,dirt)
 request=nil
 commands.WeaponNativeAttachmentChange(0,{'1',action,'901'})
 assert(request and request.collectWear and writes==starts,'no write before final release acknowledgement')
 local old,ticket=copy(request.identity),request.ticket
 state={phase='released',identity=old}; source=1
 local finalWear=report(old,dirt)
 events['feather-weapons:server:native-equipment-released'](ticket,old,true,finalWear)
 assert(state.phase=='restoring')
 local committed=writes
 events['feather-weapons:server:native-equipment-released'](ticket,old,true,finalWear)
 assert(writes==committed,'duplicate release cannot pay twice')
 state={phase='active',identity=identity}
 events['feather-weapons:server:native-equipment-restored'](ticket,identity)
end
change('install',0.2); assert(writes==1 and candidate.metadata.attachments[1].definitionId=='carbine_wide_sight'
 and candidate.revision==4 and candidate.metadata.maintenance.dirt==0.2,'changed wear plus install advances twice')
change('remove',0.3); assert(writes==2 and next(candidate.metadata.attachments)==nil and candidate.revision==6
 and candidate.metadata.maintenance.dirt==0.3,'changed wear plus return advances twice')
assert(policyChecks>=5,'station/authorization rechecked during prepare AND after release before payment')
source=1
events['feather-weapons:server:native-equipment-ui']('attachment-ui','attachment-change',
 {itemId=901,action='install',attachmentId='carbine_wide_sight',scope=copy(identity)})
assert(request.collectWear and writes==2,'player attachment intent must wait for sealed release')
local uiOld,uiTicket=copy(request.identity),request.ticket
state={phase='released',identity=uiOld}
events['feather-weapons:server:native-equipment-released'](uiTicket,uiOld,true,report(uiOld))
assert(writes==3 and state.phase=='restoring')
state={phase='active',identity=identity}
events['feather-weapons:server:native-equipment-restored'](uiTicket,identity)
assert(replies[#replies].id=='attachment-ui' and replies[#replies].result.ok,'UI completes only after fresh restore')
change('remove'); assert(writes==4 and starts==4 and candidate.revision==8,'unchanged wear adds attachment revision only')
local unknownCalls=0
exports['feather-inventory'].CommitNativeAttachmentTransition=function()
    unknownCalls=unknownCalls+1; error('unknown commit acknowledgement')
end
commands.WeaponNativeAttachmentChange(0,{'1','install','901'})
local old,ticket=copy(request.identity),request.ticket
state={phase='released',identity=old}; source=1
events['feather-weapons:server:native-equipment-released'](ticket,old,true,report(old))
commands.WeaponNativeAttachmentChange(0,{'1','install','901'})
assert(unknownCalls==1 and writes==4 and starts==4,'uncertain attachment result never retries payment or rebuilds')
print('attachment concrete transition PASS (feature/station veto, release-before-payment, final wear reservation, duplicate no double charge, fresh rebuild install/remove)')

-- Exercise the concrete binding, not only the generic coordinator: an export
-- may finish after Core retires the old session and reuses its source ID.
dofile('server/services/native_equipment_transition.lua')
local currentSession='s'
CoreAdapter.ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId=currentSession}} end
CoreAdapter.IsSessionCurrent=function(_,sid,cid) return sid==currentSession and cid=='Jane' end
identity={characterId='Jane',sessionId='s',epoch='disconnect-old'}
state={phase='active',identity=identity}
local commits=0
exports['feather-inventory'].CommitNativeAttachmentTransition=function(_,context,spec)
 assert(registered.ValidateNativeEquipmentCommit(context,spec))
 commits=commits+1
 candidate.metadata=copy(spec.after); candidate.revision=candidate.revision+1
 coroutine.yield('durable_commit_before_reply')
 return {ok=true,value={revision=candidate.revision}}
end
commands.WeaponNativeAttachmentChange(0,{'1','install','901'})
local interrupted=copy(request)
state={phase='released',identity=identity}
local worker=coroutine.create(function()
 events['feather-weapons:server:native-equipment-released'](interrupted.ticket,interrupted.identity,true,report(interrupted.identity))
end)
assert(coroutine.resume(worker) and commits==1)
currentSession='new'
WeaponNativeEquipmentBindings.RetireSession(1,'s')
identity={characterId='Jane',sessionId='new',epoch='disconnect-new'}
state={phase='active',identity=identity}
commands.WeaponNativeEquipmentDryRun(0,{'1'})
local fresh=copy(request)
local beforeStarts=starts
assert(coroutine.resume(worker) and starts==beforeStarts,'late reply cannot rebuild old session')
-- A dry run must not inherit the old attachment postcommit snapshot check.
exports['feather-inventory'].ReadNativeEquipmentTransition=function() error('old attachment contaminated new request') end
state={phase='released',identity=identity}
events['feather-weapons:server:native-equipment-released'](fresh.ticket,fresh.identity,true,report(fresh.identity))
assert(starts==beforeStarts+1 and commits==1,'new request remains independent; no economic replay')

-- One-shot live fault-injection wiring: only explicit console opt-in, exact
-- action/item/epoch, confirmed commit, and still-current source may disconnect.
dofile('server/services/native_equipment_transition.lua')
currentSession='probe-session'
identity={characterId='Jane',sessionId=currentSession,epoch='probe-epoch'}
state={phase='active',identity=identity}
candidate.metadata.attachments={}
local drops,probeWrites=0,0
local faultEnabled=0
GetConvarInt=function(name) if name=='feather_native_attachment_disconnect_probe' then return faultEnabled end; return 1 end
local expiry
SetTimeout=function(ms,fn) if ms==60000 then expiry=fn end end
DropPlayer=function(target)
 assert(target==1 and probeWrites==1,'disconnect only after confirmed durable write')
 drops=drops+1; currentSession='reconnected'
 WeaponNativeEquipmentBindings.RetireSession(1,'probe-session')
end
exports['feather-inventory'].ReadNativeEquipmentTransition=function(_,context,itemId)
 return {ok=true,value={characterId='Jane',expected={weapon_shoulder={itemId=901,revision=candidate.revision}},
 equipment={shoulder=copy(candidate)},candidate=itemId and copy(candidate) or nil}}
end
exports['feather-inventory'].CommitNativeAttachmentTransition=function(_,context,spec)
 assert(registered.ValidateNativeEquipmentCommit(context,spec))
 probeWrites=probeWrites+1; candidate.metadata=copy(spec.after); candidate.revision=candidate.revision+1
 return {ok=true,value={revision=candidate.revision}}
end
commands.WeaponNativeArmAttachmentDisconnect(0,{'1','901','install','carbine_wide_sight'})
assert(not expiry,'default-off probe cannot arm')
faultEnabled=1
commands.WeaponNativeArmAttachmentDisconnect(1,{'1','901','install','carbine_wide_sight'})
assert(not expiry,'player cannot arm a disconnect')
commands.WeaponNativeArmAttachmentDisconnect(0,{'1','901','install','carbine_wide_sight'})
assert(expiry)
expiry() -- expired arms do not remain active
commands.WeaponNativeArmAttachmentDisconnect(0,{'1','901','install','carbine_wide_sight'})
commands.WeaponNativeAttachmentChange(0,{'1','install','901'})
local armed=copy(request)
state={phase='released',identity=identity}
local startsBeforeProbe=starts
events['feather-weapons:server:native-equipment-released'](armed.ticket,armed.identity,true,report(armed.identity))
assert(drops==1 and probeWrites==1 and starts==startsBeforeProbe,'retired commit never rebuilds')
events['feather-weapons:server:native-equipment-released'](armed.ticket,armed.identity,true,report(armed.identity))
assert(drops==1 and probeWrites==1,'duplicate acknowledgement cannot repeat disconnect/payment')
