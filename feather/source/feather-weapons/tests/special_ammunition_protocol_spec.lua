for _,p in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_runtime.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local limits={ammo_tomahawk_regular=3,ammo_arrow_regular=40,ammo_arrow_small_game=40,ammo_arrow_poison=8,
 ammo_arrow_fire=8,ammo_arrow_dynamite=8,ammo_throwing_knives_regular=8,ammo_throwing_knives_poison=8}
local pools={};for id in pairs(limits) do pools[id]=0 end
pools.ammo_tomahawk_regular=3;pools.ammo_arrow_regular=40;pools.ammo_throwing_knives_regular=2;pools.ammo_throwing_knives_poison=8
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local C=WeaponCharacterAmmoClient.New()
local live=assert(R.Open({source=1,characterId='jane',sessionId='s'},{characterId='jane',revision=0,pools=pools},limits,'e'))
assert(C.Begin(live,limits,1))
local function restore()
 local req=assert(C.Prepare(1,live.pools,true))
 live=assert(R.ConfirmRestore(1,req.report));assert(C.Accept(req.id,{ok=true,value=live},1))
end
restore()
local where={version=1,bucket=0,position={x=1,y=2,z=3}}
for _,id in ipairs({'ammo_arrow_small_game','ammo_arrow_poison','ammo_arrow_fire','ammo_arrow_dynamite'}) do
 local req=assert(C.PrepareTransfer(1,live.pools,true,id,limits[id],'load-'..id))
 local work=assert(R.PrepareTransfer(1,req.report,id,limits[id],'load-'..id))
 local next=copy(live.pools);next[id]=limits[id]
 live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=live.revision+1,pools=next}}))
 assert(C.Accept(req.id,{ok=true,value=live},1));restore()
 assert(live.pools.ammo_arrow_regular==40 and live.pools.ammo_throwing_knives_poison==8)
end
local next=copy(live.pools);next.ammo_throwing_knives_poison=7
local req=assert(C.Prepare(1,next,true));local work=assert(R.PrepareObservation(1,req.report))
assert(R.AttachQuantitySpend(work,where),'Poison debit must attach server allowance location')
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=live.revision+1,pools=next}}))
assert(C.Accept(req.id,{ok=true,value=live},1))
next=copy(live.pools);next.ammo_throwing_knives_regular=3
req=assert(C.PrepareNativePickup(1,next,true,true));work=assert(R.PrepareQuantityPickup(1,req.report,where))
assert(req.ammunitionId=='ammo_throwing_knives_regular' and work.spec.nativePickupPlan.ammunitionId==req.ammunitionId)
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=live.revision+1,pools=next}}))
assert(C.Accept(req.id,{ok=true,value=live},1))
assert(live.pools.ammo_throwing_knives_poison==7 and live.pools.ammo_arrow_fire==8)
-- Unconfirmed specialty pickup reports use the normal definite-decline path.
next=copy(live.pools);next.ammo_arrow_fire=7
req=assert(C.Prepare(1,next,true));work=assert(R.PrepareObservation(1,req.report))
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=live.revision+1,pools=next}}))
assert(C.Accept(req.id,{ok=true,value=live},1))
next=copy(live.pools);next.ammo_arrow_fire=8
req=assert(C.PrepareNativePickup(1,next,true,true));work=assert(R.PrepareQuantityPickup(1,req.report,where))
local accepted=copy(live.pools)
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=live.revision+1,pools=accepted,recovered=0,quantityDeclined=true}}))
assert(C.Accept(req.id,{ok=true,value=live,quantityDeclined=true,quantityAccepted=0},1))
assert(live.pools.ammo_arrow_fire==7 and live.pools.ammo_throwing_knives_regular==3)
print('PASS special protocol: independent typed transfers/restoration, Poison allowance reservation, Regular conversion, unconfirmed special increase definite decline without other-pool changes')
