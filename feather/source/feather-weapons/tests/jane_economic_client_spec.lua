Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
dofile('shared/character_ammunition.lua'); dofile('client/character_ammunition_native.lua')
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local events,worker,acks={},{},{}
local checkpoint,invoking,sessionId=nil,'feather-character','s'
GetInvokingResource=function() return invoking end
exports=setmetatable({['feather-character']={RegisterLogoutCheckpoint=function() return {ok=true} end}},
 {__call=function(_,name,fn) assert(name=='CheckpointJanePrimaryLogout'); checkpoint=fn end})
local actualRunner
if JANE_PRIMARY_LOGOUT then
 local registered={}
 CharacterV2Result={Ok=function(v) return {ok=true,value=v} end,Err=function(c,m) return {ok=false,code=c,message=m} end}
 AddEventHandler=function() end
 GetResourceState=function() return 'started' end
 exports=setmetatable({['feather-character']={},['feather-weapons']={}},
  {__call=function(_,name,fn) registered[name]=fn end})
 dofile('../feather-character/client/checkpoints.lua')
 exports['feather-character'].RegisterLogoutCheckpoint=function(_,name,exportName)
  local old=invoking; invoking='feather-weapons'
  local result=registered.RegisterLogoutCheckpoint(name,exportName); invoking=old; return result
 end
 exports['feather-weapons'].CheckpointJanePrimaryLogout=function(_,context) return checkpoint(context) end
 local resourceExports=exports
 exports=setmetatable(resourceExports,{__call=function(_,name,fn) checkpoint=fn end})
 actualRunner=CharacterV2Checkpoints.Run
end
RegisterNetEvent=function(name,fn) events[name]=fn end
local handlers={}
AddEventHandler=function(name,fn) handlers[name]=fn end
CreateThread=function(fn) worker=coroutine.create(fn) end
Wait=function() coroutine.yield() end
GetGameTimer=function() return 1 end
PlayerPedId=function() return 1 end; PlayerId=function() return 1 end
local blocked=0; DisablePlayerFiring=function() blocked=blocked+1 end
local registry={names={},limits={}}
local native={}
for i=1,27 do local id=i==1 and 'ammo_revolver_regular' or 'ammo_test_'..i
 registry.names[id]='AMMO_TEST_'..i; registry.limits[id]=200; native[registry.names[id]]=0
