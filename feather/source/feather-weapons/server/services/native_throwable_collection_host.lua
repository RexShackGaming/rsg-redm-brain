-- Bounded two-player development bootstrap. Console admission only; no grants.
WeaponNativeThrowableCollectionHost={}
local H=WeaponNativeThrowableCollectionHost
local run,service,transport
local function printObservation()
 if run and run.observation then print('[WeaponNativeCollectionObservation] '..json.encode(run.observation)) end
end
local function mode() return Config.NativeThrowableNativeCollectionContract==1 and GetConvarInt('feather_native_paid_collection',0)==1 end
local function same(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
function H.Start(api)
 if not mode() then return true end
 local ports=WeaponNativeThrowableCollectionInventory.New()
 local function current(source)
  local a=api.actor(source)
  local expected=run and run.identities[source]
  return a and expected and a.characterId==expected.characterId and a.sessionId==expected.sessionId and a or nil
 end
 local function empty(source,identity)
  local a=current(source);if not same(a,identity) then return false end
  local result=exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot({actorSource=source,
   characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch},api.limits())
  return result and result.ok==true and result.value.pools.ammo_tomahawk_regular==0
 end
 service=WeaponNativeThrowableCollectionService.New({actor=current,now=GetGameTimer,later=SetTimeout,read=api.read,
  challenge=api.challenge,spend=api.spend,newId=function() return 'native:'..assert(DB.value('SELECT UUID()')) end,
  collectorEmpty=empty,ticket=function(a) return transport.Ticket(a) end,
  beginEscrow=function(...) return transport.BeginEscrow(...) end,readEscrow=function(...) return transport.ReadEscrow(...) end,
  bind=ports.bind,readBinding=ports.readBinding,claim=ports.claim,readClaim=ports.readClaim})
 transport=WeaponNativeThrowableCollectionTransport.New({service=service,actor=current,now=GetGameTimer,
  enabled=function() return mode() and run~=nil end,prepare=service.Prepare,
  newTicket=function() return 'collect:'..assert(DB.value('SELECT UUID()')) end,
  send=function(source,action,packet)
   TriggerClientEvent('feather-weapons:client:native-collection',source,action,packet)
   if action=='arm' then print('[WeaponNativeCollectionTest] ARMED collector; walk directly over the landed unit now.') end
   if action=='result' and (packet.result.phase=='complete' or packet.result.phase=='review_required' or packet.result.phase=='refused') then
    run.result=packet.result;print('[WeaponNativeCollectionTest] '..json.encode(packet.result))
    run.observation=transport.Diagnostics(source);printObservation()
   end
  end})
 assert(api.attach(service),'native_collection_writer_attachment_failed')
 AddEventHandler('entityCreated',function(handle) if mode() and run then service.Created(handle) end end)
 AddEventHandler('entityRemoved',function(handle) if mode() and run then service.Removed(handle) end end)
 RegisterCommand('WeaponNativeCollectionTest',function(source,args)
  if source~=0 or not mode() then return end
  if args and args[1]=='status' then print('[WeaponNativeCollectionTest] '..json.encode(run and run.result or {phase=run and 'running' or 'idle'}));printObservation();return end
  local donor,collector=tonumber(args and args[2]),tonumber(args and args[3])
  if run or not args or #args~=3 or args[1]~='start' or not donor or not collector or donor==collector
   or #GetPlayers()~=2 then return print('[WeaponNativeCollectionTest] REFUSED: fresh resource, exactly two players; usage start throwerId collectorId') end
  local d,c=api.actor(donor),api.actor(collector)
  if not d or not c or not d.alive or not c.alive or d.bucket~=c.bucket or d.characterId==c.characterId then return print('[WeaponNativeCollectionTest] REFUSED live distinct same-bucket characters required') end
  run={donor=donor,collector=collector,identities={[donor]=d,[collector]=c},attempted=false}
  if not empty(collector,c) then run=nil;return print('[WeaponNativeCollectionTest] REFUSED collector Tomahawk pool must be empty') end
  for _,id in ipairs({donor,collector}) do TriggerClientEvent('feather-weapons:client:native-collection-start',id,
   {identity=run.identities[id],bucket=d.bucket,donor=id==donor}) end
  print('[WeaponNativeCollectionTest] STARTED: equip/buy one paid Tomahawk on thrower, throw once on clear ground; collector waits for ARMED. No grants.')
 end,true)
 RegisterNetEvent('feather-weapons:server:native-collection-hint',function(packet)
  local player=source
  if not mode() or not run or player~=run.donor or run.attempted or type(packet)~='table'
   or type(packet.challengeId)~='string' or #packet.challengeId>64 or not api.challenge(player,packet.challengeId) then return end
  run.attempted=true -- one paid attempt per resource start; no economic replay
  local function link()
   if not mode() or run.result or run.watched then return end
   local result=service.Watch(player,packet.challengeId,packet.projectileId,packet.pickupId,packet.position)
   if result.phase=='watching' then
    run.watched=true
    if not transport.Arm(run.collector,result.id) then run.result={phase='review_required',reason='collector_arm_refused'} end
   elseif result.phase=='pending' then return
   else run.result={phase='review_required',reason=result.reason} end
   if run.result then print('[WeaponNativeCollectionTest] '..json.encode(run.result)) end
  end
  link()
  -- Evidence registration may lag the client hint. These are read-only linking
  -- attempts; once a watch or terminal result exists no binding/claim repeats.
  for _,delay in ipairs({100,500,1500}) do SetTimeout(delay,function()
   if not run.result and not run.watched then link() end
  end) end
 end)
 RegisterNetEvent('feather-weapons:server:native-collection',function(action,packet)
  local player=source
  if mode() and run and player==run.collector then transport.Handle(player,action,packet) end
 end)
 return true
end
