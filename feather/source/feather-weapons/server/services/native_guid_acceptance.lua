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
  restored=report.restored,visual=report.visual,recovery=report.recovery and report.recovery.phase,reportFile=file,automaticRetries=0,automaticMutationRetries=0,receivedCases=report.receivedCases,reportDeliveryRetries=report.reportDeliveryRetries} or {phase='idle'}))
end
local raw=LoadResourceFile(resource,file)
if raw then
 local ok,value=pcall(json.decode,raw)
 if ok and type(value)=='table' then report=value else report={phase='review_required',reason='saved_report_unreadable'} end
 if report.phase=='running' or report.phase=='preflight' or report.phase=='restoring' or report.phase=='checking_transport' then
  report.phase='review_required';report.reason='interrupted_run_no_automatic_resume'
 end
end
local function audit(r)
 local read=exports['feather-inventory']:ReadNativeAcceptanceAudit({r.actor})
 assert(read and read.ok and read.value and read.value[1],'guid_durable_audit_unavailable')
 return read.value[1]
end
RegisterNetEvent('feather-weapons:server:guid-suite-read',function(ticket,view)
 if not reading or source~=reading.target or ticket~=reading.ticket or not current(reading.run) then return end
 local clean=WeaponNativeAcceptanceView.Normalize(view)
 if clean and same(clean.identity,reading.bound) then reading.value=clean end
end)
local function capture(r)
 assert(current(r),'guid_session_changed')
 local state=WeaponCharacterAmmoDispatcher.Status(r.target)
 assert(state and state.phase=='active' and not state.busy and state.identity,'guid_active_owner_required')
 local bound=state.identity
 local durable=audit(r)
 serial=serial+1;local request={run=r,target=r.target,ticket='guid-read:'..GetGameTimer()..':'..serial,bound=bound}
 reading=request
 TriggerClientEvent('feather-weapons:client:guid-suite-read',r.target,request.ticket,bound)
 local started=GetGameTimer()
 while not request.value and (GetGameTimer()-started)%4294967296<10000 do assert(current(r),'guid_session_changed');Wait(50) end
 reading=nil
 assert(request.value,'guid_client_preflight_unavailable')
 local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
 local matches,why=WeaponNativeAcceptanceView.MatchesDurable(request.value,durable,registry.limits)
 assert(matches,'guid_seal_wear_before_run:'..tostring(why))
 return {durable=durable,client=request.value}
end
function S.Reserved(target) return run and run.target==target and current(run) or false end
function S.Timeout(target) return S.Reserved(target) and 2060000 or 45000 end
function S.BeforeRebuild(target)
 local r=run
 if not r or target~=r.target then return true end
 assert(current(r),'guid_session_changed')
 r.waiting=true;report.phase='running';save()
 TriggerClientEvent('feather-weapons:client:guid-suite-run',target,r.ticket,r.bound,r.total)
 local started=GetGameTimer()
 while not r.result and (GetGameTimer()-started)%4294967296<2010000 do
  assert(current(r),'guid_session_changed');Wait(50)
 end
 if not r.result then
  TriggerClientEvent('feather-weapons:client:guid-suite-cancel',target,r.ticket)
  report.phase='review_required';report.reason='native_suite_timeout_no_retry';report.cleanupComplete=false;save()
  return false
 end
 report.native=r.result;report.passed=r.result.passed;report.failedCase=r.result.failedCase
 report.cleanupComplete=r.result.cleanupComplete
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
RegisterCommand('WeaponGuidAcceptance',function(source,args)
 if source~=0 then return end
 local action=args and args[1]
 if action=='status' then return summary() end
 if action=='visual' and not run and report and report.phase=='complete' and (args[2]=='pass' or args[2]=='fail') then
  report.visual=args[2];save();return summary()
 end
 if action=='recover' and not run and report and report.phase=='review_required'
  and type(report.total)=='number' and report.total>0 and report.passed==report.total and not report.native
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
     priorEvidence=path,detailedNativeReportAvailable=original.native~=nil,after=after}
    report.phase='recovered_transport_failure';report.restored=true
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
  TriggerClientEvent('feather-weapons:client:guid-suite-cancel',run.target,run.ticket);return
 end
 if (action~='run' and action~='transport') or (#args~=1 and #args~=2) or run
  or report and report.phase~='complete' and report.phase~='idle' and report.phase~='transport_complete'
   and not (action=='transport' and report.phase=='recovered_transport_failure') or GetConvarInt(flag,0)~=1 then
  return print('[WeaponGuidAcceptance] REFUSED console run <current-server-id>, status, cancel or visual pass|fail; explicit opt-in required. Retain unresolved report.')
 end
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
  or GetResourceState('feather-weapons-native-proof')~='stopped' then return print('[WeaponGuidAcceptance] REFUSED active idle native owner required') end
 local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
 local cases=registry and WeaponGuidAcceptance.Matrix(WeaponDefinitionCatalog,registry)
 if not cases then return print('[WeaponGuidAcceptance] REFUSED catalog unavailable') end
 serial=serial+1
 local r={target=target,bound=state.identity,cases=cases,total=#cases,transportOnly=action=='transport',ticket='guid-suite:'..os.time()..':'..serial,
  actor={source=target,characterId=session.value.characterId,sessionId=session.value.sessionId}}
 run=r
 if report then
  local old=json.encode(report);assert(SaveResourceFile(resource,'native-guid-acceptance-previous.json',old,#old)~=false)
 end
 report={phase='preflight',kind=r.transportOnly and 'report_transport_only' or 'native_creation',runId=r.ticket,total=#cases,passed=0,visual='pending',automaticRetries=0,
  coverage='all valid ordered pairs plus representative four-slot; clean/customized',candidate='native_inventory_guid_v1'}
 save();print('[WeaponGuidAcceptance] STARTED. Keep the player idle; no weapons, equipment or ammo will be purchased or granted in Inventory.')
 CreateThread(function()
  local ok,why=pcall(function()
   r.before=capture(r);report.before=r.before;save()
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
   local begun=WeaponNativeEquipmentBindings.GuidValidationTransition(target)
   assert(begun and begun.ok,'guid_release_refused')
   local started=GetGameTimer()
   while (GetGameTimer()-started)%4294967296<2060000 do
    assert(current(r),'guid_session_changed')
    local transition=WeaponNativeEquipmentBindings.AcceptanceStatus(target)
    assert(not transition or transition.phase~='frozen','guid_transition_frozen_no_retry')
    if r.result and transition and transition.phase=='active' then break end
    Wait(100)
   end
   local after=capture(r);report.after=after
   assert(r.result and report.cleanupComplete==true,'guid_completion_unconfirmed')
   assert(same(r.before.durable,after.durable),'guid_saved_inventory_or_ammunition_changed')
   local before=copy(r.before.client);local nextView=after.client
   assert(before.identity.epoch~=nextView.identity.epoch,'guid_fresh_restore_required')
   before.identity.epoch=nextView.identity.epoch
   assert(same(before,nextView),'guid_restored_client_state_changed')
   report.restored=true;report.phase=r.result.phase
   report.reason=r.result.reason
  end)
  if not ok then
   report.phase='review_required';report.reason=tostring(why)
   if r.waiting then TriggerClientEvent('feather-weapons:client:guid-suite-cancel',r.target,r.ticket) end
  end
  pcall(save);reading=nil;run=nil;SetConvar(flag,'0');summary()
 end)
end,true)
