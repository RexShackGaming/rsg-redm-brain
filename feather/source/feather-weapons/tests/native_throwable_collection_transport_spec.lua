for _,file in ipairs({'server/services/native_throwable_transition_binding.lua','server/services/native_projectile_collection_observation.lua',
 'server/services/native_throwable_collection_handoff.lua','server/services/native_throwable_collection_service.lua',
 'server/services/native_throwable_collection_transport.lua','client/native_throwable_collection_escrow.lua',
 'client/native_throwable_collection_client.lua'}) do dofile(file) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture(lost)
 local clock,gate=0,true
 local actors={[1]={characterId='jane',sessionId='donor',epoch='origin',alive=true,bucket=0,position={x=0,y=0,z=0}},
  [2]={characterId='john',sessionId='collector',epoch='before',alive=true,bucket=0,ped=7,position={x=0,y=0,z=0}}}
 local rows={[10]={exists=true,networkId=30,netType=23,owner=1,bucket=0},[20]={exists=true,networkId=40,netType=8,owner=1,bucket=0}}
 local baseline={characterId='john',sessionId='collector',epoch='before',revision=0,pools={ammo_tomahawk_regular=0,ammo_revolver_regular=10}}
 local pools=copy(baseline.pools)
 local item={id=109,revision=4,holder='spent:jane',metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='PAID-109',condition=97},collectorAmmo=0}
 local client,transport,receipt
 local calls={claim=0,cleanup=0,hold=0,release=0,suspend=0,begin=0}
 local actor=function(source) return copy(actors[source]) end
 local now=function() return clock end
 local service=WeaponNativeThrowableCollectionService.New({now=now,actor=actor,read=function(handle) return copy(rows[handle]) end,
  challenge=function() return {identity=copy(actors[1]),operationId='spend',units={{itemId=109,itemRevision=4}}} end,
  spend=function() return {custody='spent',operationId='spend',itemId=109,itemRevision=4,origin=copy(actors[1]),metadata=copy(item.metadata)} end,
  newId=function() return 'watch' end,collectorEmpty=function() return item.collectorAmmo==0 end,
  ticket=function(auth) return transport.Ticket(auth) end,
  beginEscrow=function(...) calls.begin=calls.begin+1;return transport.BeginEscrow(...) end,
  readEscrow=function(...) return transport.ReadEscrow(...) end,
  bind=function(auth,current) assert(current());return copy(auth.binding) end,
  readBinding=function(auth) return copy(auth.binding) end,
  claim=function(source,b,identity,current)
   assert(current() and source==2 and b.itemId==109 and pools.ammo_tomahawk_regular==0)
   calls.claim=calls.claim+1;item.holder='carried:john';item.revision=5;item.collectorAmmo=1
   actors[2].epoch='restored'
   receipt={phase='claimed',id=b.id,revision=b.revision,itemId=109,collector=copy(identity),identity=actor(2)}
   if lost then error('SQL reply lost') end
   return copy(receipt)
  end,readClaim=function() return copy(receipt) end})
 transport=WeaponNativeThrowableCollectionTransport.New({service=service,actor=actor,now=now,enabled=function() return gate end,
  prepare=service.Prepare,newTicket=function() return 'ticket' end,
  send=function(source,action,packet)
   assert(source==2)
   if action=='arm' then assert(client.Arm(packet,true))
   elseif action=='escrow' then assert(client.Escrow(packet,true))
   else client.Result(packet,true) end
  end})
 local runtime={BeginNativeCollectionHold=function() calls.hold=calls.hold+1;return true end,
  EndNativeCollectionHold=function(ticket) calls.release=calls.release+1;return client.ReadEscrow(ticket).phase=='cleaned' end}
 client=WeaponNativeThrowableCollectionClient.New({world=function() return actor(2) end,snapshot=function() return copy(baseline) end,
  pools=function() return copy(pools) end,now=now,suspend=function() calls.suspend=calls.suspend+1 end,
  send=function(action,packet) transport.Handle(2,action,packet) end,
  escrow=function() return WeaponNativeThrowableCollectionEscrow.New({world=function() return actor(2) end,now=now,pools=function() return copy(pools) end,
   capture=function() return {guid=string.rep('a',32)} end,absent=function() return true end,
   release=function() calls.cleanup=calls.cleanup+1;pools.ammo_tomahawk_regular=0;return true end}) end})
 assert(service.Created(10));clock=100;rows[10].exists=false;service.Removed(10)
 clock=150;assert(service.Created(20));assert(service.Watch(1,'challenge',30,40,{x=0,y=0,z=0}).phase=='watching')
 assert(transport.Arm(2,'watch'))
 return client,transport,service,runtime,actors,rows,pools,item,calls,function(n) clock=n end,function(v) gate=v end
end
local event={kind='ai_pickup',referenceBuild=1491,queue=0,eventHash=-178091376,nativeTomahawkQuantity=1,
 collectorIsLocal=true,collectorPlayerIndex=16,localPlayerIndex=16,rawSlots={-897823490,1,16,-936393949,0,123,1,-1511427369}}
