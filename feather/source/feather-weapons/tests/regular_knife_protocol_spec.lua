for _,p in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_runtime.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local limits={ammo_throwing_knives_regular=8,ammo_tomahawk_regular=3,ammo_arrow_regular=40}
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local C=WeaponCharacterAmmoClient.New()
local live=assert(R.Open({source=1,characterId='jane',sessionId='s'},
 {characterId='jane',revision=0,pools={ammo_throwing_knives_regular=2,ammo_tomahawk_regular=3,ammo_arrow_regular=5}},limits,'e'))
assert(C.Begin(live,limits,1));local req=assert(C.Prepare(1,live.pools,true))
live=assert(R.ConfirmRestore(1,req.report));assert(C.Accept(req.id,{ok=true,value=live},1))
local where={version=1,bucket=0,position={x=1,y=2,z=3}}
local observed=copy(live.pools);observed.ammo_throwing_knives_regular=0
req=assert(C.Prepare(1,observed,true));local work=assert(R.PrepareObservation(1,req.report));assert(R.AttachQuantitySpend(work,where))
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=1,pools=observed}}));assert(C.Accept(req.id,{ok=true,value=live},1))
observed=copy(live.pools);observed.ammo_throwing_knives_regular=2;observed.ammo_arrow_regular=4
req=assert(C.PrepareNativePickup(1,observed,true,true));assert(req.ammunitionId=='ammo_throwing_knives_regular')
work=assert(R.PrepareQuantityPickup(1,req.report,where));assert(work.spec.nativePickupPlan.ammunitionId=='ammo_throwing_knives_regular')
local forged=copy(work.spec);forged.nativePickupPlan.ammunitionId='ammo_arrow_regular'
assert(not R.IsOperationCurrent(work.context,'pickup',forged))
local partial=copy(observed);partial.ammo_throwing_knives_regular=1
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=2,pools=partial,recovered=1,quantityDeclined=true}}))
assert(C.Accept(req.id,{ok=true,value=live,quantityDeclined=true,quantityAccepted=1},1))
assert(live.pools.ammo_throwing_knives_regular==1 and live.pools.ammo_tomahawk_regular==3 and live.pools.ammo_arrow_regular==4)
observed=copy(live.pools);observed.ammo_throwing_knives_regular=9
assert(not C.PrepareNativePickup(1,observed,true,true))
observed=copy(live.pools);observed.ammo_throwing_knives_regular=2;observed.ammo_arrow_regular=5
assert(not C.PrepareNativePickup(1,observed,true,true),'simultaneous type increases stay fail-closed')
print('PASS regular-knife protocol: paid debits, immutable pickup type, bounded/partial credit, preserve Tomahawks and genuine arrow reductions, refuse over-cap and ambiguous reports')
