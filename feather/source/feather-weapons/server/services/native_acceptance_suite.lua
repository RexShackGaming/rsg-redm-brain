-- Developer regression orchestration, never a production recovery authority.
WeaponNativeAcceptanceSuite={}
local S=WeaponNativeAcceptanceSuite
local function clone(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=clone(x) end;return o end
local function conserved(a,b)
 if not WeaponNativeAcceptanceView.Equal(a.durable,b.durable) then return false end
 local x,y=clone(a.clients),clone(b.clients)
 for _,list in ipairs({x,y}) do for _,v in ipairs(list) do v.identity.epoch='' end end
 return WeaponNativeAcceptanceView.Equal(x,y)
end
function S.New(api)
 local report=api.load();local busy=false;local refusal
 local phases={preflight=true,running=true,checkpoint=true,complete=true,review_required=true}
 local invalid=report~=nil and (type(report)~='table' or report.version~=1 or type(report.phase)~='string'
  or not phases[report.phase] or type(report.steps)~='table' or type(report.runId)~='string'
  or (report.phase=='complete' and (#report.steps~=3 or type(report.before)~='table' or type(report.last)~='table')))
 if report and not invalid and report.phase~='complete' and report.phase~='review_required' then
  report.phase='review_required';report.reason='interrupted_run_no_replay'
 end
 local function save()
  if api.save(report)~=true then error('report_write_failed_no_retry') end
 end
 local T={}
 function T.Status() return invalid and {phase='report_invalid_do_not_retry'} or clone(report or refusal or {phase='idle'}) end
 function T.Run(again)
  if busy or invalid then return T.Status() end
  local preflightOnly=report and report.phase=='review_required' and #report.steps==0
   and report.pendingStep==nil and report.before==nil and report.last==nil
  if report and not preflightOnly and (report.phase~='complete' or not again) then return T.Status() end
  local prior=preflightOnly and {runId=report.runId,phase=report.phase,reason=report.reason} or nil
  busy=true;local started=false
  local ok,why=pcall(function()
   local actors=api.discover()
   if type(actors)~='table' or #actors~=2 then error('both_unique_test_characters_required') end
   report={version=1,runId=api.id(),phase='preflight',automaticRetries=0,steps={},actors=clone(actors),
    visual='pending',scope='seal_restore_overlap_conservation_only',priorPreflight=prior}
   started=true
   save()
   report.before=api.capture(actors);report.last=clone(report.before);save()
   local steps={{name='Jane seal and restore',actor=1},{name='Jane competing and stale acknowledgement refusal',actor=1,overlap=true},
    {name='John seal and restore',actor=2}}
   for _,step in ipairs(steps) do
    if api.current(actors)~=true then error('session_changed_no_retry') end
    report.phase='running';report.pendingStep=step.name;save() -- evidence before dispatch
    local result=api.transition(actors[step.actor],step.overlap==true)
    if type(result)~='table' or result.ok~=true then error('transition_refused_or_unknown_no_retry') end
    if step.overlap and (not result.value or result.value.competingRefused~=true
     or result.value.staleAcknowledgementRefused~=true) then error('overlap_evidence_missing') end
    api.awaitRestore(actors[step.actor],report.last.clients[step.actor].identity.epoch)
    if api.current(actors)~=true then error('session_changed_no_retry') end
    local after=api.capture(actors)
    if not conserved(report.before,after) then error('inventory_ammo_equipment_or_native_wear_changed') end
    local observer=step.actor==1 and 2 or 1
    if after.clients[observer].identity.epoch~=report.last.clients[observer].identity.epoch then error('observer_epoch_changed') end
    report.steps[#report.steps+1]={name=step.name,phase='passed'}
    report.last=after;report.pendingStep=nil;report.phase='checkpoint';save()
    api.progress(step.name)
   end
   report.phase='complete';save()
  end)
  if not ok then
   if started then
    report.phase='review_required'
    local code=tostring(why):match(':%d+: ([a-z_]+)$') or tostring(why):match('^([a-z_]+)$')
    report.reason=code or 'unexpected_failure_no_retry'
    if api.failureDetail then report.failureDetail=clone(api.failureDetail()) end
    pcall(save)
   else refusal={phase='refused',reason='both_unique_test_characters_required',steps={},automaticRetries=0} end
  end
  busy=false;return T.Status()
 end
 function T.Visual(value)
  if busy or invalid or not report or report.phase~='complete' or (value~='pass' and value~='fail') then return T.Status() end
  report.visual=value;local ok=pcall(save)
  if not ok then report.phase='review_required';report.reason='visual_report_write_failed' end
  return T.Status()
 end
 return T
end

if type(RegisterCommand)~='function' then return end
local flag='feather_native_acceptance_suite'
SetConvar(flag,'0') -- never inherit an armed suite after a resource restart
local path='native-acceptance-report.json'
local resource=GetCurrentResourceName()
local pending={};local serial=0;local lastMismatch
local expected={'6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb','4560a489-ca6c-11f1-9ad4-e0d55eaa2deb'}
local function enabled()
 return Config.DevMode==true and Config.NativeAlphaRuntime==true and Config.NativeAlphaLifecycleWearEnabled==true
  and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
  and (GetConvarInt(flag,0)==1 or GetConvarInt('feather_native_restart_suite',0)==1) and GetResourceState('feather-inventory')=='started'
  and GetResourceState('feather-weapons-native-proof')=='stopped'
end
local function current(actors)
 if not enabled() then return false end
 for _,a in ipairs(actors) do if not CoreAdapter.IsSessionCurrent(a.source,a.sessionId,a.characterId) then return false end end
 return true
end
local function discover()
 if not enabled() then error('acceptance_disabled') end
 local actors={}
 for _,raw in ipairs(GetPlayers()) do
  local target=tonumber(raw);local r=CoreAdapter.ResolveSession(target)
  if r and r.ok then for i,cid in ipairs(expected) do if r.value.characterId==cid then
   if actors[i] then error('duplicate_test_character') end
   if not WeaponNativeEnrollment.Allows(Config,cid) or WeaponNativeEquipmentBindings.IsStopping(target) then error('test_owner_not_available') end
   actors[i]={source=target,characterId=cid,sessionId=r.value.sessionId,label=i==1 and 'Jane' or 'John'}
  end end end
 end
 if not actors[1] or not actors[2] then error('both_test_characters_required') end
 return actors
end
local function identity(a)
 local state=WeaponCharacterAmmoDispatcher.Status(a.source)
 local b=state and state.identity
 if not state or state.phase~='active' or state.busy or not b or b.sessionId~=a.sessionId
  or b.characterId~=a.characterId or type(b.epoch)~='string' then error('active_idle_owner_required') end
 return {sessionId=b.sessionId,characterId=b.characterId,epoch=b.epoch}
end
RegisterNetEvent('feather-weapons:server:acceptance-report',function(ticket,value)
 local request=pending[source]
 if not enabled() or not request or request.ticket~=ticket or request.done then return end
 local clean=WeaponNativeAcceptanceView.Normalize(value)
 if not CoreAdapter.IsSessionCurrent(source,request.bound.sessionId,request.bound.characterId)
  or not clean or not WeaponNativeAcceptanceView.Equal(clean.identity,request.bound) then return end
 request.value=clean;request.done=true
end)
local function capture(actors)
 if not current(actors) then error('session_changed') end
 local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
 if not registry or type(registry.limits)~='table' then error('server_ammo_catalog_unavailable') end
 local read=exports['feather-inventory']:ReadNativeAcceptanceAudit(actors)
 if not read or not read.ok then
  local reason=type(read)=='table' and type(read.reason)=='string' and #read.reason<=80
   and read.reason:match('^[a-z_]+$') and read.reason or 'unavailable'
  error('durable_audit_'..reason)
 end
 local clients={}
 for i,a in ipairs(actors) do
  serial=serial+1
  local request={ticket=('acceptance:%s:%s'):format(GetGameTimer(),serial),bound=identity(a)}
  pending[a.source]=request
  TriggerClientEvent('feather-weapons:client:acceptance-read',a.source,request.ticket,request.bound)
  local started=GetGameTimer()
  while not request.done and (GetGameTimer()-started)%4294967296<10000 do
   if not current(actors) then pending[a.source]=nil;error('session_changed') end
   Wait(50)
  end
  pending[a.source]=nil
  if not request.done then error('client_readback_timeout') end
  clients[i]=request.value
  local matches,check,detail=WeaponNativeAcceptanceView.MatchesDurable(clients[i],read.value[i],registry.limits)
  if not matches then
   lastMismatch={actor=a.label,check=check,detail=detail}
   print('[WeaponNativeAcceptance] CHECK '..json.encode(lastMismatch))
   error('client_durable_'..check)
  end
 end
 if not current(actors) then error('session_changed') end
 return {durable=read.value,clients=clients}
end
local suite=S.New({
 load=function()
  local raw=LoadResourceFile(resource,path);if not raw or raw=='' then return nil end
  local ok,v=pcall(json.decode,raw);return ok and v or false
 end,
 save=function(report)
  local raw=json.encode(report);local ok=SaveResourceFile(resource,path,raw,#raw)
  return (ok==true or ok==1) and LoadResourceFile(resource,path)==raw
 end,
 id=function() return ('%s:%s'):format(os.time(),GetGameTimer()) end,
 discover=discover,current=current,capture=capture,
 failureDetail=function() return lastMismatch end,
 transition=function(a,overlap) return WeaponNativeEquipmentBindings.AcceptanceTransition(a.source,overlap) end,
 awaitRestore=function(a,oldEpoch)
  local started=GetGameTimer()
  while (GetGameTimer()-started)%4294967296<45000 do
   if not current({a}) then error('session_changed') end
   local status=WeaponNativeEquipmentBindings.AcceptanceStatus(a.source)
   if status and status.phase=='frozen' then error('transition_frozen_no_retry') end
   if status and status.phase=='active' and status.sessionId==a.sessionId then
    local now=identity(a);if now.epoch==oldEpoch then error('fresh_epoch_required') end
    return
   end
   Wait(50)
  end
  error('restore_timeout_no_retry')
 end,
 progress=function(name) print('[WeaponNativeAcceptance] PASS '..name) end
})
local running=false
local function report(value)
 local summary={phase=value.phase,runId=value.runId,reason=value.reason,pendingStep=value.pendingStep,
  automaticRetries=0,visual=value.visual,passed=#(value.steps or {}),total=3,reportFile=path}
 summary.failureDetail=value.failureDetail
 print('[WeaponNativeAcceptance] '..json.encode(summary))
 if value.phase=='complete' then print('[WeaponNativeAcceptance] Automated checks complete. Visual check: Jane draws her equipped weapons; John checks his existing utility wheel. Record visual pass or fail.') end
 if value.phase=='review_required' then print('[WeaponNativeAcceptance] STOP: report retained; no automatic replay or fixture repair. Inspect the named step before another test.') end
end
RegisterCommand('WeaponNativeAcceptance',function(source,args)
 if source~=0 or Config.DevMode~=true then return end
 local action=args and args[1]
 if action=='status' and #args==1 then return report(suite.Status()) end
 if action=='visual' and #args==2 and not running then return report(suite.Visual(args[2])) end
 if (action~='run' and action~='again') or #args~=1 or running or GetConvarInt(flag,0)~=1 or not enabled()
  or (WeaponRestartAcceptanceRuntime and WeaponRestartAcceptanceRuntime.Busy()) then
  return print('[WeaponNativeAcceptance] REFUSED development opt-in and run/status/visual required')
 end
 running=true
 lastMismatch=nil
 print('[WeaponNativeAcceptance] STARTED automatic identity discovery, state capture and three lifecycle checks; keep both players idle')
 CreateThread(function()
  local ok,value=pcall(suite.Run,action=='again')
  pending={};SetConvar(flag,'0');running=false
  report(ok and value or {phase='review_required',reason='suite_exception_no_retry'})
 end)
end,true)

-- Reuse the same challenged, bounded readback for restart comparisons.
WeaponNativeAcceptanceSuite.RestartAccess={discover=discover,capture=capture,identity=identity,
 busy=function() return running end}
