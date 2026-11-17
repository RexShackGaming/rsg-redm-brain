-- Cooperative scheduling exercises both real server release barriers. Native
-- clients and SQL audit reads are modeled, no item/economic mutation ports.
dofile('shared/native_acceptance_view.lua')
dofile('shared/character_ammunition.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function scenario(mode,recover)
 local commands,events,flags,files,documents,threads={},{},{},{},{},{}
 local seq,clock,begun,restored,acks,foreignReplies=0,0,0,0,0,0
 local collectionHints=0
 local states={}
 for _,id in ipairs({9,10}) do states[id]={phase='active',identity={characterId='c'..id,sessionId='s'..id,epoch='old'..id}} end
 GetCurrentResourceName=function() return 'feather-weapons' end
 GetGameTimer=function() return clock end
 GetConvarInt=function(k,d) return flags[k] or d end
 SetConvar=function(k,v) flags[k]=tonumber(v) end
 RegisterCommand=function(k,v) commands[k]=v end
 RegisterNetEvent=function(k,v) events[k]=v end
 AddEventHandler=function(k,v) events[k]=v end
 CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
 Wait=function() coroutine.yield() end
 json={encode=function(v) seq=seq+1;documents[tostring(seq)]=copy(v);return tostring(seq) end,decode=function(v) return copy(documents[v]) end}
 SaveResourceFile=function(_,name,raw) files[name]=raw;return true end
 LoadResourceFile=function(_,name) return files[name] end
 GetPlayers=function() return mode=='one-player' and {'9'} or {'9','10'} end
 GetResourceState=function() return 'missing' end
 CoreAdapter={ResolveSession=function(id) local s=states[id];return {ok=s~=nil,value=s and copy(s.identity)} end,
  IsSessionCurrent=function(id,sid,cid) if mode=='source-reset' then source=0 end;local s=states[id];return s and s.identity.sessionId==sid and s.identity.characterId==cid end}
 WeaponCharacterAmmoDispatcher={Status=function(id) return states[id] end}
 WeaponCharacterAmmoPolicy={Build=function() return {limits={ammo=10}} end}
 WeaponDefinitionCatalog={}
 WeaponGuidAcceptance={Matrix=function() error('shared must not run firearm matrix') end}
 WeaponNativeThrowableLifetimeCapture={New=function() return {Report=function() return {phase=mode=='world-unavailable' and 'unconfirmed' or 'matched',matches={},records={},counters={},rejected={}} end} end}
 WeaponNativeProjectileCollectionProbe={New=function() return {
  Hint=function(kind,value,player) assert(kind=='collection_event' and player==10);collectionHints=collectionHints+1 end,
  Report=function() return {phase=(mode=='uncorrelated' or mode=='competing' or mode=='competing-missing') and 'review_required' or 'correlated_observation',expectedAmbiguityRefused=mode=='competing' or mode=='competing-missing',syntheticBatchAbsent=mode=='competing'} end} end}
 local audits={}
 exports={['feather-inventory']={ReadNativeAcceptanceAudit=function(_,actors)
  local id=actors[1].source;audits[id]=(audits[id] or 0)+1
  return {ok=true,value={{items={},equipment={},ammo={{revision=1,pools={ammo=0}}}}}}
 end}}
 local ticket
 local function call(id,name,...)
  local old=source;source=id;events[name](...);source=old
 end
 TriggerClientEvent=function(name,id,t,bound,total,variant)
  if name=='feather-weapons:client:guid-suite-read' then
   call(id,'feather-weapons:server:guid-suite-read',t,{identity=copy(bound),revision=1,pools={ammo=0},copies=0,utility={},melee={},maintenance={}})
  elseif name=='feather-weapons:client:guid-suite-shared-collector' then
   assert(id==10 and states[10].phase=='released');ticket=t
   if mode=='competing' or mode=='competing-missing' then assert(variant==2,'recipient requires two-unit batch') else assert(variant==nil) end
   call(9,'feather-weapons:server:guid-suite-shared-ready',t) -- wrong role ignored
   call(10,'feather-weapons:server:guid-suite-shared-ready','stale')
   call(10,'feather-weapons:server:guid-suite-shared-ready',t)
  elseif name=='feather-weapons:client:guid-suite-throwable' then
   assert(id==9 and variant==((mode=='competing' or mode=='competing-missing') and 'shared-competing' or 'shared') and t==ticket and states[10].phase=='released')
   call(10,'feather-weapons:server:guid-suite-collection-hint',t,'collection_event',{})
   local row={id='throwable:shared-collector',phase=mode=='peer-cleanup-fail' and 'failed' or 'passed',cleanupComplete=mode~='peer-cleanup-fail',captured=true,syntheticNativeOnly=true,economicWrites=0,expectedUnits=2,quantityAtCapture=2,captureMode='zero_ammo_carrier',pickupEvents={{},{}}}
   local raw=json.encode(row)
   call(9,'feather-weapons:server:guid-suite-shared-result',t,raw)
   assert(acks==0,'thrower cannot report collector cleanup')
   call(10,'feather-weapons:server:guid-suite-shared-result',t,raw)
   call(10,'feather-weapons:server:guid-suite-shared-result',t,raw)
   assert(acks==2,'report resend acknowledges identical evidence only')
   call(9,'feather-weapons:server:guid-suite-chunk',t,1,json.encode({first=1,rows={{id='throwable:world-capture',phase='passed',cleanupComplete=true}}}))
   call(9,'feather-weapons:server:guid-suite-result',t,2,json.encode({wireVersion=2,phase='complete',passed=1,total=1,caseCount=1,cleanupComplete=true}))
  elseif name=='feather-weapons:client:guid-suite-shared-ack' then assert(id==10,'collector acknowledgements keep the captured event source');acks=acks+1
  elseif name=='feather-weapons:client:guid-suite-shared-collected' then assert(id==9);foreignReplies=foreignReplies+1
  elseif name=='feather-weapons:client:guid-suite-report-ack' or name=='feather-weapons:client:guid-suite-cancel' then return
  else error(name) end
 end
 WeaponNativeEquipmentBindings={GuidValidationTransition=function(id)
  assert(WeaponGuidAcceptanceServer.Reserved(id));begun=begun+1;states[id].phase='released'
  CreateThread(function()
   local ok,result=pcall(WeaponGuidAcceptanceServer.BeforeRebuild,id)
   if ok and result then restored=restored+1;states[id].phase='active';states[id].identity.epoch='fresh'..id
   else states[id].phase='frozen' end
  end)
  return {ok=true}
 end,AcceptanceStatus=function(id) return states[id] end}
 dofile('server/services/native_guid_acceptance.lua')
 flags.feather_native_guid_suite=1
 commands.WeaponGuidAcceptance(0,{(mode=='competing' or mode=='competing-missing') and 'shared-competing' or 'shared','9',mode=='same-role' and '9' or '10'})
 for tick=1,1000 do
  local alive=false;clock=clock+50
  for _,co in ipairs(threads) do if coroutine.status(co)~='dead' then alive=true;local ok,why=coroutine.resume(co);assert(ok,why) end end
  if not alive then break end
 end
 if recover then
  for id,state in pairs(states) do state.phase='active';state.identity.epoch='rejoined'..id;state.identity.sessionId='fresh-sid'..id end
  if recover=='same-session' then states[10].identity.sessionId='s10' end
  if recover=='changed-state' then
   local originalAudit=exports['feather-inventory'].ReadNativeAcceptanceAudit
   exports['feather-inventory'].ReadNativeAcceptanceAudit=function(...)
    local result=originalAudit(...);result.value[1].items={{id=999}};return result
   end
  end
  flags.feather_native_guid_suite=1
  commands.WeaponGuidAcceptance(0,{'recover-shared','9','10'})
  for tick=1,100 do
   local alive=false;clock=clock+50
   for _,co in ipairs(threads) do if coroutine.status(co)~='dead' then alive=true;local ok,why=coroutine.resume(co);assert(ok,why) end end
   if not alive then break end
  end
 end
 local report=copy(documents[files['native-guid-acceptance-report.json']])
 return report,begun,restored,audits,foreignReplies,collectionHints
end
for _,mode in ipairs({'one-player','same-role'}) do local _,begun=scenario(mode);assert(begun==0,mode) end
local report,begun,restored,audits,foreignReplies=scenario('success')
assert(begun==2 and restored==2 and foreignReplies==1 and audits[9]==2 and audits[10]==2,
 table.concat({begun,restored,foreignReplies,audits[9] or 0,audits[10] or 0,tostring(report and report.reason)},','))
assert(report.restored and report.collectorRestored and report.sharedCollector.phase=='passed' and report.kind=='throwable_shared_collection')
assert(report.phase=='complete' and report.lifecycle.phase=='passed' and report.lifecycle.bothLoadoutsRestored)
local report=scenario('world-unavailable')
assert(report.phase=='complete' and report.lifecycle.phase=='passed' and report.world.phase=='unconfirmed',
 'synthetic shared lifecycle success retains independent unavailable model diagnostic')
assert(report.acceptanceScope=='synthetic_shared_native_lifecycle' and report.lifecycle.economicWrites==0
 and not report.lifecycle.canClaim and not report.lifecycle.pickupCredits and not report.lifecycle.originConfirmed)
local report,begun,restored,_,_,hints=scenario('source-reset')
assert(report.restored and report.collectorRestored and begun==2 and restored==2 and hints==1,
 'yielding Core calls must not turn a foreign collector into source0 or the thrower')
local report,begun,restored,_,foreignReplies=scenario('peer-cleanup-fail')
assert(begun==2 and restored==0 and foreignReplies==0 and report.cleanupComplete==false,'partial cleanup cannot certify the group or release the thrower')
local report,begun,restored,_,foreignReplies=scenario('uncorrelated')
assert(foreignReplies==0,'collector cleanup never certifies removal of an unrelated thrower world unit')
assert(report.phase=='review_required' and report.reason=='shared_collection_not_correlated'
 and report.lifecycle.phase=='review_required','matched model diagnostic cannot substitute for bound shared collection')
local report,begun,restored=scenario('peer-cleanup-fail','success')
assert(report.phase=='recovered_shared_session_failure' and report.recovery.phase=='confirmed'
 and report.restored and report.collectorRestored and report.cleanupComplete==false and begun==2 and restored==0,
 'fresh session verification performs no native transition/retry and preserves original failed cleanup')
local report=scenario('peer-cleanup-fail','same-session')
assert(report.phase=='review_required' and not report.recovery,'both participants must have new sessions')
local report=scenario('peer-cleanup-fail','changed-state')
assert(report.phase=='review_required' and report.recovery.phase=='refused' and report.before.durable.items[1]==nil,
 'changed durable state is retained, never repaired to fit the test')
print('PASS two-player acceptance server: explicit distinct roles, both release barriers, collector-only replies, report-only resend, both durable/native snapshots and fresh restores')

local report,_,restored,_,reply=scenario('competing')
assert(report.phase=='complete' and restored==2 and reply==1 and report.lifecycle.expectedAmbiguityRefused and not report.lifecycle.collectionCorrelated)
assert(report.acceptanceScope=='synthetic_competing_native_cleanup' and not report.lifecycle.canClaim)
local report,_,_,_,reply=scenario('competing-missing')
assert(reply==0 and report.phase=='review_required','negative verdict never releases thrower without all registered native lifetimes absent')
