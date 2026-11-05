-- Restart journal: never replays preparation after an interrupted dispatch.
WeaponRestartAcceptance={}
local R=WeaponRestartAcceptance
local function clone(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
-- Match the existing NativeAcceptanceView wear contract. Durable state and
-- every field outside these exact native-maintenance paths remain exact.
local wearFields={damage=true,degradation=true,dirt=true,soot=true,permanentDegradation=true}
local function sameNativeWear(a,b,path)
 local field=path:match('^clients%[%d+%]%.maintenance%[%d+%]%.wear%.([%a]+)$')
 return field and wearFields[field] and type(a)=='number' and type(b)=='number'
  and a==a and b==b and a>=0 and a<=1 and b>=0 and b<=1 and math.abs(a-b)<=0.000001
end
function R.Conserved(a,b,equal) return R.Compare(a,b).equal end
function R.Compare(a,b)
 local x,y=clone(a),clone(b)
 for _,snapshot in ipairs({x,y}) do
  for _,client in ipairs(snapshot.clients or {}) do client.identity.sessionId='';client.identity.epoch='' end
 end
 local changes,total,rounded={},0,{}
 local function brief(v)
  if type(v)=='table' then local n=0;for _ in pairs(v) do n=n+1 end;return {type='table',entries=n} end
  if type(v)=='string' and #v>128 then return v:sub(1,128)..'...' end
  return v
 end
 local function walk(left,right,path)
  if type(left)=='table' and type(right)=='table' then
   local keys,seen={},{}
   for k in pairs(left) do keys[#keys+1]=k;seen[k]=true end
   for k in pairs(right) do if not seen[k] then keys[#keys+1]=k end end
   table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
   for _,k in ipairs(keys) do walk(left[k],right[k],path..(type(k)=='number' and ('['..k..']') or ('.'..tostring(k)))) end
  elseif type(left)~=type(right) or left~=right then
   if sameNativeWear(left,right,path) then
    rounded[#rounded+1]={path=path,beforeExact=string.format('%.17g',left),afterExact=string.format('%.17g',right),absoluteDifference=math.abs(left-right)}
    return
   end
   total=total+1
   if #changes<20 then changes[#changes+1]={path=path,before=brief(left),after=brief(right),beforeType=type(left),afterType=type(right)} end
  end
 end
 walk(x.durable,y.durable,'durable');walk(x.clients,y.clients,'clients')
 local extras={};for k in pairs(x) do if k~='durable' and k~='clients' then extras[k]=true end end
 for k in pairs(y) do if k~='durable' and k~='clients' then extras[k]=true end end
 for k in pairs(extras) do walk(x[k],y[k],tostring(k)) end
 return {equal=total==0,totalDifferences=total,differences=changes,truncated=total>#changes,
  nativeWearTolerance=0.000001,acceptedWearRounding=rounded,durableComparison='exact'}
end
function R.New(api)
 local report=api.load();local busy=false
 local valid={preparing=true,awaiting_restart=true,server_passed=true,complete=true,review_required=true}
 local invalid=report~=nil and (type(report)~='table' or report.version~=1 or not valid[report.phase] or type(report.steps)~='table' or type(report.runId)~='string'
  or (report.phase=='awaiting_restart' and (type(report.before)~='table' or type(report.prepared)~='table' or (report.mode~='server' and report.mode~='database')))
  or (report.phase=='server_passed' and (#report.steps~=1 or report.steps[1].mode~='server'))
  or (report.phase=='complete' and (#report.steps~=2 or report.steps[1].mode~='server' or report.steps[2].mode~='database')))
 if report and not invalid and report.phase=='preparing' then report.phase='review_required';report.reason='interrupted_prepare_no_replay' end
 local T={}
 local function save() assert(api.save(report)==true,'restart_report_not_durable') end
 function T.Status() return invalid and {phase='invalid_report_no_retry'} or clone(report or {phase='idle',steps={}}) end
 function T.Busy() return busy end
 function T.Prepare(mode)
  if busy or invalid or (mode~='server' and mode~='database') then return T.Status() end
  if report and (report.phase~='server_passed' or mode~='database') then return T.Status() end
  if not report and mode~='server' then return {phase='refused',reason='server_restart_first',steps={}} end
  busy=true
  local ok,why=pcall(function()
   report=report or {version=1,runId=api.id(),steps={},visual='pending',automaticMutationRetries=0}
   report.phase='preparing';report.mode=mode;save()
   api.sealAndRestore()
   report.before=api.capture()
   if mode=='server' and api.readGates then report.gameplayConvars=api.readGates() end
   save()
   local prepared=api.prepareProbe(mode)
   assert(prepared and prepared.ok,'restart_probe_prepare_unconfirmed_no_retry')
   report.prepared=prepared;report.phase='awaiting_restart';save()
  end)
  if not ok and report then report.phase='review_required';report.reason=tostring(why):match('([a-z_]+)$') or 'restart_prepare_failed'
   if api.failureDetail then report.failureDetail=clone(api.failureDetail()) end
   pcall(save) end
  busy=false;return T.Status()
 end
 -- Explicit recovery ONLY for an earlier refused seal with no captured baseline
 -- or probe dispatch. Never replay seals: validate fresh read-only evidence.
 function T.RetryPreflight()
  if busy or invalid or not report or report.phase~='review_required'
   or report.reason~='restart_seal_restore_refused' or #report.steps~=0
   or report.before~=nil or report.prepared~=nil or report.mode~='server' then return T.Status() end
  busy=true
  local original=clone(report)
  local ok,why=pcall(function()
   assert(api.probeIdle()==true,'restart_probe_not_idle')
   local snapshot=api.capture() -- challenges current idle owners and SQL; no seal replay
   local gates=api.readGates and api.readGates() or nil
   assert(api.probeIdle()==true,'restart_probe_not_idle')
   report={version=1,runId=api.id(),phase='preparing',mode='server',steps={},visual='pending',
    automaticMutationRetries=0,before=snapshot,gameplayConvars=gates,priorPreflight=original,
    resumedWithoutSealReplay=true}
   save()
   local prepared=api.prepareProbe('server')
   assert(prepared and prepared.ok,'restart_probe_prepare_unconfirmed_no_retry')
   report.prepared=prepared;report.phase='awaiting_restart';save()
  end)
  if not ok then
   -- Once a baseline/probe dispatch is journaled, this action cannot run again.
   if report~=nil and report.before~=nil then
    report.phase='review_required';report.reason=tostring(why):match('([a-z_]+)$') or 'restart_preflight_failed';pcall(save)
   else report=original end
  end
  busy=false;return T.Status()
 end
 function T.Verify()
  local rechecking=report and report.phase=='review_required' and report.reason=='restart_snapshot_changed_no_repair'
   and type(report.before)=='table' and type(report.prepared)=='table'
  if busy or invalid or not report or (report.phase~='awaiting_restart' and not rechecking) then return T.Status() end
  busy=true
  local ok,why=pcall(function()
   if api.gatesMatch and not api.gatesMatch(report.gameplayConvars) then if rechecking then report.waitingReason='restore_recorded_gameplay_settings' else report.reason='restore_recorded_gameplay_settings' end;return end
   local proof=api.verifyProbe()
   if not proof or proof.ok~=true then return end -- read-only retry while recovery settles
   assert(proof.mode==report.mode,'restart_probe_mode_mismatch')
   local captured,after=pcall(api.capture)
   if not captured then
    for _,code in ipairs({'both_test_characters_required','active_idle_owner_required','client_readback_timeout','session_changed','test_owner_not_available'}) do
     if tostring(after):find(code,1,true) then if rechecking then report.waitingReason='waiting_for_active_test_characters' else report.reason='waiting_for_active_test_characters' end;return end
    end
    error('restart_capture_unavailable')
   end
   if rechecking and not report.originalFailedComparison then
    local previous=report.lastComparison or report.inspections and report.inspections[#report.inspections]
    report.originalFailedComparison=previous and clone(previous) or nil
   end
   report.lastComparison={after=clone(after),detail=R.Compare(report.before,after)}
   report.comparisonSource='verification';report.comparisonPolicy='native_maintenance_1e_6_durable_exact'
   save() -- retain the exact failed AFTER evidence before refusing
   assert(R.Conserved(report.before,after,api.equal),'restart_snapshot_changed_no_repair')
   if report.mode=='server' then
    assert(proof.hostToken~=report.prepared.hostToken,'full_server_restart_not_observed')
    for i,client in ipairs(after.clients) do assert(client.identity.sessionId~=report.before.clients[i].identity.sessionId,'fresh_server_session_required') end
   else
    assert(proof.hostToken==report.prepared.hostToken,'server_changed_during_database_test')
   end
   report.steps[#report.steps+1]={mode=report.mode,phase='passed',proof=proof,before=clone(report.before),after=after}
   report.phase=report.mode=='server' and 'server_passed' or 'complete';report.before=nil;report.reason=nil;report.waitingReason=nil;save()
  end)
  if not ok then report.phase='review_required';report.reason=tostring(why):match('([a-z_]+)$') or 'restart_verify_failed';pcall(save) end
  busy=false;return T.Status()
 end
 function T.Inspect()
  if busy or invalid or not report or type(report.before)~='table'
   or (report.phase~='review_required' and report.phase~='awaiting_restart') then return T.Status() end
  if #(report.inspections or {})>=5 then return T.Status() end
  busy=true
  local ok,why=pcall(function()
   local after=api.capture() -- SQL/client readbacks only; no seal or probe replay
   local probe=api.probeStatus and api.probeStatus() or nil
   report.inspections=report.inspections or {}
   report.inspections[#report.inspections+1]={after=after,detail=R.Compare(report.before,after),probe=probe}
   report.comparisonSource='inspection';report.inspectionError=nil;save()
  end)
  if not ok then report.inspectionError='restart_inspection_unavailable';pcall(save) end
  busy=false;return T.Status()
 end
 function T.Visual(value)
  if busy or invalid or not report or report.phase~='complete' or (value~='pass' and value~='fail') then return T.Status() end
  report.visual=value
  if value=='fail' then report.phase='review_required';report.reason='visual_failed' end
  if not pcall(save) then report.phase='review_required';report.reason='restart_visual_not_durable' end
  return T.Status()
 end
 return T
end
