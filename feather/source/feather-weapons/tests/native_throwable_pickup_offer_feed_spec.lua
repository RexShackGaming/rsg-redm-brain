dofile('server/services/native_throwable_pickup_offer_feed.lua')
local actor={characterId='jane',sessionId='sid',epoch='epoch',alive=true,bucket=1,position={x=0,y=0,z=0}}
local sent,held={},false
local api={actor=function() return actor end,available=function() return not held end,
 send=function(_,value) sent[#sent+1]=value end}
local function row(id,x,bucket) return {version=3,kind='paid_tomahawk_pickup',phase='available',pickupId=id,pickupRevision=0,
 bucket=bucket or 1,position={x=x,y=0,z=0},metadata={serialNumber='private'},origin={characterId='john'}} end
api.page=function(cursor)
 if not cursor then return {bindings={row('near',1),row('foreign',1,2),row('far',100)},scanned=64,hasMore=true,cursor='page1'} end
 return {bindings={row('nearer',0)},scanned=1,hasMore=false,cursor='page2'}
end
local feed=WeaponNativeThrowablePickupOfferFeed.New(api)
assert(not feed.Send(1));assert(feed.Step());assert(not feed.Send(1),'partial scan never replaces complete snapshot')
assert(feed.Step() and feed.Send(1))
assert(#sent[1].pickups==2 and sent[1].pickups[1].id=='nearer' and sent[1].sequence==1)
assert(not sent[1].pickups[1].metadata and not sent[1].pickups[1].origin)
held=true;assert(feed.Send(1) and #sent[2].pickups==0 and sent[2].sequence==2)
held=false;actor.epoch='new';assert(feed.Send(1) and sent[3].sequence==1)
api.page=function() error('database unavailable') end
assert(not feed.Step());assert(feed.Send(1) and #sent[4].pickups==2,'failed reload preserves complete cache')
actor.alive=false;assert(not feed.Send(1));actor.alive=true
api.available=function() actor.sessionId='changed';return true end
assert(not feed.Send(1),'session changes while projection yields cannot receive old offers')
print('PASS durable offer feed: bounded reload, no partial publish, nearby bucket projection, privacy, reservation filtering and session sequencing')
local native=row('native',1);native.presentation='native'
api.page=function() return {bindings={native},scanned=1,hasMore=false} end
local isolated=WeaponNativeThrowablePickupOfferFeed.New(api)
assert(not isolated.Step() and not isolated.Send(1),'native binding cannot publish a prompt visual even if mislabeled v3')
