dofile('server/services/native_throwable_pickup_claims.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture()
 local actor={characterId='jane',sessionId='session',epoch='epoch',alive=true,bucket=1,position={x=0,y=0,z=0}}
 local binding={id='token',revision=2,kind='paid_tomahawk_pickup',phase='available',itemId=42,itemRevision=7,
  origin={characterId='john',sessionId='old',epoch='old'},bucket=1,position={x=1,y=0,z=0}}
 local claims,reads=0,0
 local api={actor=function() return copy(actor) end,binding=function() return copy(binding) end,changed=function() end}
 local service
 local function receipt() return {phase='claimed',id='token',revision=2,itemId=42,collector=copy(actor)} end
 api.claim=function(source,bound,identity,authority)
  claims=claims+1;assert(bound.itemId==42 and identity.characterId=='jane' and authority())
  assert(service.Claim(2,{id='token',revision=2}).phase=='pending','second collector locked before yield')
  assert(service.Claim(1,{id='other',revision=2}).phase=='pending','one reservation per actor')
  error('reply lost after SQL commit')
 end
 api.readClaim=function() reads=reads+1;return receipt() end
 service=WeaponNativeThrowablePickupClaims.New(api)
 return service,actor,binding,api,function() return claims,reads end
end
local s,a,b,api,counts=fixture()
assert(s.Claim(1,{id='token',revision=2,position={x=0,y=0,z=0}}).phase=='pending')
assert(not s.Available('token'))
assert(s.Read(2,{id='token',revision=2}).phase=='refused')
assert(s.Read(1,{id='token',revision=3}).phase=='refused')
a.sessionId='changed';assert(s.Read(1,{id='token',revision=2}).phase=='pending');a.sessionId='session'
assert(s.Read(1,{id='token',revision=2}).phase=='claimed' and s.Available('token'))
local c,r=counts();assert(c==1 and r==1,'status read cannot replay an economic claim')
for _,bad in ipairs({'far','dead','bucket','revision','origin'}) do
 local s,a,b,api,counts=fixture()
 if bad=='far' then a.position.x=100 elseif bad=='dead' then a.alive=false
 elseif bad=='bucket' then a.bucket=2 elseif bad=='revision' then b.revision=3 else b.origin={} end
 assert(s.Claim(1,{id='token',revision=2}).phase=='refused' and counts()==0,bad)
end
local s,a,b,api,counts=fixture()
api.claim=function(_,_,_,authority) a.position.x=100;assert(not authority());return {phase='refused'} end
assert(s.Claim(1,{id='token',revision=2}).phase=='refused')
local s,a,b,api=fixture()
s.Claim(1,{id='token',revision=2})
api.readClaim=function() return {phase='claimed',id='token',revision=2,itemId=99,collector=copy(a)} end
assert(s.Read(1,{id='token',revision=2}).phase=='pending' and not s.Available('token'))
print('PASS shared pickup admission: server distance/identity, competing collectors, pre-yield reservation, uncertain receipt readback')
local s,a,b,api,counts=fixture();b.presentation='native'
assert(s.Claim(1,{id='token',revision=2}).phase=='refused' and counts()==0,'native presentation cannot enter prompt claim')
local s,a,b,api=fixture()
api.binding=function() error('read outage before mutation') end
assert(s.Claim(1,{id='token',revision=2}).phase=='refused' and s.Available('token'))
local s,a,b,api=fixture()
api.claim=function(_,_,_,authority) b.position.x=0;assert(not authority());return {phase='refused'} end
assert(s.Claim(1,{id='token',revision=2}).phase=='refused','binding cannot move while claim is reserved')
local s,a,b,api=fixture()
s.Claim(1,{id='token',revision=2})
local old={characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch}
a.epoch='restored'
api.readClaim=function() return {phase='claimed',id='token',revision=2,itemId=42,collector=old,identity=a} end
assert(s.Read(1,{id='token',revision=2}).phase=='claimed','exact restore receipt can finish a same-login fresh-epoch handoff')
