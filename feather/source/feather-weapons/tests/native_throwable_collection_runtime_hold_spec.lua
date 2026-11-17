dofile('client/character_ammunition_lifecycle.lua')
dofile('client/character_ammunition_driver.lua')
dofile('client/character_ammunition_client_runtime.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture(enabled)
 local identity={characterId='john',sessionId='login',epoch='epoch'}
 local state={phase='closed',session={ammo={phase='active',baseline={characterId='john',sessionId='login',epoch='epoch',revision=3,
  pools={ammo_tomahawk_regular=0,ammo_revolver_regular=10}}}}}
 local now,ped,life=0,1,'alive'
 local calls={tick=0,operation=0,blocked=false}
 WeaponCharacterAmmoWorldContext={Identity=function() return copy(identity) end}
 WeaponCharacterAmmoHost={New=function()
  local host={Status=function() return copy(state) end,Receive=function() state.phase='active';return true end,
   Tick=function() calls.tick=calls.tick+1;return true end,
   Suspend=function(reason) state.phase='frozen';state.reason=reason end,
   ReadDeathObservation=function() return {} end}
  for _,name in ipairs({'Transfer','Checkpoint','PrepareEquipmentRelease','Finalize','Cleanup','RecoverDeath','FinalizeDeath','Quiesce'}) do
   host[name]=function() calls.operation=calls.operation+1;return true end
  end
  return host
 end}
 local receipt={phase='cleaned',ticket='ticket',identity=copy(identity),quantityBefore=1,quantityAfter=0,
  guidCaptured=true,guidReleased=true,otherPoolsUnchanged=true}
 local api={ped=function() return ped end,now=function() return now end,life=function() return life end,
  block=function(v) calls.blocked=v end,collectionEnabled=function() return enabled~=false end,
  readCollectionEscrow=function() return copy(receipt) end}
 local runtime=assert(WeaponCharacterAmmoClientRuntime.New(api))
 assert(runtime.Receive({runtime=copy(identity)},true));assert(runtime.Step())
 return runtime,api,state,identity,receipt,calls,function(n,p,l) now=n or now;ped=p or ped;life=l or life end
end
local r,api,s,i,receipt,c=fixture(false)
assert(select(2,r.BeginNativeCollectionHold('ticket',i))=='native_collection_hold_disabled')
assert(r.Step() and not r.Status().collectionHold)
local r,api,s,i,receipt,c,advance=fixture()
assert(r.BeginNativeCollectionHold('ticket',i))
local ticks=c.tick
assert(r.Step() and c.blocked and c.tick==ticks)
for _,name in ipairs({'Transfer','Receive','ReleaseEquipment','Finalize','Cleanup','RecoverDeath','FinalizeDeath','Quiesce'}) do
 assert(not r[name](i) and c.operation==0,name..' cannot cross provisional collection')
end
assert(not r.Checkpoint({}).ok and c.operation==0)
assert(not r.EndNativeCollectionHold('wrong') and r.Status().collectionHold)
assert(r.EndNativeCollectionHold('ticket') and not r.Status().collectionHold)
assert(select(2,r.BeginNativeCollectionHold('ticket',i))=='native_collection_hold_invalid','cleanup ticket cannot be reused')
advance(300)
assert(r.Step() and c.tick==ticks+1)
for _,bad in ipairs({'dead','ped','login','epoch','revision','pools','pending','closing','clock','receipt','throwing_port'}) do
 local r,api,s,i,receipt,c,change=fixture();assert(r.BeginNativeCollectionHold('ticket',i))
 if bad=='dead' then change(nil,nil,'dead')
 elseif bad=='ped' then change(nil,2)
 elseif bad=='login' then i.sessionId='other'
 elseif bad=='epoch' then s.session.ammo.baseline.epoch='other'
 elseif bad=='revision' then s.session.ammo.baseline.revision=4
 elseif bad=='pools' then s.session.ammo.baseline.pools.ammo_revolver_regular=11
 elseif bad=='pending' then s.session.ammo.pending=true
 elseif bad=='closing' then s.session.ammo.deathClosing=true
 elseif bad=='clock' then change(10001)
 elseif bad=='receipt' then receipt.guidReleased=false
 else api.readCollectionEscrow=function() error('unavailable') end end
 if bad~='receipt' and bad~='throwing_port' then assert(not r.Step()) end
 assert(not r.EndNativeCollectionHold('ticket') and r.Status().collectionHold.phase=='review_required',bad)
 assert(s.phase=='frozen' and c.blocked and c.operation==0,bad)
end
local r,api,s,i=fixture();s.session.throwable={fundedQuantity=0}
assert(select(2,r.BeginNativeCollectionHold('ticket',i))=='native_collection_empty_carry_required')
local r,api,s,i,receipt,c=fixture()
assert(r.BeginNativeCollectionHold('ticket',i));r.Suspend('external_shutdown')
assert(r.Status().collectionHold.reason=='external_shutdown' and not r.EndNativeCollectionHold('ticket'))
print('PASS runtime provisional pickup hold: opt-in only, no observation or lifecycle writes, per-frame death/scope/deadline checks, exact cleanup receipt resumes')
local r,api,s,i,receipt,c=fixture()
local ticks=c.tick
api.beforeCollectionSample=function(runtime)
 assert(runtime==r);api.beforeCollectionSample=nil
 return runtime.BeginNativeCollectionHold('ticket',i)
end
assert(r.Step() and c.tick==ticks and r.Status().collectionHold,'provisional hold must intercept the same frame before normal sampling')
assert(r.EndNativeCollectionHold('ticket'))
