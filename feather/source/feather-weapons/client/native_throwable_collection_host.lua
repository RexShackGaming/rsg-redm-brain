WeaponNativeThrowableCollectionClientHost={}
local H=WeaponNativeThrowableCollectionClientHost
local permissions,client,record,captureEpoch,projectile,pickup,challenge,failed
local stopped=false
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
function H.Enabled() return Config.NativeThrowableNativeCollectionContract==1 and GetConvarInt('feather_native_paid_collection',0)==1 end
local function runtimeState()
 local status=WeaponCharacterAmmoActiveOwner and WeaponCharacterAmmoActiveOwner.Status()
 return status and status.bootstrap and status.bootstrap.runtime
end
local function snapshot()
 local r=runtimeState();return r and r.session and r.session.ammo and r.session.ammo.baseline
end
local function world()
 local b=snapshot();if not b then return nil end
 local ped=PlayerPedId();local live=WeaponCharacterAmmoWorldContext.Read()
 if not live or not live.ok or not live.value or live.value.characterId~=b.characterId or live.value.sessionId~=b.sessionId then return nil end
 return {characterId=b.characterId,sessionId=b.sessionId,epoch=b.epoch,ped=ped,
  alive=live and live.ok==true and IsEntityDead(ped)~=true and IsEntityDead(ped)~=1,bucket=record and record.bucket or 0}
end
local function fail(reason)
 failed=reason
 if permissions then permissions.Suppress() end
 print('[WeaponNativeCollectionTest] CLIENT REVIEW '..tostring(reason))
end
local function pools()
 local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
 return assert(WeaponCharacterAmmoNative.New(registry.names,registry.limits)).Read(PlayerPedId(),true)
end
local function sendHint()
 if record and record.donor and projectile and pickup and challenge and not record.sent then
  if pickup.networkId==projectile then return end
  record.sent=true
  TriggerServerEvent('feather-weapons:server:native-collection-hint',{challengeId=challenge.id,
   projectileId=projectile,pickupId=pickup.networkId,position=pickup.position})
 end
end
function H.Ready() return H.Enabled() and permissions and permissions.Status().active and not failed and not stopped or false end
function H.ReadEscrow(ticket) return client and client.ReadEscrow(ticket) or {phase='pending'} end
function H.BeforeStep(runtime)
 if not H.Enabled() then return true end
 if failed then return false end
 return not client or client.BeforeStep(runtime)
end
RegisterNetEvent('feather-weapons:client:native-collection-start',function(packet)
 if source~=65535 or not H.Ready() or record or type(packet)~='table' or type(packet.identity)~='table' then return end
 local w=world()
 if not w or w.characterId~=packet.identity.characterId or w.sessionId~=packet.identity.sessionId then return end
 record={identity=copy(packet.identity),bucket=packet.bucket,donor=packet.donor==true}
 client=WeaponNativeThrowableCollectionClient.New({world=world,snapshot=snapshot,pools=pools,now=GetGameTimer,
  send=function(action,payload) TriggerServerEvent('feather-weapons:server:native-collection',action,payload) end,
  suspend=function(reason) fail(reason) end,
  escrow=function(identity,runtime)
   assert(permissions.Suppress(),'native_collection_permission_suppression_failed')
   local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
   return assert(WeaponNativeThrowableAdapter.ScopedCollection(PlayerPedId(),identity,function(check)
    local w=world();local status=runtime.Status()
    return w and w.alive and w.characterId==check.characterId and w.sessionId==check.sessionId
     and w.epoch==check.epoch and status.collectionHold and status.collectionHold.phase=='holding'
   end,world,WeaponDefinitionCatalog,registry))
  end})
end)
RegisterNetEvent('feather-weapons:client:throwable-spend-challenge',function(packet)
 if source~=65535 or not H.Enabled() or not record or not record.donor or challenge or type(packet)~='table' then return end
 local w=world()
 if not w or not packet.identity or packet.identity.epoch~=w.epoch or packet.identity.sessionId~=w.sessionId
  or packet.identity.characterId~=w.characterId or type(packet.units)~='table' or #packet.units~=1 then return fail('paid_challenge_scope_changed') end
 challenge=copy(packet);sendHint()
end)
RegisterNetEvent('feather-weapons:client:native-collection',function(action,packet)
 if source~=65535 or not H.Ready() or not client then return end
 if action=='arm' then
  if client.Arm(packet,true) then assert(permissions.Allow(),'native_collection_permission_allow_failed');print('[WeaponNativeCollectionTest] ARMED: walk over the Tomahawk now.') end
 elseif action=='escrow' then client.Escrow(packet,true)
 elseif action=='result' then
  local accepted=client.Result(packet,true)
  if accepted and packet and packet.result and packet.result.phase=='complete' then permissions.Suppress();print('[WeaponNativeCollectionTest] COMPLETE: canonical paid unit recovered; test unequip and reconnect next.') end
 end
end)
CreateThread(function()
 while not stopped do
  if H.Enabled() then
   if not permissions then
    permissions=WeaponNativeThrowablePickupPermissions.New(function(model,allowed)
     SetLocalPlayerPermittedToCollectPickupsWithModel(joaat(model),allowed)
    end,Config.NativeThrowablePickupPriorPolicy)
    if not permissions.Suppress() then fail('native_collection_permission_start_failed') end
   end
   local w=world()
   if record and w and w.alive and not failed and (not captureEpoch or captureEpoch~=w.epoch) then
    if captureEpoch then WeaponNativeThrowableEventProbe.Stop() end
    captureEpoch=w.epoch;projectile,pickup=nil,nil
    local identity=copy(w)
    local started=WeaponNativeThrowableEventProbe.StartReleased(identity,function()
     local now=world();if now and now.alive and now.epoch==identity.epoch then return now end
    end,function() end,function(value,kind)
     if kind=='owned_projectile' and record.donor then projectile=value.networkId;sendHint()
     elseif kind=='collection_candidate' and record.donor and value.networkId~=projectile then pickup=copy(value);sendHint()
     elseif kind=='collection_event' and not record.donor and client then client.Event(value) end
    end,180000)
    if not started then fail('native_collection_event_capture_unavailable') else WeaponNativeThrowableEventProbe.LoanStage('awaiting_pickup') end
   end
  elseif permissions then permissions.Restore();permissions=nil end
  Wait(50)
 end
end)
RegisterCommand('weaponNativeCollectionStatus',function()
 print('[WeaponNativeCollectionTest] '..json.encode({enabled=H.Enabled(),ready=H.Ready(),failure=failed,client=client and client.Status(),donor=record and record.donor}))
end,false)
AddEventHandler('onResourceStop',function(resource)
 if resource~=GetCurrentResourceName() then return end
 stopped=true;if captureEpoch then WeaponNativeThrowableEventProbe.Stop() end
 if permissions then permissions.Restore() end
end)
