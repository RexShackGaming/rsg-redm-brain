dofile('shared/native_acceptance_view.lua')
dofile('shared/character_ammunition.lua')
local limits={ammo=100,known_zero_pool=100}
local matches=WeaponNativeAcceptanceView.MatchesDurable
WeaponNativeAcceptanceView.MatchesDurable=function(v,d) return matches(v,d,limits) end
local V=WeaponNativeAcceptanceView
local wear={damage=0,degradation=0.01,dirt=1,soot=0,permanentDegradation=0}
local id={characterId='jane',sessionId='session',epoch='epoch'}
local status={phase='started',cleanupComplete=false,ownedCopies=1,bootstrap={runtime={phase='active',runtimeBusy=false,
 session={ammo={phase='active',baseline={phase='active',characterId=id.characterId,sessionId=id.sessionId,epoch=id.epoch,revision=35,pools={ammo=1}}},
 utility={phase='active',items={{phase='active',itemId=229,itemRevision=8,guidOwnershipCaptured=true}}}}}}}
local owner={Status=function() return status end,MaintenanceStatus=function() return {epoch='epoch',items={{itemInstanceId=112,itemRevision=2,maintenance=wear}}} end}
local v=assert(V.Read(owner,id));assert(v.utility[1].id==229 and v.maintenance[1].wear.dirt==1)
local durable={items={{id=112,row_revision=2,metadata={maintenance=wear}},{id=229,row_revision=8}},
 equipment={{slot='weapon',inventory_items_id=112},{slot='weapon_utility',inventory_items_id=229}},ammo={{revision=35,pools={ammo=1}}}}
assert(V.MatchesDurable(v,durable))
v.pools.known_zero_pool=0;assert(V.MatchesDurable(v,durable),'missing known zero pool is normalized by normal runtime contract')
v.pools.known_zero_pool=1;local ok,why=V.MatchesDurable(v,durable);assert(not ok and why=='ammo_pools')
v.pools.known_zero_pool=0
v.pools.unknown_pool=0;assert(not V.MatchesDurable(v,durable),'unknown pool still refused even if zero');v.pools.unknown_pool=nil
durable.ammo[1].revision=36;ok,why=V.MatchesDurable(v,durable);assert(not ok and why=='ammo_revision');durable.ammo[1].revision=35
durable.items[2].row_revision=9;assert(not V.MatchesDurable(v,durable));durable.items[2].row_revision=8
durable.equipment[2].inventory_items_id=999;assert(not V.MatchesDurable(v,durable));durable.equipment[2].inventory_items_id=229
v.maintenance[1].wear.dirt=0;assert(not V.MatchesDurable(v,durable));v.maintenance[1].wear.dirt=1
status.bootstrap.runtime.runtimeBusy=true;assert(V.Read(owner,id)==nil);status.bootstrap.runtime.runtimeBusy=false
status.bootstrap.runtime.session.ammo.pending=true;assert(V.Read(owner,id)==nil);status.bootstrap.runtime.session.ammo.pending=nil
status.bootstrap.runtime.session.utility.items[1].guidOwnershipCaptured=false;assert(V.Read(owner,id)==nil)
status.bootstrap.runtime.session.utility.items[1].guidOwnershipCaptured=true
assert(V.Read(owner,{characterId='john',sessionId='session',epoch='epoch'})==nil)
v=assert(V.Read(owner,id));v.utility[2]=v.utility[1];assert(V.Normalize(v)==nil)
v=assert(V.Read(owner,id));v.pools.ammo=0/0;assert(V.Normalize(v)==nil)
print('PASS bounded actual-owner view: epoch, idle state, GUID ownership, durable ammo/item revision/equipment/wear matching, malformed input')
