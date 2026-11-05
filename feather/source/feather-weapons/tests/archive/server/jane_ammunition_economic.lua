local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local active,attempted,logoutSession=nil,false,nil
local sequence=0
local autoLogin=nil
local guardName='feather-weapons-jane-economic'
local function enabled()
 return Config.DevMode==true and Config.CharacterAmmunitionEnabled~=true
  and Config.CharacterAmmoTransportEnabled~=true and GetConvar('feather_jane_ammo_economic','0')=='1'
  and GetResourceState('feather-weapons-native-proof')=='stopped'
end
local function current(src,sid,char)
 return active and active.source==src and active.sessionId==sid and char==jane and enabled()
  and exports['feather-core']:IsSessionCurrent(src,sid,char)==true
end
local runtime=WeaponCharacterAmmoRuntime.New(current)
exports('ValidateCharacterAmmoRuntimeOperation',function(context,operation,spec)
 return GetInvokingResource()=='feather-inventory' and enabled()
  and runtime.IsOperationCurrent(context,operation,spec)==true
end)
local function guard(item) return not active or tonumber(item.id)~=112,'Jane economic native hold' end
local function release(owner)
 for _,name in ipairs({'UnregisterMoveGuard','UnregisterDestroyGuard','UnregisterInstanceChangeGuard'}) do owner.api.Guards[name](guardName) end
 active=nil
end
local function send(owner,kind,value,plan)
 assert(current(owner.source,owner.sessionId,jane),'context changed before dispatch')
 owner.stage=kind
 TriggerClientEvent('feather-weapons:jane-economic:reply',owner.source,kind,value,plan)
end
local function commit(owner,request,method)
 assert(request,'runtime request refused')
 local result=exports['feather-inventory'][method](exports['feather-inventory'],request.context,request.spec)
 local value,reason=runtime.Complete(request.context,result)
 return assert(value,'Inventory commit/runtime completion refused: '..tostring(
  type(result)=='table' and result.error and result.error.code or reason))
