Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaMaintenanceEnabled=true,NativeAlphaPeriodicWearEnabled=true,NativeAlphaPeriodicWearIntervalMs=60000,
 NativeAlphaCharacterId='Jane',AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition_item.lua'); dofile('shared/character_maintenance.lua')
dofile('shared/character_lifecycle_wear.lua')
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
local def=WeaponDefinitionCatalog.weapons.revolver_cattleman
local item={id=128,revision=5,itemName=def.itemName,metadata={schemaVersion=2,weaponDefinitionId=def.id,serialNumber='fixture',condition=90,quality=100,
 maintenance={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0.5,soot=0},ammo={ownership='character',type=def.ammunitionType},
 attachments={},cosmetics={},flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local assigned=true
local events,commands,registered,timers={},{},{},{}
RegisterNetEvent=function(name,fn) events[name]=fn end; RegisterCommand=function(name,fn) commands[name]=fn end
AddEventHandler=RegisterNetEvent; SetTimeout=function(_,fn) timers[#timers+1]=fn end
local thread
CreateThread=function(fn) thread=coroutine.create(fn) end
GetPlayers=function() return {'1'} end
Wait=function() coroutine.yield() end
local clock=0; GetGameTimer=function() return clock end
GetResourceState=function() return 'stopped' end
GetInvokingResource=function() return 'feather-inventory' end
local diagnostic; json={encode=function(value) diagnostic=value; return 'diagnostic' end}
local id={characterId='Jane',sessionId='s',epoch='e'}
local state={phase='active',identity=id}
local read,release,reads,writes,restores=nil,nil,0,0,0
TriggerClientEvent=function(name,target,a,b,c)
 assert(target==1)
 if name=='feather-weapons:client:native-maintenance-read' then read={ticket=a,identity=b,itemId=c}
 elseif name=='feather-weapons:client:native-equipment-release' then release=a end
end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end,
 IsSessionCurrent=function() return true end}
WeaponCharacterAmmoPolicy={Build=function() return {} end}
WeaponCharacterAmmoMaterialization={Build=function(rows)
 if rows.primary then assert(rows.primary.metadata.condition>=def.condition.equipMinimum,'broken item must not be projected for reconstruction') end
 return {}
end,Validate=function() return true end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end,
 ReadBoundMaintenanceItems=function() return {{id=128,revision=item.revision,metadata=copy(item.metadata),definition=copy(def)}} end}
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 restores=restores+1; local bundle={}; WeaponNativeEquipmentBindings.Attach(1,bundle)
 assert(bundle.equipmentTransition.ticket==release.ticket)
 id={characterId='Jane',sessionId='s',epoch='e'..restores}; state={phase='restoring',identity=id}
 return {ok=true,value=id}
end}
local disableOnCommit=false
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function() reads=reads+1; return {ok=true,value={characterId='Jane',brokenEquipmentContract=not NATIVE_BROKEN_INVENTORY_OLD and 1 or nil,
  expected=assigned and {weapon={itemId=128,revision=item.revision}} or {},equipment=assigned and {primary=copy(item)} or {},candidate=copy(item)}} end,
 CommitNativeRepairTransition=function(_,context,spec)
  if disableOnCommit then Config.NativeAlphaPeriodicWearEnabled=false end
  if not registered.ValidateNativeEquipmentCommit(context,spec) then return {ok=false} end
  assert(spec.action=='maintenance' and spec.periodic==true and state.phase=='released' and spec.material==nil)
  item.metadata=copy(spec.after); item.revision=item.revision+1; writes=writes+1
  if spec.brokenEquipment and spec.brokenEquipment.weapon then
   assert(spec.brokenEquipment.weapon.itemId==128 and item.metadata.condition==0)
   assigned=false
  end
  return {ok=true,value={}}
 end,
}},{__call=function(_,name,fn) registered[name]=fn end})
dofile('server/services/native_equipment_transition.lua')
local function sweep(time) clock=time; assert(coroutine.resume(thread)) end
local function report(dirt,damage)
 source=1; events['feather-weapons:server:native-maintenance-report'](read.ticket,read.identity.epoch,128,item.revision,
  {degradation=0.10000000149,permanentDegradation=0.1,damage=damage or 0.1,dirt=dirt,soot=0})
end
sweep(0); assert(not read)
sweep(60000); assert(read and reads==0 and writes==0)
if NATIVE_BROKEN_SCENARIO==true then
 report(0.5,1)
 if NATIVE_BROKEN_INVENTORY_OLD then
  assert(not release and writes==0 and assigned,'old Inventory must refuse before releasing/writing broken wear')
  return
 end
 assert(release and writes==0,'broken report still requires owned release')
 local outgoing=release.identity; state={phase='released',identity=outgoing}
 events['feather-weapons:server:native-equipment-released'](release.ticket,outgoing,true)
 assert(writes==1 and not assigned and item.metadata.condition==0 and restores==1,'broken assignment may rebuild empty without false lost-equipment refusal')
 state={phase='active',identity=id}
 events['feather-weapons:server:native-equipment-restored'](release.ticket,id)
 commands.WeaponNativePeriodicWearStatus(0,{'1'}); assert(diagnostic.state.persisted==1)
 print('Broken wear concrete binding PASS (server plan, release-before-CAS, intentional removal verified, empty fresh rebuild)')
 return
end
report(0.5); assert(reads==0 and writes==0 and not release,'unchanged input performs no SQL or rebuild')
commands.WeaponNativePeriodicWearStatus(0,{'1'}); assert(diagnostic.state.unchanged==1)
sweep(120000); report(0.6); assert(release and writes==0,'changed periodic sample still requires release')
local old=release.identity; state={phase='released',identity=old}
events['feather-weapons:server:native-equipment-released'](release.ticket,old,true)
assert(writes==1 and item.revision==6 and restores==1)
state={phase='active',identity=id}
events['feather-weapons:server:native-equipment-restored'](release.ticket,id)
commands.WeaponNativePeriodicWearStatus(0,{'1'}); assert(diagnostic.state.persisted==1)
sweep(120001); local before=reads
sweep(180001); report(0.6)
assert(writes==1 and reads==before and restores==1,'saved wear cannot churn revision or reconstruct again')
commands.WeaponNativePeriodicWearStatus(0,{'1'}); assert(diagnostic.state.unchanged==2)
sweep(240001); state.phase='sealed'; before=reads; report(0.7)
assert(reads==before and writes==1,'late death report must not write or retire copies')
state.phase='active'; sweep(300001); disableOnCommit=true; report(0.7)
old=release.identity; state={phase='released',identity=old}
events['feather-weapons:server:native-equipment-released'](release.ticket,old,true)
assert(writes==1 and restores==1,'periodic disable before commit vetoes write/rebuild')
Config.NativeAlphaPeriodicWearEnabled=true; sweep(360001)
assert(writes==1 and restores==1,'frozen transition cannot automatically retry')
print('Periodic concrete bindings PASS (automatic server tickets, no-op skips SQL, release-before-CAS/fresh restore, no churn, late death/disable/uncertain refusal)')
