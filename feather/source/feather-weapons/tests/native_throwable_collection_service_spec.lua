for _,file in ipairs({'server/services/native_throwable_transition_binding.lua','server/services/native_projectile_collection_observation.lua',
 'server/services/native_throwable_collection_handoff.lua','server/services/native_throwable_collection_service.lua',
 'client/native_throwable_collection_escrow.lua'}) do dofile(file) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local event={referenceBuild=1491,kind='ai_pickup',queue=0,eventHash=-178091376,localPlayerIndex=16,nativeTomahawkQuantity=1,
 rawSlots={-897823490,1,16,-936393949,0,147252816,1,-1511427369}}
local function fixture(mode)
 local clock=0
 local actors={[1]={characterId='jane',sessionId='donor',epoch='origin',alive=true,bucket=0,position={x=0,y=0,z=0}},
  [2]={characterId='john',sessionId='collector',epoch='before',alive=true,bucket=0,position={x=0,y=0,z=0}}}
 local rows={[10]={exists=true,networkId=30,netType=23,owner=1,bucket=0},
  [20]={exists=true,networkId=40,netType=8,owner=1,bucket=0}}
 local metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='PAID-109',condition=97,flags={stolen=true},attachments={}}
 local spend={custody='spent',operationId='spend:1',itemId=109,itemRevision=4,origin=copy(actors[1]),metadata=copy(metadata)}
 local pools={ammo_tomahawk_regular=1,ammo_revolver_regular=10}
 local baseline={ammo_tomahawk_regular=0,ammo_revolver_regular=10}
 local canonical={id=109,revision=4,holder='spent:jane',metadata=copy(metadata),collectorAmmo=0}
 local counts={bind=0,claim=0,release=0,readClaim=0}
 local binding,receipt,escrow,service
 local api={now=function() return clock end,actor=function(source) return copy(actors[source]) end,
  read=function(handle) return copy(rows[handle]) end,newId=function() return 'paid-pickup' end,
  ticket=function() return 'cleanup-ticket' end,collectorEmpty=function() return canonical.collectorAmmo==0 end,
  challenge=function(source,id)
   if source==1 and id=='server-challenge' then return {identity=copy(actors[1]),operationId='spend:1',units={{itemId=109,itemRevision=4}}} end
  end,
  spend=function() counts.spend=(counts.spend or 0)+1;return copy(spend) end}
 api.beginEscrow=function(source,ticket,identity)
  assert(source==2 and canonical.holder=='spent:jane' and canonical.collectorAmmo==0)
  escrow=WeaponNativeThrowableCollectionEscrow.New({now=api.now,
   world=function() local a=copy(actors[2]);a.ped=7;return a end,pools=function() return copy(pools) end,
   capture=function() return {guid=string.rep('a',32)} end,
   release=function() counts.release=counts.release+1;pools.ammo_tomahawk_regular=0;return mode~='cleanup_failure' end,
   absent=function() return true end})
  return escrow.Begin(ticket,identity,baseline)
 end
 api.readEscrow=function() return escrow.Status() end
 api.bind=function(value,current)
  counts.bind=counts.bind+1;assert(current() and pools.ammo_tomahawk_regular==0)
  local reads=counts.spend
  for _=1,20 do assert(current()) end
  assert(counts.spend==reads,'write guards must not reopen receipt transactions')
  assert(service.ValidateBinding(1,value.binding) and not service.ValidateBinding(2,value.binding),'only origin writer reservation can cross Inventory storage')
  assert(value.binding.version==4 and value.binding.metadata.serialNumber=='PAID-109')
  binding=copy(value.binding)
  if mode=='lost_binding_reply' then error('binding committed but reply lost') end
  return binding
 end
 api.readBinding=function() return copy(binding) end
 api.claim=function(source,b,identity,current)
  counts.claim=counts.claim+1;assert(current() and source==2 and b.itemId==109 and b.itemRevision==4)
  assert(canonical.holder=='spent:jane' and pools.ammo_tomahawk_regular==0)
  canonical.holder='carried:john';canonical.revision=5;canonical.collectorAmmo=1
  actors[2].epoch='restored'
  receipt={phase='claimed',id=b.id,revision=b.revision,itemId=109,collector=copy(identity),identity=copy(actors[2])}
  if mode=='lost_reply' then error('SQL reply lost after modeled commit') end
  return copy(receipt)
 end
 api.readClaim=function() counts.readClaim=counts.readClaim+1;return copy(receipt) end
 service=WeaponNativeThrowableCollectionService.New(api)
 assert(service.Created(10));clock=100;rows[10].exists=false;service.Removed(10)
 clock=150;assert(service.Created(20))
 assert(service.Watch(1,'server-challenge',30,40,{x=0,y=0,z=0}).phase=='watching')
 return service,actors,rows,spend,canonical,counts,function(n) clock=n end
end
for _,mode in ipairs({'success','lost_reply','lost_binding_reply','cleanup_failure'}) do
 local s,a,rows,spend,item,c,time=fixture(mode)
 rows[20].exists=false;s.Removed(20);time(250)
 assert(s.Observe(2,'event',event).phase=='correlated_observation')
 assert(s.Begin(2,'event').phase=='escrow_pending')
 local result=s.Read(2,'cleanup-ticket')
 if mode=='cleanup_failure' then
  assert(result.phase=='review_required' and c.bind==0 and c.claim==0 and item.holder=='spent:jane')
 else
  if mode=='lost_reply' then assert(result.phase=='claim_pending');result=s.Read(2,'cleanup-ticket') end
  if mode=='lost_binding_reply' then assert(result.phase=='binding_pending');result=s.Read(2,'cleanup-ticket') end
  assert(result.phase=='complete' and item.id==109 and item.revision==5 and item.holder=='carried:john')
  assert(item.metadata.serialNumber=='PAID-109' and item.metadata.condition==97 and item.metadata.flags.stolen)
  assert(c.claim==1 and c.bind==1 and c.release==1)
  assert(not s.ValidateBinding(1,{}),'finished writer does not authorize more storage writes')
  s.Read(2,'cleanup-ticket');s.Begin(2,'event');assert(c.claim==1 and c.release==1)
 end
end
local s,a,rows,spend,item,c,time=fixture()
assert(s.Observe(2,'event',event).phase=='pending')
assert(s.Begin(2,'event').phase=='refused' and c.release==0,'native presence cannot authorize cleanup/claim')
local s,a,rows,spend,item,c,time=fixture()
rows[20].exists=false;s.Removed(20);time(250)
assert(s.Observe(2,'event',event).phase=='correlated_observation')
spend.metadata.serialNumber='changed'
assert(s.Begin(2,'event').phase=='refused' and c.release==0,'changed paid receipt invalidates correlation')
local s,a,rows,spend,item,c,time=fixture()
rows[20].exists=false;s.Removed(20);time(250)
assert(s.Observe(2,'event',event).phase=='correlated_observation');time(10251)
assert(s.Begin(2,'event').phase=='refused' and c.release==0,'old unclaimed event cannot start a fresh cleanup handoff')
print('PASS paid native collection service composition: actual lifetime/paid receipt/observer + client escrow + one canonical handoff; modeled native/SQL ports')
