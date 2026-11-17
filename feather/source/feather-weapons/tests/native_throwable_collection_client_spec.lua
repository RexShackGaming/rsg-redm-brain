dofile('client/native_throwable_collection_client.lua')
dofile('client/native_throwable_collection_escrow.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local event={kind='ai_pickup',referenceBuild=1491,queue=0,eventHash=-178091376,nativeTomahawkQuantity=1,
 collectorIsLocal=true,collectorPlayerIndex=16,localPlayerIndex=16,rawSlots={-897823490,1,16,-936393949,0,123,1,-1511427369}}
local function fixture()
 local world={characterId='john',sessionId='session',epoch='before',alive=true,ped=7,bucket=0}
 local baseline={characterId='john',sessionId='session',epoch='before',revision=0,pools={ammo_tomahawk_regular=0,ammo_revolver_regular=10}}
 local pools=copy(baseline.pools);local now=0
 local calls={observe=0,status=0,cleaned=0,begin=0,finish=0,release=0,suspend=0}
 local c
 local runtime={BeginNativeCollectionHold=function(ticket,i) calls.begin=calls.begin+1;return ticket=='ticket' and i.epoch=='before' end,
  EndNativeCollectionHold=function(ticket)
   calls.finish=calls.finish+1;return c.ReadEscrow(ticket).phase=='cleaned' and pools.ammo_tomahawk_regular==0
  end}
 local api={now=function() return now end,world=function() return copy(world) end,
  snapshot=function() return copy(baseline) end,pools=function() return copy(pools) end,
  suspend=function() calls.suspend=calls.suspend+1 end,
  send=function(action) calls[action]=calls[action]+1 end}
 api.escrow=function()
  return WeaponNativeThrowableCollectionEscrow.New({world=api.world,now=api.now,pools=api.pools,
   capture=function() return {guid=string.rep('a',32)} end,absent=function() return true end,
   release=function() calls.release=calls.release+1;pools.ammo_tomahawk_regular=0;return true end})
 end
 c=WeaponNativeThrowableCollectionClient.New(api)
 local packet={ticket='ticket',identity=copy(world),bucket=0,lifetimeMs=30000}
 return c,api,world,baseline,pools,calls,runtime,packet,function(n) now=n end
end
for _,early in ipairs({false,true}) do
 local c,api,w,b,p,n,r,packet,time=fixture()
 assert(not c.Arm(packet,false) and c.Arm(packet,true));assert(c.BeforeStep(r) and n.begin==0)
 p.ammo_tomahawk_regular=1
 if early then assert(c.Event(event)) end
 assert(c.BeforeStep(r) and n.begin==1 and c.Status().phase=='held')
 if not early then assert(c.Event(event)) end
 assert(n.observe==1 and not c.Event(event))
 assert(not c.Escrow({ticket='forged',identity=w},true))
 assert(c.Escrow({ticket='ticket',identity=w},true))
 assert(c.Status().phase=='cleaned' and n.release==1 and n.finish==1 and n.cleaned==1)
 assert(c.Escrow({ticket='ticket',identity=w},true) and n.cleaned==2 and n.release==1,'duplicate request may resend receipt only')
 time(300);assert(c.BeforeStep(r) and n.status>=1 and n.observe==1)
 w.epoch='restored'
 assert(c.Result({ticket='ticket',result={phase='complete',collector=packet.identity,identity=copy(w)}},true))
 assert(c.Status().phase=='idle' and not c.Arm(packet,true))
end
for _,bad in ipairs({'death','epoch','revision','other_pool','two_units','timeout','send_failure'}) do
 local c,api,w,b,p,n,r,packet,time=fixture();assert(c.Arm(packet,true))
 if bad=='death' then w.alive=false
 elseif bad=='epoch' then w.epoch='changed'
 elseif bad=='revision' then b.revision=1
 elseif bad=='other_pool' then p.ammo_revolver_regular=11
 elseif bad=='two_units' then p.ammo_tomahawk_regular=2
 else p.ammo_tomahawk_regular=1;assert(c.BeforeStep(r))
  if bad=='timeout' then time(10001) else api.send=function() error('transport unavailable') end;assert(not c.Event(event)) end
 end
 assert(not c.BeforeStep(r) and n.suspend>0 and n.release==0,bad)
end
local c,api,w,b,p,n,r,packet,time=fixture();assert(c.Arm(packet,true));time(30001)
assert(c.BeforeStep(r) and c.Status().phase=='idle' and n.suspend==0,'unused arm expires without changing native state')
print('PASS server-armed collection client: pre-sample hold, early/late local event, exact cleanup, receipt-only duplicate replies, fresh restore and failure retention')