end
joaat=function(v) return v end
GetPedAmmoByType=function(_,hash) return native[hash] end
SetPedAmmoByType=function(_,hash,n) native[hash]=n end
Citizen={InvokeNative=function(_,_,hash,n) native[hash]=native[hash]-n end}
WeaponDefinitionCatalog={}
WeaponCharacterAmmoPolicy={Build=function() return registry end}
WeaponCharacterAmmoMaterialization={Validate=function() return true end}
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId=jane,sessionId=sessionId,ped=1}} end}
WeaponCharacterAmmoWorldContext.Identity=function() return {characterId=jane,sessionId=sessionId} end
local created,removed=0,0
WeaponCharacterAmmoCreationNative={New=function(_,current)
 return {createSingle=function(_,amount,identity) assert(amount==0 and current(identity)); created=created+1; return {entity=2} end,
 finish=function() return true end,remove=function() removed=removed+1; return true end}
end}
TriggerServerEvent=function(_,kind,report) acks[#acks+1]={kind=kind,report=report} end
dofile('tests/archive/client/jane_ammunition_economic.lua')
local reply=events['feather-weapons:jane-economic:reply']
local function baseline(revision,amount,phase)
 local pools={}; for id in pairs(registry.limits) do pools[id]=id=='ammo_revolver_regular' and amount or 0 end
 local epoch=JANE_PRIMARY_LOGOUT and ('jane-primary-'..(JANE_AUTO_LOGIN and 'auto-' or '')..(JANE_PRIMARY_RECOVER and 'recover' or 'logout')..':'..sessionId..':1')
  or JANE_PRIMARY_ROUNDTRIP and 'jane-primary-roundtrip:s:1' or 'e'
 return {characterId=jane,sessionId=sessionId,epoch=epoch,revision=revision,pools=pools,phase=phase}
end
local initial=baseline(JANE_PRIMARY_LOGOUT and (JANE_AUTO_LOGIN and 7 or 5) or JANE_PRIMARY_ROUNDTRIP and 3 or 0,0,'restoring')
local plan={identity={characterId=jane,sessionId='s',epoch=initial.epoch},items={{itemInstanceId=112,itemRevision=1,
 definitionId='revolver_cattleman',point=2}}}
source=1; reply('create',initial,plan); assert(created==0)
source=65535; reply('create',initial,plan); assert(created==1 and acks[#acks].kind=='create')
if JANE_PRIMARY_LOGOUT then
 local loadedRevision=JANE_AUTO_LOGIN and 8 or 6
 reply('load',baseline(loadedRevision,1,'restoring')); assert(native.AMMO_TEST_1==1)
 reply('logout-ready',baseline(loadedRevision,1,'active'))
 invoking='untrusted'; assert(not checkpoint({characterId=jane,reason='logout'}).ok); invoking='feather-character'
 assert(not checkpoint({characterId='original',reason='logout'}).ok)
 local result
 local quit=coroutine.create(function() result=(actualRunner or checkpoint)({characterId=jane,reason='logout'}) end)
 assert(coroutine.resume(quit) and not result and acks[#acks].kind=='logout-ready')
 assert(not checkpoint({characterId=jane,reason='logout'}).ok,'overlapping checkpoint refused')
 reply('cleanup',baseline(loadedRevision,1,'sealed')); assert(removed==1 and acks[#acks].kind=='cleanup')
 assert(coroutine.resume(quit) and not result,'must wait for server release acknowledgement')
 events['feather-weapons:jane-economic:released'](initial.epoch,'s')
 assert(coroutine.resume(quit) and result.ok,'actual release permits logout')
 native.AMMO_TEST_1=JANE_RETAINED_NATIVE and 1 or 0; sessionId='new-login'; JANE_PRIMARY_RECOVER=true
 if JANE_AUTO_LOGIN then
  handlers['feather-character:client:runtime-ready.v1']({characterId=jane})
  assert(coroutine.resume(worker))
  assert(acks[#acks].kind==jane and acks[#acks].report==sessionId,'automatic hint uses independent current identity')
 end
 if JANE_RETAINED_INVALID then native.AMMO_TEST_2=1 end
 initial=baseline(loadedRevision,0,'restoring'); plan.identity={characterId=jane,sessionId=sessionId,epoch=initial.epoch}
 local count=#acks
 reply('create',initial,plan)
 if JANE_RETAINED_INVALID then
  assert(created==1 and removed==1 and #acks==count and native.AMMO_TEST_2==1,'unexpected retained pool must refuse before creation/reset/ack')
  JANE_PRIMARY_RECOVER=nil
  print('Jane recovery foreign native pool refusal PASS (no creation/native reset/ack; failed owner retained)')
  return
 end
 assert(created==2 and acks[#acks].kind=='create')
 reply('load',baseline(loadedRevision,1,'restoring')); assert(native.AMMO_TEST_1==1)
 reply('unload',baseline(loadedRevision+1,0,'restoring')); assert(native.AMMO_TEST_1==0)
 reply('cleanup',baseline(loadedRevision+1,0,'sealed')); assert(removed==2)
 events['feather-weapons:jane-economic:released'](initial.epoch,sessionId)
 assert(checkpoint({characterId=jane,reason='logout'}).ok)
 JANE_PRIMARY_RECOVER=nil
 print('Jane saved-primary logout/login client PASS (Character callback caller/context/overlap, seal/cleanup/server-release wait, new-session restore1/unload1; native mocks)')
 return
end
if JANE_PRIMARY_ROUNDTRIP then
 reply('load',baseline(4,1,'restoring')); assert(native.AMMO_TEST_1==1 and acks[#acks].kind=='load')
 assert(coroutine.resume(worker)); assert(coroutine.resume(worker) and blocked>0,'saved roundtrip never enables firing')
 local count=#acks; reply('load',baseline(4,1,'restoring')); assert(#acks==count)
 reply('unload',baseline(5,0,'restoring')); assert(native.AMMO_TEST_1==0 and acks[#acks].kind=='unload')
 reply('cleanup',baseline(5,0,'sealed')); assert(removed==1 and acks[#acks].kind=='cleanup')
 print('Jane saved-primary roundtrip client PASS (native restore1/readback/restore0, firing blocked, duplicate barrier, owned cleanup; native mocks)')
 return
end
reply('load',baseline(1,2,'restoring')); assert(native.AMMO_TEST_1==2 and acks[#acks].kind=='load')
local count=#acks; reply('load',baseline(1,2,'restoring')); assert(#acks==count,'duplicate restore ignored')
reply('shot',baseline(1,2,'active'))
assert(coroutine.resume(worker)) -- initial Wait
native.AMMO_TEST_1=1; assert(coroutine.resume(worker))
assert(acks[#acks].kind=='shot' and acks[#acks].report.pools.ammo_revolver_regular==1)
assert(coroutine.resume(worker) and blocked>0,'pending shot blocks additional firing')
reply('unload',baseline(3,0,'restoring')); assert(native.AMMO_TEST_1==0 and acks[#acks].kind=='unload')
reply('cleanup',baseline(3,0,'sealed'))
assert(removed==1 and acks[#acks].kind=='cleanup' and acks[#acks].report.cleanupComplete==true)
print('Jane economics client PASS (server-origin, zero creation, actual native-pool adapter restore/readback, shot observation, duplicate barrier, cleanup; native mocks)')
