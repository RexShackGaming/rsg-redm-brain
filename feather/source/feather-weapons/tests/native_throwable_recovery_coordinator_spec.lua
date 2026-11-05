dofile('server/services/native_throwable_recovery_coordinator.lua')
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local identity={characterId='john',sessionId='s',epoch='e'}
local plan={version=1,kind='projectile_binding_plan',units=1,pickupCredits=false,spendReceiptId='spend11',
 projectileInstanceId='boot:1',originEventId='origin1',networkId=70,identity=identity}
for _,mode in ipairs({'success','foreign_lifetime','distance','bucket','nan','dead','unverified','consume_false',
 'consume_throws','still_present','commit_refused','commit_throws','authority_lost','reentrant'}) do
 local present,authority,removes,commits=true,true,0,0
 local coordinator
 coordinator=WeaponNativeThrowableRecoveryCoordinator.New({
  current=function() return authority end,
  verified=function()
   if mode=='reentrant' then assert(not coordinator.Begin(identity,plan)) end
   return mode~='unverified'
  end,
  inspect=function()
   if not present and mode~='still_present' then return {present=false,instanceId='boot:1'} end
   return {present=true,instanceId=mode=='foreign_lifetime' and 'boot:2' or 'boot:1',networkId=70,
    model='WEAPON_THROWN_TOMAHAWK',actorAlive=mode~='dead',bucket=0,actorBucket=mode=='bucket' and 1 or 0,
    position={x=mode=='nan' and 0/0 or mode=='distance' and 3 or 1,y=0,z=0},actorPosition={x=0,y=0,z=0}}
  end,
  consume=function()
   removes=removes+1
   if mode=='consume_throws' then error('lost reply') end
   if mode=='consume_false' then return false end
   present=false; return true
  end,
  commit=function()
   commits=commits+1
   if mode=='commit_throws' then error('lost reply after possible commit') end
   if mode=='authority_lost' then authority=false end
   return {ok=mode~='commit_refused'}
  end})
 local ok=coordinator.Begin(identity,plan)
 local status=coordinator.Status('spend11')
 if mode=='success' or mode=='reentrant' then
  assert(ok and removes==1 and commits==1 and status.phase=='complete')
 else
  assert(not ok and status.phase=='frozen')
  if mode=='commit_refused' or mode=='commit_throws' or mode=='authority_lost' then
   assert(status.worldOutcome=='confirmed_absent' and commits==1)
  end
 end
 local oldRemoves,oldCommits=removes,commits
 assert(not coordinator.Begin(identity,plan) and removes==oldRemoves and commits==oldCommits,'never retry unknown world/SQL outcome')
 local other=copy(plan); other.spendReceiptId='spend12'
 assert(not coordinator.Begin(identity,other),'same projectile/origin remains reserved across spend keys')
end
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(not manifest:find('native_throwable_recovery_coordinator.lua',1,true))
print('inert recovery reconciliation PASS: verified/reserved exact lifetime + proximity, consume once/absence before claim, partial failure retained, no automatic retry')
