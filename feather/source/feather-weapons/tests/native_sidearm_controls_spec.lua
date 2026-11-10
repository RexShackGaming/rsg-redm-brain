vector3=function(x,y,z) return {x=x,y=y,z=z} end
dofile('config.lua') -- exercise actual shipped lifecycle-wear default
GetConvarInt=function(_,default) return default end
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua','shared/character_maintenance.lua',
 'shared/character_lifecycle_wear.lua','shared/character_attachments.lua','shared/character_ammunition_materialization.lua'}) do dofile(file) end
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
local function gun(id,wear)
 return {id=id,revision=wear and 10 or 2,itemName='weapon_revolver_cattleman',metadata={schemaVersion=2,
 weaponDefinitionId='revolver_cattleman',serialNumber='test-'..id,condition=wear and 90 or 100,quality=100,
 maintenance={degradation=wear or 0,permanentDegradation=wear or 0,damage=wear or 0,dirt=0,soot=0},
 ammo={ownership='character',type='ammo_revolver_regular'},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}}
end
local items={[231]=gun(231),[128]=gun(128,.1)}
local rows={primary=items[231],offhand=items[128]}
local id={characterId='Jane',sessionId='s',epoch='e1'}
local state={phase='active',identity=id}
local events,registered={},{}
local reply,release
local observed={}
local writes,starts,clock=0,0,100
RegisterCommand=function() end; AddEventHandler=function() end; SetTimeout=function() end
RegisterNetEvent=function(name,fn) events[name]=fn end
GetResourceState=function() return 'stopped' end
GetGameTimer=function() return clock end
GetInvokingResource=function() return 'feather-inventory' end
CoreAdapter={ResolveSession=function() return {ok=true,value=id} end,IsSessionCurrent=function() return true end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
AttachmentService={AuthorizeNativeModification=function() return {ok=true} end}
TriggerClientEvent=function(name,_,value,_,result)
 if name=='feather-weapons:client:native-equipment-result' then reply=result else release=value end
end
exports=setmetatable({['feather-inventory']={ReadNativeEquipmentTransition=function(_,_,selected)
 local expected={}
 if rows.primary then expected.weapon={itemId=rows.primary.id,revision=rows.primary.revision} end
 if rows.offhand then expected.weapon_offhand={itemId=rows.offhand.id,revision=rows.offhand.revision} end
 return {ok=true,value={characterId='Jane',equipment=copy(rows),expected=expected,candidate=copy(items[selected])}}
 end,ReadNativeAttachmentMaterial=function() return {ok=true,value={definitionId=9,quantity=0}} end,
 ReadNativeRepairMaterial=function() return {ok=true,value={definitionId=10,quantity=0}} end,
 CommitNativeEquipmentTransition=function(_,context,spec)
 assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
 assert(spec.lifecycleSnapshot and type(spec.lifecycleWear)=='table','shipped defaults collect final wear before equipment writes')
 for _,change in ipairs(spec.lifecycleWear) do
  local item=items[change.itemId]
  assert(item.revision==change.itemRevision)
  item.metadata=copy(change.after); item.revision=item.revision+1
 end
 if spec.action=='move' then
  assert(spec.fromSlot=='weapon' and spec.itemId==231 and spec.itemRevision==2)
  rows.primary,rows.offhand=rows.offhand,rows.primary
 elseif spec.action=='unequip_primary' then
  assert(spec.expected.weapon.itemId==rows.primary.id and spec.expected.weapon_offhand.itemId==rows.offhand.id and not spec.itemId)
  rows.primary=rows.offhand; rows.offhand=nil
 else error('unexpected action') end
 writes=writes+1; return {ok=true,value={}}
end}},{__call=function(_,name,fn) registered[name]=fn end})
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1
 id={characterId='Jane',sessionId='s',epoch='e'..(starts+1)}
 state={phase='restoring',identity=id}; return {ok=true,value=id}
end}
dofile('server/services/native_equipment_transition.lua')
source=1
local function ui(kind,item,action,slot,scope)
 clock=clock+5000
 events['feather-weapons:server:native-equipment-ui']('ui:'..clock,kind,{itemId=item,action=action,slot=slot,scope=scope or id})
end
local function option(action)
 for _,v in ipairs(reply.value.options) do if v.action==action then return v end end
end
local function finish()
 assert(release.collectWear==true,'normal sidearm action must request final wear with shipped defaults')
 local wear={epoch=release.identity.epoch,items={}}
 for _,item in pairs(rows) do wear.items[#wear.items+1]={itemInstanceId=item.id,itemRevision=item.revision,
  maintenance=copy(observed[item.id] or item.metadata.maintenance)} end
 state={phase='released',identity=release.identity}
 events['feather-weapons:server:native-equipment-released'](release.ticket,release.identity,true,wear)
 assert(state.phase=='restoring')
 state={phase='active',identity=id}
 events['feather-weapons:server:native-equipment-restored'](release.ticket,id)
 assert(reply.ok)
end
ui('options',231)
assert(reply.ok and option('move').slot=='weapon_offhand' and option('unequip_primary') and not option('unequip')
 and reply.value.explanation=='ui_equipment_promote_hint')
ui('options',128)
assert(reply.ok and option('move').slot=='weapon' and option('unequip') and not option('unequip_primary'))
local old=copy(id)
observed[128]=copy(items[128].metadata.maintenance)
observed[128].degradation=.10333333164453; observed[128].soot=.00499999988824
ui('change',231,'move','weapon_offhand'); assert(writes==0 and release,'no write before seal and release')
finish(); assert(writes==1 and rows.primary.id==128 and rows.offhand.id==231)
assert(rows.primary.metadata.maintenance.permanentDegradation==.1 and rows.offhand.revision==2,'wear stays with each instance')
assert(items[128].revision==11 and items[128].metadata.maintenance.soot==observed[128].soot
 and items[128].metadata.maintenance.degradation==observed[128].degradation,'first-shot wear persists through Swap hands')
ui('change',231,'move','weapon',old)
assert(not reply.ok and writes==1,'stale panel cannot swap again')
ui('change',231,'unequip_primary','weapon')
assert(not reply.ok and writes==1,'offhand selection cannot remove Primary through a forged option')
ui('change',128,'unequip_primary','weapon'); finish()
assert(writes==2 and rows.primary.id==231 and not rows.offhand,'only Primary removed; companion promoted in one released commit')
assert(rows.primary.revision==2 and items[128].revision==11 and items[128].metadata.maintenance.permanentDegradation==.1,
 'promotion does not alter either instance wear or revision')
ui('options',231)
assert(reply.ok and reply.value.explanation=='ui_equipment_primary_needed' and option('unequip') and not option('move'))
ui('change',231,'move','weapon_offhand')
assert(not reply.ok and writes==2,'lone primary cannot create an invalid offhand-only loadout')
rows={primary=items[231],offhand=items[128]}
ui('change',231,'unequip_primary','weapon'); finish()
assert(writes==3 and rows.primary.id==128 and rows.primary.revision==11 and not rows.offhand
 and rows.primary.metadata.maintenance.permanentDegradation==.1,'worn Offhand also promotes without transferring or resetting wear')
assert(rows.primary.metadata.maintenance.soot==observed[128].soot,'promotion also preserves previously fired wear')
print('Sidearm controls PASS (real policy previews, signed released swap, per-instance wear, Primary removal/Offhand promotion, stale and forged refusal)')
