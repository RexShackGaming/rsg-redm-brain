dofile('server/services/native_throwable_pickup_transport.lua')
local time,calls,replies=0,0,{}
local actor={characterId='jane',sessionId='sid',epoch='old'}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local scope=copy(actor)
local api={enabled=function() return true end,now=function() return time end,actor=function(source) assert(source==1);return actor end,
 read=function() return {phase='pending'} end,offers=function() return {phase='updated'} end,
 reply=function(_,id,_,result) replies[id]=result end}
local transport
api.claim=function(source,request)
 calls=calls+1;assert(source==1 and request.id=='pickup')
 assert(not transport.Handle(1,'nested',scope,'claim',request),'reserve before backend can yield')
 error('commit reply lost')
end
transport=WeaponNativeThrowablePickupTransport.New(api)
assert(not transport.Handle(1,'forged',scope,'claim',{id='pickup',revision=0,actorSource=2}))
assert(transport.Handle(1,'one',scope,'claim',{id='pickup',revision=0}) and calls==1 and replies.one.phase=='pending')
assert(transport.Handle(1,'one',scope,'claim',{id='pickup',revision=0}) and calls==1)
assert(not transport.Handle(1,'one',scope,'claim',{id='other',revision=0}))
time=2000;actor.epoch='fresh'
assert(not transport.Handle(1,'stale',scope,'claim',{id='pickup',revision=0}))
api.read=function() return {phase='claimed',id='pickup',revision=0,identity=actor,receipt={metadata='private'}} end
assert(transport.Handle(1,'status',scope,'status',{id='pickup',revision=0}))
assert(replies.status.identity.epoch=='fresh' and not replies.status.receipt)
time=4000;actor.sessionId='replacement'
assert(not transport.Handle(1,'wrong-login',scope,'status',{id='pickup',revision=0}))
local events={};RegisterNetEvent=function(name,fn) events[name]=fn end;AddEventHandler=function() end
api.actor=function(source) assert(source==7);return actor end
api.claim=function(source) assert(source==7);calls=calls+1;return {phase='refused',code='pickup_unavailable',metadata='private'} end
WeaponNativeThrowablePickupTransport.Install(api)
source=7;events['feather-weapons:server:throwable-pickup-request']('event',actor,'claim',{id='pickup',revision=0})
assert(replies.event.phase=='refused' and calls==2,'event actor comes from Cfx source')
assert(replies.event.code=='pickup_unavailable' and replies.event.metadata==nil,'bounded refusal code survives private response projection')
local reads=0
api.actor=function() reads=reads+1;return actor end
local other=WeaponNativeThrowablePickupTransport.New(api)
for i=1,20 do other.Handle(9,'rate-'..i,{characterId='fake',sessionId='fake-'..i,epoch='fake'},'offers',{}) end
assert(reads==4,'fake session scopes cannot replenish source rate budget')
print('PASS installed pickup handler: Cfx source, session/epoch gates, request dedup/rate limits, pre-yield reservation and private receipt projection')
