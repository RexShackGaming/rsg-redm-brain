dofile('client/native_throwable_pickup_transport.lua')
local actor={characterId='jane',sessionId='sid',epoch='old'}
local handler,transport,mode,time,sends=nil,nil,'success',0,0
local api={world=function() return actor end,now=function() return time end,wait=function(ms) time=time+ms end,
 register=function(fn) handler=fn end}
api.send=function(id,scope,kind,data)
 sends=sends+1
 assert(not handler(1,id,scope,{phase='claimed'}),'client-origin response rejected')
 assert(not handler(65535,'wrong',scope,{phase='refused'}),'wrong nonce rejected')
 assert(transport.Call('claim',data).phase=='pending','nested claim cannot send twice')
 if mode=='timeout' then return end
 if mode=='logout' then actor.sessionId='new';return end
 actor.epoch='fresh'
 local result={phase='claimed',id=data.id,revision=data.revision,identity={characterId='jane',sessionId='sid',epoch='fresh'}}
 if mode=='wrong-restore' then result.identity.epoch='foreign' end
 assert(handler(65535,id,scope,result))
end
transport=WeaponNativeThrowablePickupClientTransport.New(api)
local result=transport.Call('claim',{id='pickup',revision=0})
assert(result.phase=='claimed' and result.identity.epoch=='fresh' and sends==1)
mode='wrong-restore';assert(transport.Call('claim',{id='pickup',revision=0}).phase=='pending')
mode='timeout';local before=sends;assert(transport.Call('status',{id='pickup',revision=0}).phase=='pending' and sends==before+1)
mode='logout';assert(transport.Call('status',{id='pickup',revision=0}).phase=='pending')
transport.Stop();before=sends;assert(transport.Call('claim',{id='pickup',revision=0}).phase=='pending' and sends==before)
print('PASS client pickup transport: server source, nonce/scope, no mutation retry, timeout/logout, exact restored identity and stop fence')
