dofile('shared/native_restart_acceptance.lua')
local clone
clone=function(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
local equal
equal=function(a,b) if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end;for k,v in pairs(a) do if not equal(v,b[k]) then return false end end;for k in pairs(b) do if a[k]==nil then return false end end;return true end
local gatesReady=true
local disk,prepares,seals,host,session,ready,failCapture,changed=nil,0,0,'old','old',false,false,false
local function snapshot() return {durable={items={serial='original',revision=4},ammo=1},clients={{identity={characterId='Jane',sessionId=session,epoch=session},wear=changed and 1 or 0.2}}} end
local api={readGates=function() return {feature=1} end,gatesMatch=function(v) return gatesReady and v.feature==1 end,load=function() return clone(disk) end,save=function(r) disk=clone(r);return true end,id=function() return 'run' end,equal=equal,
 sealAndRestore=function() seals=seals+1 end,capture=function() if failCapture then error('both_test_characters_required') end;return snapshot() end,
 prepareProbe=function(mode) prepares=prepares+1;return {ok=true,hostToken=host,mode=mode} end,
 verifyProbe=function() return {ok=ready,hostToken=host,mode=disk.mode} end}
local suite=WeaponRestartAcceptance.New(api)
assert(suite.Prepare('database').phase=='refused' and prepares==0)
assert(suite.Prepare('server').phase=='awaiting_restart' and prepares==1 and seals==1)
suite=WeaponRestartAcceptance.New(api)
assert(suite.Prepare('server').phase=='awaiting_restart' and prepares==1,'restart cannot replay dispatch')
assert(suite.Verify().phase=='awaiting_restart')
host='new';session='new';ready=true;gatesReady=false
assert(suite.Verify().phase=='awaiting_restart' and suite.Status().reason=='restore_recorded_gameplay_settings')
gatesReady=true;failCapture=true
assert(suite.Verify().phase=='awaiting_restart','read-only retry until characters return')
failCapture=false;assert(suite.Verify().phase=='server_passed' and #disk.steps==1)
assert(suite.Prepare('database').phase=='awaiting_restart' and prepares==2)
assert(suite.Verify().phase=='complete' and #disk.steps==2)
assert(suite.Visual('pass').visual=='pass')
suite=WeaponRestartAcceptance.New(api);assert(suite.Prepare('server').phase=='complete' and prepares==2)
-- A changed durable/native snapshot cannot be repaired or accepted.
disk=nil;host='old';session='old';ready=false;suite=WeaponRestartAcceptance.New(api);suite.Prepare('server')
host='new';session='new';ready=true;changed=true
assert(suite.Verify().phase=='review_required' and prepares==3)
assert(suite.Prepare('database').phase=='review_required' and prepares==3)
-- A journal left before/while dispatching is not automatically replayable.
disk={version=1,runId='r',phase='preparing',steps={}}
suite=WeaponRestartAcceptance.New(api);assert(suite.Status().phase=='review_required')
disk={version=1,runId='r',phase='complete',steps={}}
assert(WeaponRestartAcceptance.New(api).Status().phase=='invalid_report_no_retry')
print('Restart acceptance PASS: persistent sequential server/database phases, fresh sessions, conservation, read-only waiting, visual evidence, corrupt/interrupted refusal and no prepare replay')

-- Recover the known pre-dispatch harness refusal without replaying a seal.
local failed={version=1,runId='failed',mode='server',phase='review_required',reason='restart_seal_restore_refused',steps={},visual='pending'}
disk=clone(failed);changed=false;local oldSeals,oldPrepares=seals,prepares
api.probeIdle=function() return false end
suite=WeaponRestartAcceptance.New(api);assert(suite.RetryPreflight().phase=='review_required' and prepares==oldPrepares)
api.probeIdle=function() return true end
suite=WeaponRestartAcceptance.New(api)
local resumed=suite.RetryPreflight()
assert(resumed.phase=='awaiting_restart' and resumed.priorPreflight.runId=='failed' and resumed.resumedWithoutSealReplay)
assert(seals==oldSeals and prepares==oldPrepares+1,'fresh read-only baseline, one new probe, zero seal replay')
suite.RetryPreflight();assert(prepares==oldPrepares+1)
disk=clone(failed);disk.before={durable={}};suite=WeaponRestartAcceptance.New(api)
assert(suite.RetryPreflight().phase=='review_required' and prepares==oldPrepares+1,'baseline/dispatch evidence forbids preflight recovery')
print('Restart preflight recovery PASS: exact old refusal only, idle probe, preserved prior report, read-only baseline and no repeated seal/dispatch')

-- Inspection retains the baseline and never dispatches lifecycle or probe work.
disk=nil;host='old';session='old';ready=false;changed=false
suite=WeaponRestartAcceptance.New(api);suite.Prepare('server')
host='new';session='new';ready=true;changed=true
local mismatch=suite.Verify();assert(mismatch.phase=='review_required' and mismatch.lastComparison.detail.totalDifferences==1)
local oldBefore=clone(mismatch.before);local counts={prepares,seals}
local inspected=suite.Inspect()
assert(inspected.phase=='review_required' and inspected.reason=='restart_snapshot_changed_no_repair')
assert(equal(inspected.before,oldBefore) and prepares==counts[1] and seals==counts[2])
assert(inspected.inspections[1].detail.differences[1].path=='clients[1].wear')
assert(inspected.inspections[1].detail.differences[1].before==0.2 and inspected.inspections[1].detail.differences[1].after==1)
local a=snapshot();local b=clone(a);b.clients[1].identity.sessionId='other';b.clients[1].identity.epoch='other'
assert(WeaponRestartAcceptance.Compare(a,b).equal,'only expected runtime identity fields excluded')
b.durable.ammo=2;assert(not WeaponRestartAcceptance.Compare(a,b).equal,'economic differences remain strict')
print('Restart snapshot diagnostics PASS: exact before/after retention, strict bounded paths, read-only inspection and preserved failed phase/baseline')

-- Persisted JSON decimals and fresh native float values differ below the normal
-- wear contract tolerance. Only the five exact maintenance paths may use it.
local baseline={durable={revision=4,metadata={maintenance={dirt=0.6680000424385}}},clients={{identity={characterId='Jane',sessionId='old',epoch='old'},maintenance={{id=112,revision=2,wear={degradation=0.00871666707098,dirt=0.6680000424385,soot=0.00499999988824,damage=0,permanentDegradation=0}}}}}}
local fresh=clone(baseline)
fresh.clients[1].identity.sessionId='new';fresh.clients[1].identity.epoch='new'
fresh.clients[1].maintenance[1].wear.degradation=0.00871666707098484
fresh.clients[1].maintenance[1].wear.dirt=0.6680000424385071
fresh.clients[1].maintenance[1].wear.soot=0.004999999888241291
local detail=WeaponRestartAcceptance.Compare(baseline,fresh)
assert(detail.equal and #detail.acceptedWearRounding==3 and detail.acceptedWearRounding[1].beforeExact~=detail.acceptedWearRounding[1].afterExact)
fresh.durable.metadata.maintenance.dirt=0.6680000424385071
assert(not WeaponRestartAcceptance.Conserved(baseline,fresh,equal),'durable wear document stays exact')
fresh=clone(baseline);fresh.clients[1].maintenance[1].revision=2.00000001
assert(not WeaponRestartAcceptance.Conserved(baseline,fresh,equal),'item revisions have no tolerance')
fresh=clone(baseline);fresh.clients[1].maintenance[1].wear.dirt=0.66801
assert(not WeaponRestartAcceptance.Conserved(baseline,fresh,equal),'meaningful native wear drift refuses')
fresh=clone(baseline);fresh.clients[1].maintenance[1].wear.extra=0.2
assert(not WeaponRestartAcceptance.Conserved(baseline,fresh,equal),'unknown fields stay exact')
fresh=clone(baseline);fresh.extra=1
assert(not WeaponRestartAcceptance.Conserved(baseline,fresh,equal),'unknown top-level fields stay exact')
-- Reverify the same saved failed baseline, without seals, preparation or restart.
disk={version=1,runId='rounding',mode='server',phase='review_required',reason='restart_snapshot_changed_no_repair',steps={},visual='pending',before=clone(baseline),prepared={hostToken='old'},gameplayConvars={feature=1},inspections={{after=clone(fresh),detail={equal=false}}}}
api.capture=function() local next=clone(baseline);next.clients[1].identity.sessionId='new';next.clients[1].identity.epoch='new';next.clients[1].maintenance[1].wear.degradation=0.00871666707098484;return next end
host='new';ready=true
local countSeals,countPrepares=seals,prepares
suite=WeaponRestartAcceptance.New(api);local verified=suite.Verify()
assert(verified.phase=='server_passed' and #verified.steps==1 and verified.originalFailedComparison)
assert(equal(verified.steps[1].before,baseline) and seals==countSeals and prepares==countPrepares,'original baseline retained, zero lifecycle/probe replay')
print('Restart wear precision PASS: native five-field tolerance only, exact durable/identity/revision/unknown fields, meaningful drift refusal and read-only saved-baseline reverify')
