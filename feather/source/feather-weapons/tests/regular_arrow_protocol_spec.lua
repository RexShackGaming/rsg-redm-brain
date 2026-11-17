for _,p in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_runtime.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local limits={ammo_arrow_regular=40,ammo_tomahawk_regular=3,ammo_revolver_regular=100}
local runtime=WeaponCharacterAmmoRuntime.New(function() return true end)
local client=WeaponCharacterAmmoClient.New()
local live=assert(runtime.Open({source=1,characterId='jane',sessionId='s'},
 {characterId='jane',revision=0,pools={ammo_arrow_regular=5,ammo_tomahawk_regular=3,ammo_revolver_regular=20}},limits,'e'))
assert(client.Begin(live,limits,1))
local req=assert(client.Prepare(1,live.pools,true));live=assert(runtime.ConfirmRestore(1,req.report));assert(client.Accept(req.id,{ok=true,value=live},1))
local where={version=1,bucket=0,position={x=1,y=2,z=3}}
local pools=copy(live.pools);pools.ammo_arrow_regular=3;pools.ammo_tomahawk_regular=2
req=assert(client.Prepare(1,pools,true));local work=assert(runtime.PrepareObservation(1,req.report))
assert(runtime.AttachQuantitySpend(work,where),'one settled sample may debit both supported types')
live=assert(runtime.Complete(work.context,{ok=true,value={characterId='jane',revision=1,pools=pools}}))
assert(client.Accept(req.id,{ok=true,value=live},1))
pools=copy(live.pools);pools.ammo_arrow_regular=5;pools.ammo_revolver_regular=19
req=assert(client.PrepareNativePickup(1,pools,true,true));assert(req.ammunitionId=='ammo_arrow_regular')
work=assert(runtime.PrepareQuantityPickup(1,req.report,where));assert(work.spec.nativePickupPlan.ammunitionId=='ammo_arrow_regular')
local forged=copy(work.spec);forged.nativePickupPlan.ammunitionId='ammo_tomahawk_regular'
assert(not runtime.IsOperationCurrent(work.context,'pickup',forged),'caller cannot switch allowance type after reservation')
local accepted=copy(pools);accepted.ammo_arrow_regular=4
live=assert(runtime.Complete(work.context,{ok=true,value={characterId='jane',revision=2,pools=accepted,quantityDeclined=true,recovered=1}}))
assert(client.Accept(req.id,{ok=true,value=live,quantityDeclined=true,quantityAccepted=1},1))
assert(live.pools.ammo_arrow_regular==4 and live.pools.ammo_tomahawk_regular==2 and live.pools.ammo_revolver_regular==19)
pools=copy(live.pools);pools.ammo_arrow_regular=6;pools.ammo_tomahawk_regular=3
assert(not client.PrepareNativePickup(1,pools,true,true),'ambiguous simultaneous type increases fail closed')
pools=copy(live.pools);pools.ammo_arrow_regular=41
assert(not client.PrepareNativePickup(1,pools,true,true),'over-cap read cannot be credited')
print('PASS regular-arrow protocol: immutable type reservation, batched arrow increase, partial credit, genuine firearm debit preserved, foreign/over-cap rejection')
