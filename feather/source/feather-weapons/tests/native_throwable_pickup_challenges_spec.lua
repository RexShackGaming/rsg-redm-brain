dofile('server/services/native_throwable_pickup_challenges.lua')
local actor={characterId='jane',sessionId='sid',epoch='epoch',alive=true}
local identity={characterId='jane',sessionId='sid',epoch='epoch'}
local sent,time,reads=0,0,0
local c
local api={actor=function() return actor end,now=function() return time end,newId=function() return 'challenge' end,
 send=function(source,packet)
  sent=sent+1;assert(source==1 and packet.units[1].itemRevision==8 and not packet.units[1].metadata)
 end,
 spend=function(_,op,id)
  reads=reads+1
  assert(not c.Confirmed(1,identity,op,{id}),'reservation precedes yielding ports')
  return {custody='spent',operationId=op,itemId=id,itemRevision=8,origin=identity,
   metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid'}}
 end}
c=WeaponNativeThrowablePickupChallenges.New(api)
assert(c.Confirmed(1,identity,'observe:1',{42}) and sent==1 and reads==1)
assert(not c.Confirmed(1,identity,'observe:1',{42}) and sent==1)
assert(c.Read(1,'challenge').units[1].itemId==42 and not c.Read(2,'challenge'))
actor.epoch='new';assert(not c.Read(1,'challenge'));actor.epoch='epoch'
time=90000;assert(not c.Read(1,'challenge'))
api.spend=function() error('receipt unavailable') end
assert(not c.Confirmed(1,identity,'observe:2',{43}) and sent==1)
assert(not c.Confirmed(1,identity,'observe:2',{43}),'uncertain admission is not replayed')
assert(not c.Confirmed(1,false,'observe:3',{43}))
api.spend=function(_,op,id) return {custody='spent',operationId=op,itemId=id,itemRevision=9,origin=identity,
 metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid'}} end
api.newId=function() actor.sessionId='replacement';return 'stale' end
assert(not c.Confirmed(1,identity,'observe:4',{44}) and sent==1,'UUID yield cannot publish to a replaced session')
print('PASS paid-spend challenge: canonical receipt, pre-yield reservation, private projection, login/epoch/expiry and no replay after failure')
