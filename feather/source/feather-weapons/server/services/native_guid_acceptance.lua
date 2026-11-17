-- Console-only opt-in native validation; client reports are diagnostic evidence.
WeaponGuidAcceptanceServer={}
local S=WeaponGuidAcceptanceServer
local flag='feather_native_guid_suite'
local file='native-guid-acceptance-report.json'
local resource=GetCurrentResourceName()
SetConvar(flag,'0') -- a restart must never inherit an armed test
local run,report,reading,lastFinal
local serial=0
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function same(a,b) return WeaponNativeAcceptanceView.Equal(a,b) end
local function current(r)
 return run==r and GetConvarInt(flag,0)==1 and CoreAdapter.IsSessionCurrent(r.target,r.bound.sessionId,r.bound.characterId)
  and (not r.shared or CoreAdapter.IsSessionCurrent(r.shared.target,r.shared.bound.sessionId,r.shared.bound.characterId))
end
local function save()
 if not report then return end
 local raw=json.encode(report)
 assert(#raw<4194304 and SaveResourceFile(resource,file,raw,#raw)~=false,'guid_report_write_failed')
 assert(LoadResourceFile(resource,file)==raw,'guid_report_readback_failed')
end
local function summary()
 print('[WeaponGuidAcceptance] '..json.encode(report and {phase=report.phase,reason=report.reason,
  passed=report.passed,total=report.total,kind=report.kind,failedCase=report.failedCase,cleanupComplete=report.cleanupComplete,
  transition=report.transition,
  collection=report.collection,
  lifecycle=report.lifecycle,
  acceptanceScope=report.acceptanceScope,
  sharedCollector=report.sharedCollector,
  world=report.world and {phase=report.world.phase,counters=report.world.counters,rejected=report.world.rejected,matchCount=#report.world.matches,removedMatchCount=report.world.removedMatchCount,recordCount=#report.world.records,readFailures=report.world.readFailures,originConfirmed=false},
  restored=report.restored,collectorRestored=report.collectorRestored,visual=report.visual,recovery=report.recovery and report.recovery.phase,reportFile=file,automaticRetries=0,automaticMutationRetries=0,receivedCases=report.receivedCases,reportDeliveryRetries=report.reportDeliveryRetries} or {phase='idle'}))
end
local raw=LoadResourceFile(resource,file)
if raw then
 local ok,value=pcall(json.decode,raw)
 if ok and type(value)=='table' then report=value else report={phase='review_required',reason='saved_report_unreadable'} end
 if report.phase=='running' or report.phase=='preflight' or report.phase=='restoring' or report.phase=='checking_transport' then
  report.phase='review_required';report.reason='interrupted_run_no_automatic_resume'
 end
end
local function audit(r,target)
 local actor=r.shared and target==r.shared.target and r.shared.actor or r.actor
 local read=exports['feather-inventory']:ReadNativeAcceptanceAudit({actor})
 assert(read and read.ok and read.value and read.value[1],'guid_durable_audit_unavailable')
 return read.value[1]
end
RegisterNetEvent('feather-weapons:server:guid-suite-read',function(ticket,view)
 if not reading or source~=reading.target or ticket~=reading.ticket or not current(reading.run) then return end
 local clean=WeaponNativeAcceptanceView.Normalize(view)
 if clean and same(clean.identity,reading.bound) then reading.value=clean end
end)
local function capture(r,target)
 target=target or r.target
 assert(current(r),'guid_session_changed')
 local state=WeaponCharacterAmmoDispatcher.Status(target)
 assert(state and state.phase=='active' and not state.busy and state.identity,'guid_active_owner_required')
 local bound=state.identity
 local durable=audit(r,target)
 serial=serial+1;local request={run=r,target=target,ticket='guid-read:'..GetGameTimer()..':'..serial,bound=bound}
 reading=request
 TriggerClientEvent('feather-weapons:client:guid-suite-read',target,request.ticket,bound)
 local started=GetGameTimer()
 while not request.value and (GetGameTimer()-started)%4294967296<10000 do assert(current(r),'guid_session_changed');Wait(50) end
 reading=nil
 assert(request.value,'guid_client_preflight_unavailable')
 local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
 local matches,why=WeaponNativeAcceptanceView.MatchesDurable(request.value,durable,registry.limits,r.shared and {allowEmptyFirearms=true} or nil)
 assert(matches,'guid_seal_wear_before_run:'..tostring(why))
 return {durable=durable,client=request.value}
end
function S.Reserved(target) return run and (run.target==target or run.shared and run.shared.target==target) and current(run) or false end
function S.Timeout(target) return S.Reserved(target) and (run.shared and 300000 or run.throwable and 240000 or 2060000) or 45000 end
function S.BeforeRebuild(target)
 local r=run
 if not r then return true end
 if r.shared and target==r.shared.target then
  assert(current(r),'guid_shared_session_changed')
  r.shared.released=true
  local origin={characterId=r.bound.characterId,sessionId=r.bound.sessionId,epoch='native-loan:'..r.ticket}
  TriggerClientEvent('feather-weapons:client:guid-suite-shared-collector',target,r.ticket,r.shared.bound,origin,r.competing and 2 or nil)
  local started=GetGameTimer()
  while not r.shared.result and (GetGameTimer()-started)%4294967296<240000 do assert(current(r),'guid_shared_session_changed');Wait(50) end
  if not r.shared.result or r.shared.result.cleanupComplete~=true then return false end
  -- Collector cleanup alone could concern a different nearby unit. Release the
  -- thrower's spent entry only after this fixture's bound lifetime correlates.
  local settled=GetGameTimer()
  while r.collection and (r.collection.Report().phase=='pending' or r.competing and not r.collection.Report().syntheticBatchAbsent) and (GetGameTimer()-settled)%4294967296<1500 do
   assert(current(r),'guid_shared_session_changed');Wait(50)
  end
  local collection=r.collection and r.collection.Report()
  local accepted=collection and (not r.competing and collection.phase=='correlated_observation'
   or r.competing and collection.expectedAmbiguityRefused==true and collection.syntheticBatchAbsent==true)
  if r.shared.result.phase=='passed' and accepted then
   TriggerClientEvent('feather-weapons:client:guid-suite-shared-collected',r.target,r.ticket)
  end
  return true
 end
 if target~=r.target then return true end
 assert(current(r),'guid_session_changed')
 r.waiting=true;report.phase='running'
 if r.shared then
  local started=GetGameTimer()
  while not r.shared.ready and (GetGameTimer()-started)%4294967296<20000 do assert(current(r),'guid_shared_session_changed');Wait(50) end
  assert(r.shared.ready,'guid_collector_not_ready')
 end
 if r.landing then
  assert(type(GetNetTypeFromEntity)=='function','landing_nettype_native_required')
  local started=GetGameTimer();local token=0
  local identity={characterId=r.bound.characterId,sessionId=r.bound.sessionId,epoch='native-loan:'..r.ticket}
  local function loanCurrent() return r.waiting and current(r) and (GetGameTimer()-started)%4294967296<120000 end
  r.transitionProtocol=WeaponNativeThrowableTransitionProtocol.New({synthetic=true,now=GetGameTimer,later=SetTimeout,
   actor=function(source)
    if source~=r.target or not loanCurrent() then return nil end
    local ped=GetPlayerPed(source);if not ped or ped==0 or not DoesEntityExist(ped) then return nil end
    local p=GetEntityCoords(ped)
    return {characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,alive=true,
     bucket=GetPlayerRoutingBucket(source),position={x=p.x,y=p.y,z=p.z}}
   end,
   read=function(handle)
    if not DoesEntityExist(handle) then return {exists=false} end
    return {exists=true,networkId=NetworkGetNetworkIdFromEntity(handle),netType=GetNetTypeFromEntity(handle),
     owner=NetworkGetEntityOwner(handle),bucket=GetEntityRoutingBucket(handle)}
   end,
   challenge=function(source,id)
    if source==r.target and id=='landing-loan' and loanCurrent() then
     return {identity=copy(identity),operationId='observe:1',units={{itemId=900000001,itemRevision=1}}}
    end
   end,
   spend=function(source,operationId,itemId)
    if source==r.target and operationId=='observe:1' and itemId==900000001 and loanCurrent() then
     return {custody='spent',operationId=operationId,itemId=itemId,itemRevision=1,origin=copy(identity),
      metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='ISOLATED-LOAN-ONLY'}}
    end
   end,
   newId=function() token=token+1;return 'loan:'..r.ticket..':'..token end,
   place=function()
    -- Test completion only. Never calls an Inventory export or creates a world grant.
    r.transitionCompleted=true;return {phase='available',id='isolated-loan-only'}
   end,
   readPlacement=function() return {phase=r.transitionCompleted and 'available' or 'pending',id='isolated-loan-only'} end})
 end
 if r.throwable and not r.landing and WeaponNativeProjectileCollectionProbe then
  local started=GetGameTimer()
  local identity={characterId=r.bound.characterId,sessionId=r.bound.sessionId,epoch='native-loan:'..r.ticket}
  local function loanCurrent() return r.waiting and current(r) and (GetGameTimer()-started)%4294967296<(r.shared and 240000 or 120000) end
  r.collection=WeaponNativeProjectileCollectionProbe.New({competing=r.competing,identity=identity,target=r.target,collector=r.shared and r.shared.target,serialNumber=r.shared and 'ISOLATED-SHARED-LOAN' or nil,watchMs=r.shared and 180000 or nil,now=GetGameTimer,later=SetTimeout,current=loanCurrent,
   actor=function(player)
    local peer=r.shared and player==r.shared.target
    if (player~=r.target and not peer) or not loanCurrent() then return nil end
    local ped=GetPlayerPed(player);if not ped or ped==0 or not DoesEntityExist(ped) then return nil end
    local p=GetEntityCoords(ped)
    return {characterId=peer and r.shared.bound.characterId or identity.characterId,sessionId=peer and r.shared.bound.sessionId or identity.sessionId,
     epoch=peer and 'native-loan:'..r.ticket..':collector' or identity.epoch,alive=true,
     bucket=GetPlayerRoutingBucket(player),position={x=p.x,y=p.y,z=p.z}}
   end,
   read=function(handle)
    if not DoesEntityExist(handle) then return {exists=false} end
    return {exists=true,networkId=NetworkGetNetworkIdFromEntity(handle),netType=GetNetTypeFromEntity(handle),
     owner=NetworkGetEntityOwner(handle),bucket=GetEntityRoutingBucket(handle)}
   end})
 end
 if r.throwable then
  r.world=WeaponNativeThrowableLifetimeCapture.New({now=GetGameTimer,later=SetTimeout,resolve=NetworkGetEntityFromNetworkId,
   current=function() return r.waiting and current(r) end,
   tomahawk=function(hash) return type(hash)=='number' and hash%1==0 and (hash & 0xffffffff)==(joaat('WEAPON_THROWN_TOMAHAWK') & 0xffffffff) end,
   read=function(handle,actor)
    if not DoesEntityExist(handle) then return nil,'entity_missing',{exists=false} end
    local entityType=GetEntityType(handle)
    local model=GetEntityModel(handle) & 0xffffffff
    local evidence={exists=true,entityType=entityType,model=model,networkId=NetworkGetNetworkIdFromEntity(handle),owner=NetworkGetEntityOwner(handle)}
    if type(GetNetTypeFromEntity)=='function' then evidence.netType=GetNetTypeFromEntity(handle) end
    if entityType~=3 then return nil,'entity_type_'..tostring(entityType),evidence end
    -- CPickupCreationDataNode has no parsed model/GetModelHash branch in the
    -- RDR3 sync tree. A known Pickup model0 is capability evidence, not a
    -- transient readiness error or proof of a different weapon model.
    if model==0 and evidence.netType==8 then return nil,'pickup_model_unavailable',evidence end
    if model~=(joaat('w_melee_tomahawk01') & 0xffffffff) and model~=(joaat('w_melee_tomahawk02') & 0xffffffff) then return nil,'model_mismatch_'..tostring(model),evidence end
    local ped=GetPlayerPed(actor);if not ped or ped==0 or not DoesEntityExist(ped) then return nil,'player_ped_missing' end
    local p=GetEntityCoords(ped);local q=GetEntityCoords(handle)
    local distance=(p.x-q.x)^2+(p.y-q.y)^2+(p.z-q.z)^2
    return {networkId=NetworkGetNetworkIdFromEntity(handle),model=model,owner=NetworkGetEntityOwner(handle),
     bucket=GetEntityRoutingBucket(handle),playerBucket=GetPlayerRoutingBucket(actor),nearby=distance<=2500}
   end},r.target,r.ticket)
 end
 save()
 TriggerClientEvent(r.throwable and 'feather-weapons:client:guid-suite-throwable' or 'feather-weapons:client:guid-suite-run',target,r.ticket,r.bound,r.total,r.landing and 'landing' or r.competing and 'shared-competing' or r.shared and 'shared' or nil)
 local started=GetGameTimer()
 while not r.result and (GetGameTimer()-started)%4294967296<(r.shared and 300000 or r.throwable and 180000 or 2010000) do
  assert(current(r),'guid_session_changed');Wait(50)
 end
 if not r.result then
  TriggerClientEvent('feather-weapons:client:guid-suite-cancel',target,r.ticket)
  report.phase='review_required';report.reason='native_suite_timeout_no_retry';report.cleanupComplete=false;save()
  return false
 end
 if r.landing then
  report.transition={readinessVersion=2,serverRemovalConfirmed=r.transitionCompleted==true,syntheticNativeOnly=true,economicWrites=0,
   diagnostics=r.transitionProtocol and r.transitionProtocol.Diagnostics()}
  if r.result.phase=='complete' and not r.transitionCompleted then
   r.result.clientClaimedCompletion=true;r.result.phase='review_required';r.result.passed=0
   r.result.cleanupComplete=false;r.result.reason='server_pickup_cleanup_not_confirmed'
  end
 end
 if r.collection then report.collection=r.collection.Report() end
 if r.shared then report.sharedCollector=r.shared.result end
 if r.world then
  report.world=r.world.Report(r.result.cases)
  r.waiting=false -- exclude original-loadout restoration entities from capture
  -- Shared acceptance exercises a synthetic native lifecycle, not paid origin
  -- attribution. Preserve the independent model-based diagnostic unchanged.
  if not r.shared and not r.landing and r.result.phase=='complete' and report.world.phase~='matched' then
   r.result.phase='review_required';r.result.reason='server_object_lifetime_not_correlated'
  end
 end
 if r.shared and r.result.phase=='complete'
  and (not report.collection or not r.competing and report.collection.phase~='correlated_observation'
   or r.competing and (report.collection.expectedAmbiguityRefused~=true or report.collection.syntheticBatchAbsent~=true)) then
  r.result.phase='review_required';r.result.reason='shared_collection_not_correlated'
 end
 report.native=r.result;report.passed=r.result.passed;report.failedCase=r.result.failedCase
 report.throwerCleanupComplete=r.result.cleanupComplete
 report.cleanupComplete=r.result.cleanupComplete and (not r.shared or r.shared.result and r.shared.result.cleanupComplete==true) or false
 if report.cleanupComplete~=true then
  report.phase='review_required';report.reason=r.result.reason or 'native_cleanup_unconfirmed';save();return false
 end
 -- A failed but independently cleaned case may restore the original loadout.
 report.phase='restoring';report.reason=r.result.reason;save();return true
end
RegisterNetEvent('feather-weapons:server:guid-suite-progress',function(ticket,index,total,id)
 local r=run
 if not r or source~=r.target or ticket~=r.ticket or not r.waiting or not current(r)
  or type(index)~='number' or index%1~=0 or index<1 or index>r.total or total~=r.total
  or not r.cases[index] or id~=r.cases[index].id or index<report.passed then return end
 report.passed=index;report.currentCase=id;save()
 print(('[WeaponGuidAcceptance] %s/%s %s'):format(index,total,id))
end)
local function packet(raw)
 if type(raw)~='string' or #raw>6000 then return nil end
 local ok,value=pcall(json.decode,raw)
 return ok and type(value)=='table' and value or nil
end
local function ack(target,ticket,kind,sequence)
 TriggerClientEvent('feather-weapons:client:guid-suite-report-ack',target,ticket,kind,sequence)
end
RegisterNetEvent('feather-weapons:server:guid-suite-chunk',function(ticket,sequence,raw)
 local playerSource=source
 local r=run
 if not r or playerSource~=r.target or ticket~=r.ticket or not r.waiting or not current(r)
  or type(sequence)~='number' or sequence%1~=0 or sequence<1 or sequence>r.total then return end
 r.chunks=r.chunks or {};r.rows=r.rows or {};r.bytes=r.bytes or 0
 if r.chunks[sequence] then
  if r.chunks[sequence]==raw then
   report.reportDeliveryRetries=(report.reportDeliveryRetries or 0)+1
   ack(playerSource,ticket,'chunk',sequence)
  end
  return
 end
 if r.result or sequence~=#r.chunks+1 then return end
 local value=packet(raw)
 if not value or value.first~=#r.rows+1 or type(value.rows)~='table' or #value.rows<1
  or #value.rows>50 or #r.rows+#value.rows>r.total or r.bytes+#raw>3000000 then return end
 for index,row in ipairs(value.rows) do
  local expected=r.cases[#r.rows+index]
  if type(row)~='table' or row.id~=expected.id or (row.phase~='passed' and row.phase~='failed')
   or type(row.cleanupComplete)~='boolean' then return end
 end
 for _,row in ipairs(value.rows) do r.rows[#r.rows+1]=row end
 r.chunks[sequence]=raw;r.bytes=r.bytes+#raw
 report.receivedCases=#r.rows;report.evidenceRows=r.rows
 -- Save bounded checkpoints; do not rewrite a growing report for every packet.
 if #r.rows==r.total or #r.rows%50<#value.rows then save() end
 ack(playerSource,ticket,'chunk',sequence)
end)
RegisterNetEvent('feather-weapons:server:guid-suite-result',function(ticket,sequence,raw)
 local playerSource=source
 local r=run
 if lastFinal and playerSource==lastFinal.target and ticket==lastFinal.ticket and sequence==lastFinal.sequence
  and raw==lastFinal.raw and CoreAdapter.IsSessionCurrent(playerSource,lastFinal.sessionId,lastFinal.characterId) then
  return ack(playerSource,ticket,'result',sequence)
 end
 if not r or playerSource~=r.target or ticket~=r.ticket or not r.waiting or r.result or not current(r)
  or sequence~=#(r.chunks or {})+1 then return end
 local value=packet(raw);local rows=r.rows or {}
 if not value or value.wireVersion~=2 or type(value.passed)~='number' or value.passed%1~=0
  or value.passed<0 or value.passed>r.total or value.total~=r.total or value.caseCount~=#rows
  or (value.phase~='complete' and value.phase~='review_required') or type(value.cleanupComplete)~='boolean' then return end
 if value.phase=='complete' and (value.passed~=r.total or value.cleanupComplete~=true or #rows~=r.total) then return end
 for i=1,value.passed do if not rows[i] or rows[i].phase~='passed' or rows[i].cleanupComplete~=true then return end end
 if value.reason~=nil and (type(value.reason)~='string' or #value.reason>2048) then return end
 r.result={phase=value.phase,passed=value.passed,total=value.total,cleanupComplete=value.cleanupComplete,
  reason=value.reason,failedCase=value.failedCase,cases=rows,wireVersion=2,visual='pending',automaticRetries=0}
 report.native=r.result;report.evidenceRows=nil;report.reportDeliveryRetries=report.reportDeliveryRetries or 0
 save() -- acknowledge only evidence that survived file readback
 lastFinal={target=r.target,ticket=ticket,sequence=sequence,raw=raw,
  sessionId=r.bound.sessionId,characterId=r.bound.characterId}
 ack(playerSource,ticket,'result',sequence)
end)
RegisterNetEvent('feather-weapons:server:guid-suite-object-hint',function(ticket,networkId,model)
 local r=run
 if r and r.throwable and r.waiting and r.world and source==r.target and ticket==r.ticket and current(r) then
  r.world.Hint(networkId,model)
 end
end)
RegisterNetEvent('feather-weapons:server:guid-suite-collection-hint',function(ticket,kind,value)
 local player=source -- Core/export calls below may yield; never re-read global source.
 local r=run
 if r and r.throwable and not r.landing and r.waiting and r.collection
  and (player==r.target or r.shared and player==r.shared.target and kind=='collection_event')
  and ticket==r.ticket and current(r) and type(value)=='table'
  and (kind=='owned_projectile' or kind=='collection_candidate' or kind=='collection_event') then
  r.collection.Hint(kind,value,player)
 end
end)
RegisterNetEvent('feather-weapons:server:guid-suite-shared-ready',function(ticket)
 local player=source
 local r=run
 if r and r.shared and player==r.shared.target and ticket==r.ticket and current(r) and r.shared.released then r.shared.ready=true end
end)
RegisterNetEvent('feather-weapons:server:guid-suite-shared-result',function(ticket,raw)
 local player=source
 local r=run
 if not r or not r.shared or player~=r.shared.target or ticket~=r.ticket or not current(r) or not r.shared.released then return end
 if r.shared.raw then
  if raw==r.shared.raw then TriggerClientEvent('feather-weapons:client:guid-suite-shared-ack',player,ticket) end
  return
 end
 local row=packet(raw)
 if not row or row.id~='throwable:shared-collector' or row.syntheticNativeOnly~=true or row.economicWrites~=0
  or (row.phase~='passed' and row.phase~='failed') or type(row.cleanupComplete)~='boolean'
  or row.phase=='passed' and (row.cleanupComplete~=true or row.captured~=true) then return end
 if r.competing and row.phase=='passed' and (row.expectedUnits~=2 or row.quantityAtCapture~=2
  or type(row.pickupEvents)~='table' or #row.pickupEvents<2 or row.captureMode~='zero_ammo_carrier') then return end
 local previous=report.sharedCollector;report.sharedCollector=row
 local saved=pcall(save)
 if not saved then report.sharedCollector=previous;return end
 r.shared.result=row;r.shared.raw=raw
 TriggerClientEvent('feather-weapons:client:guid-suite-shared-ack',player,ticket)
end)
if type(AddEventHandler)=='function' then
 AddEventHandler('entityCreated',function(handle) local r=run;if r and current(r) then
  if r.world then r.world.Created(handle) end
  if r.transitionProtocol and r.waiting then r.transitionProtocol.Created(handle) end
  if r.collection and r.waiting then r.collection.Created(handle) end
 end end)
 AddEventHandler('entityRemoved',function(handle) local r=run;if r and current(r) then
  if r.world then r.world.Removed(handle) end
  if r.transitionProtocol and r.waiting then r.transitionProtocol.Removed(handle) end
  if r.collection and r.waiting then r.collection.Removed(handle) end
 end end)
 AddEventHandler('startProjectileEvent',function(actor,data) local r=run;if r and r.world and current(r) then r.world.Projectile(actor,data) end end)
end
RegisterNetEvent('feather-weapons:server:guid-suite-landing-action',function(ticket,action,request)
 local r=run;local player=source
 if not r or not r.landing or not r.waiting or not r.transitionProtocol or player~=r.target
  or ticket~=r.ticket or not current(r) or type(request)~='table' or request.id~='landing-loan' then return end
 local now=GetGameTimer()
 if not r.actionRate or (now-r.actionRate.started)%4294967296>=1000 then r.actionRate={started=now,count=0} end
 if r.actionRate.count>=4 then return end;r.actionRate.count=r.actionRate.count+1
 local ok,result=pcall(r.transitionProtocol.Handle,player,action,request)
 if not r.waiting or not current(r) then return end
 TriggerClientEvent('feather-weapons:client:guid-suite-landing-result',player,ticket,action,request.id,
  ok and result or {phase='pending',id=request.id})
end)
RegisterCommand('WeaponGuidAcceptance',function(source,args)
 if source~=0 then return end
 local action=args and args[1]
 if Config and Config.NativeThrowableQuantityOnly==true and ({throwable=true,landing=true,shared=true,['shared-competing']=true})[action or ''] then
  return print('[WeaponGuidAcceptance] REFUSED retired exact-item throwable experiment; use quantity-mode diagnostics. Retained evidence is available through status/archive.')
 end
 local competing=action=='shared-competing'
 if competing then action='shared' end
 if action=='status' then return summary() end
 if action=='recover-shared' then
  if run or GetConvarInt(flag,0)~=1 or #args~=3 or not report or report.phase~='review_required'
   or report.kind~='throwable_shared_collection' or not report.before or not report.before.client or not report.before.durable
   or not report.sharedBefore or not report.sharedBefore.client or not report.sharedBefore.durable then
   return print('[WeaponGuidAcceptance] REFUSED retained shared report and two fresh active sessions required')
  end
  local function participant(id,previous)
   local session=id and CoreAdapter.ResolveSession(id);local state=id and WeaponCharacterAmmoDispatcher.Status(id)
   if not session or not session.ok or not state or state.phase~='active' or state.busy or not state.identity
    or state.identity.characterId~=previous.client.identity.characterId or session.value.characterId~=state.identity.characterId
    or session.value.sessionId~=state.identity.sessionId or state.identity.sessionId==previous.client.identity.sessionId then return nil end
   return {target=id,bound=copy(state.identity),actor={source=id,characterId=session.value.characterId,sessionId=session.value.sessionId}}
  end
  local first=participant(tonumber(args[2]),report.before);local second=participant(tonumber(args[3]),report.sharedBefore)
  if not first or not second or first.target==second.target then return print('[WeaponGuidAcceptance] REFUSED both original characters must be in fresh active sessions, in original role order') end
  local original=copy(report)
  local r={target=first.target,bound=first.bound,actor=first.actor,shared=second};run=r
  CreateThread(function()
   local ok,why=pcall(function()
    local function verify(previous,after)
     assert(same(previous.durable,after.durable),'shared_recovery_saved_state_changed_no_repair')
     local prior=copy(previous.client);prior.identity=copy(after.client.identity)
     for index,item in ipairs(prior.maintenance or {}) do
      local actual=after.client.maintenance[index];assert(actual and actual.id==item.id,'shared_recovery_native_item_changed')
      for field,value in pairs(item.wear) do
       local n=actual.wear[field];assert(type(n)=='number' and math.abs(value-n)<=0.000001,'shared_recovery_native_wear_changed');item.wear[field]=n
      end
     end
     assert(same(prior,after.client),'shared_recovery_native_state_changed_no_repair')
    end
    local after=capture(r);local peerAfter=capture(r,r.shared.target)
    verify(original.before,after);verify(original.sharedBefore,peerAfter)
    local archived='native-guid-acceptance-shared-failure-'..os.time()..'-'..GetGameTimer()..'.json'
    local raw=json.encode(original)
    assert(SaveResourceFile(resource,archived,raw,#raw)~=false and LoadResourceFile(resource,archived)==raw,'shared_recovery_archive_failed')
    report.recovery={phase='confirmed',kind='two_fresh_session_verification',savedStateUnchanged=true,
     originalLoadoutsActive=true,priorEvidence=archived,after=after,collectorAfter=peerAfter}
    report.phase='recovered_shared_session_failure';report.restored=true;report.collectorRestored=true
    -- Preserve original cleanupComplete/failure: disconnect is not retrospective
    -- proof that the original fixture performed exact native retirement.
   end)
   if not ok then report.recovery={phase='refused',reason=tostring(why)} end
   pcall(save);reading=nil;run=nil;SetConvar(flag,'0');summary()
  end)
  return
 end
 if action=='visual' and not run and report and report.phase=='complete' and (args[2]=='pass' or args[2]=='fail') then
  report.visual=args[2];save();return summary()
 end
 local transportRecovery=action=='recover' and report and type(report.total)=='number' and report.total>0
  and report.passed==report.total and not report.native
 local landingSessionRecovery=action=='recover-session' and report and report.kind=='throwable_landing_cleanup'
  and report.native and type(report.native.cases)=='table' and #report.native.cases==1
  and report.native.cases[1].id=='throwable:landing-cleanup'
  and report.native.cases[1].syntheticNativeOnly==true and report.native.cases[1].economicWrites==0
 if (transportRecovery or landingSessionRecovery) and not run and report and report.phase=='review_required'
  and report.before and report.before.client and report.before.durable and GetConvarInt(flag,0)==1 then
  local target=tonumber(args[2])
  if #args==1 then
   local found={}
   for _,player in ipairs(GetPlayers()) do
    local id=tonumber(player);local state=id and WeaponCharacterAmmoDispatcher.Status(id)
    if state and state.phase=='active' and not state.busy then found[#found+1]=id end
   end
   if #found==1 then target=found[1] end
  end
  local session=target and CoreAdapter.ResolveSession(target)
  local state=target and WeaponCharacterAmmoDispatcher.Status(target)
  local before=report.before.client.identity
  if not session or not session.ok or not state or state.phase~='active' or not state.identity
   or session.value.characterId~=before.characterId or session.value.sessionId==before.sessionId then
   return print('[WeaponGuidAcceptance] REFUSED recovery requires original character in a fresh active session')
  end
  local original=copy(report)
  local r={target=target,bound=copy(state.identity),actor={source=target,characterId=session.value.characterId,sessionId=session.value.sessionId}}
  run=r
  CreateThread(function()
   local ok,why=pcall(function()
    local after=capture(r)
    assert(same(original.before.durable,after.durable),'recovery_saved_state_changed_no_repair')
    local previous=copy(original.before.client)
    previous.identity=copy(after.client.identity)
    for index,item in ipairs(previous.maintenance or {}) do
     local actual=after.client.maintenance[index]
     assert(actual and actual.id==item.id,'recovery_native_item_identity_changed')
     for field,value in pairs(item.wear) do
      local n=actual.wear[field]
      assert(type(n)=='number' and math.abs(value-n)<=0.000001,'recovery_native_wear_changed')
      item.wear[field]=n -- compare a private copy; saved item metadata remains exact
     end
    end
    assert(same(previous,after.client),'recovery_native_state_changed_no_repair')
    local path='native-guid-acceptance-transport-failure-'..os.time()..'-'..GetGameTimer()..'.json'
    local raw=json.encode(original)
    assert(SaveResourceFile(resource,path,raw,#raw)~=false and LoadResourceFile(resource,path)==raw,'recovery_evidence_archive_failed')
    report.recovery={phase='confirmed',savedStateUnchanged=true,originalLoadoutActive=true,
     kind=landingSessionRecovery and 'fresh_session_verification' or 'report_transport',
     priorEvidence=path,detailedNativeReportAvailable=original.native~=nil,after=after}
    report.phase=landingSessionRecovery and 'recovered_session_failure' or 'recovered_transport_failure';report.restored=true
    -- Preserve unknown original cleanup/report state instead of retroactively certifying it.
   end)
   if not ok then report.recovery={phase='refused',reason=tostring(why)} end
   pcall(save);reading=nil;run=nil;SetConvar(flag,'0');summary()
  end)
  return
 end
 if action=='resend' and not run and lastFinal
  and CoreAdapter.IsSessionCurrent(lastFinal.target,lastFinal.sessionId,lastFinal.characterId) then
  return TriggerClientEvent('feather-weapons:client:guid-suite-resend',lastFinal.target,lastFinal.ticket,true)
 end
 if action=='archive' and not run and report then
  local archived='native-guid-acceptance-'..os.time()..'-'..GetGameTimer()..'.json'
  local text=json.encode(report)
  assert(SaveResourceFile(resource,archived,text,#text)~=false and LoadResourceFile(resource,archived)==text,'guid_archive_failed')
  report={phase='idle',archivedReport=archived};save();summary()
  return print('[WeaponGuidAcceptance] Evidence archived only. No native/runtime/Inventory state was repaired or released.')
 end
 if action=='resend' and run and run.waiting then
  return TriggerClientEvent('feather-weapons:client:guid-suite-resend',run.target,run.ticket)
 end
 if action=='cancel' and run then
  if run.shared then TriggerClientEvent('feather-weapons:client:guid-suite-cancel',run.shared.target,run.ticket) end
  TriggerClientEvent('feather-weapons:client:guid-suite-cancel',run.target,run.ticket);return
 end
 if (action~='run' and action~='transport' and action~='throwable' and action~='landing' and action~='shared')
  or (action=='shared' and #args~=3 or action~='shared' and #args~=1 and #args~=2) or run
  or report and report.phase~='complete' and report.phase~='idle' and report.phase~='transport_complete'
   and not (action=='transport' and report.phase=='recovered_transport_failure') or GetConvarInt(flag,0)~=1 then
  return print('[WeaponGuidAcceptance] REFUSED console run|throwable|landing <server-id>, shared <thrower-id> <collector-id>, status, cancel or visual pass|fail; explicit opt-in required. Retain unresolved report.')
 end
 if (action=='throwable' or action=='landing') and #GetPlayers()~=1 then return print('[WeaponGuidAcceptance] REFUSED isolated throwable test requires exactly one connected player') end
 if action=='shared' and #GetPlayers()~=2 then return print('[WeaponGuidAcceptance] REFUSED shared test requires exactly two connected players') end
 local target=tonumber(args[2])
 if #args==1 then
  local found={}
  for _,player in ipairs(GetPlayers()) do
   local id=tonumber(player);local status=id and WeaponCharacterAmmoDispatcher.Status(id)
   if status and status.phase=='active' and not status.busy then found[#found+1]=id end
  end
  if #found~=1 then return print('[WeaponGuidAcceptance] REFUSED exactly one active player required, or specify run <current-server-id>') end
  target=found[1]
 end
 local session=target and CoreAdapter.ResolveSession(target)
 local state=target and WeaponCharacterAmmoDispatcher.Status(target)
 if not session or not session.ok or not state or state.phase~='active' or state.busy or not state.identity
  or state.identity.characterId~=session.value.characterId or state.identity.sessionId~=session.value.sessionId
  or (GetResourceState('feather-weapons-native-proof')~='stopped' and GetResourceState('feather-weapons-native-proof')~='missing') then return print('[WeaponGuidAcceptance] REFUSED active idle native owner required') end
 local peer
 if action=='shared' then
  local id=tonumber(args[3]);local s=id and CoreAdapter.ResolveSession(id);local status=id and WeaponCharacterAmmoDispatcher.Status(id)
  if not id or id==target or not s or not s.ok or not status or status.phase~='active' or status.busy or not status.identity
   or status.identity.characterId~=s.value.characterId or status.identity.sessionId~=s.value.sessionId
   or s.value.characterId==session.value.characterId then return print('[WeaponGuidAcceptance] REFUSED distinct active idle collector required') end
  peer={target=id,bound=copy(status.identity),actor={source=id,characterId=s.value.characterId,sessionId=s.value.sessionId}}
 end
 local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
 local cases=action=='landing' and {{id='throwable:landing-cleanup'}} or (action=='throwable' or action=='shared') and {{id='throwable:world-capture'}} or registry and WeaponGuidAcceptance.Matrix(WeaponDefinitionCatalog,registry)
 if not cases then return print('[WeaponGuidAcceptance] REFUSED catalog unavailable') end
 serial=serial+1
 local r={target=target,bound=state.identity,shared=peer,competing=competing,cases=cases,total=#cases,transportOnly=action=='transport',throwable=action=='throwable' or action=='landing' or action=='shared',landing=action=='landing',ticket='guid-suite:'..os.time()..':'..serial,
  actor={source=target,characterId=session.value.characterId,sessionId=session.value.sessionId}}
 run=r
 if report then
  local old=json.encode(report);assert(SaveResourceFile(resource,'native-guid-acceptance-previous.json',old,#old)~=false)
 end
 report={phase='preflight',kind=r.shared and 'throwable_shared_collection' or r.landing and 'throwable_landing_cleanup' or r.throwable and 'throwable_world_capture' or r.transportOnly and 'report_transport_only' or 'native_creation',runId=r.ticket,total=#cases,passed=0,visual='pending',automaticRetries=0,
  coverage=r.landing and 'isolated fresh throw/stable landing/exact cleanup; synthetic challenge; no paid publication' or r.throwable and 'one isolated native throw/pickup; no paid pickup authority' or 'all valid ordered pairs plus representative four-slot; clean/customized',
  candidate=r.landing and 'native_throwable_landing_cleanup' or r.throwable and 'native_throwable_world_capture' or 'native_inventory_guid_v1'}
 if r.shared then report.acceptanceScope=r.competing and 'synthetic_competing_native_cleanup' or 'synthetic_shared_native_lifecycle' end
 save();print(r.competing and ('[WeaponGuidAcceptance] STARTED competing negative test. Thrower=%s collector=%s. Throw TWO units, then collect BOTH. No Inventory grants.'):format(target,r.shared.target) or r.shared and ('[WeaponGuidAcceptance] STARTED shared native test. Thrower=%s collector=%s. Throw once, switch clients, collect within three minutes. No Inventory grants.'):format(target,r.shared.target) or r.landing and '[WeaponGuidAcceptance] STARTED isolated landing/cleanup probe. After the client prompt, throw once onto nearby clear ground; do not collect. No Inventory grants or paid publication.' or r.throwable and '[WeaponGuidAcceptance] STARTED isolated Tomahawk test. After the client prompt, throw once and recover that unit within 90 seconds. No Inventory grants.' or '[WeaponGuidAcceptance] STARTED. Keep the player idle; no weapons, equipment or ammo will be purchased or granted in Inventory.')
 CreateThread(function()
  local ok,why=pcall(function()
   r.before=capture(r);report.before=r.before;save()
   if r.shared then r.shared.before=capture(r,r.shared.target);report.sharedBefore=r.shared.before;save() end
   if r.transportOnly then
    r.waiting=true;report.phase='checking_transport';save()
    TriggerClientEvent('feather-weapons:client:guid-suite-transport',target,r.ticket,r.bound,r.total)
    local started=GetGameTimer()
    while not r.result and (GetGameTimer()-started)%4294967296<190000 do assert(current(r),'guid_session_changed');Wait(50) end
    assert(r.result and r.result.phase=='complete','report_transport_not_confirmed')
    local after=capture(r);report.after=after
    assert(same(r.before.durable,after.durable) and same(r.before.client,after.client),'transport_check_state_changed')
    report.native=nil;report.transport=r.result;report.passed=r.result.passed
    report.phase='transport_complete';report.visual='not_applicable';report.cleanupComplete=true
    return
   end
   if r.shared then
    local peerBegun=WeaponNativeEquipmentBindings.GuidValidationTransition(r.shared.target)
    assert(peerBegun and peerBegun.ok,'guid_collector_release_refused')
   end
   local begun=WeaponNativeEquipmentBindings.GuidValidationTransition(target)
   assert(begun and begun.ok,'guid_release_refused')
   local started=GetGameTimer()
   while (GetGameTimer()-started)%4294967296<2060000 do
    assert(current(r),'guid_session_changed')
    local transition=WeaponNativeEquipmentBindings.AcceptanceStatus(target)
    local peerTransition=r.shared and WeaponNativeEquipmentBindings.AcceptanceStatus(r.shared.target)
    assert(not transition or transition.phase~='frozen','guid_transition_frozen_no_retry')
    assert(not peerTransition or peerTransition.phase~='frozen','guid_collector_transition_frozen_no_retry')
    if r.result and transition and transition.phase=='active' and (not r.shared or peerTransition and peerTransition.phase=='active') then break end
    Wait(100)
   end
   local after=capture(r);report.after=after
   assert(r.result and report.cleanupComplete==true,'guid_completion_unconfirmed')
   assert(same(r.before.durable,after.durable),'guid_saved_inventory_or_ammunition_changed')
   local before=copy(r.before.client);local nextView=after.client
   assert(before.identity.epoch~=nextView.identity.epoch,'guid_fresh_restore_required')
   before.identity.epoch=nextView.identity.epoch
   assert(same(before,nextView),'guid_restored_client_state_changed')
   if r.shared then
    local peerAfter=capture(r,r.shared.target);report.sharedAfter=peerAfter
    assert(r.shared.result and r.shared.result.cleanupComplete==true,'guid_collector_cleanup_unconfirmed')
    assert(same(r.shared.before.durable,peerAfter.durable),'guid_collector_saved_state_changed')
    local peerBefore=copy(r.shared.before.client)
    assert(peerBefore.identity.epoch~=peerAfter.client.identity.epoch,'guid_collector_fresh_restore_required')
    peerBefore.identity.epoch=peerAfter.client.identity.epoch
    assert(same(peerBefore,peerAfter.client),'guid_collector_restored_state_changed')
    report.collectorRestored=true
    if r.shared.result.phase~='passed' then r.result.phase='review_required';r.result.reason='guid_collector_case_failed' end
   end
   report.restored=true;report.phase=r.result.phase
   report.reason=r.result.reason
   if r.shared then
    report.acceptanceScope=r.competing and 'synthetic_competing_native_cleanup' or 'synthetic_shared_native_lifecycle'
    report.lifecycle={phase=report.phase=='complete' and 'passed' or 'review_required',
     collectionCorrelated=report.collection and report.collection.phase=='correlated_observation' or false,
     expectedAmbiguityRefused=r.competing and report.collection and report.collection.expectedAmbiguityRefused or false,
     cleanupComplete=report.cleanupComplete==true,bothLoadoutsRestored=true,
     syntheticNativeOnly=true,economicWrites=0,canClaim=false,pickupCredits=false,originConfirmed=false}
   end
  end)
  if not ok then
   report.phase='review_required';report.transitionReason=tostring(why)
   report.reason=report.native and report.native.reason or tostring(why)
   -- Preserve read-only lifetime evidence even when a peer fails before the
   -- thrower submits its final case; clearing run must not discard this stage.
   if r.collection then local read,value=pcall(r.collection.Report);if read then report.collection=value end end
   if r.world then local read,value=pcall(r.world.Report,r.result and r.result.cases);if read then report.world=value end end
   if r.shared then report.sharedCollector=r.shared.result end
   if r.shared then report.lifecycle={phase='review_required',reason=tostring(why),
    syntheticNativeOnly=true,economicWrites=0,canClaim=false,pickupCredits=false,originConfirmed=false} end
   if r.waiting then TriggerClientEvent('feather-weapons:client:guid-suite-cancel',r.target,r.ticket) end
   if r.shared then TriggerClientEvent('feather-weapons:client:guid-suite-cancel',r.shared.target,r.ticket) end
  end
  pcall(save);reading=nil;run=nil;SetConvar(flag,'0');summary()
 end)
end,true)
