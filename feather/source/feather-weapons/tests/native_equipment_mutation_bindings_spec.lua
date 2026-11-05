dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
local commands,events,registered={},{},{}
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,NativeAlphaCharacterId='Jane'}
RegisterCommand=function(name,fn) commands[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=function(name,fn) events[name]=fn end
SetTimeout=function() end
local clock=10
GetGameTimer=function() return clock end
GetResourceState=function() return 'stopped' end
local id={characterId='Jane',sessionId='s',epoch='e1'}
local state={phase='active',identity=id}
local assigned=true
local writes,starts=0,0
local reads=0
local request
local replies={}
local wearRead
TriggerClientEvent=function(name,target,value,scope,result)
 assert(target==1)
 if name=='feather-weapons:client:native-maintenance-read' then wearRead={ticket=value,identity=scope,itemId=result}
 elseif name=='feather-weapons:client:native-equipment-result' then replies[#replies+1]={id=value,scope=scope,result=result}
 else request=value end
end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end,
 IsSessionCurrent=function(target,s,c) return target==1 and s=='s' and c=='Jane' end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
WeaponDefinitionCatalog={}
WeaponCharacterAmmoPolicy={Build=function() return {} end}
WeaponCharacterAmmoMaterialization={Build=function(rows)
 if rows.offhand and not rows.primary then return nil,'primary_required_for_offhand' end
 if rows.primary and rows.primary.itemName~='cattleman' then return nil,'unregistered_firearm' end
 return {items=rows}
end,Validate=function() return true end}
local candidate={id=112,revision=1,itemName='cattleman',metadata={}}
GetInvokingResource=function() return 'feather-inventory' end
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function(_,context,item)
  reads=reads+1
  assert(context.actorSource==1)
  return {ok=true,value={characterId='Jane',expected=assigned and {weapon={itemId=112,revision=candidate.revision}} or {},
   equipment=assigned and {primary=candidate} or {},candidate=item and candidate or nil}}
 end,
 CommitNativeEquipmentTransition=function(_,context,spec)
  assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
  assert(spec.slot=='weapon' and spec.characterId=='Jane')
  if spec.action=='unequip' then assert(spec.expected.weapon.itemId==112); assigned=false
  else assert(not next(spec.expected) and spec.itemRevision==1); assigned=true end
  writes=writes+1; return {ok=true,value={slot='weapon'}}
 end
}},{__call=function(_,name,fn) registered[name]=fn end})
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1
 local bundle={}; WeaponNativeEquipmentBindings.Attach(1,bundle)
 assert(bundle.equipmentTransition.ticket==request.ticket)
 id={characterId='Jane',sessionId='s',epoch='e'..(starts+1)}
 state={phase='restoring',identity=id}; return {ok=true,value=id}
end}
dofile('server/services/native_equipment_transition.lua')
commands.WeaponNativeEquipmentChange(0,{'1','unequip','invalid'})
assert(not request and writes==0)
commands.WeaponNativeEquipmentChange(0,{'1','unequip','weapon'})
assert(request and writes==0)
local function finish()
 local old=request.identity
 state={phase='released',identity=old}; source=1
 events['feather-weapons:server:native-equipment-released'](request.ticket,old,true)
 assert(state.phase=='restoring')
 state={phase='active',identity=id}
 events['feather-weapons:server:native-equipment-restored'](request.ticket,id)
 assert(not registered.ValidateNativeEquipmentCommit({actorSource=1},{}))
