-- Server-challenged, temporary native validation. No item/equipment/ammo writes.
WeaponGuidAcceptanceClient={}
local C=WeaponGuidAcceptanceClient
local active,used=nil,{}
local function yes(v) return v==true or v==1 end
local function same(a,b) return WeaponNativeAcceptanceView.Equal(a,b) end
local function ownerClosed()
 local owner=WeaponCharacterAmmoActiveOwner
 local s=owner and owner.Status();local r=s and s.bootstrap and s.bootstrap.runtime
 return s and s.ownedCopies==0 and s.cleanupComplete==true and r and r.phase=='closed'
  and not r.runtimeBusy and not r.receiving
end
RegisterNetEvent('feather-weapons:client:guid-suite-report-ack',function(ticket,kind,sequence)
 if source~=65535 or not active or active.ticket~=ticket then return end
 if active.awaiting and active.awaiting.kind==kind and active.awaiting.sequence==sequence then
  active.awaiting.accepted=true
  if kind=='result' and not active.sending and active.report and active.report.cleanupComplete==true then
   C.Delivery={ok=true,lateAcknowledgement=true,retries=active.deliveryRetries or 0};active=nil
  end
 end
end)
local function deliver(run,finalOnly)
 if run.sending or not run.report then return end
 run.sending=true
 local ok,why=pcall(function()
  if not run.reportPackets then run.reportPackets,run.reportSummary=WeaponGuidAcceptance.Packets(run.report,json.encode) end
  local packets,summary=run.reportPackets,run.reportSummary
  local started=GetGameTimer()
  local function send(kind,sequence,payload)
   local pending={kind=kind,sequence=sequence};run.awaiting=pending
   for attempt=1,3 do
    if attempt>1 then run.deliveryRetries=(run.deliveryRetries or 0)+1 end
    TriggerServerEvent('feather-weapons:server:guid-suite-'..kind,run.ticket,sequence,payload)
    local sent=GetGameTimer()
    while not pending.accepted and (GetGameTimer()-sent)%4294967296<1500 do
     assert((GetGameTimer()-started)%4294967296<180000,'report_delivery_deadline')
     local world=WeaponCharacterAmmoWorldContext.Read();world=world and world.ok and world.value
     assert(world and world.characterId==run.bound.characterId and world.sessionId==run.bound.sessionId,'report_session_changed')
     Wait(25)
    end
    if pending.accepted then run.awaiting=nil;return end
   end
   error('report_acknowledgement_timeout')
  end
  if not finalOnly then for index,packet in ipairs(packets) do send('chunk',index,packet) end end
  send('result',#packets+1,summary)
 end)
 run.sending=false
 C.Report=run.report -- retain results independently of successful delivery
 C.Delivery={ok=ok,reason=not ok and tostring(why) or nil,retries=run.deliveryRetries or 0}
 if ok and run.report.cleanupComplete==true or run.transportOnly then active=nil end
end
RegisterNetEvent('feather-weapons:client:guid-suite-resend',function(ticket,finalOnly)
 if source==65535 and active and active.ticket==ticket and active.report and not active.sending then
  local run=active;CreateThread(function() deliver(run,finalOnly==true) end)
 end
end)
RegisterNetEvent('feather-weapons:client:guid-suite-transport',function(ticket,bound,total)
 if source~=65535 or active or used[ticket] or type(ticket)~='string' or #ticket>128
  or not WeaponNativeAcceptanceView.Read(WeaponCharacterAmmoActiveOwner,bound) then return end
 local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
 local cases=registry and WeaponGuidAcceptance.Matrix(WeaponDefinitionCatalog,registry)
 if not cases or #cases~=total then return end
 used[ticket]=true
 local run={ticket=ticket,bound=bound,transportOnly=true}
 active=run
 CreateThread(function()
  local rows={}
  for index,case in ipairs(cases) do
   local row={id=case.id,phase='passed',cleanupComplete=true,synthetic=true,observations={}}
   for n,point in ipairs({2,3,9,10}) do
    local guid=string.format('%032x',index*4+n)
    row.observations[n]={item='synthetic-report-row',point=point,guid=guid,entity=index*4+n,
     wear={degradation=0.125,damage=0.1,permanentDegradation=0.1,dirt=0.25,soot=0.5},
     activation={point=point,expectedGuid=guid,outputGuid=guid,callCompleted=true,nativeReturn='synthetic'}}
   end
   rows[#rows+1]=row
  end
  run.report={phase='complete',cases=rows,passed=total,total=total,cleanupComplete=true,
   candidate='report_transport_only',coverage='synthetic packet load; no native calls'}
  deliver(run)
 end)
end)
RegisterNetEvent('feather-weapons:client:guid-suite-read',function(ticket,bound)
 if source~=65535 or active or type(ticket)~='string' or #ticket>128 then return end
 local view=WeaponNativeAcceptanceView.Read(WeaponCharacterAmmoActiveOwner,bound)
 TriggerServerEvent('feather-weapons:server:guid-suite-read',ticket,view)
end)
RegisterNetEvent('feather-weapons:client:guid-suite-cancel',function(ticket)
 if source==65535 and active and active.ticket==ticket then active.cancelled=true end
end)
RegisterNetEvent('feather-weapons:client:guid-suite-run',function(ticket,bound,expectedTotal)
 if source~=65535 or active or used[ticket] or type(ticket)~='string' or #ticket<1 or #ticket>128
  or type(bound)~='table' or not ownerClosed() then return end
 local world=WeaponCharacterAmmoWorldContext.Read()
 local value=world and world.ok and world.value
 if not value or value.characterId~=bound.characterId or value.sessionId~=bound.sessionId then return end
 used[ticket]=true
 active={ticket=ticket,bound=bound,ped=value.ped,started=GetGameTimer()}
 local run=active
 CreateThread(function()
  while active==run do
   DisablePlayerFiring(PlayerId(),true)
   for _,key in ipairs({0x07CE1E61,0xF84FA74F,0xCEE12B50,0xE30CD707}) do DisableControlAction(0,key,true) end
   Wait(0)
  end
 end)
 CreateThread(function()
  local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
  local native=registry and WeaponCharacterAmmoNative.New(registry.names,registry.limits)
  local baseline=native and native.Read(run.ped,true)
  local cases=registry and WeaponGuidAcceptance.Matrix(WeaponDefinitionCatalog,registry)
  local function worldCurrent()
   local v=WeaponCharacterAmmoWorldContext.Read();v=v and v.ok and v.value
   return active==run and ownerClosed() and v and v.characterId==bound.characterId and v.sessionId==bound.sessionId
    and v.ped==run.ped and PlayerPedId()==run.ped
  end
  local function modelsEmpty()
   for _,w in pairs(registry.weapons) do if yes(HasPedGotWeapon(run.ped,joaat(w.nativeWeaponName),false)) then return false end end
   return true
  end
  local report
  if not cases or #cases~=expectedTotal or not baseline or not worldCurrent() or not modelsEmpty() then
   report={phase='review_required',reason='released_world_or_empty_models_required',cleanupComplete=worldCurrent() and baseline~=nil and modelsEmpty(),passed=0,total=expectedTotal,cases={}}
  else
   report=WeaponGuidAcceptance.Run({case=function(case,index)
    local started=GetGameTimer();local cleaning=false;local dual
    local function current()
     return worldCurrent() and (cleaning or not run.cancelled and (GetGameTimer()-run.started)%4294967296<1800000
      and (GetGameTimer()-started)%4294967296<15000)
    end
    local identity={characterId=bound.characterId,sessionId=bound.sessionId,epoch='guid-suite:'..index..':'..run.started}
    local plan,why=WeaponGuidAcceptance.Plan(case,WeaponDefinitionCatalog,registry,identity)
    if not plan or not current() then return {ok=false,cleanupComplete=true,reason=why or 'suite_cancelled_or_context_changed'} end
    local original=json.encode(plan)
    local adapter,reason=WeaponCharacterAmmoCreationNative.Scoped(run.ped,identity,function()
     if not current() then return false end
     if not dual then dual=WeaponCharacterAmmoDualNative.New(run.ped,current) end
     return dual.Ensure()==true
    end,function() return not dual or dual.Cleanup()==true end,current)
    if not adapter then return {ok=false,cleanupComplete=true,reason=reason} end
    local executor=WeaponCharacterAmmoLoadout.New(adapter)
    local made,failure,partial=executor.Create(plan)
    local records=made and made.handles or partial and partial.handles or {}
    local observations=not made and adapter.creationFailureEvidence and adapter.creationFailureEvidence() or {};local passed=made~=nil
    if made then
     local checked,detail=pcall(function()
      local guids,entities={},{}
      for i,record in ipairs(records) do
       assert(current(),'case_lifecycle_or_deadline_changed')
       local raw=string.rep('\0',104)
       assert(yes(Citizen.InvokeNative(0x6929E22158E52265,run.ped,record.point,raw)),'point_guid_unreadable')
       local key=WeaponCharacterAmmoCreationNative.GuidKey(raw)
       assert(key and key==WeaponCharacterAmmoCreationNative.GuidKey(record.guid) and not guids[key],'point_guid_mismatch_or_duplicate')
       assert(not entities[record.entity],'duplicate_entity')
       guids[key]=true;entities[record.entity]=true
       local read,why=adapter.readMaintenance(record,identity);assert(read,why)
       local expected=plan.items[i].maintenance
       for field,n in pairs(expected) do assert(type(read[field])=='number' and math.abs(read[field]-n)<=0.000001,'wear_mismatch:'..field) end
       observations[#observations+1]={item=plan.items[i].definitionId,point=record.point,guid=key,entity=record.entity,wear=read,activation=record.guidActivationEvidence}
      end
      assert(json.encode(plan)==original,'temporary_plan_mutated')
      assert(same(native.Read(run.ped,true),baseline),'ammunition_changed_during_creation')
     end)
     if not checked then passed=false;failure=tostring(detail) end
    end
    cleaning=true -- deadlines/cancel never suppress exact same-context compensation
    local retained={}
    for i=#records,1,-1 do
     local ok,removed=pcall(adapter.remove,records[i])
     if not ok or removed~=true then retained[#retained+1]=records[i] end
    end
    local clean=#retained==0
    if clean then
     local attempted=adapter.creationAttemptHandles and adapter.creationAttemptHandles() or records
     for _,record in ipairs(attempted) do
      local raw=string.rep('\0',72)..string.pack('<I4I4',joaat('SLOTID_NONE') & 0xffffffff,0)..string.rep('\0',96)
      local ok,found=pcall(Citizen.InvokeNative,0x025A1B1FB03FBF61,1,record.guid,raw,22,1)
      if not ok or (found~=false and found~=0) then clean=false;failure='removed_guid_absence_unconfirmed' end
     end
    end
    if clean then local ok,result=pcall(adapter.cleanupSetup);clean=ok and result==true end
    if clean then
     Wait(0)
     clean=worldCurrent() and modelsEmpty() and same(native.Read(run.ped,true),baseline)
    end
    return {ok=passed and clean,cleanupComplete=clean,reason=failure or (not clean and 'case_cleanup_or_ammo_mismatch' or nil),
     retained=#retained,observations=observations}
   end,progress=function(index,total,id)
    if index%10==0 then TriggerServerEvent('feather-weapons:server:guid-suite-progress',ticket,index,total,id) end
    Wait(0)
   end},cases)
  end
  run.report=report
  deliver(run) -- unacknowledged delivery retains evidence/input, never repeats creation
 end)
end)

-- Temporary fixture only. The normal runtime remains blocked unless this exact
-- released-owner reservation is currently waiting for its single throw.
function C.AllowTemporaryFiring()
 local r=active
 return r~=nil and r.throwable==true and (r.stage=='awaiting_throw' or r.competing and r.stage=='awaiting_pickup') and not r.cancelled
  and (GetGameTimer()-r.started)%4294967296<(r.shared and 180000 or 90000) and r.current() == true
  and (GetPedAmmoByType(r.ped,joaat('AMMO_TOMAHAWK'))==1 or r.competing and GetPedAmmoByType(r.ped,joaat('AMMO_TOMAHAWK'))==2)
end
RegisterNetEvent('feather-weapons:client:guid-suite-throwable',function(ticket,bound,total,mode)
 if Config and Config.NativeThrowableQuantityOnly==true then return end
 if source~=65535 or active or used[ticket] or type(ticket)~='string' or #ticket<1 or #ticket>128
  or type(bound)~='table' or total~=1 or (mode~=nil and mode~='landing' and mode~='shared' and mode~='shared-competing') or not ownerClosed() then return end
 local w=WeaponCharacterAmmoWorldContext.Read();w=w and w.ok and w.value
 if not w or w.characterId~=bound.characterId or w.sessionId~=bound.sessionId then return end
 used[ticket]=true
 local r={ticket=ticket,bound=bound,ped=w.ped,started=GetGameTimer(),throwable=true,shared=mode=='shared' or mode=='shared-competing',competing=mode=='shared-competing',landing=mode=='landing',stage='preflight'}
 active=r
 local function current()
  local v=WeaponCharacterAmmoWorldContext.Read();v=v and v.ok and v.value
  return active==r and ownerClosed() and v~=nil and v.characterId==bound.characterId
   and v.sessionId==bound.sessionId and v.ped==r.ped and PlayerPedId()==r.ped
   and yes(DoesEntityExist(r.ped)) and not yes(IsEntityDead(r.ped))
 end
 r.current=current
 CreateThread(function()
  local started=false
  local ok,result=pcall(function()
   local base=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
   local limits={};for k,v in pairs(base.limits) do limits[k]=v end;limits.ammo_tomahawk_regular=3
   local registry=assert(WeaponNativeThrowablePolicy.RegistryFromLimits(WeaponDefinitionCatalog,limits))
   local native=assert(WeaponCharacterAmmoNative.New(registry.names,registry.limits))
   local identity={characterId=bound.characterId,sessionId=bound.sessionId,epoch='native-loan:'..ticket}
   local function readWorld()
    if not current() then return nil end
    return {characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,ped=r.ped}
   end
   if mode=='landing' then
    local function landingWorld()
     local value=readWorld();if not value then return nil end
     local position=GetEntityCoords(r.ped)
     value.alive=true;value.revision=1;value.position={x=position.x,y=position.y,z=position.z};return value
    end
    return WeaponNativeThrowableLandingLoanTest.Run({now=GetGameTimer,wait=Wait,current=current,
     diagnostic=function(row) print('[WeaponNativeLandingProbe] '..json.encode(row)) end,
     transitionEvidence=function(landing)
      return WeaponNativeThrowableLandingAdapter.Survey(landing,current,Wait,GetGameTimer,function(object)
       if object.kind=='closest_at_landing' and object.exists==true and type(object.networkId)=='number'
        and object.networkId>0 and current() then
        -- Hint requests a server native read, never a pickup grant or adoption.
        TriggerServerEvent('feather-weapons:server:guid-suite-object-hint',ticket,object.networkId,object.model)
       end
      end)
     end,
     cancelled=function() return r.cancelled==true end,
     pools=function() return native.Read(r.ped,true) end,
     quantity=function() return GetPedAmmoByType(r.ped,joaat('AMMO_TOMAHAWK')) end,
     permissions=function()
      local prior=Config.NativeThrowablePickupPriorPolicy
      if not prior then
       -- Older test configurations have no declared model policy. Require an
       -- explicit operator baseline; never pretend there is a native getter.
       local allowed=GetConvarInt('feather_native_landing_prior_pickups',-1)
       assert(allowed==0 or allowed==1,'landing_probe_prior_pickup_policy_required')
       prior={w_melee_tomahawk01=allowed==1,w_melee_tomahawk02=allowed==1}
      end
      return WeaponNativeThrowablePickupPermissions.New(function(model,allowed)
       SetLocalPlayerPermittedToCollectPickupsWithModel(joaat(model),allowed)
      end,prior)
     end,
     stage=function(stage)
      r.stage=stage
      if stage=='awaiting_throw' then print('[WeaponGuidAcceptance] Landing probe ready: throw ONCE into nearby clear ground. Do not collect it; wait for automatic cleanup and restore.') end
     end,
     owner=function(sealed) return WeaponNativeThrowableAdapter.Scoped(r.ped,identity,current,sealed,WeaponDefinitionCatalog,registry) end,
     placement=function()
      local controller
      controller=WeaponNativeThrowablePlacementClient.New({world=landingWorld,now=GetGameTimer,
       quantity=function() return GetPedAmmoByType(r.ped,joaat('AMMO_TOMAHAWK')) end,
       probe=function(value)
        local found,_,entity=GetProjectileOfProjectileTypeWithinDistance(value.ped,joaat('WEAPON_THROWN_TOMAHAWK'),50.0,false,true)
        if not yes(found) then return nil end
        assert(type(entity)=='number' and entity>0 and yes(DoesEntityExist(entity)),'loan_projectile_unreadable')
        local networked=yes(NetworkGetEntityIsNetworked(entity))
        return {entity=entity,model=GetEntityModel(entity)&0xffffffff,networked=networked,
         networkId=networked and NetworkGetNetworkIdFromEntity(entity) or nil}
       end,
       newLanding=function(authorize,fresh) return WeaponNativeThrowableLandingAdapter.New(landingWorld,authorize,fresh) end,
       send=function(action,request)
        assert(current() and request.id=='landing-loan','loan_context_changed')
        TriggerServerEvent('feather-weapons:server:guid-suite-landing-action',ticket,action,request)
       end})
      r.landingClient=controller
      return controller
     end},identity,registry)
   end
   if WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.UnitsEnabled and WeaponNativeThrowablePolicy.UnitsEnabled() then
    assert(WeaponNativeThrowablePickupClient and WeaponNativeThrowablePickupClient.BeginNativeLoan(),
     'loan_pickup_policy_release_unconfirmed')
    r.nativePickupPaused=true
   end
   assert(WeaponNativeThrowableEventProbe.StartReleased(identity,readWorld,function() end,function(object,kind)
    if current() and (r.stage=='awaiting_pickup' or kind=='collection_event' and r.stage=='settling_events') then
     if kind=='owned_projectile' or kind=='collection_candidate' or kind=='collection_event' then
      TriggerServerEvent('feather-weapons:server:guid-suite-collection-hint',ticket,kind,object)
     end
     if kind~='collection_event' then TriggerServerEvent('feather-weapons:server:guid-suite-object-hint',ticket,object.networkId,object.model) end
    end
   end,r.shared and 180000 or nil),'loan_event_probe_unavailable')
   started=true
   return WeaponNativeThrowableLoanTest.Run({now=GetGameTimer,wait=Wait,current=current,durationMs=r.shared and 180000 or nil,
    serialNumber=r.shared and 'ISOLATED-SHARED-LOAN' or nil,
    unitCount=r.competing and 2 or 1,remoteCollected=r.shared and function() return r.sharedCollected==true end or nil,
    cancelled=function() return r.cancelled==true end,
    pools=function() return native.Read(r.ped,true) end,
    quantity=function() return GetPedAmmoByType(r.ped,joaat('AMMO_TOMAHAWK')) end,
    events=WeaponNativeThrowableEventProbe.Records,
    stage=function(stage)
     r.stage=stage
     WeaponNativeThrowableEventProbe.LoanStage(stage)
     if stage=='awaiting_throw' then
      print(r.competing and '[WeaponGuidAcceptance] Competing probe: throw TWO units onto nearby clear ground. Collector stays behind you until both land, then collects BOTH.' or mode=='shared' and '[WeaponGuidAcceptance] Shared Tomahawk ready: throw ONCE onto clear ground; only the designated other player should collect it.' or '[WeaponGuidAcceptance] Temporary Tomahawk ready: draw it, throw ONCE, then collect that same unit within 90 seconds.')
     end
    end,
    owner=function(sealed)
     return WeaponNativeThrowableAdapter.Scoped(r.ped,identity,current,sealed,WeaponDefinitionCatalog,registry)
    end},identity,registry)
  end)
  if started then WeaponNativeThrowableEventProbe.Stop() end
  r.stage='reporting'
  r.report=ok and result or {phase='review_required',reason=tostring(result),passed=0,total=1,
   cleanupComplete=not started and current(),cases={}}
  if r.nativePickupPaused and r.report.cleanupComplete==true then WeaponNativeThrowablePickupClient.EndNativeLoan() end
  deliver(r) -- retransmit evidence only, never replay the temporary native unit
 end)
end)
RegisterNetEvent('feather-weapons:client:guid-suite-shared-collected',function(ticket)
 if source==65535 and active and active.throwable and active.ticket==ticket then active.sharedCollected=true end
end)
RegisterNetEvent('feather-weapons:client:guid-suite-shared-ack',function(ticket)
 if source==65535 and active and active.sharedCollector and active.ticket==ticket then
  active.sharedAck=true
  if not active.sharedSending and active.sharedReport and active.sharedReport.cleanupComplete then active=nil end
 end
end)
RegisterNetEvent('feather-weapons:client:guid-suite-shared-collector',function(ticket,bound,origin,unitCount)
 if Config and Config.NativeThrowableQuantityOnly==true then return end
 if source~=65535 or active or used[ticket] or type(ticket)~='string' or #ticket<1 or #ticket>128
  or (unitCount~=nil and unitCount~=2) or type(bound)~='table' or type(origin)~='table' or not ownerClosed() then return end
 for _,key in ipairs({'characterId','sessionId','epoch'}) do if type(origin[key])~='string' or #origin[key]<1 or #origin[key]>128 then return end end
 local world=WeaponCharacterAmmoWorldContext.Read();world=world and world.ok and world.value
 if not world or world.characterId~=bound.characterId or world.sessionId~=bound.sessionId then return end
 used[ticket]=true
 local r={ticket=ticket,bound=bound,ped=world.ped,sharedCollector=true,started=GetGameTimer()};active=r
 local identity={characterId=bound.characterId,sessionId=bound.sessionId,epoch='native-loan:'..ticket..':collector'}
 local function current()
  local w=WeaponCharacterAmmoWorldContext.Read();w=w and w.ok and w.value
  return active==r and ownerClosed() and w and w.characterId==bound.characterId and w.sessionId==bound.sessionId
   and w.ped==r.ped and PlayerPedId()==r.ped and yes(DoesEntityExist(r.ped)) and not yes(IsEntityDead(r.ped))
 end
 CreateThread(function()
  local paused,started=false,false
  local ok,row=pcall(function()
   local base=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog));local limits={}
   for k,v in pairs(base.limits) do limits[k]=v end;limits.ammo_tomahawk_regular=3
   local registry=assert(WeaponNativeThrowablePolicy.RegistryFromLimits(WeaponDefinitionCatalog,limits))
   local native=assert(WeaponCharacterAmmoNative.New(registry.names,registry.limits))
   assert(WeaponNativeThrowablePickupClient.BeginNativeLoan(),'collector_pickup_policy_release_unconfirmed');paused=true
   local function readWorld() if current() then return {characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,ped=r.ped} end end
   assert(WeaponNativeThrowableEventProbe.StartReleased(identity,readWorld,function() end,function(event,kind)
    if current() and kind=='collection_event' then TriggerServerEvent('feather-weapons:server:guid-suite-collection-hint',ticket,kind,event) end
   end,180000),'collector_event_probe_unavailable');started=true
   WeaponNativeThrowableEventProbe.LoanStage('awaiting_pickup')
   return WeaponNativeThrowableCollectorLoanTest.Run({unitCount=unitCount,now=GetGameTimer,wait=Wait,current=current,
    cancelled=function() return r.cancelled==true end,
    pools=function() return native.Read(r.ped,true) end,
    quantity=function() return GetPedAmmoByType(r.ped,joaat('AMMO_TOMAHAWK')) end,
    present=function() return yes(HasPedGotWeapon(r.ped,joaat('WEAPON_THROWN_TOMAHAWK'),false)) end,
    events=WeaponNativeThrowableEventProbe.Records,
    owner=function(sealed) return WeaponNativeThrowableAdapter.Scoped(r.ped,identity,current,sealed,WeaponDefinitionCatalog,registry) end,
    ready=function()
     print(unitCount==2 and '[WeaponGuidAcceptance] Competing collector: wait for BOTH ground throws, then collect BOTH. No paid items are awarded.' or '[WeaponGuidAcceptance] Collector ready: wait for the designated player to throw, then collect that Tomahawk. Do not buy, equip or throw another unit.')
     TriggerServerEvent('feather-weapons:server:guid-suite-shared-ready',ticket)
    end},identity,origin,registry)
  end)
  if started then WeaponNativeThrowableEventProbe.Stop() end
  row=ok and row or {phase='failed',cleanupComplete=false,reason=tostring(row),syntheticNativeOnly=true,economicWrites=0}
  r.sharedReport=row;C.SharedReport=row
  if paused and row.cleanupComplete then WeaponNativeThrowablePickupClient.EndNativeLoan() end
  local raw=json.encode(row)
  r.sharedSending=true
  if #raw<=6000 then for attempt=1,3 do
   TriggerServerEvent('feather-weapons:server:guid-suite-shared-result',ticket,raw)
   local sent=GetGameTimer()
   while not r.sharedAck and (GetGameTimer()-sent)%4294967296<1500 do Wait(25) end
   if r.sharedAck then break end
  end end
  r.sharedSending=false
  print('[WeaponGuidAcceptanceSharedCollector] '..raw)
  if r.sharedAck and row.cleanupComplete then active=nil end
 end)
end)
RegisterNetEvent('feather-weapons:client:guid-suite-landing-result',function(ticket,action,id,result)
 local r=active
 if source~=65535 or not r or not r.landing or ticket~=r.ticket or not r.landingClient or not r.current() then return end
 r.landingClient.Result(action,id,result)
end)