end
local function begin(source,args,savedPrimary,expectedSession)
 if source~=0 then return end
 local target=tonumber(args and args[1])
 local automatic=savedPrimary=='auto-logout' or savedPrimary=='auto-recover'
 if automatic then savedPrimary=savedPrimary=='auto-logout' and 'logout' or 'recover' end
 local lifecycle=savedPrimary=='logout' or savedPrimary=='recover'
 if (attempted and not (savedPrimary=='recover' and logoutSession)) or active or not enabled() or not target or target<1 or target%1~=0 or args[2]~=jane then
  print('[WeaponJaneEconomic] BLOCKED: exact Jane/opt-in/one attempt per start required'); return
 end
 attempted=true
 local owner={source=target,busy=true,automatic=automatic,savedPrimary=savedPrimary==true or lifecycle,lifecycle=lifecycle and savedPrimary or nil}; active=owner
 savedPrimary=owner.savedPrimary
 local dispatched=false
 local ok,reason=pcall(function()
  local session=exports['feather-core']:GetSessionContext(target)
  assert(session and session.ok and type(session.value)=='table' and session.value.characterId==jane,
   'Jane session required at serverId='..target..'; select Jane and use WeaponJaneSession to confirm current ID')
  owner.sessionId=session.value.sessionId
  assert(not expectedSession or owner.sessionId==expectedSession,'automatic login session changed')
  if owner.lifecycle=='recover' then assert(owner.sessionId~=logoutSession,'new login session required') end
  assert(current(target,owner.sessionId,jane),'current Jane required')
  owner.api=exports['feather-inventory']:initiate()
  for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
   local result=owner.api.Guards[name](guardName,guard); assert(result and result.ok,'item guard required')
  end
  local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
  local context={actorSource=target,characterId=jane,sessionId=owner.sessionId}
  local read=exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot(context,registry.limits)
  assert(current(target,owner.sessionId,jane) and read and read.ok,'current snapshot required')
  local initialRevision=owner.lifecycle=='logout' and (automatic and 7 or 5) or owner.lifecycle=='recover' and (automatic and 8 or 6) or savedPrimary and 3 or 0
  assert(read.value.characterId==jane and read.value.revision==initialRevision,'exact initial ledger required')
  if savedPrimary then
   local primary=read.value.equipment.primary
   assert(primary and primary.id==112 and primary.revision==1 and primary.itemName=='weapon_revolver_cattleman','saved primary required')
   for slot in pairs(read.value.equipment) do assert(slot=='primary','only primary permitted') end
  else assert(next(read.value.equipment)==nil,'unequipped required') end
  for id in pairs(registry.limits) do assert(read.value.pools[id]==(owner.lifecycle=='recover' and id=='ammo_revolver_regular' and 1 or 0),'exact initial belt required') end
  local item=owner.api.GetItemForCharacter(jane,112)
  assert(current(target,owner.sessionId,jane) and item and item.ok,'current item required')
  local row=item.value
  assert(row.id==112 and row.revision==1 and row.definition.name=='weapon_revolver_cattleman'
   and row.metadata.serialNumber=='FW-REVO-6AC9DCDE-FDEBF3-0001','exact item identity required')
  sequence=sequence+1
  local epoch=('%s:%s:%s:%s'):format(owner.lifecycle and 'jane-primary-'..(automatic and 'auto-' or '')..owner.lifecycle or savedPrimary and 'jane-primary-roundtrip' or 'jane-economic',owner.sessionId,GetGameTimer(),sequence)
  local report=assert(runtime.Open({source=target,characterId=jane,sessionId=owner.sessionId},read.value,registry.limits,epoch))
  local equipment=savedPrimary and read.value.equipment or {primary={id=112,revision=1,itemName=row.definition.name,metadata=row.metadata}}
  if savedPrimary then assert(equipment.primary.metadata.serialNumber==row.metadata.serialNumber,'saved serial mismatch') end
  local plan=assert(WeaponCharacterAmmoMaterialization.Build(equipment,
   WeaponDefinitionCatalog,registry,report))
  owner.report=report; dispatched=true
  if owner.lifecycle=='recover' then
   local zero={}; for key,value in pairs(report) do zero[key]=value end
   zero.pools={}; for id in pairs(registry.limits) do zero.pools[id]=0 end
   send(owner,'create',zero,plan)
  else send(owner,'create',report,plan) end
 end)
 owner.busy=false
 if not ok then
  owner.stage='failed'
  if not dispatched then
   if owner.sessionId then runtime.Revoke(target,owner.sessionId) end
   if owner.api then pcall(release,owner) else active=nil end
   if active==nil then attempted=false end -- no dispatch/SQL mutation: safe preflight retry
  end
  print('[WeaponJaneEconomic] '..(not dispatched and active==nil and 'WAIT ' or 'FAIL ')..tostring(reason)
   ..(not dispatched and active==nil and '; preflight only, no native/ammo writes; retry when current'
    or '; retain holds after dispatch; no automatic rollback of committed ammo'))
 end
