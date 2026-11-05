local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local owner,attempted,logoutSession,checkpointRegistered=nil,false,nil,false
local autoArm,autoRequested=nil,false
local function current(value)
 local read=WeaponCharacterAmmoWorldContext.Read()
 return read.ok and read.value.characterId==jane and read.value.sessionId==value.sessionId and read.value.ped==value.ped
end
local function report(value)
 local pools=assert(value.ammo.Read(value.ped,current(value)),'native read/current context failed')
 return {characterId=jane,sessionId=value.sessionId,epoch=value.epoch,revision=value.report.revision,pools=pools}
end
local function equal(left,right)
 for id,count in pairs(left) do if right[id]~=count then return false end end
 for id,count in pairs(right) do if left[id]~=count then return false end end
 return true
end
local function fail(value,reason)
 value.stage='failed'; print('[WeaponJaneEconomic] FAIL '..tostring(reason)..'; do not restart resources; report logs')
end
local function ack(value,kind)
 TriggerServerEvent('feather-weapons:jane-economic:ack',kind,report(value))
end
exports('CheckpointJanePrimaryLogout',function(context)
 local value=owner
 if GetInvokingResource()~='feather-character' then return {ok=false,error={code='checkpoint_caller_denied'}} end
 if not value then return {ok=true} end
 if value.lifecycle~='logout' or value.stage~='logout-ready' or value.busy
  or type(context)~='table' or context.characterId~=jane
  or (context.reason~='logout' and context.reason~='save_quit') then return {ok=false,error={code='jane_checkpoint_not_ready'}} end
 -- Reserve retirement before yielding; success waits for actual server release.
 value.stage='checkpoint'
 local ok,result=pcall(function()
  assert(current(value),'logout world changed')
  ack(value,'logout-ready')
  local deadline=GetGameTimer()+10000
  while not value.released do
   assert(value.stage~='failed' and GetGameTimer()<deadline and current(value),'logout release failed/timeout')
   Wait(0)
  end
  return {ok=true,value={released=true,characterId=jane,sessionId=value.sessionId}}
 end)
 if not ok then fail(value,result); return {ok=false,error={code='jane_checkpoint_failed'}} end
 return result
end)
RegisterNetEvent('feather-weapons:jane-economic:reply',function(kind,baseline,plan)
 if source~=65535 or Config.DevMode~=true or Config.CharacterAmmunitionEnabled==true
  or Config.CharacterAmmoTransportEnabled==true then return end
 if type(baseline)~='table' or baseline.characterId~=jane then return end
 if kind=='create' then
  local lifecycle=type(baseline.epoch)=='string' and baseline.epoch:match('^jane%-primary%-(logout):')
   or type(baseline.epoch)=='string' and baseline.epoch:match('^jane%-primary%-(recover):')
  local automatic=type(baseline.epoch)=='string' and (baseline.epoch:match('^jane%-primary%-auto%-(logout):')
   or baseline.epoch:match('^jane%-primary%-auto%-(recover):'))
  if automatic then lifecycle=automatic end
  if owner or (attempted and not (lifecycle=='recover' and logoutSession and baseline.sessionId~=logoutSession)) then return end
  attempted=true
  owner={sessionId=baseline.sessionId,epoch=baseline.epoch,report=baseline,stage='creating',busy=true,
   lifecycle=lifecycle or nil,automatic=automatic~=nil,
   savedPrimary=lifecycle~=false and lifecycle~=nil or type(baseline.epoch)=='string' and baseline.epoch:match('^jane%-primary%-roundtrip:')~=nil}
 else
  if not owner or owner.busy or owner.epoch~=baseline.epoch or owner.sessionId~=baseline.sessionId then return end
  if not ((kind=='load' and owner.stage=='create') or (kind=='shot' and owner.stage=='load')
   or (kind=='logout-ready' and owner.lifecycle=='logout' and owner.stage=='load')
   or (kind=='unload' and (owner.stage=='sent-shot' or (owner.savedPrimary and owner.stage=='load')))
   or (kind=='cleanup' and (owner.stage=='unload' or (owner.lifecycle=='logout' and owner.stage=='checkpoint')))) then return end
  owner.busy=true
 end
 local value=owner
 local ok,reason=pcall(function()
  if kind=='create' then
   local initial=value.lifecycle=='logout' and (value.automatic and 7 or 5) or value.lifecycle=='recover' and (value.automatic and 8 or 6) or value.savedPrimary and 3 or 0
   assert(baseline.revision==initial,'exact initial revision required')
   if value.lifecycle and not checkpointRegistered then
    local result=exports['feather-character']:RegisterLogoutCheckpoint('feather-weapons:jane-primary','CheckpointJanePrimaryLogout')
    assert(result and result.ok,'Character checkpoint registration failed')
    checkpointRegistered=true
   end
   local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
   assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,baseline),'invalid materialization')
   assert(#plan.items==1 and plan.items[1].itemInstanceId==112 and plan.items[1].itemRevision==1
    and plan.items[1].definitionId=='revolver_cattleman' and plan.items[1].point==2,'exact Jane item required')
   local read=WeaponCharacterAmmoWorldContext.Read()
   assert(read.ok and read.value.characterId==jane and read.value.sessionId==value.sessionId,'alive Jane required')
   value.ped=read.value.ped
   value.ammo=assert(WeaponCharacterAmmoNative.New(registry.names,registry.limits))
   local native=report(value)
   local retained=value.lifecycle=='recover' and native.pools.ammo_revolver_regular==1
   for id,count in pairs(native.pools) do
    assert(count==(retained and id=='ammo_revolver_regular' and 1 or 0),
     'unexpected native pool '..id..'='..tostring(count)..'; recovery permits only empty or saved Regular1')
   end
   if retained then print('[WeaponJanePrimaryRecover] retained Regular1 native pool; no ammo grant/reset') end
   value.creation=WeaponCharacterAmmoCreationNative.New(value.ped,function(identity)
    return identity==plan.identity and current(value)
   end,function() return false end)
   value.record=assert(value.creation.createSingle(plan.items[1],0,plan.identity),'zero-ammo creation failed')
   assert(value.creation.finish({value.record},plan.identity),'holster verification failed')
   assert(equal(report(value).pools,native.pools),'zero creation changed existing native ammo')
   value.stage='create'; ack(value,'create')
  elseif kind=='load' or kind=='unload' then
   assert(current(value),'world changed before restore')
   local expected=kind=='load' and (value.savedPrimary and 1 or 2) or 0
   local revision=value.lifecycle and (value.automatic and (kind=='load' and 8 or 9) or (kind=='load' and 6 or 7)) or value.savedPrimary and (kind=='load' and 4 or 5) or (kind=='load' and 1 or 3)
   assert(baseline.phase=='restoring' and baseline.revision==revision
    and baseline.pools.ammo_revolver_regular==expected,'unexpected economic baseline')
   for id,count in pairs(baseline.pools) do assert(count==(id=='ammo_revolver_regular' and expected or 0),'unexpected pool') end
   assert(value.ammo.Restore(baseline,value.ped,true),'exact native restore failed')
   value.report=baseline; value.stage=kind; ack(value,kind)
  elseif kind=='logout-ready' then
   assert(baseline.phase=='active' and baseline.revision==(value.automatic and 8 or 6) and equal(report(value).pools,baseline.pools),'logout baseline mismatch')
   value.report=baseline; value.stage='logout-ready'
   print('[WeaponJanePrimaryLogout] READY: run /logout; no firing/switch/reload; carried1 will remain saved')
  elseif kind=='shot' then
   assert(not value.savedPrimary,'saved-primary roundtrip must never arm firing')
   assert(baseline.phase=='active' and baseline.revision==1 and equal(report(value).pools,baseline.pools),'shot baseline mismatch')
   value.report=baseline; value.stage='armed'; value.deadline=GetGameTimer()+120000
   print('[WeaponJaneEconomic] ARMED: fire ONE Regular round from single Cattleman; no switching/reloading')
  elseif kind=='cleanup' then
   local revision=value.lifecycle=='logout' and (value.automatic and 8 or 6) or value.lifecycle=='recover' and (value.automatic and 9 or 7) or value.savedPrimary and 5 or 3
   assert(baseline.phase=='sealed' and baseline.revision==revision and equal(report(value).pools,baseline.pools),'sealed native belt required')
   assert(value.creation.remove(value.record)==true,'owned native cleanup failed')
   value.report=baseline; value.stage='cleaned'
   -- Cleanup acknowledges owned-copy removal against the sealed persisted belt;
   -- removing the last native weapon may itself change native pool readbacks.
   local final=value.lifecycle=='logout' and baseline or report(value)
   final.cleanupComplete=true; final.remainingCopies=0
   if value.lifecycle then value.stage='cleanup-pending' end
   TriggerServerEvent('feather-weapons:jane-economic:ack','cleanup',final)
   if not value.lifecycle then owner=nil end
  end
 end)
 value.busy=false
 if not ok then fail(value,reason) end
