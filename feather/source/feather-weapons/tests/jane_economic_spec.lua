Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_runtime.lua')
dofile('shared/character_ammunition_catalog.lua'); dofile('shared/character_ammunition_policy.lua')
dofile('shared/character_ammunition_item.lua'); dofile('shared/character_ammunition_materialization.lua')
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local scope,current='1',true
GetConvar=function() return scope end; GetResourceState=function() return 'stopped' end
GetGameTimer=function() return 1 end
GetPlayers=function() return {'1'} end
local commands,events,registered,guards,sent={},{},{},{},{}
RegisterCommand=function(name,fn) commands[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
TriggerClientEvent=function(name,target,kind,value,plan) sent[#sent+1]={kind=kind,value=value,plan=plan} end
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local pools={}; for id in pairs(registry.limits) do pools[id]=0 end
local api={Guards={}}
for _,kind in ipairs({'Move','Destroy','InstanceChange'}) do
 api.Guards['Register'..kind..'Guard']=function(_,fn) guards[kind]=fn; return {ok=true} end
 api.Guards['Unregister'..kind..'Guard']=function() guards[kind]=nil end
end
api.GetItemForCharacter=function()
 return {ok=true,value={id=112,revision=1,definition={name='weapon_revolver_cattleman'},metadata={
  schemaVersion=2,weaponDefinitionId='revolver_cattleman',serialNumber='FW-REVO-6AC9DCDE-FDEBF3-0001',condition=100,quality=100,
  maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},ammo={ownership='character',type='ammo_revolver_regular'},
  attachments={},cosmetics={},flags={stolen=false,evidence=false,disabled=false},provenance={}}}}
end
Result={Ok=function(v) return {ok=true,value=v} end,Err=function(c,m) return {ok=false,error={code=c,message=m}} end,
 Codes={DENIED='denied',INVALID_INPUT='invalid',CONFLICT='conflict',NOT_FOUND='missing',LIMIT_EXCEEDED='limit'},IsOk=function(v) return v.ok end}
InventoryIdentity={NormalizeCharacterId=function(v) return v==jane and v or nil end}
InventoryAPI={AccessModes={REMOVE='remove',INSERT='insert'}}
local initialRevision=JANE_PRIMARY_LOGOUT and (JANE_AUTO_LOGIN and 7 or 5) or JANE_PRIMARY_ROUNDTRIP and 3 or 0
local initialLoose=(JANE_PRIMARY_LOGOUT or JANE_PRIMARY_ROUNDTRIP) and 1 or 2
local database={revision=initialRevision,pools=pools,loose=initialLoose,receipts={}}
local function copy(v) if type(v)~='table' then return v end; local o={}; for k,x in pairs(v) do o[k]=copy(x) end; return o end
json={encode=copy,decode=copy}
local tx={query=function(sql,args)
 if sql:find('SELECT id FROM inventory',1,true) then return {{id=1}} end
 if sql:find('SELECT revision, pools',1,true) then return {{revision=database.revision,pools=database.pools}} end
 if sql:find('SELECT result FROM',1,true) then local r=database.receipts[args[2]]; return r and {{result=r}} or {} end
 if sql:find('SELECT id, type',1,true) then return {{id=8,type='item_ammo',instance_mode='stack'}} end
 if sql:find('UPDATE feather_character',1,true) then
  database.pools=copy(args[1]); database.revision=args[2]
  if JANE_ECONOMIC_REVOKE or (JANE_ECONOMIC_REVOKE_UNLOAD and args[2]==(JANE_AUTO_LOGIN and 9 or 5)) then scope='0' end
  return {affectedRows=1}
 end
 if sql:find('INSERT INTO feather_ammunition',1,true) then database.receipts[args[2]]=copy(args[3]); return {affectedRows=1} end
 error(sql)
end,RequireAccess=function() end,
 RemoveQuantity=function(_,_,_,n) assert(database.loose>=n); database.loose=database.loose-n; return Result.Ok({}) end,
 AddQuantity=function(_,_,_,n) database.loose=database.loose+n; return Result.Ok({}) end}
TransactionAPI={Transaction=function(_,fn) local before=copy(database); local r=fn(tx); if not r.ok then database=before end; return r end}
local caller='feather-inventory'
GetInvokingResource=function() return caller end
local inv={initiate=function() return api end,GetCharacterFirearmRuntimeSnapshot=function()
 local equipment={}
 if JANE_PRIMARY_ROUNDTRIP or JANE_PRIMARY_LOGOUT then local row=api.GetItemForCharacter().value
  equipment.primary={id=row.id,revision=row.revision,itemName=row.definition.name,metadata=row.metadata}
 end
 return {ok=true,value={characterId=jane,revision=database.revision,pools=copy(database.pools),equipment=equipment}}
end}
local sessionId='s'
exports=setmetatable({['feather-core']={GetSessionContext=function() return {ok=true,value={characterId=jane,sessionId=sessionId}} end,
 IsSessionCurrent=function(_,target,sid,char) return current and target==1 and sid==sessionId and char==jane end},['feather-inventory']=inv,['feather-weapons']={}},
 {__call=function(_,name,fn) registered[name]=fn end})
RegisterCommand=function(name,fn) commands[name]=fn end
dofile('../feather-inventory/server/services/character_ammunition.lua')
inv.MutateCharacterAmmunition=function(_,context,spec) return CharacterAmmunitionAPI.Mutate(context,spec,'feather-weapons') end
inv.ObserveCharacterAmmunition=function(_,context,spec) return CharacterAmmunitionAPI.Observe(context,spec,'feather-weapons') end
dofile('tests/archive/server/jane_ammunition_economic.lua')
exports['feather-weapons'].ValidateCharacterAmmoRuntimeOperation=function(_,ctx,operation,spec)
 return registered.ValidateCharacterAmmoRuntimeOperation(ctx,operation,spec)
end
local run=JANE_PRIMARY_LOGOUT and (JANE_AUTO_LOGIN and commands.WeaponJanePrimaryAutoLogin or commands.WeaponJanePrimaryLogout) or JANE_PRIMARY_ROUNDTRIP and commands.WeaponJanePrimaryRoundtrip or commands.WeaponJaneEconomic
run(1,{'1',jane}); assert(#sent==0)
local getSession=exports['feather-core'].GetSessionContext
exports['feather-core'].GetSessionContext=function() return {ok=false,error={code='not_active'}} end
commands.WeaponJaneSession(0,{jane})
run(0,{'1',jane}); run(0,{'1',jane})
assert(#sent==0 and next(guards)==nil and database.revision==initialRevision and database.loose==initialLoose,
 'not-active preflight retries must neither latch attempt nor write/dispatch')
exports['feather-core'].GetSessionContext=getSession
commands.WeaponJaneSession(0,{jane})
run(0,{'1',jane}); assert(sent[1].kind=='create' and next(guards))
local acknowledge=events['feather-weapons:jane-economic:ack']
source=2; acknowledge('create',sent[1].value); assert(database.revision==initialRevision)
source=1; acknowledge('create',sent[1].value)
if JANE_ECONOMIC_REVOKE then
 assert(database.revision==initialRevision and database.loose==initialLoose and database.pools.ammo_revolver_regular==0 and next(database.receipts)==nil,
  'scope loss after SQL write rolls back load/loose/receipt')
 assert(next(guards),'failed dispatched attempt retains item holds')
 print('Jane scoped economics revocation PASS (post-write scope loss rolls back actual Inventory API transaction; holds retained)')
 return
end
if JANE_PRIMARY_LOGOUT then
 local loadedRevision=JANE_AUTO_LOGIN and 8 or 6
 assert(database.revision==loadedRevision and database.loose==0 and sent[#sent].kind=='load')
 acknowledge('load',sent[#sent].value); assert(sent[#sent].kind=='logout-ready')
 local report=sent[#sent].value
 local prior=#sent; source=2; acknowledge('logout-ready',report); assert(#sent==prior); source=1
 acknowledge('logout-ready',report); assert(sent[#sent].kind=='cleanup' and next(guards))
 local clean=copy(sent[#sent].value); clean.cleanupComplete=true; clean.remainingCopies=0
 acknowledge('cleanup',clean); assert(next(guards)==nil and sent[#sent].kind==report.epoch,'release ack dispatched')
 assert(database.revision==loadedRevision and database.pools.ammo_revolver_regular==1 and database.loose==0)
 sessionId='new-login'
 if JANE_AUTO_LOGIN then
  local before=#sent
  source=2; events['feather-weapons:jane-economic:auto-ready'](jane,sessionId); assert(#sent==before)
  source=1; events['feather-weapons:jane-economic:auto-ready']('original',sessionId); assert(#sent==before)
  events['feather-weapons:jane-economic:auto-ready'](jane,'s'); assert(#sent==before)
  events['feather-weapons:jane-economic:auto-ready'](jane,sessionId)
  before=#sent; events['feather-weapons:jane-economic:auto-ready'](jane,sessionId); assert(#sent==before)
 else commands.WeaponJanePrimaryRecover(0,{'1',jane}) end
 assert(sent[#sent].kind=='create' and sent[#sent].value.pools.ammo_revolver_regular==0,'zero creation precedes stored carried restore')
 acknowledge('create',sent[#sent].value); assert(sent[#sent].kind=='load' and sent[#sent].value.pools.ammo_revolver_regular==1)
 acknowledge('load',sent[#sent].value)
 if JANE_ECONOMIC_REVOKE_UNLOAD then
  assert(database.revision==loadedRevision and database.loose==0 and database.pools.ammo_revolver_regular==1
   and database.receipts['jane-auto-login-unload-v1']==nil and next(guards),
   'scope loss after unload write must roll back to the committed carried round and retain holds')
  print('Jane automatic login unload revocation rollback PASS'); return
 end
 assert(database.revision==loadedRevision+1 and database.loose==1 and sent[#sent].kind=='unload')
 acknowledge('unload',sent[#sent].value); assert(sent[#sent].kind=='cleanup')
 clean=copy(sent[#sent].value); clean.cleanupComplete=true; clean.remainingCopies=0
 acknowledge('cleanup',clean); assert(next(guards)==nil and database.pools.ammo_revolver_regular==0)
 assert(database.receipts[JANE_AUTO_LOGIN and 'jane-auto-login-load-v1' or 'jane-logout-load-v1'].fingerprint=='ammo_revolver_regular:1:'..(loadedRevision-1))
 assert(database.receipts[JANE_AUTO_LOGIN and 'jane-auto-login-unload-v1' or 'jane-login-unload-v1'].fingerprint=='ammo_revolver_regular:-1:'..loadedRevision)
 print('Jane saved-primary logout/login server PASS (actual Inventory API, persisted1 seal/release, new session authoritative restore, unload1, holds/receipts; mocked CFX/SQL)')
 return
end
if JANE_PRIMARY_ROUNDTRIP then
 assert(database.revision==4 and database.loose==0 and sent[#sent].kind=='load')
 local loaded=sent[#sent].value
 acknowledge('create',sent[1].value); assert(database.revision==4,'duplicate cannot load twice')
 acknowledge('shot',loaded); assert(database.revision==4,'no shot stage exists')
 acknowledge('load',loaded)
 if JANE_ECONOMIC_REVOKE_UNLOAD then
  assert(database.revision==4 and database.loose==0 and database.pools.ammo_revolver_regular==1,
   'unload scope loss rolls back unload but preserves previously committed load')
  assert(database.receipts['jane-primary-load-v1'] and not database.receipts['jane-primary-unload-v1'],
   'failed unload cannot persist a return receipt or undo earlier load receipt')
  assert(next(guards),'loaded native copy must retain item holds after failed unload')
  local prior=#sent
  acknowledge('load',loaded); acknowledge('unload',loaded)
  assert(database.revision==4 and database.loose==0 and #sent==prior,'failed owner cannot replay into another mutation')
  print('Jane saved-primary unload revocation PASS (actual Inventory API rollback, loaded1 retained, loose0, no unload receipt, holds/retry freeze; mocked CFX/SQL)')
  return
 end
 assert(database.revision==5 and database.loose==1 and database.pools.ammo_revolver_regular==0 and sent[#sent].kind=='unload')
 acknowledge('unload',sent[#sent].value); assert(sent[#sent].kind=='cleanup' and next(guards))
 local clean=copy(sent[#sent].value); clean.cleanupComplete=true; clean.remainingCopies=0
 acknowledge('cleanup',clean); assert(next(guards)==nil)
 assert(database.receipts['jane-primary-load-v1'].fingerprint=='ammo_revolver_regular:1:3')
 assert(database.receipts['jane-primary-unload-v1'].fingerprint=='ammo_revolver_regular:-1:4')
 print('Jane saved-primary roundtrip PASS (actual runtime/Inventory API, load1/unload1 without observe/firing, receipts, barriers and cleanup; mocked CFX/SQL)')
 return
end
assert(database.revision==1 and database.loose==0 and sent[#sent].kind=='load')
acknowledge('create',sent[1].value); assert(database.revision==1,'duplicate must not spend twice')
acknowledge('load',sent[#sent].value); assert(sent[#sent].kind=='shot')
local shot=copy(sent[#sent].value); shot.pools.ammo_revolver_regular=1
acknowledge('shot',shot)
assert(database.revision==3 and database.loose==1 and database.pools.ammo_revolver_regular==0 and sent[#sent].kind=='unload')
acknowledge('unload',sent[#sent].value); assert(sent[#sent].kind=='cleanup' and next(guards),'seal retains holds')
local clean=copy(sent[#sent].value); clean.cleanupComplete=true; clean.remainingCopies=0
acknowledge('cleanup',clean); assert(next(guards)==nil)
assert(database.receipts['jane-economic-load-v1'] and database.receipts['jane-economic-unload-v1'])
assert(Config.CharacterAmmunitionEnabled==false,'global flag never enabled')
print('Jane scoped economics PASS (actual pure runtime + Inventory API, load2/shot1/unload1, restore barriers, receipts, retained/released holds; mocked CFX/SQL)')
