local flag='feather_native_restart_suite'
SetConvar(flag,'0')
local resource=GetCurrentResourceName()
local path='native-restart-report.json'
local function enabled() return Config.DevMode==true and Config.NativeAlphaRuntime==true and GetConvarInt(flag,0)==1 end
local gates={'feather_native_knife','feather_native_melee','feather_native_throwable','feather_native_utility',
 'feather_native_lasso_reinforced','feather_native_davy_lantern','feather_native_binoculars','feather_native_camera',
 'feather_native_camera_advanced','feather_native_binoculars_improved','feather_native_metal_detector','feather_native_fishing_rod'}
local function readGates() local values={};for _,name in ipairs(gates) do values[name]=GetConvarInt(name,0);assert(values[name]==0 or values[name]==1,'gameplay_switch_not_boolean') end;return values end
local function gatesMatch(values)
 if type(values)~='table' then return false end
 for _,name in ipairs(gates) do if values[name]~=GetConvarInt(name,0) then return false end end;return true
end
local function access() return WeaponNativeAcceptanceSuite.RestartAccess end
local function capture()
 local a=access();return a.capture(a.discover())
end
local failureDetail
local suite=WeaponRestartAcceptance.New({
 load=function()
  local raw=LoadResourceFile(resource,path);if not raw or raw=='' then return nil end
  local ok,value=pcall(json.decode,raw);return ok and value or false
 end,
 save=function(report)
  local raw=json.encode(report);local ok=SaveResourceFile(resource,path,raw,#raw)
  return (ok==true or ok==1) and LoadResourceFile(resource,path)==raw
 end,
 id=function() return ('%s:%s'):format(os.time(),GetGameTimer()) end,
 failureDetail=function() return failureDetail end,
 equal=WeaponNativeAcceptanceView.Equal,capture=capture,readGates=readGates,gatesMatch=gatesMatch,
 sealAndRestore=function()
  local a=access();assert(not a.busy(),'acceptance_suite_busy')
  local actors=a.discover()
  for _,actor in ipairs(actors) do
   local old=a.identity(actor)
   local result=WeaponNativeEquipmentBindings.AcceptanceTransition(actor.source,false)
   if not result or not result.ok then
    failureDetail={actor=actor.label,source=actor.source,code=result and result.error and result.error.code or 'missing_transition_reply'}
    print('[WeaponRestartAcceptance] REFUSED '..json.encode(failureDetail))
    error('restart_seal_restore_refused')
   end
   local start=GetGameTimer();local restored=false
   while (GetGameTimer()-start)%4294967296<45000 do
    assert(CoreAdapter.IsSessionCurrent(actor.source,actor.sessionId,actor.characterId),'restart_session_changed')
    local state=WeaponNativeEquipmentBindings.AcceptanceStatus(actor.source)
    if state and state.phase=='frozen' then error('restart_restore_frozen') end
    if state and state.phase=='active' and a.identity(actor).epoch~=old.epoch then restored=true;break end
    Wait(50)
   end
   assert(restored,'restart_restore_timeout')
  end
 end,
 probeIdle=function() local p=exports['feather-inventory']:ReadRestartRecovery(false);return p and p.ok and p.phase=='idle' end,
 prepareProbe=function(mode) return exports['feather-inventory']:PrepareRestartRecovery(mode) end,
 probeStatus=function() return exports['feather-inventory']:ReadRestartRecovery(false) end,
 verifyProbe=function() return exports['feather-inventory']:ReadRestartRecovery(true) end
})
local running=false
WeaponRestartAcceptanceRuntime={Busy=function() return running end}
local function report(value)
 local inspection=value.inspections and value.inspections[#value.inspections]
 local comparison=value.comparisonSource=='verification' and value.lastComparison and value.lastComparison.detail
  or inspection and inspection.detail or value.lastComparison and value.lastComparison.detail
 local proof
 local ok,p=pcall(function() return exports['feather-inventory']:ReadRestartRecovery(false) end)
 if ok then proof=p end
 print('[WeaponRestartAcceptance] '..json.encode({phase=value.phase,mode=value.mode,reason=value.reason,waitingReason=value.waitingReason,comparison=comparison,inspectionError=value.inspectionError,
  passed=#(value.steps or {}),total=2,failureDetail=value.failureDetail or failureDetail,visual=value.visual,reportFile=path,probe=proof,automaticMutationRetries=0}))
 if value.phase=='awaiting_restart' then print('[WeaponRestartAcceptance] Evidence saved. Perform only the named prepared restart and keep gameplay idle. After both characters return, use verify; do not repeat preparation or a restart to bypass pending evidence.') end
end
RegisterCommand('WeaponRestartAcceptance',function(source,args)
 if source~=0 or Config.DevMode~=true then return end
 local action=args and args[1]
 if action=='status' and #args==1 then return report(suite.Status()) end
 if action=='settings' and #args==1 and not running then
  local state=suite.Status();local values=state.gameplayConvars
  local proof=exports['feather-inventory']:ReadRestartRecovery(false)
  if #GetPlayers()~=0 or not proof or not proof.ok or proof.released~=true or not state.prepared or proof.hostToken==state.prepared.hostToken then
   return print('[WeaponRestartAcceptance] REFUSED a new server process and disconnected clients are required before restoring settings')
  end
  if state.phase~='awaiting_restart' or state.mode~='server' or type(values)~='table' then return print('[WeaponRestartAcceptance] REFUSED no recorded server restart settings') end
  for _,name in ipairs(gates) do if values[name]~=0 and values[name]~=1 then return print('[WeaponRestartAcceptance] REFUSED invalid recorded gameplay settings') end end
  for _,name in ipairs(gates) do SetConvarReplicated(name,tostring(values[name])) end
  return print('[WeaponRestartAcceptance] Recorded gameplay switches restored; no issuance or fault-injection flags enabled.')
 end
 if action=='visual' and #args==2 and not running then
  local value=suite.Visual(args[2]);if value.phase=='complete' and value.visual=='pass' then SetConvar(flag,'0') end
  return report(value)
 end
 if running or not enabled() or access().busy() then return print('[WeaponRestartAcceptance] REFUSED idle development opt-in required') end
 if not ((action=='prepare' and #args==2 and (args[2]=='server' or args[2]=='database')) or ((action=='verify' or action=='retry-preflight' or action=='inspect') and #args==1)) then return end
 running=true
 CreateThread(function()
  local method=action=='prepare' and function() return suite.Prepare(args[2]) end
   or action=='retry-preflight' and suite.RetryPreflight or action=='inspect' and suite.Inspect or suite.Verify
  local ok,value=pcall(method)
  running=false
  report(ok and value or {phase='review_required',reason='restart_suite_exception_no_retry'})
 end)
end,true)
