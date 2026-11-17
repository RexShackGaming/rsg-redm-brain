dofile('client/native_throwable_collection_escrow.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture()
 local world={characterId='john',sessionId='login',epoch='epoch',alive=true,ped=1,bucket=0}
 local pools={ammo_tomahawk_regular=1,ammo_revolver_regular=100}
 local baseline={ammo_tomahawk_regular=0,ammo_revolver_regular=100}
 local calls={capture=0,release=0};local now=0
 local api={world=function() return copy(world) end,now=function() return now end,pools=function() return copy(pools) end}
 api.capture=function() calls.capture=calls.capture+1;return {guid=string.rep('a',32)} end
 api.release=function() calls.release=calls.release+1;pools.ammo_tomahawk_regular=0;return true end
 api.absent=function() return true end
 local e=WeaponNativeThrowableCollectionEscrow.New(api)
 return e,api,world,pools,baseline,calls,function(n) now=n end
end
local e,api,w,p,b,c=fixture()
local s=e.Begin('ticket',w,b)
assert(s.phase=='cleaned' and s.guidCaptured and s.guidReleased and s.otherPoolsUnchanged)
assert(s.quantityBefore==1 and s.quantityAfter==0 and c.capture==1 and c.release==1)
assert(e.Step().phase=='cleaned' and c.release==1)
assert(e.Begin('replay',w,b).phase=='refused')
for _,bad in ipairs({'quantity','other_pool','death','epoch','guid','release','absent','baseline','exception','timeout'}) do
 local e,api,w,p,b,c,time=fixture()
 if bad=='quantity' then p.ammo_tomahawk_regular=2
 elseif bad=='other_pool' then p.ammo_revolver_regular=101
 elseif bad=='death' then api.capture=function() c.capture=c.capture+1;w.alive=false;return {guid=string.rep('a',32)} end
 elseif bad=='epoch' then api.capture=function() c.capture=c.capture+1;w.epoch='changed';return {guid=string.rep('a',32)} end
 elseif bad=='guid' then api.capture=function() c.capture=c.capture+1;return {guid=string.rep('0',32)} end
 elseif bad=='release' then api.release=function() c.release=c.release+1;return false end
 elseif bad=='absent' then api.absent=function() return false end
 elseif bad=='baseline' then api.release=function() c.release=c.release+1;p.ammo_tomahawk_regular=0;p.ammo_revolver_regular=99;return true end
 elseif bad=='exception' then api.release=function() c.release=c.release+1;error('native reply lost') end
 else api.capture=function() c.capture=c.capture+1;time(10001);return {guid=string.rep('a',32)} end end
 assert(e.Begin('ticket',w,b).phase=='review_required',bad)
 local captures,releases=c.capture,c.release
 assert(e.Step().phase=='review_required' and c.capture==captures and c.release==releases,bad..' must never replay')
 if bad=='death' or bad=='epoch' or bad=='timeout' or bad=='guid' then assert(c.release==0) end
end
print('PASS provisional native collection escrow: one exact GUID, all-pool conservation, scope/death/deadline refusal, uncertain native writes never replay')
