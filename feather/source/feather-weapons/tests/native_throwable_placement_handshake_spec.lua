dofile('server/services/native_throwable_placement_handshake.lua')
local a={characterId='j',sessionId='s',epoch='e',alive=true,bucket=1,position={x=0,y=0,z=0}}
local c={phase='issued',identity={characterId='j',sessionId='s',epoch='e'},operationId='observe:1',units={{itemId=42,itemRevision=8}}}
local writes,reads=0,0;local h
local api={actor=function() return a end,challenge=function(source,id) if source==1 and id=='throw' then return c end end,
 newId=function() return 'cleanup' end,
 place=function(source,spec)
  writes=writes+1;assert(spec.itemId==42 and spec.itemRevision==8 and spec.spendOperationId=='observe:1')
  assert(h.Handle(1,'cleaned',{id='throw',cleanupToken='cleanup'}).phase=='pending');error('reply lost')
 end,
 read=function() reads=reads+1;return {phase='available',id='pickup'} end}
h=WeaponNativeThrowablePlacementHandshake.New(api)
assert(h.Handle(1,'cleaned',{id='throw',cleanupToken='cleanup'}).phase=='refused' and writes==0)
assert(h.Handle(2,'landing',{id='throw',position={x=1,y=0,z=0}}).phase=='refused')
assert(h.Handle(1,'landing',{id='throw',position={x=51,y=0,z=0}}).phase=='refused')
local request={id='throw',position={x=1,y=0,z=0}}
assert(h.Handle(1,'landing',request).cleanupToken=='cleanup')
assert(h.Handle(1,'landing',{id='throw',position={x=2,y=0,z=0}}).phase=='refused')
assert(h.Handle(1,'cleaned',{id='throw',cleanupToken='wrong'}).phase=='refused')
assert(h.Handle(1,'cleaned',{id='throw',cleanupToken='cleanup'}).phase=='pending' and writes==1)
assert(h.Handle(1,'cleaned',{id='throw',cleanupToken='cleanup'}).phase=='pending' and writes==1)
assert(h.Handle(1,'status',{id='throw'}).phase=='available' and writes==1 and reads==1)
a.sessionId='replacement';assert(h.Handle(1,'status',{id='throw'}).phase=='refused')
local handler,replies,clock=nil,0,0
RegisterNetEvent=function(name,fn) assert(name=='feather-weapons:server:throwable-placement-request');handler=fn end
AddEventHandler=function() end
api.enabled=function() return true end;api.now=function() return clock end
api.reply=function(player,action,id,result) assert(player==1 and id=='throw');replies=replies+1 end
WeaponNativeThrowablePlacementHandshake.Install(api)
source=1;a.sessionId='s'
for i=1,8 do handler('landing',request) end
assert(replies==4,'per-source rate limit before actor/storage admission')
clock=1000;source=2;handler('landing',request);assert(replies==4)
print('PASS placement handshake: exact challenge, bounded immutable landing, separate cleanup token, pre-yield reservation and receipt-only lost-reply recovery')