for _,lost in ipairs({false,true}) do
 local c,t,s,r,a,rows,p,item,n,time=fixture(lost)
 assert(not t.Handle(1,'observe',{ticket='ticket',event=event}),'foreign source cannot use collector ticket')
 assert(not t.Handle(2,'observe',{ticket='forged',event=event}))
 rows[20].exists=false;s.Removed(20);p.ammo_tomahawk_regular=1
 assert(c.Event(event));assert(c.BeforeStep(r))
 if lost then time(500);assert(c.BeforeStep(r)) end
 assert(c.Status().phase=='idle' and item.holder=='carried:john' and item.id==109 and item.revision==5)
 assert(item.metadata.serialNumber=='PAID-109' and item.metadata.condition==97)
 assert(n.claim==1 and n.cleanup==1 and n.hold==1 and n.release==1 and n.suspend==0)
 t.Handle(2,'status',{ticket='ticket'});t.Handle(2,'observe',{ticket='ticket',event=event})
 assert(n.claim==1 and n.cleanup==1 and n.begin==1,'replayed packets cannot repeat economic/native mutations')
end
local c,t,s,r,a,rows,p,item,n,time,gate=fixture()
gate(false);assert(not t.Handle(2,'status',{ticket='ticket'}) and n.claim==0)
print('PASS actual paid collection transport/client/service composition: server arm, early event, pre-sample hold, cleanup/release, exact paid row, lost SQL reply and packet replay')

-- Actual yielded ingress: the medical/actor and observer calls can wait on
-- another resource. A concurrent status must not read a busy observer.
do
 local identity={characterId='john',sessionId='sid',epoch='epoch',alive=true,bucket=0}
 local yielding=false;local observations,begins,reads=0,0,0
 local api={enabled=function() return true end,now=function() return 0 end,
  actor=function() if yielding then coroutine.yield('actor_wait') end;return identity end,
  prepare=function() return {identity=identity,bucket=0} end,newTicket=function() return 'ticket' end,send=function() end,
  service={Observe=function() observations=observations+1;coroutine.yield('observe_wait');return {phase='pending'} end,
   ReadObservation=function() reads=reads+1;return {phase='correlated_observation'} end,
   Begin=function() begins=begins+1;return {phase='escrow_pending'} end,Read=function() return {phase='pending'} end}}
 local t=WeaponNativeThrowableCollectionTransport.New(api);assert(t.Arm(2,'watch'))
 yielding=true
 local worker=coroutine.create(function() return t.Handle(2,'observe',{ticket='ticket',event=event}) end)
 assert(select(2,coroutine.resume(worker))=='actor_wait')
 assert(t.Handle(2,'status',{ticket='ticket'}) and reads==0)
 yielding=false
 assert(select(2,coroutine.resume(worker))=='observe_wait')
 assert(t.Handle(2,'status',{ticket='ticket'}) and reads==0 and begins==0)
 assert(coroutine.resume(worker));assert(observations==1 and reads==1 and begins==1)
 assert(t.Handle(2,'status',{ticket='ticket'}) and begins==1)
end
-- An observe arriving while an earlier status waits must be queued, not lost;
-- it is not a safe-to-repeat mutation request from the client.
do
 local identity={characterId='john',sessionId='sid',epoch='epoch',alive=true,bucket=0}
 local yielding=false;local observations,begins=0,0
 local api={enabled=function() return true end,now=function() return 0 end,
  actor=function() if yielding then coroutine.yield('actor_wait') end;return identity end,
  prepare=function() return {identity=identity,bucket=0} end,newTicket=function() return 'ticket' end,send=function() end,
  service={Observe=function() observations=observations+1;return {phase='correlated_observation'} end,
   ReadObservation=function() return {phase='correlated_observation'} end,
   Begin=function() begins=begins+1;return {phase='escrow_pending'} end,Read=function() return {phase='pending'} end}}
 local t=WeaponNativeThrowableCollectionTransport.New(api);assert(t.Arm(2,'watch'))
 yielding=true
 local worker=coroutine.create(function() return t.Handle(2,'status',{ticket='ticket'}) end)
 assert(select(2,coroutine.resume(worker))=='actor_wait')
 assert(t.Handle(2,'observe',{ticket='ticket',event=event}))
 assert(t.Handle(2,'observe',{ticket='ticket',event=event}))
 yielding=false;assert(coroutine.resume(worker));assert(observations==1 and begins==1)
end
print('PASS yielded native collection transport: status/Observe overlap, queued single observation, no invalid busy read or repeated Begin')
do
 local c,t,s,r,a,rows,p,item,n=fixture()
 a[2].position.x=3;rows[20].exists=false;s.Removed(20);p.ammo_tomahawk_regular=1
 assert(t.Handle(2,'observe',{ticket='ticket',event=event}))
 local d=t.Diagnostics(2)
 assert(d.reason=='no_bound_candidate' and d.candidateDiagnostics.watches[1].distanceSquared==9)
 d.candidateDiagnostics.watches[1].position.x=999
 local read=s.ReadObservation
 s.ReadObservation=function() error('diagnostic getter must not poll') end
 assert(t.Diagnostics(2).candidateDiagnostics.watches[1].position.x==0 and t.Diagnostics(1)==nil)
 s.ReadObservation=read
 assert(n.begin==0 and n.claim==0 and n.cleanup==0 and p.ammo_tomahawk_regular==1)
end
print('PASS server-only observation diagnostics: retained refusal inputs, immutable readback, no progress or cleanup/claim')
