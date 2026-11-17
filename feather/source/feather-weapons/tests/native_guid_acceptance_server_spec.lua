dofile('shared/native_acceptance_view.lua')
dofile('shared/character_ammunition.lua')
dofile('server/services/native_throwable_lifetime_capture.lua')
dofile('server/services/native_throwable_transition_binding.lua')
dofile('server/services/native_throwable_transition_protocol.lua')
local RealLifetimeCapture=WeaponNativeThrowableLifetimeCapture
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local function fixture(mode)
 local commands,events,flags,files,documents={},{},{},{},{}
 local sequence,clock,transitions,restores=0,0,0,0
 local sid='s'
 local removedEntities={};local landingReplies={}
 local state={phase='active',identity={characterId='arbitrary-current-player',sessionId='s',epoch='old'}}
 local wear={damage=0,degradation=0,dirt=0,soot=0,permanentDegradation=0}
 local durable={items={{id=1,row_revision=1,metadata={maintenance=wear}}},equipment={{slot='weapon',inventory_items_id=1}},
  ammo={{revision=57,pools={ammo=1}}},guards={{id=1,moveBlocked=true}}}
 Config={DevMode=false}
 GetCurrentResourceName=function() return 'feather-weapons' end
 GetConvarInt=function(name,default) if flags[name]~=nil then return flags[name] end;return default end
 SetConvar=function(name,value) flags[name]=tonumber(value) end
 GetGameTimer=function() return clock end
 Wait=function(ms) clock=clock+(mode=='timeout' and 1900000 or ms) end
 RegisterCommand=function(name,fn) commands[name]=fn end
 RegisterNetEvent=function(name,fn) events[name]=fn end
 AddEventHandler=function(name,fn) events[name]=fn end
 SetTimeout=function(_,fn) fn() end
 joaat=function(name) return ({WEAPON_THROWN_TOMAHAWK=101,w_melee_tomahawk01=201,w_melee_tomahawk02=202})[name] end
 DoesEntityExist=function(handle) return not removedEntities[handle] end
 GetEntityType=function() return 3 end
 GetNetTypeFromEntity=function(handle) return mode=='landing-protocol' and handle==50 and 23 or 8 end
 GetEntityModel=function() return 201 end
 GetPlayerPed=function() return 5 end
 GetEntityCoords=function() return {x=0,y=0,z=0} end
 NetworkGetEntityFromNetworkId=function(id) assert(id==16);return 50 end
 NetworkGetNetworkIdFromEntity=function(handle) return handle==51 and 17 or 16 end
 NetworkGetEntityOwner=function() return 9 end
 GetEntityRoutingBucket=function() return 1 end
 GetPlayerRoutingBucket=function() return 1 end
 CreateThread=function(fn) fn() end
 json={encode=function(v) sequence=sequence+1;documents[tostring(sequence)]=copy(v);return tostring(sequence) end,
  decode=function(raw) return copy(documents[raw]) end}
 SaveResourceFile=function(_,path,raw) files[path]=raw;return true end
 LoadResourceFile=function(_,path) return files[path] end
 CoreAdapter={ResolveSession=function(target) return {ok=target==9,value={characterId=state.identity.characterId,sessionId=sid}} end,
  IsSessionCurrent=function(target,session,cid) return target==9 and session==sid and cid==state.identity.characterId end}
 WeaponCharacterAmmoDispatcher={Status=function() return state end}
 WeaponCharacterAmmoPolicy={Build=function() return {limits={ammo=10}} end}
 WeaponDefinitionCatalog={}
 WeaponGuidAcceptance={Matrix=function() return {{id='one'},{id='two'}} end}
 GetResourceState=function() return (mode=='throwable' or mode=='throwable-unmatched') and 'missing' or 'stopped' end
 GetPlayers=function() return mode=='multiple' and {'9','10'} or {'9'} end
 exports={['feather-inventory']={ReadNativeAcceptanceAudit=function(_,actors)
  assert(#actors==1 and actors[1].source==9)
  return {ok=true,value={copy(durable)}}
 end}}
 TriggerClientEvent=function(name,target,ticket,bound,total,variant)
  if name=='feather-weapons:client:guid-suite-read' then
   source=8;events['feather-weapons:server:guid-suite-read'](ticket,{}) -- foreign reply is ignored
   source=9
   local view={identity=copy(bound),revision=57,pools={ammo=1},copies=1,utility={},melee={},
    maintenance={{id=1,revision=1,wear=copy(wear)}}}
   events['feather-weapons:server:guid-suite-read'](ticket,view)
  elseif name=='feather-weapons:client:guid-suite-report-ack' then return
  elseif name=='feather-weapons:client:guid-suite-landing-result' then landingReplies[#landingReplies+1]=copy(variant);return
  elseif name=='feather-weapons:client:guid-suite-run' or name=='feather-weapons:client:guid-suite-transport' or name=='feather-weapons:client:guid-suite-throwable' then
   if mode=='timeout' then
    source=9;events['feather-weapons:server:guid-suite-progress'](ticket,total,total,'two');return
   end
   source=9
   local success=mode~='retained' and mode~='clean-failure' and mode~='landing-retained'
   local value={phase=success and 'complete' or 'review_required',total=total,passed=success and total or 0,
    cleanupComplete=mode~='retained' and mode~='landing-retained',reason=not success and 'sentinel_failure' or nil,
    failedCase=not success and 'one' or nil,cases=success and {{id='one',phase='passed',cleanupComplete=true},{id='two',phase='passed',cleanupComplete=true}}
     or {{id='one',phase='failed',cleanupComplete=mode~='retained'}}}
   if mode=='landing' or mode=='landing-retained' or mode=='landing-candidate' or mode=='landing-protocol' then
    assert(variant=='landing' and total==1 and name=='feather-weapons:client:guid-suite-throwable')
    value.cases={{id='throwable:landing-cleanup',phase=success and 'passed' or 'failed',cleanupComplete=success,syntheticNativeOnly=true,economicWrites=0}}
    if mode=='landing-protocol' then
     events.entityCreated(50);clock=50;removedEntities[50]=true;events.entityRemoved(50)
     clock=100;events.entityCreated(51)
     local transition={id='landing-loan',projectileNetworkId=16,pickupNetworkId=17}
     source=8;events['feather-weapons:server:guid-suite-landing-action'](ticket,'transition',transition)
     source=9;events['feather-weapons:server:guid-suite-landing-action']('foreign','transition',transition)
     assert(#landingReplies==0,'foreign source/ticket cannot obtain transition authorization')
     events['feather-weapons:server:guid-suite-landing-action'](ticket,'transition',transition)
     assert(landingReplies[#landingReplies].phase=='transition_authorized')
     events['feather-weapons:server:guid-suite-landing-action'](ticket,'landing',
      {id='landing-loan',transitionToken=landingReplies[#landingReplies].transitionToken,position={x=0,y=0,z=0}})
     local cleanupToken=landingReplies[#landingReplies].cleanupToken;assert(cleanupToken)
     events['feather-weapons:server:guid-suite-landing-action'](ticket,'cleaned',{id='landing-loan',cleanupToken='foreign'})
     assert(landingReplies[#landingReplies].phase=='refused')
     events['feather-weapons:server:guid-suite-landing-action'](ticket,'cleaned',{id='landing-loan',cleanupToken=cleanupToken})
     assert(landingReplies[#landingReplies].phase=='pending','client ACK cannot bypass server absence')
     clock=1100;removedEntities[51]=true;events.entityRemoved(51)
     events['feather-weapons:server:guid-suite-landing-action'](ticket,'status',{id='landing-loan'})
     assert(landingReplies[#landingReplies].phase=='available')
    end
    if mode=='landing-candidate' then
     events.entityCreated(50)
     events['feather-weapons:server:guid-suite-object-hint'](ticket,16,201)
     value.cases[1].worldEvidence={{kind='tomahawk_object_snapshot',candidateOnly=true,
      object={networked=true,networkId=16,model=201}}}
    end
   end
   if mode=='throwable' or mode=='throwable-unmatched' or mode=='throwable-lookup' then
    assert(total==1 and name=='feather-weapons:client:guid-suite-throwable')
    if mode=='throwable-lookup' then
     source=8;events['feather-weapons:server:guid-suite-object-hint'](ticket,16,201)
     source=9;events['feather-weapons:server:guid-suite-object-hint']('foreign-ticket',16,201)
     events['feather-weapons:server:guid-suite-object-hint'](ticket,16,201)
    end
    if mode=='throwable' then
     events.entityCreated(50);events.startProjectileEvent(9,{weaponHash=101});events.entityRemoved(50)
    end
    value.cases={{id='throwable:world-capture',phase='passed',cleanupComplete=true,
     worldEvidence={{kind='tomahawk_object_snapshot',object={networked=true,networkId=16,model=201}}}}}
   end
   local body=json.encode({first=1,rows=value.cases})
   events['feather-weapons:server:guid-suite-chunk']('stale-ticket',1,body)
   events['feather-weapons:server:guid-suite-chunk'](ticket,1,body)
   events['feather-weapons:server:guid-suite-chunk'](ticket,1,body) -- report-only duplicate, not native replay
   value.caseCount=#value.cases;value.cases=nil;value.wireVersion=2
   local final=json.encode(value)
   events['feather-weapons:server:guid-suite-result']('stale-ticket',2,final)
   events['feather-weapons:server:guid-suite-result'](ticket,2,final)
   events['feather-weapons:server:guid-suite-result'](ticket,2,final) -- lost final acknowledgement is safe

  elseif name~='feather-weapons:client:guid-suite-cancel' then error(name) end
 end
 WeaponNativeThrowableLifetimeCapture=RealLifetimeCapture
 WeaponNativeEquipmentBindings={GuidValidationTransition=function(target)
  transitions=transitions+1
  assert(WeaponGuidAcceptanceServer.Reserved(target) and WeaponGuidAcceptanceServer.Timeout(target)>45000)
  state.phase='released'
  if WeaponGuidAcceptanceServer.BeforeRebuild(target) then
   restores=restores+1;state.phase='active';state.identity.epoch='fresh'
  else state.phase='frozen' end
  return {ok=true}
 end,AcceptanceStatus=function() return {phase=state.phase} end}
 dofile('server/services/native_guid_acceptance.lua')
 local function result() return copy(documents[files['native-guid-acceptance-report.json']]),transitions,restores end
 return commands,flags,result,function(changed) sid='fresh-session';state.phase='active';state.identity.sessionId=sid;state.identity.epoch='fresh-epoch'
  if changed then durable.items[1].metadata.condition=0 end
 end
end
for _,mode in ipairs({'success','clean-failure','retained','timeout'}) do
 local commands,flags,result=fixture(mode)
 commands.WeaponGuidAcceptance(9,{'run','9'});assert(select(2,result())==0,'players cannot start suite')
 commands.WeaponGuidAcceptance(0,{'run','9'});assert(select(2,result())==0,'default off')
 flags.feather_native_guid_suite=1
 commands.WeaponGuidAcceptance(0,{'run','9'})
 local report,transitions,restores=result()
 assert(transitions==1 and flags.feather_native_guid_suite==0,'one reservation, opt-in consumed')
 if mode=='success' then
  assert(report.phase=='complete' and report.restored and restores==1 and report.before.client.identity.epoch=='old')
 elseif mode=='clean-failure' then assert(report.phase=='review_required' and report.restored and restores==1)
 else
  assert(report.phase=='review_required' and restores==0,'uncertain cleanup must never rebuild over retained copies')
  if mode=='retained' then assert(report.reason=='sentinel_failure' and report.transitionReason,'native failure reason survives outer transition failure') end
 end
end
print('GUID server orchestration PASS (normal mode, console/opt-in/source/ticket gates, one transition, durable/client comparison, cleaned failure restore, retained/timeout hold)')
local commands,flags,result=fixture('landing')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'landing','9'})
local report,transitions,restores=result()
assert(report.kind=='throwable_landing_cleanup' and report.phase=='review_required' and transitions==1 and restores==0
 and report.world.phase=='unconfirmed' and report.reason=='server_pickup_cleanup_not_confirmed',
 'client completion alone cannot bypass server transition/removal confirmation')
local commands,flags,result=fixture('landing-candidate')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'landing','9'})
local report=select(1,result())
assert(report.world.phase=='matched' and report.world.counters.hintResolved==1 and report.world.originConfirmed==false,
 'server reads/model/owner/bucket/creation may match a candidate without promoting it to paid origin authority')
local commands,flags,result=fixture('landing-protocol')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'landing','9'})
local report,transitions,restores=result()
assert(report.phase=='complete' and transitions==1 and restores==1,'real registered isolated transition actions precede original-loadout restore')
assert(report.transition.serverRemovalConfirmed and report.transition.economicWrites==0)
local commands,flags,result,reconnect=fixture('landing-retained')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'landing','9'})
local failed=select(1,result());assert(failed.phase=='review_required' and not failed.cleanupComplete)
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'recover-session','9'})
assert(select(1,result()).phase=='review_required','same failed login cannot certify recovery')
reconnect();flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'recover-session','9'})
local recovered=select(1,result())
assert(recovered.phase=='recovered_session_failure' and recovered.restored and not recovered.cleanupComplete
 and recovered.passed==0 and recovered.native.reason=='sentinel_failure','fresh session verifies unchanged saved state without certifying prior native cleanup')
local commands,flags,result,reconnect=fixture('landing-retained')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'landing','9'})
reconnect(true);flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'recover-session','9'})
local refused=select(1,result())
assert(refused.phase=='review_required' and refused.recovery.phase=='refused' and refused.passed==0,'changed durable state is never repaired or accepted')

