dofile('server/services/native_throwable_collection_handoff.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture()
 local actor={characterId='john',sessionId='login',epoch='before',alive=true,bucket=0}
 local origin={characterId='jane',sessionId='donor',epoch='donor-epoch'}
 local binding={id='native-binding',revision=0,itemId=109,itemRevision=8,origin=origin,
  version=4,kind='paid_tomahawk_native_pickup',pickupId='native-binding',pickupRevision=0,
  presentation='native',phase='available',metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='PAID-109'}}
 local authorization={kind='paid_native_collection',phase='correlated',collector=copy(actor),origin=origin,bucket=0,binding=binding}
 local counts={escrow=0,bind=0,claim=0,readBinding=0,readClaim=0}
 local api={actor=function() return copy(actor) end,resolve=function() return copy(authorization) end,
  current=function() return true end,ticket=function() return 'ticket' end}
 local escrow={phase='cleaned',ticket='ticket',identity=copy(actor),quantityBefore=1,quantityAfter=0,
  guidCaptured=true,guidReleased=true,otherPoolsUnchanged=true}
 local function receipt()
  local old=copy(actor);old.epoch='before';actor.epoch='after'
  return {phase='claimed',id=binding.id,revision=binding.revision,itemId=109,collector=old,identity=copy(actor)}
 end
 api.beginEscrow=function() counts.escrow=counts.escrow+1;return true end
 api.readEscrow=function() return copy(escrow) end
 api.bind=function(_,current) counts.bind=counts.bind+1;assert(current());return copy(binding) end
 api.readBinding=function() counts.readBinding=counts.readBinding+1;return copy(binding) end
 api.claim=function(_,b,identity,current)
  counts.claim=counts.claim+1;assert(current() and b.itemId==109 and identity.epoch=='before');return receipt()
 end
 api.readClaim=function() counts.readClaim=counts.readClaim+1;return receipt() end
 local h=WeaponNativeThrowableCollectionHandoff.New(api)
 return h,api,actor,authorization,escrow,counts,receipt
end
local h,api,a,auth,escrow,c=fixture()
assert(h.Begin(1,'observed').phase=='escrow_pending')
assert(h.Read(2,'ticket').reason=='unknown_handoff')
assert(h.Read(1,'ticket').phase=='complete')
assert(c.escrow==1 and c.bind==1 and c.claim==1)
assert(h.Read(1,'ticket').phase=='complete' and c.claim==1)
assert(h.Begin(1,'replayed-event').phase=='refused' and c.escrow==1 and c.claim==1)
for _,failure in ipairs({'synthetic','uncorrelated','prompt','metadata','wrong_collector','bucket','dead'}) do
 local h,api,a,auth,escrow,c=fixture()
 if failure=='synthetic' then auth.kind='synthetic_native_collection'
 elseif failure=='uncorrelated' then auth.phase='review_required'
 elseif failure=='prompt' then auth.binding.presentation='prompt'
 elseif failure=='metadata' then auth.binding.metadata.serialNumber=nil
 elseif failure=='wrong_collector' then auth.collector.sessionId='other'
 elseif failure=='bucket' then a.bucket=1 else a.alive=false end
 assert(h.Begin(1,'observed').phase=='refused' and c.escrow==0,failure)
end
for _,failure in ipairs({'guidReleased','otherPoolsUnchanged','quantityAfter','quantityBefore','ticket','identity'}) do
 local h,api,a,auth,escrow,c=fixture();h.Begin(1,'observed')
 if failure=='quantityAfter' then escrow.quantityAfter=1
 elseif failure=='quantityBefore' then escrow.quantityBefore=2
 elseif failure=='ticket' then escrow.ticket='other'
 elseif failure=='identity' then escrow.identity.epoch='other'
 else escrow[failure]=false end
 assert(h.Read(1,'ticket').phase=='review_required' and c.bind==0 and c.claim==0,failure)
end
local h,api,a,auth,escrow,c=fixture()
api.bind=function() c.bind=c.bind+1;error('lost SQL binding reply') end
h.Begin(1,'observed');assert(h.Read(1,'ticket').phase=='binding_pending')
assert(h.Read(1,'ticket').phase=='complete' and c.bind==1 and c.readBinding==1 and c.claim==1)
local h,api,a,auth,escrow,c,receipt=fixture()
api.claim=function() c.claim=c.claim+1;error('lost claim reply') end
h.Begin(1,'observed');assert(h.Read(1,'ticket').phase=='claim_pending')
assert(h.Read(1,'ticket').phase=='complete' and c.claim==1 and c.readClaim==1)
local h,api,a,auth,escrow,c=fixture()
api.claim=function() c.claim=c.claim+1;return {phase='pending'} end
h.Begin(1,'observed');h.Read(1,'ticket');a.sessionId='new-login'
assert(h.Read(1,'ticket').phase=='claim_pending','receipt from a new login cannot certify restore')
assert(c.claim==1)
local h,api,a,auth,escrow,c=fixture()
h.Begin(1,'observed');a.alive=false
assert(h.Read(1,'ticket').phase=='review_required' and c.bind==0)
local h,api,a,auth,escrow,c=fixture()
api.bind=function(_,current)
 c.bind=c.bind+1;a.epoch='changed';assert(not current());return copy(auth.binding)
end
h.Begin(1,'observed');assert(h.Read(1,'ticket').phase=='review_required' and c.claim==0)
local h,api,a,auth,escrow,c=fixture()
api.readEscrow=function()
 assert(h.Read(1,'ticket').phase=='escrow_pending','reentrant status cannot bind twice')
 return escrow
end
h.Begin(1,'observed');assert(h.Read(1,'ticket').phase=='complete' and c.bind==1 and c.claim==1)
print('PASS paid native collection handoff: exact unit reservation, escrow proof, no replay after uncertain writes, fresh restore receipt')