end)
RegisterNetEvent('feather-weapons:jane-economic:released',function(epoch,sessionId)
 local value=owner
 if source~=65535 or not value or not value.lifecycle or value.stage~='cleanup-pending'
  or value.epoch~=epoch or value.sessionId~=sessionId then return end
 value.released=true; value.stage='released'
 if value.lifecycle=='logout' then
  logoutSession=sessionId
  if value.automatic then autoArm=sessionId end
 end
 owner=nil
end)
AddEventHandler('feather-character:client:runtime-ready.v1',function(lifecycle)
 if not autoArm or autoRequested or owner or type(lifecycle)~='table' or lifecycle.characterId~=jane
  or Config.DevMode~=true or Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then return end
 local identity=WeaponCharacterAmmoWorldContext.Identity()
 if not identity or identity.characterId~=jane or identity.sessionId==autoArm then return end
 local expected=identity.sessionId
 autoRequested=true
 CreateThread(function()
  local deadline=GetGameTimer()+30000
  while GetGameTimer()<deadline do
   local now=WeaponCharacterAmmoWorldContext.Identity()
   if not now or now.characterId~=jane or now.sessionId~=expected or Config.DevMode~=true
    or Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then return end
   local ready=WeaponCharacterAmmoWorldContext.Read()
   if ready.ok and ready.value.characterId==jane and ready.value.sessionId==expected then
    TriggerServerEvent('feather-weapons:jane-economic:auto-ready',jane,expected); return
   end
   Wait(100)
  end
  print('[WeaponJanePrimaryAutoLogin] NOT READY: no automatic native restore attempted; committed carried1 retained')
 end)
end)
RegisterNetEvent('feather-weapons:jane-economic:failed',function(epoch)
 if source==65535 and owner and owner.epoch==epoch then fail(owner,'server gate failed') end
end)
CreateThread(function()
 while true do
  Wait(0)
  local value=owner
  if value and value.stage~='cleaned' then
   if value.stage~='armed' then DisablePlayerFiring(PlayerId(),true) end
   if value.ped and not value.busy and value.stage~='failed' then
    local contextOk,contextCurrent=pcall(current,value)
    if not contextOk or not contextCurrent then fail(value,'world/session changed or context read failed')
    elseif value.stage=='armed' then
     local ok,result=pcall(report,value)
     if not ok then fail(value,result)
     elseif not equal(result.pools,value.report.pools) then
      local valid=result.pools.ammo_revolver_regular==1
      for id,count in pairs(result.pools) do valid=valid and count==(id=='ammo_revolver_regular' and 1 or 0) end
      if valid then
       value.stage='sent-shot'
       TriggerServerEvent('feather-weapons:jane-economic:ack','shot',result)
      else fail(value,'not exactly one regular reduction') end
     elseif GetGameTimer()>value.deadline then fail(value,'shot timeout; committed load retained') end
    end
   end
  end
 end
end)
AddEventHandler('onResourceStop',function(name)
 if name==GetCurrentResourceName() and owner then
  print('[WeaponJaneEconomic] STOP while active: committed ammo/copy may remain; no blind cleanup/reset')
 end
end)