end
finish(); assert(writes==1 and not assigned)
commands.WeaponNativeEquipmentChange(0,{'1','equip','weapon','112'})
assert(writes==1); finish(); assert(writes==2 and assigned and starts==2)
commands.WeaponNativeEquipmentChange(0,{'1','equip','weapon','112'})
assert(writes==2 and starts==2,'already equipped refused without release/write')
source=1
events['feather-weapons:server:native-equipment-ui']('preview','options',{itemId=112,scope=id})
assert(replies[#replies].result.ok and replies[#replies].result.value.options[1].action=='unequip')
local old=id
events['feather-weapons:server:native-equipment-ui']('change','change',{itemId=112,action='unequip',slot='weapon',scope=id})
assert(writes==2,'UI cannot write before acknowledged release')
events['core.session.left.v1']({source=1,sessionId='older-session'})
assert(replies[#replies].id=='preview','old-session event must not clear newer pending UI request')
events['feather-weapons:server:native-equipment-ui']('overlap','change',{itemId=112,action='unequip',slot='weapon',scope=id})
finish(); assert(writes==3 and not assigned)
assert(replies[#replies].id=='change' and replies[#replies].result.ok)
events['feather-weapons:server:native-equipment-ui']('stale','change',{itemId=112,action='equip',slot='weapon',scope=old})
assert(not replies[#replies].result.ok and writes==3)
local changesBefore=reads
events['feather-weapons:server:native-equipment-ui']('change-rate','change',{itemId=112,action='equip',slot='weapon',scope=id})
assert(replies[#replies].result.error.code=='equipment_rate_limited' and reads==changesBefore and writes==3,
 'excess changes must be denied before preflight or release')
local before=reads
for i=1,5 do events['feather-weapons:server:native-equipment-ui']('rate:'..i,'options',{itemId=112,scope=id}) end
assert(reads==before+3,'initial preview used one of the four immediate options tokens')
assert(replies[#replies].result.error.code=='equipment_rate_limited' and writes==3)
clock=clock+1000
events['feather-weapons:server:native-equipment-ui']('refilled','options',{itemId=112,scope=id})
assert(replies[#replies].result.ok and reads==before+4,'one options token refills per second')
before=reads
events['feather-weapons:server:native-equipment-ui']('bad-slot','change',{itemId=112,action='equip',slot={},scope=id})
events['feather-weapons:server:native-equipment-ui']('bad-item','options',{itemId=0/0,scope=id})
assert(reads==before,'malformed payload refused before SQL')
local noisy={characterId=id.characterId,sessionId=id.sessionId,epoch=id.epoch}
noisy.extra=noisy -- ignored fields must not be recursively copied
clock=clock+1000
events['feather-weapons:server:native-equipment-ui']('bounded','options',{itemId=112,scope=noisy})
assert(replies[#replies].result.ok and replies[#replies].scope.extra==nil)
clock=4294967280
for i=1,4 do events['feather-weapons:server:native-equipment-ui']('wrap:'..i,'options',{itemId=112,scope=id}) end
clock=984
before=reads
events['feather-weapons:server:native-equipment-ui']('after-wrap','options',{itemId=112,scope=id})
assert(replies[#replies].result.ok and reads==before+1,'unsigned timer wrap refills one token')
events['playerDropped']()
before=reads
events['feather-weapons:server:native-equipment-ui']('new-connection','options',{itemId=112,scope=id})
assert(replies[#replies].result.ok and reads==before+1,'disconnect clears old rate budget')
print('Native equipment mutation bindings PASS (console policy/retry, server snapshot, release-before-CAS, unequip/equip rebuild)')
local priorReads=reads
commands.WeaponNativeRepair(0,{'1','112'})
assert(reads==priorReads,'repair default disabled before SQL')
Config.NativeAlphaRepairEnabled=true
Config.AmmunitionPools={enabled=false}; Config.Escrow={maxTotal=200}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition_item.lua'); dofile('shared/character_maintenance.lua')
dofile('shared/character_lifecycle_wear.lua')
local definition=WeaponDefinitionCatalog.weapons.revolver_cattleman
definition.itemName='cattleman'
candidate.metadata={schemaVersion=2,weaponDefinitionId=definition.id,serialNumber='serial',condition=50,quality=100,
 maintenance={degradation=0.5,permanentDegradation=0,damage=0,dirt=1,soot=0},
 ammo={ownership='character',type=definition.ammunitionType},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}
local oilQuantity=1
exports['feather-inventory'].ReadNativeRepairMaterial=function(_,context,name)
 assert(name=='gun_oil' and context.characterId=='Jane'); return {ok=true,value={definitionId=9,quantity=oilQuantity}}
end
exports['feather-inventory'].CommitNativeRepairTransition=function(_,context,spec)
 assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
 assert(spec.after.condition==100)
 if spec.action=='maintenance' then assert(spec.material==nil)
 else assert(spec.material.quantity==1 and spec.material.itemName=='gun_oil') end
 candidate.metadata=spec.after; candidate.revision=candidate.revision+1; writes=writes+1; return {ok=true,value={}}
end
local rawCommit=exports['feather-inventory'].CommitNativeRepairTransition
exports['feather-inventory'].CommitNativeRepairTransition=function(...)
 local result=rawCommit(...)
 -- Reproduce the native float -> SQL JSON -> decoded decimal boundary.
 candidate.metadata.maintenance.dirt=tonumber(string.format('%.14g',candidate.metadata.maintenance.dirt))
 return result
end
local repairWrites=writes
assigned=true
local beforeMissingOil=request
oilQuantity=0
commands.WeaponNativeRepair(0,{'1','112'})
assert(request==beforeMissingOil and writes==repairWrites,'missing oil must not release active copies or pay')
oilQuantity=0/0
commands.WeaponNativeRepair(0,{'1','112'})
assert(request==beforeMissingOil and writes==repairWrites,'invalid quantity cannot retire native ownership')
oilQuantity=1
commands.WeaponNativeRepair(1,{'1','112'}); assert(writes==repairWrites)
commands.WeaponNativeRepair(0,{'1','112'}); assert(writes==repairWrites)
local repairTicket=request.ticket
commands.WeaponNativeEquipmentChange(0,{'1','equip','weapon','112'})
assert(request.ticket==repairTicket,'repair uses shared equipment reservation')
finish(); assert(writes==repairWrites+1 and candidate.metadata.condition==100)
commands.WeaponNativeRepair(0,{'1','112'})
assert(writes==repairWrites+1,'pristine repeat refuses before release/payment')
print('Native repair concrete bindings PASS (default-off console gate, canonical metadata/material, shared reservation, release-before-write/restore)')
Config.NativeAlphaMaintenanceEnabled=true
local wearWrites=writes
commands.WeaponNativeMaintenanceCheckpoint(0,{'1','112'})
assert(wearRead and writes==wearWrites)
local cleanReport={degradation=0.000001,permanentDegradation=0,damage=0,dirt=0,soot=0}
source=1
events['feather-weapons:server:native-maintenance-report'](wearRead.ticket,wearRead.identity.epoch,112,candidate.revision,cleanReport)
assert(writes==wearWrites,'native float noise must not write/release')
commands.WeaponNativeMaintenanceCheckpoint(0,{'1','112'})
cleanReport.dirt=0.20000000298023224
local usedTicket=wearRead.ticket
events['feather-weapons:server:native-maintenance-report'](usedTicket,wearRead.identity.epoch,112,candidate.revision,cleanReport)
assert(writes==wearWrites,'wear must release before write')
finish(); assert(writes==wearWrites+1 and candidate.metadata.maintenance.dirt==0.20000000298023,
 'JSON-rounded native float must reconstruct without a second commit')
events['feather-weapons:server:native-maintenance-report'](usedTicket,id.epoch,112,candidate.revision,cleanReport)
assert(writes==wearWrites+1,'duplicate report cannot commit twice')
print('Native wear bindings PASS (console-only request, no-change tolerance, exact revision/ticket, shared release-before-CAS, no materials)')
dofile('shared/character_lifecycle_wear.lua')
Config.NativeAlphaLifecycleWearEnabled=true
local equipmentCommit=exports['feather-inventory'].CommitNativeEquipmentTransition
local finalWearCommits=0
exports['feather-inventory'].CommitNativeEquipmentTransition=function(_,context,intent)
 assert(registered.ValidateNativeEquipmentCommit(context,intent) and state.phase=='released')
 assert(#intent.lifecycleWear==1 and intent.lifecycleWear[1].after.maintenance.dirt==0.3)
 candidate.metadata=intent.lifecycleWear[1].after; candidate.revision=candidate.revision+1
 finalWearCommits=finalWearCommits+1; assigned=false; writes=writes+1
 return {ok=true,value={}}
end
commands.WeaponNativeEquipmentChange(0,{'1','unequip','weapon'})
assert(request.collectWear==true)
local outgoing=request.identity
state={phase='released',identity=outgoing}; source=1
events['feather-weapons:server:native-equipment-released'](request.ticket,outgoing,true,
 {epoch=outgoing.epoch,items={{itemInstanceId=112,itemRevision=candidate.revision,
  maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0.3,soot=0}}}})
assert(finalWearCommits==1 and state.phase=='restoring' and not assigned)
state={phase='active',identity=id}
events['feather-weapons:server:native-equipment-restored'](request.ticket,id)
assert(candidate.metadata.maintenance.dirt==0.3,'outgoing copy wear saved before assignment change')
exports['feather-inventory'].CommitNativeEquipmentTransition=equipmentCommit
Config.NativeAlphaLifecycleWearEnabled=false; assigned=true
print('Concrete lifecycle wear bindings PASS (complete release report, outgoing-copy metadata plan, shared atomic commit/restore)')
candidate.metadata.maintenance.dirt=1
local commitRepair=exports['feather-inventory'].CommitNativeRepairTransition
exports['feather-inventory'].CommitNativeRepairTransition=function(...)
 local result=commitRepair(...); assigned=false; return result
end
local priorStarts=starts
commands.WeaponNativeRepair(0,{'1','112'})
state={phase='released',identity=request.identity}; source=1
events['feather-weapons:server:native-equipment-released'](request.ticket,request.identity,true)
assert(starts==priorStarts and state.phase=='released','lost equipment cannot rebuild empty and claim repair PASS')
print('Native repair lost-equipment regression PASS (confirmed commit retained; empty-loadout success prevented)')