local commands,flags,result,reconnect=fixture('timeout')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'run','9'})
reconnect();flags.feather_native_guid_suite=1
commands.WeaponGuidAcceptance(0,{'recover','9'})
local recovered,transitions,restores=result()
assert(recovered.phase=='recovered_transport_failure' and recovered.restored and recovered.recovery.savedStateUnchanged
 and not recovered.recovery.detailedNativeReportAvailable and transitions==1 and restores==0,
 'fresh-session recovery compares saved/native state without replaying native cases or clearing old evidence')

local commands,flags,result=fixture('success')
flags.feather_native_guid_suite=1
commands.WeaponGuidAcceptance(0,{'transport','9'})
local transported,transitions,restores=result()
assert(transported.phase=='transport_complete' and transported.kind=='report_transport_only'
 and transitions==0 and restores==0 and transported.transport.passed==2,
 'transport-only check exercises packet receipt without release, creation or loadout changes')

local commands,flags,result,reconnect=fixture('timeout')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'run','9'})
reconnect(true);flags.feather_native_guid_suite=1
commands.WeaponGuidAcceptance(0,{'recover','9'})
local refused,transitions,restores=result()
assert(refused.phase=='review_required' and refused.recovery.phase=='refused' and transitions==1 and restores==0
 and refused.before.durable.items[1].metadata.condition==nil,
 'recovery refuses changed durable metadata and preserves original evidence without repair')