end
RegisterCommand('WeaponJaneEconomic',function(source,args) begin(source,args,false) end,true)
RegisterCommand('WeaponJanePrimaryRoundtrip',function(source,args) begin(source,args,true) end,true)
RegisterCommand('WeaponJanePrimaryLogout',function(source,args) begin(source,args,'logout') end,true)
RegisterCommand('WeaponJanePrimaryRecover',function(source,args) begin(source,args,'recover') end,true)
RegisterCommand('WeaponJanePrimaryAutoLogin',function(source,args) begin(source,args,'auto-logout') end,true)
RegisterCommand('WeaponJanePrimaryAutoRecover',function(source,args) begin(source,args,'auto-recover') end,true)
RegisterNetEvent('feather-weapons:jane-economic:auto-ready',function(characterId,sessionId)
 local target=source
 local arm=autoLogin
 if not arm or arm.used or arm.busy or active or not enabled() or target~=arm.source
  or characterId~=jane or type(sessionId)~='string' or sessionId==arm.sessionId then return end
 arm.busy=true
 local called,valid=pcall(function() return exports['feather-core']:IsSessionCurrent(target,sessionId,jane) end)
 arm.busy=nil
 if not called or valid~=true or arm.used or active or not enabled() then return end
 arm.used=true
 begin(0,{tostring(target),jane},'auto-recover',sessionId)
end)
RegisterCommand('WeaponJaneSession',function(source,args)
 if source~=0 or not enabled() or not args or args[1]~=jane then return end
 local ok,reason=pcall(function()
  local matches=0
  for _,raw in ipairs(GetPlayers()) do
   local target=tonumber(raw)
   local session=target and exports['feather-core']:GetSessionContext(target)
   local value=session and session.ok and session.value
   if type(value)=='table' and value.characterId==jane
    and exports['feather-core']:IsSessionCurrent(target,value.sessionId,jane)==true then
    matches=matches+1; print('[WeaponJaneSession] CURRENT Jane serverId='..target..'; identity only, not native readiness')
   end
  end
  if matches==0 then print('[WeaponJaneSession] WAIT no active Jane session; select Jane and wait until playable') end
 end)
 if not ok then print('[WeaponJaneSession] FAIL '..tostring(reason)) end
end,true)
RegisterNetEvent('feather-weapons:jane-economic:ack',function(kind,report)
 local owner,src=active,source
 if not owner or owner.busy or type(owner.report)~='table' or src~=owner.source or kind~=owner.stage or type(report)~='table'
  or report.epoch~=owner.report.epoch or report.sessionId~=owner.sessionId or report.characterId~=jane then return end
 owner.busy=true -- serialize before yielded Core/Inventory exports
 local ok,reason=pcall(function()
  assert(current(src,owner.sessionId,jane),'session/scope changed')
  if kind=='create' or kind=='load' or kind=='unload' then
   if kind=='create' and owner.lifecycle=='recover' then
    assert(report.revision==(owner.automatic and 8 or 6) and type(report.pools)=='table','zero creation acknowledgement required')
    local retained=report.pools.ammo_revolver_regular==1
    for id in pairs(owner.report.pools) do
     assert(report.pools[id]==(retained and id=='ammo_revolver_regular' and 1 or 0),
      'creation must preserve empty or exact saved Regular1 native pool')
    end
    for id in pairs(report.pools) do assert(owner.report.pools[id]~=nil,'unknown pool') end
    send(owner,'load',owner.report); return
   end
   owner.report=assert(runtime.ConfirmRestore(src,report),'exact restore ack required')
   if kind=='create' then
    local request=assert(runtime.PrepareTransfer(src,owner.report,'ammo_revolver_regular',owner.savedPrimary and 1 or 2,
     owner.lifecycle=='logout' and (owner.automatic and 'jane-auto-login-load-v1' or 'jane-logout-load-v1') or owner.savedPrimary and 'jane-primary-load-v1' or 'jane-economic-load-v1'))
    owner.report=commit(owner,request,'MutateCharacterAmmunition'); send(owner,'load',owner.report)
    print('[WeaponJaneEconomic] LOAD COMMITTED carried'..(owner.savedPrimary and '1' or '2')..'; awaiting exact native ack')
   elseif kind=='load' then
    if owner.lifecycle=='logout' then
     send(owner,'logout-ready',owner.report)
     print('[WeaponJanePrimaryLogout] READY carried1 revision'..owner.report.revision..'; run /logout, do not fire/switch/reload')
    elseif owner.savedPrimary then
     print((owner.lifecycle=='recover' and '[WeaponJanePrimaryRecover] ' or '[WeaponJanePrimaryRoundtrip] ')
      ..'LOAD ACK carried1 revision'..owner.report.revision..'; unloading without firing')
     owner.report=commit(owner,assert(runtime.PrepareTransfer(src,owner.report,'ammo_revolver_regular',-1,
      owner.lifecycle=='recover' and (owner.automatic and 'jane-auto-login-unload-v1' or 'jane-login-unload-v1') or 'jane-primary-unload-v1')),
      'MutateCharacterAmmunition')
     send(owner,'unload',owner.report)
    else
     send(owner,'shot',owner.report)
     print('[WeaponJaneEconomic] ARMED: single-draw Regular; fire ONCE, no reload/switch/logout/death')
    end
   else
    owner.report=assert(runtime.PrepareFinalObservation(src,owner.report).value)
    assert(owner.report.phase=='sealed','empty final seal required')
    send(owner,'cleanup',owner.report)
    print('[WeaponJaneEconomic] UNLOAD ACK carried0 revision'..tostring(owner.report.revision)..'; remove owned native copy')
   end
  elseif kind=='logout-ready' then
   assert(owner.lifecycle=='logout','logout gate required')
   local final=assert(runtime.PrepareFinalObservation(src,report))
   assert(final.unchanged and final.value.phase=='sealed','no firing/changed pool permitted')
   owner.report=final.value; send(owner,'cleanup',owner.report)
  elseif kind=='shot' then
   assert(report.pools and report.pools.ammo_revolver_regular==1,'exactly one shot required')
   owner.report=commit(owner,assert(runtime.PrepareObservation(src,report)),'ObserveCharacterAmmunition')
   print('[WeaponJaneEconomic] SHOT SAVED carried1 revision2; unloading remaining round')
   owner.report=commit(owner,assert(runtime.PrepareTransfer(src,owner.report,'ammo_revolver_regular',-1,'jane-economic-unload-v1')),
    'MutateCharacterAmmunition')
   send(owner,'unload',owner.report)
  elseif kind=='cleanup' then
   assert(runtime.ConfirmCleanup(src,report),'sealed cleanup ack required')
   release(owner)
   if owner.lifecycle then
    if owner.lifecycle=='logout' then
     logoutSession=owner.sessionId
     if owner.automatic then autoLogin={source=src,sessionId=owner.sessionId} end
    end
    TriggerClientEvent('feather-weapons:jane-economic:released',src,owner.report.epoch,owner.sessionId)
    print(owner.automatic and (owner.lifecycle=='logout'
     and '[WeaponJanePrimaryAutoLogin] LOGOUT PASS carried1 revision8; login Jane for automatic restore/unload'
     or '[WeaponJanePrimaryAutoLogin] PASS automatic restored1/unloaded1 ledgerRevision9 carried0 loose1; owned cleanup/hold release; saved primary retained')
     or owner.lifecycle=='logout' and '[WeaponJanePrimaryLogout] PASS sealed/released carried1 revision6; saved primary retained; login Jane then run recovery'
     or '[WeaponJanePrimaryRecover] PASS restored1/unloaded1 ledgerRevision7 carried0 loose1; owned cleanup/hold release; saved primary retained')
   else print(owner.savedPrimary and '[WeaponJanePrimaryRoundtrip] PASS load1/unload1 no firing; ledger revision5 carried0 loose1; saved primary retained; owned cleanup/hold release; global production disabled'
    or '[WeaponJaneEconomic] PASS load2/fire1/unload1; ledger revision3 carried0; owned cleanup/hold release; real Inventory exports; global production disabled')
   end
  end
 end)
 owner.busy=false
 if not ok then
  owner.stage='failed'; runtime.Revoke(src,owner.sessionId)
  TriggerClientEvent('feather-weapons:jane-economic:failed',src,owner.report.epoch)
  print('[WeaponJaneEconomic] FAIL '..tostring(reason)..'; committed state retained; keep holds and report logs')
 end
end)
