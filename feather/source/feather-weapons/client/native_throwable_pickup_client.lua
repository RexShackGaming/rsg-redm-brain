-- Normal client recovery host. Contract admission stays disabled until the
-- confirmed-spend/landing handshake is included in the combined deployment.
WeaponNativeThrowablePickupClient={}
local S=WeaponNativeThrowablePickupClient
local life,permissions,transport,lastScope,latest,stopped,failed=nil,nil,nil,nil,nil,false,false
local placement
local nativeLoan=false
local function enabled() return not nativeLoan and not (Config.NativeThrowableNativeCollectionContract==1 and GetConvarInt('feather_native_paid_collection',0)==1)
 and Config.NativeThrowablePickupContract==1 and WeaponNativeThrowablePolicy.UnitsEnabled() end
local function same(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function yes(v) return v==true or v==1 end
local function world()
 local context=WeaponCharacterAmmoWorldContext and WeaponCharacterAmmoWorldContext.Identity()
 if not context then return nil end
 local status=WeaponCharacterAmmoActiveOwner and WeaponCharacterAmmoActiveOwner.Status()
 local runtime=status and status.bootstrap and status.bootstrap.runtime
 local ammo=runtime and runtime.session and runtime.session.ammo
 local baseline=ammo and ammo.baseline
 local epoch=baseline and baseline.characterId==context.characterId and baseline.sessionId==context.sessionId and baseline.epoch
 if not epoch and lastScope and context.characterId==lastScope.characterId and context.sessionId==lastScope.sessionId then epoch=lastScope.epoch end
 if type(epoch)~='string' then return nil end
 local ped=PlayerPedId();if not yes(DoesEntityExist(ped)) then return nil end
 local position=GetEntityCoords(ped)
 local alive=WeaponCharacterAmmoWorldContext.Read()
 return {characterId=context.characterId,sessionId=context.sessionId,epoch=epoch,ped=ped,revision=baseline and baseline.revision,
  alive=alive and alive.ok==true and not yes(IsEntityDead(ped)),
  busy=not runtime or runtime.phase~='active' or runtime.runtimeBusy or runtime.receiving or runtime.quiescing
   or not ammo or ammo.pending or ammo.closing,
  observationBusy=not runtime or runtime.phase~='active' or runtime.runtimeBusy or runtime.receiving or runtime.quiescing
   or not ammo or ammo.closing,
  bucket=latest and same(latest.identity,{characterId=context.characterId,sessionId=context.sessionId,epoch=epoch}) and latest.bucket or 0,
  position={x=position.x,y=position.y,z=position.z}}
end
local function cleanup()
 local clean=true
 if life then local ok,result=pcall(life.Stop);clean=ok and result==true; if clean then life=nil end end
 if permissions then local ok,result=pcall(permissions.Restore);clean=clean and ok and result==true; if ok and result then permissions=nil end end
 return clean
end
-- Called only by the server-challenged isolated fixture after normal owner
-- release. Keep the durable units registry enabled; pause interaction instead.
function S.BeginNativeLoan()
 local status=WeaponCharacterAmmoActiveOwner and WeaponCharacterAmmoActiveOwner.Status()
 local runtime=status and status.bootstrap and status.bootstrap.runtime
 if nativeLoan or failed or stopped or not runtime or runtime.phase~='closed'
  or status.ownedCopies~=0 or status.cleanupComplete~=true then return false end
 nativeLoan=true
 if not cleanup() then failed=true;return false end
 placement,lastScope,latest=nil,nil,nil
 return true
end
function S.EndNativeLoan() nativeLoan=false end
function S.Ready() return enabled() and not stopped and not failed and permissions and permissions.Status().active==true
 and placement and placement.Ready() or false end
function S.Status()
 return {enabled=enabled(),ready=S.Ready(),failed=failed,stopped=stopped,
  permissions=permissions and permissions.Status() or nil,
  placement=placement and placement.Status() or nil,lifecycle=life and life.Status() or nil}
end
RegisterCommand('weaponThrowableStatus',function() print('[WeaponThrowableStatus] '..json.encode(S.Status())) end,false)
RegisterNetEvent('feather-weapons:client:throwable-spend-challenge',function(packet)
 if source~=65535 or not enabled() or stopped or failed or not placement then return end
 local ok,accepted=pcall(placement.Challenge,packet)
 if not ok or not accepted then failed=true;print('[feather-weapons] throwable challenge association unconfirmed; retained for review') end
end)
RegisterNetEvent('feather-weapons:client:throwable-placement-result',function(action,id,result)
 if source~=65535 or not enabled() or stopped or failed or not placement then return end
 local ok=pcall(placement.Result,action,id,result)
 if not ok then failed=true end
end)
CreateThread(function()
 while not stopped do
  if enabled() and not failed and permissions and permissions.Status().active then
   local ok=pcall(function()
    if not placement then
     placement=WeaponNativeThrowablePlacementClient.New({world=world,now=function() return GetGameTimer()%4294967296 end,
      quantity=function() return GetPedAmmoByType(PlayerPedId(),joaat('AMMO_TOMAHAWK')) end,
      probe=function(identity)
       local found,_,entity=GetProjectileOfProjectileTypeWithinDistance(identity.ped,joaat('WEAPON_THROWN_TOMAHAWK'),50.0,false,true)
       if not yes(found) then return nil end
       assert(type(entity)=='number' and entity>0 and yes(DoesEntityExist(entity)),'projectile_read_unavailable')
       local model=GetEntityModel(entity)&0xffffffff
       assert(model==(joaat('w_melee_tomahawk01')&0xffffffff) or model==(joaat('w_melee_tomahawk02')&0xffffffff),'projectile_model_changed')
       local networked=yes(NetworkGetEntityIsNetworked(entity))
       return {entity=entity,model=model,networked=networked,networkId=networked and NetworkGetNetworkIdFromEntity(entity) or nil}
      end,
      newLanding=function(authorize,fresh) return WeaponNativeThrowableLandingAdapter.New(world,authorize,fresh) end,
      send=function(action,request) TriggerServerEvent('feather-weapons:server:throwable-placement-request',action,request) end})
    end
    placement.Tick()
    local result=placement.Status()
    if result.phase=='review_required' then error('throwable_placement_review_required') end
    if result.phase=='complete' then assert(placement.AcknowledgeCompletion(result.id),'throwable_completion_ack_failed') end
   end)
   if not ok then failed=true;print('[feather-weapons] throwable placement retained for review; no automatic replay') end
  end
  Wait(enabled() and 50 or 750)
 end
end)
RegisterNetEvent('feather-weapons:client:throwable-pickup-offers',function(snapshot)
 if source~=65535 or not enabled() or stopped or type(snapshot)~='table' or type(snapshot.identity)~='table'
  or type(snapshot.pickups)~='table' or #snapshot.pickups>64 or type(snapshot.sequence)~='number'
  or snapshot.sequence<0 or snapshot.sequence%1~=0 or snapshot.sequence==math.huge
  or type(snapshot.bucket)~='number' or snapshot.bucket<0 or snapshot.bucket%1~=0 or snapshot.bucket==math.huge then return end
 local current=world()
 if not same(current,snapshot.identity) then return end
 if latest and same(latest.identity,snapshot.identity) and snapshot.sequence<=latest.sequence then return end
 latest=snapshot
 if life then life.Snapshot(snapshot.identity,snapshot.sequence,snapshot.pickups) end
end)
CreateThread(function()
 local lastOffer
 while not stopped do
  local delay=750
  if not enabled() and not failed then
   if not cleanup() then failed=true end
  elseif not failed then
   local ok=pcall(function()
    if not transport then transport=WeaponNativeThrowablePickupClientTransport.Install(world) end
    if not permissions then
     permissions=WeaponNativeThrowablePickupPermissions.New(function(model,allowed)
      SetLocalPlayerPermittedToCollectPickupsWithModel(joaat(model),allowed)
     end,Config.NativeThrowablePickupPriorPolicy)
     assert(permissions.Suppress(),'pickup_suppression_failed')
    end
    local current=world()
    if current and current.alive and not current.busy and not life then
     lastScope={characterId=current.characterId,sessionId=current.sessionId,epoch=current.epoch}
     life=WeaponNativeThrowablePickupLifecycle.New({world=world,now=function() return GetGameTimer()%4294967296 end,
      claim=function(request) return transport.Call('claim',request) end,
      readClaim=function(request) return transport.Call('status',request,request.identity) end,
      visuals=WeaponNativeThrowablePickupVisualAdapter.New,prompt=WeaponNativeThrowablePickupPromptAdapter.New,
      -- The resource owns suppression across native epoch changes. Each client
      -- lifecycle borrows it; actual restoration belongs to resource cleanup.
      permissions=function() return {Suppress=function() return permissions.Status().active end,Restore=function() return true end} end})
     assert(life.Start(),'pickup_lifecycle_start_failed')
     if latest and same(latest.identity,current) then life.Snapshot(current,latest.sequence,latest.pickups) end
    end
    if life then
     delay=life.Tick()
     local phase=life.Status().phase
     if phase=='cleanup_required' then error('pickup_cleanup_required') end
     if phase=='closed' then life=nil end
    end
    local now=GetGameTimer()%4294967296
    if current and not current.busy and (not lastOffer or (now-lastOffer)%4294967296>=5000) then
     lastOffer=now
     CreateThread(function() transport.Call('offers',{}) end)
    end
   end)
   if not ok then failed=true;cleanup();print('[feather-weapons] pickup lifecycle retained for review; no automatic claim replay') end
  end
  Wait(delay)
 end
end)
AddEventHandler('feather-core:locale:changed',function() if life then life.LanguageChanged() end end)
AddEventHandler('onResourceStop',function(resource)
 if resource~=GetCurrentResourceName() then return end
 stopped=true;if transport then transport.Stop() end
 if not cleanup() then print('[feather-weapons] pickup cleanup unconfirmed') end
end)
