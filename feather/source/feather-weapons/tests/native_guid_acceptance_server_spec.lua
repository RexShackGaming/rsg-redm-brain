dofile('shared/native_acceptance_view.lua')
dofile('shared/character_ammunition.lua')
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local function fixture(mode)
 local commands,events,flags,files,documents={},{},{},{},{}
 local sequence,clock,transitions,restores=0,0,0,0
 local sid='s'
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
 GetResourceState=function() return 'stopped' end
 exports={['feather-inventory']={ReadNativeAcceptanceAudit=function(_,actors)
  assert(#actors==1 and actors[1].source==9)
  return {ok=true,value={copy(durable)}}
 end}}
 TriggerClientEvent=function(name,target,ticket,bound,total)
  if name=='feather-weapons:client:guid-suite-read' then
   source=8;events['feather-weapons:server:guid-suite-read'](ticket,{}) -- foreign reply is ignored
   source=9
   local view={identity=copy(bound),revision=57,pools={ammo=1},copies=1,utility={},melee={},
    maintenance={{id=1,revision=1,wear=copy(wear)}}}
   events['feather-weapons:server:guid-suite-read'](ticket,view)
  elseif name=='feather-weapons:client:guid-suite-report-ack' then return
  elseif name=='feather-weapons:client:guid-suite-run' or name=='feather-weapons:client:guid-suite-transport' then
   if mode=='timeout' then
    source=9;events['feather-weapons:server:guid-suite-progress'](ticket,total,total,'two');return
   end
   source=9
   local success=mode~='retained' and mode~='clean-failure'
   local value={phase=success and 'complete' or 'review_required',total=total,passed=success and total or 0,
    cleanupComplete=mode~='retained',reason=not success and 'sentinel_failure' or nil,
    failedCase=not success and 'one' or nil,cases=success and {{id='one',phase='passed',cleanupComplete=true},{id='two',phase='passed',cleanupComplete=true}}
     or {{id='one',phase='failed',cleanupComplete=mode~='retained'}}}
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
 else assert(report.phase=='review_required' and restores==0,'uncertain cleanup must never rebuild over retained copies') end
end
print('GUID server orchestration PASS (normal mode, console/opt-in/source/ticket gates, one transition, durable/client comparison, cleaned failure restore, retained/timeout hold)')

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
