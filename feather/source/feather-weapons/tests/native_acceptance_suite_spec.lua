dofile('shared/native_acceptance_view.lua')
dofile('server/services/native_acceptance_suite.lua')
local copy
copy=function(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
local actors={{source=13,sessionId='jane',characterId='jane'},{source=14,sessionId='john',characterId='john'}}
local function fixture()
 local saved,engine,actions={},nil,0
 saved.value=nil
 local snapshot={durable={{items={{id=229,revision=8}}},{items={{id=155,revision=4}}}},clients={
  {identity={epoch='jane:1'},pools={ammo=1},maintenance={{id=112,wear={dirt=1}}}},
  {identity={epoch='john:1'},pools={ammo=1},maintenance={{id=155,wear={dirt=0}}}}}}
 local api={load=function() return copy(saved.value) end,save=function(v) saved.value=copy(v);return true end,
  id=function() return 'run1' end,discover=function() return actors end,current=function() return true end,
  capture=function() return copy(snapshot) end,
  transition=function(a,overlap)
   assert(saved.value.phase=='running' and saved.value.pendingStep,'persist before dispatch')
   actions=actions+1
   local i=a.sessionId=='jane' and 1 or 2;snapshot.clients[i].identity.epoch=a.sessionId..':'..actions+1
   return {ok=true,value={competingRefused=overlap,staleAcknowledgementRefused=overlap}}
  end,awaitRestore=function() end,progress=function() end}
 engine=WeaponNativeAcceptanceSuite.New(api)
 return engine,api,saved,snapshot,function() return actions end
end
local engine,api,saved,snapshot,actions=fixture()
local report=engine.Run(false)
assert(report.phase=='complete' and #report.steps==3 and actions()==3 and report.visual=='pending')
assert(report.actors[1].source==13 and report.actors[2].source==14)
assert(engine.Run(false).phase=='complete' and actions()==3,'completed run must not replay')
assert(engine.Visual('pass').visual=='pass')
engine=WeaponNativeAcceptanceSuite.New(api)
assert(engine.Run(false).visual=='pass' and actions()==3,'restart retains completed evidence')
engine,api,saved,snapshot,actions=fixture()
api.transition=function() error('lost callback') end
report=engine.Run(false)
assert(report.phase=='review_required' and saved.value.pendingStep)
local restarted=WeaponNativeAcceptanceSuite.New(api)
assert(restarted.Run(false).phase=='review_required' and actions()==0,'uncertain dispatch never replayed')
engine,api,saved,snapshot,actions=fixture()
local transition=api.transition
api.transition=function(a,o) local v=transition(a,o);snapshot.durable[1].items[1].revision=9;return v end
assert(engine.Run(false).phase=='review_required' and actions()==1,'durable mutation stops subsequent steps')
engine,api,saved,snapshot,actions=fixture()
transition=api.transition
api.transition=function(a,o) local v=transition(a,o);snapshot.clients[2].identity.epoch='unexpected';return v end
assert(engine.Run(false).phase=='review_required' and actions()==1,'observer epoch mutation stops suite')
engine,api,saved,snapshot,actions=fixture()
api.save=function() return false end
assert(engine.Run(false).phase=='review_required' and actions()==0,'journal failure prevents dispatch')
engine,api,saved,snapshot,actions=fixture()
local available=false;api.discover=function() if available then return actors end end
assert(engine.Run(false).phase=='refused' and actions()==0)
available=true;assert(engine.Run(false).phase=='complete','missing players can reconnect without clearing evidence')
engine,api,saved,snapshot,actions=fixture()
api.current=function() return false end
assert(engine.Run(false).phase=='review_required' and actions()==0,'session drift prevents action')
engine,api,saved,snapshot,actions=fixture()
saved.value={version=1,runId='old',phase='running',steps={},pendingStep='unknown'}
engine=WeaponNativeAcceptanceSuite.New(api)
assert(engine.Run(false).phase=='review_required' and actions()==0,'crash journal cannot silently replay')
saved.value=false;engine=WeaponNativeAcceptanceSuite.New(api)
assert(engine.Status().phase=='report_invalid_do_not_retry')
engine,api,saved,snapshot,actions=fixture()
local capture=api.capture
api.capture=function() error('durable_audit_unavailable') end
api.failureDetail=function() return {actor='Jane',check='ammo_pools',detail={pool='known_pool',client=1,durable=0}} end
local refused=engine.Run(false)
assert(refused.phase=='review_required' and refused.before==nil and actions()==0)
assert(refused.failureDetail.check=='ammo_pools' and saved.value.failureDetail.detail.client==1)
api.capture=capture
local retried=engine.Run(false)
assert(retried.phase=='complete' and actions()==3 and retried.priorPreflight.runId=='run1',
 'explicit run may repeat a read-only failed initial preflight, preserving its summary')
engine,api,saved,snapshot,actions=fixture()
capture=api.capture
local captures=0
api.capture=function() captures=captures+1;if captures==2 then error('durable_audit_unavailable') end;return capture() end
assert(engine.Run(false).phase=='review_required' and actions()==1)
api.capture=capture
assert(engine.Run(false).phase=='review_required' and actions()==1,'post-dispatch audit failure never permits preflight retry')
engine,api,saved,snapshot,actions=fixture()
snapshot.durable[1].items[2]={id=230,metadataState='sql_null'}
transition=api.transition
api.transition=function(a,o)
 local result=transition(a,o)
 snapshot.durable[1].items[2].metadata={};snapshot.durable[1].items[2].metadataState='document'
 return result
end
assert(engine.Run(false).phase=='review_required' and actions()==1,'SQL NULL to empty document changes must not be hidden')
print('PASS acceptance suite: checkpoint-before-dispatch, completed evidence, no uncertain replay, conservation/observer/session stop, preflight recovery')
