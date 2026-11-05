dofile('client/character_ammunition_checkpoint.lua')
local scope={characterId='Jane',sessionId='s',epoch='e'}
local clock,caller,enabled,phase=0,'feather-character',true,'active'
local replies,request,mode=0,nil,'success'
local gate
local function state() return {phase=phase,session={ammo={baseline=scope}}} end
gate=WeaponCharacterAmmoCheckpoint.Lifecycle({
 caller=function() return caller end,identity=function() return scope end,
 enabled=function() return enabled end,status=state,now=function() return clock end,
 send=function(id,bound) request={id=id,scope=bound} end,
 wait=function()
  clock=clock+1000
  if mode=='success' then
   assert(not gate.Reply(request.id,request.scope,{ok=true},false),'local result refused')
   assert(not gate.Reply('stale',request.scope,{ok=true},true),'stale result refused')
   assert(gate.Run({characterId='Jane',reason='logout'}).error.code=='checkpoint_in_flight')
   phase='closed'; assert(gate.Reply(request.id,request.scope,{ok=true},true)); replies=replies+1
  elseif mode=='denied' then gate.Reply(request.id,request.scope,{ok=false,error={code='commit_refused'}},true)
  elseif mode=='early' then gate.Reply(request.id,request.scope,{ok=true},true)
  elseif mode=='disable' then enabled=false end
 end,
})
caller='other'; assert(not gate.Run({characterId='Jane',reason='logout'}).ok and not request)
caller='feather-character'; assert(not gate.Run({characterId='foreign',reason='logout'}).ok and not request)
assert(gate.Run({characterId='Jane',reason='logout'}).ok and replies==1)
assert(not gate.Reply(request.id,request.scope,{ok=true},true),'completed ticket retired')
phase='active'; mode='denied'; assert(gate.Run({characterId='Jane',reason='save_quit'}).error.code=='commit_refused')
mode='early'; assert(gate.Run({characterId='Jane',reason='logout'}).error.code=='logout_wear_release_not_confirmed')
mode='disable'; assert(gate.Run({characterId='Jane',reason='logout'}).error.code=='logout_wear_context_changed')
enabled=true; mode='timeout'; assert(gate.Run({characterId='Jane',reason='logout'}).error.code=='logout_wear_timeout_no_retry')
print('Native logout wear checkpoint PASS (server commit acknowledgment, closed owner, caller/context/overlap/stale/disable/timeout veto)')