local commands,flags,result=fixture('throwable')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'throwable','9'})
local report,transitions,restores=result()
assert(report.kind=='throwable_world_capture' and report.phase=='complete' and report.total==1
 and report.passed==1 and transitions==1 and restores==1 and report.restored
 and report.world.phase=='matched' and report.world.removedMatchCount==1)
local commands,flags,result=fixture('multiple')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'throwable','9'})
assert(select(2,result())==0,'temporary world unit requires exactly one connected player')

local commands,flags,result=fixture('throwable-unmatched')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'throwable','9'})
local report,transitions,restores=result()
assert(report.phase=='review_required' and report.reason=='server_object_lifetime_not_correlated'
 and report.cleanupComplete and report.restored and restores==1 and report.world.phase=='unconfirmed',
 'missing server lifetime never becomes a diagnostic pass and never prevents independently safe original-loadout restoration')

local commands,flags,result=fixture('throwable-lookup')
flags.feather_native_guid_suite=1;commands.WeaponGuidAcceptance(0,{'throwable','9'})
local report,_,restores=result()
assert(report.phase=='review_required' and report.restored and restores==1
 and report.world.phase=='observed_without_creation' and report.world.counters.hintRequests==1,
 'source/ticket checked live lookup stays distinct from a real server creation callback')
