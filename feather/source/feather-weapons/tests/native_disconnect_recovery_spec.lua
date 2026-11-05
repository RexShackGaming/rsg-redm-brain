dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_runtime.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
Config={CharacterAmmunitionEnabled=true,DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane'}
local sessions={[1]='old'}
CoreAdapter={ResolveSession=function(target) return {ok=true,value={characterId='Jane',sessionId=sessions[target]}} end,
 IsSessionCurrent=function(target,s,c) return sessions[target]==s and c=='Jane' end}
WeaponCharacterAmmoCatalog={Build=function() return {limits={regular=10}} end}
WeaponCharacterAmmoMaterialization={Build=function(rows,_,_,id) return {identity=copy(id),items={{itemInstanceId=112,itemRevision=rows.primary.revision,metadata=copy(rows.primary.metadata)}}} end}
local registered,events={},{},{}
local db={revision=26,pools={regular=1},equipment={primary={id=112,revision=1,itemName='cattleman',metadata={serial='original'}}}}
local calls,mode=0,'confirmed'
exports=setmetatable({['feather-inventory']={
 GetCharacterFirearmRuntimeSnapshot=function(_,context) return {ok=true,value={characterId='Jane',revision=db.revision,pools=copy(db.pools),equipment=copy(db.equipment)}} end,
 ObserveCharacterAmmunition=function(_,context,spec)
  assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec)); calls=calls+1
  if mode=='yield_before_commit' then
   coroutine.yield('before_commit')
   if not registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec) then return {ok=false} end
  end
  if mode=='refused' then return {ok=false} end
  db.revision=db.revision+1; db.pools=copy(spec.pools)
  if mode=='lost_ack' then
   sessions[context.actorSource]=nil
   WeaponCharacterAmmoService.Revoke(context.actorSource,nil,'player_dropped')
  end
  local reply={ok=true,value={characterId='Jane',revision=db.revision,pools=copy(db.pools)}}
  if mode=='yield_after_commit' then coroutine.yield('after_commit') end
  return reply
 end,
}},{__call=function(_,name,fn) registered[name]=fn end})
GetInvokingResource=function() return 'feather-inventory' end
GetGameTimer=function() return calls+1 end
AddEventHandler=function(name,fn) events[name]=fn end
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
assert(S.CanReleaseInventoryGuards(),'no lease/open work allows native guard teardown')
local function open(target)
 local bundle=assert(S.OpenLoadout(target,{},{}).value)
 assert(S.ConfirmRestore(target,bundle.runtime).ok); return bundle.runtime
end
local old=open(1)
assert(not S.CanReleaseInventoryGuards(),'active native item lease retains guards')
assert(not S.ReconcileSession(1,{characterId='Jane',sessionId='foreign'}).ok,'new scope must be independently current')
assert(#S.ReconcileSession(1,{characterId='Jane',sessionId='old'}).value.retired==0)
assert(not S.OpenLoadout(1,{},{}).ok,'same-session unreleased owner never thaws')
sessions[1]='new'
local retired=S.ReconcileSession(1,{characterId='Jane',sessionId='new'})
assert(retired.ok and #retired.value.retired==1 and not S.IsNativeItemBound(112))
assert(S.CanReleaseInventoryGuards(),'independently retired lease no longer owns item guards')
local fresh=open(1)
assert(fresh.revision==26 and fresh.pools.regular==1 and fresh.epoch~=old.epoch and calls==0,'reconnect reads durable funded belt without economic replay')
local evidence=S.ReadRecoveryStatus(1)
assert(evidence.prior.sessionId=='old' and not evidence.prior.nativeCleanupConfirmed and not evidence.economicReplay and not evidence.nativeAdoption)
events['core.session.left.v1']({source=1,sessionId='old'})
assert(S.ReadRecoveryStatus(1) and not S.Observe(1,old).ok,'late old session/epoch cannot affect source reuse')
mode='lost_ack'; fresh.pools.regular=0
assert(not S.Observe(1,fresh).ok and db.revision==27 and db.pools.regular==0,'committed write may lose acknowledgment')
sessions[2]='rejoin'
local after=open(2)
assert(after.revision==27 and after.pools.regular==0 and calls==1,'do not refund/retry a committed lost reply')
evidence=S.ReadRecoveryStatus(2)
assert(evidence.prior.pendingOperation=='observe' and evidence.prior.unresolvedPersistence
 and evidence.prior.lastAcknowledgedLedgerRevision==26 and evidence.ledgerRevision==27)
S.Revoke(2,nil,'player_dropped'); sessions[2]='again'; db.pools.regular=1; mode='refused'
local refused=open(2); refused.pools.regular=0
assert(not S.Observe(2,refused).ok and db.revision==27 and db.pools.regular==1)
sessions[2]='after_refusal'
assert(S.ReconcileSession(2,{characterId='Jane',sessionId='after_refusal'}).ok)
local final=open(2)
assert(final.revision==27 and final.pools.regular==1 and calls==2,'refused transaction leaves last durable baseline')
assert(S.ReadRecoveryStatus(2).prior.providerOutcome=='refused')
-- A process restart loses every in-memory owner/retirement record. Only the
-- durable provider snapshot survives; absence of history is not cleanup proof.
local beforeRestart=copy(final)
local beforeCalls=calls
sessions={[2]='after_process_restart'}
dofile('shared/character_ammunition_runtime.lua')
dofile('server/services/character_ammunition_runtime.lua')
S=WeaponCharacterAmmoService
local restarted=open(2)
local restartEvidence=S.ReadRecoveryStatus(2)
assert(restarted.revision==27 and restarted.pools.regular==1 and calls==beforeCalls,
 'fresh process restores durable funded snapshot without economic mutation')
assert(restartEvidence.prior==nil and not restartEvidence.economicReplay
 and not restartEvidence.nativeAdoption,'lost transient history never implies cleanup/adoption')
assert(not S.Observe(2,beforeRestart).ok,'pre-restart session report remains stale')
assert(S.ReadRecoveryStatus(2).currentAcknowledged.sessionId=='after_process_restart')
-- Real coroutine suspension: new same-source owner restores before the old
-- provider reply returns, both before and after the durable commit boundary.
for _,boundary in ipairs({'yield_before_commit','yield_after_commit'}) do
 S.Revoke(2,nil,'player_dropped'); sessions[2]='pending_'..boundary
 db.pools.regular=1; mode=boundary
 local report=open(2); local initialRevision=db.revision; local initialCalls=calls
 report.pools.regular=0
 local outcome
 local pending=coroutine.create(function() outcome=S.Observe(2,report) end)
 local ok,point=coroutine.resume(pending)
 assert(ok and point==(boundary=='yield_before_commit' and 'before_commit' or 'after_commit'))
 sessions[2]=nil; S.Revoke(2,nil,'player_dropped')
 sessions[2]='replacement_'..boundary
 local replacement=open(2)
 local committed=boundary=='yield_after_commit'
 assert(replacement.revision==initialRevision+(committed and 1 or 0)
  and replacement.pools.regular==(committed and 0 or 1))
 assert(coroutine.resume(pending) and coroutine.status(pending)=='dead')
 assert(outcome and not outcome.ok and calls==initialCalls+1,
  'late old reply must not acknowledge/replay onto replacement owner')
 local live=S.ReadRecoveryStatus(2).currentAcknowledged
 assert(live.epoch==replacement.epoch and live.revision==replacement.revision
  and live.pools.regular==replacement.pools.regular,
  'late completion cannot freeze, replace or mutate fresh runtime')
 assert(db.revision==replacement.revision and db.pools.regular==replacement.pools.regular)
end
print('Disconnect recovery PASS (current new session only, stale hold retirement/source reuse, no native cleanup/adoption claims, confirmed/refused/lost-ack durable reconstruction without replay)')
