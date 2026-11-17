dofile('shared/native_throwable_event_reference.lua')
local decode=WeaponNativeThrowableEventReference.Decode
local command,thread,last,report,gameEvent
AddEventHandler=function(name,fn) assert(name=='gameEventTriggered');gameEvent=fn end
local time,flag,build,epoch,mode=0,0,1491,'e','normal'
GetConvarInt=function(name,default) assert(name=='feather_native_throwable_event_probe' and default==0);return flag end
GetGameTimer=function() return time end
GetGameBuildNumber=function() return build end
RegisterCommand=function(name,fn) assert(name=='weaponNativeThrowableEvents');command=fn end
CreateThread=function(fn) assert(not thread);thread=fn end
Wait=function(n) assert(n==0);time=time+30000 end
PlayerPedId=function() return 7 end
DoesEntityExist=function() return true end
IsEntityDead=function() return false end
joaat=function(name)
 return ({WEAPON_THROWN_TOMAHAWK=101,w_melee_tomahawk01=201,w_melee_tomahawk02=202,
 pickup_weapon_thrown_tomahawk_mp=301,pickup_weapon_thrown_tomahawk=302})[name] or error(name)
end
WeaponCharacterAmmoActiveOwner={Status=function() return {bootstrap={runtime={epoch=epoch,session={ammo={baseline={
 characterId='john',sessionId='s'}}}}}} end}
GetNumberOfEvents=function() return mode=='overflow' and 70 or mode=='duplicates' and 40 or mode=='read-fail' and 20 or 1 end
GetEventAtIndex=function(queue) return queue==1 and -454144443 or -178091376 end
local bytes
Citizen={InvokeNative=function(hash,queue,index,buffer,size)
 assert(hash==0x57EC5FA4D4D6AFCA and #buffer==64 and size==8,'RAGE slot count, not64 bytes, passed to native')
 if mode=='owner-change' then epoch='replacement' end
 if mode=='read-fail' then return false end
 local values=queue==1 and {42,0,301,0,201,1,0,0} or {301,1,0,0,0,0,1,101}
 if mode=='unrelated' then values=queue==1 and {42,0,999,0,999,0,0,0} or {999,0,0,0,0,0,0,999} end
 local slots={};for _,v in ipairs(values) do slots[#slots+1]=string.pack('<i4i4',v,0) end;bytes=table.concat(slots)
 return true
end}
WeaponNativeThrowableEventReference.Decode=function(b,q,h,buffer)
 assert(#buffer==64);return decode(b,q,h,bytes) -- native output buffer boundary is modeled
end
json={encode=function(v) report=v;return 'report' end}
local oldPrint=print;print=function() end
for _,name in ipairs({'GiveWeaponToPed','SetPedAmmoByType','DeleteEntity','TriggerServerEvent',
 'SetLocalPlayerPermittedToCollectPickupsWithModel','NetworkRequestControlOfEntity','ListenProjectileHitEvents'}) do
 _G[name]=function() error('read-only probe called '..name) end
end
dofile('client/native_throwable_event_probe.lua')
command(0,{'start'});assert(report.phase=='refused' and not thread)
flag=1;build=1436;command(0,{'start'});assert(report.reason=='throwable_event_reference_build_unsupported' and not thread)
build=1491
local function start(m)
 mode=m;epoch='e';thread=nil;command(0,{'start'});assert(report.phase=='capturing')
 local fn=thread;fn();command(0,{'status'});return report
end
local r=start('normal');assert(r.phase=='complete' and r.reason=='window_complete' and #r.records==2)
assert(r.records[1].kind=='network_pickup' and r.records[2].kind=='ai_pickup' and r.originConfirmed==false)
r=start('unrelated');assert(#r.records==0)
r=start('owner-change');assert(r.reason=='owner_changed' and #r.records==0)
r=start('duplicates');assert(r.reason=='record_limit' and #r.records==32 and r.truncated)
r=start('overflow');assert(r.reason=='record_limit' and r.truncated)
r=start('read-fail');assert(r.reason=='read_failure_limit' and r.readFailures==16 and #r.records==0)
mode='normal';thread=nil;command(0,{'start'});local fn=thread
command(0,{'start'});assert(report.reason=='explicit_probe_gate_and_idle_required')
command(0,{'stop'});assert(report.reason=='operator_stop');fn()
mode='normal';thread=nil;command(0,{'start'});fn=thread;flag=0;fn();assert(report.reason=='probe_disabled')
GetLootingPickupTargetEntity=function(ped) assert(ped==7);return 10 end
GetEntityModel=function() return 201 end
NetworkGetEntityIsNetworked=function() return true end
NetworkGetNetworkIdFromEntity=function() return 110 end
DoesPickupExist=function(handle) assert(handle==42);return true end
GetPickupObject=function(handle) assert(handle==42);return 10 end
HasPickupBeenCollected=function(handle) assert(handle==42);return true end
PlayerId=function() return 0 end
local oldHash=joaat
joaat=function(name) if name=='AMMO_TOMAHAWK' then return 401 end;return oldHash(name) end
GetPedAmmoByType=function(ped,hash) assert(ped==7 and hash==401);return 1 end
mode='normal';epoch='e';thread=nil
local delivered
assert(WeaponNativeThrowableEventProbe.Start({characterId='john',sessionId='s',epoch='e'},function(value) delivered=value end),
 'server challenge may start read-only capture without a replicated local debug switch')
thread()
assert(delivered and #delivered.records==3 and delivered.records[1].kind=='pickup_target_snapshot'
 and delivered.records[1].object.networkId==110 and delivered.records[2].pickupObject.networkId==110,
 'target and pickup handles yield matching read-only network evidence')
assert(delivered.completed==nil,'callbacks never enter JSON report state')
assert(delivered.records[2].collectorIsLocal and delivered.records[2].nativeTomahawkQuantity==1
 and delivered.records[2].nativeCollected and delivered.records[2].collectedReadConfirmed)
assert(delivered.records[3].pickupHandle==nil and delivered.records[3].nativeCollected==nil,
 'AI events never inherit the network event pickup handle or collection readback')
-- The isolated loan has already closed its normal owner; its private reader
-- supplies only the server-bound temporary identity while that release remains.
thread=nil;delivered=nil;flag=0
WeaponCharacterAmmoActiveOwner={Status=function() return {ownedCopies=0,cleanupComplete=true,bootstrap={runtime={phase='closed'}}} end}
local loan={characterId='john',sessionId='s',epoch='native-loan:ticket',ped=7}
assert(WeaponNativeThrowableEventProbe.StartReleased(loan,function() return loan end,function(v) delivered=v end))
thread()
assert(delivered and delivered.durationMs==90000 and delivered.reason=='window_complete'
 and #WeaponNativeThrowableEventProbe.Records()>0)
thread=nil;delivered=nil
assert(WeaponNativeThrowableEventProbe.StartReleased(loan,function() return loan end,function(v) delivered=v end))
loan={characterId='other',sessionId='s',epoch='new',ped=7};thread()
assert(delivered and delivered.reason=='owner_changed' and #delivered.records==0)
-- Diagnostic fallback sees only nearby detached Tomahawk models; snapshots
-- and raw engine messages remain explicitly unconfirmed.
thread=nil;delivered=nil
loan={characterId='john',sessionId='s',epoch='native-loan:next',ped=7}
local scans,hints=0,0
GetGamePool=function(kind) assert(kind=='CObject');scans=scans+1;return {10,11} end
IsEntityAttached=function(entity) return entity==11 end
GetEntityCoords=function() return {x=0,y=0,z=0} end
assert(WeaponNativeThrowableEventProbe.StartReleased(loan,function() return loan end,function(v) delivered=v end,function(object,kind)
 if kind=='collection_event' then return end
 hints=hints+1;assert(object.networkId==110 and object.entity==10)
end))
WeaponNativeThrowableEventProbe.LoanStage('awaiting_pickup')
gameEvent('CEventNetworkPlayerCollectedPickup',{1,2,3,'discarded'})
gameEvent('unrelated',{1,2})
thread()
assert(hints==1,'one live hint per unique observed object, not every frame')
assert(scans==3 and delivered.objectScans==3 and delivered.objectScanFailures==0)
local found=false
for _,row in ipairs(delivered.records) do
 assert(row.originConfirmed==false)
 if row.kind=='tomahawk_object_snapshot' then assert(row.object.entity==10);found=true end
end
assert(found and delivered.records[1].kind=='game_event' and delivered.records[1].rawSlots[4]==0)
local count=#delivered.records;gameEvent('CEventNetworkPlayerCollectedPickup',{1})
assert(#delivered.records==count,'no engine capture after stop')
-- The targeted native is additive until live comparison proves landed support.
-- Owned-first suppresses a redundant generic notification, while a prior
-- generic observation cannot suppress a later owned-projectile notification.
thread=nil;delivered=nil;hints=0
local reads=0
GetProjectileOfProjectileTypeWithinDistance=function(ped,weapon,distance,p5,ownedOnly)
 assert(ped==7 and weapon==101 and distance==50.0 and p5==false and type(ownedOnly)=='boolean')
 reads=reads+1;return true,{x=0,y=0,z=0},10
end
assert(WeaponNativeThrowableEventProbe.StartReleased(loan,function() return loan end,function(v) delivered=v end,function(_,kind) if kind~='collection_event' then hints=hints+1 end end))
WeaponNativeThrowableEventProbe.LoanStage('awaiting_pickup');thread()
assert(reads==6 and hints==1 and delivered.projectileReaderAvailable and delivered.projectileReadFailures==0)
local projectile=false
for _,row in ipairs(delivered.records) do if row.kind=='tomahawk_projectile_snapshot' then projectile=true;assert(row.object.networkId==110 and row.originConfirmed==false) end end
assert(projectile,'typed result yields a validated candidate, never authority')
for _,first in ipairs({'pool','unowned'}) do
 thread=nil;delivered=nil;local notifications={};local frame=0
 GetProjectileOfProjectileTypeWithinDistance=function(_,_,_,_,ownedOnly)
  if frame==0 then return first=='unowned' and not ownedOnly,{x=0,y=0,z=0},10 end
  return true,{x=0,y=0,z=0},10
 end
 local previousWait=Wait
 Wait=function(n) frame=frame+1;previousWait(n) end
 assert(WeaponNativeThrowableEventProbe.StartReleased(loan,function() return loan end,function(v) delivered=v end,function(object,kind)
  if kind=='collection_event' then return end
  notifications[#notifications+1]=kind or 'generic';assert(object.networkId==110)
 end))
 WeaponNativeThrowableEventProbe.LoanStage('awaiting_pickup');thread();Wait=previousWait
 assert(#notifications==2 and notifications[1]=='generic' and notifications[2]=='owned_projectile',
  first..' first must not swallow owned evidence or repeat it on later frames')
 assert(delivered.readFailures==0 and delivered.projectileReadFailures==0)
end
thread=nil;delivered=nil
GetProjectileOfProjectileTypeWithinDistance=function() error('native unavailable') end
assert(WeaponNativeThrowableEventProbe.StartReleased(loan,function() return loan end,function(v) delivered=v end))
WeaponNativeThrowableEventProbe.LoanStage('awaiting_pickup');thread()
assert(delivered.projectileReadFailures==6 and delivered.objectScans==3,'reader failure preserves independent fallback diagnostics')
-- Closest-model candidates are independent diagnostics, including an object
-- lifetime change. They never become an exact identity or a pickup credit.
thread=nil;delivered=nil
local exists=true
DoesEntityExist=function(entity) return entity~=12 or exists end
NetworkGetNetworkIdFromEntity=function(entity) return entity==12 and 112 or 110 end
GetClosestObjectOfType=function() return 12 end
GetProjectileOfProjectileTypeWithinDistance=function() return true,{x=0,y=0,z=0},10 end
local priorWait=Wait
Wait=function(n) exists=false;priorWait(n) end
assert(WeaponNativeThrowableEventProbe.StartReleased(loan,function() return loan end,function(v) delivered=v end))
WeaponNativeThrowableEventProbe.LoanStage('awaiting_pickup');thread()
local candidate,missing=false,false
for _,row in ipairs(delivered.records) do
 if row.kind=='native_collection_candidate' then candidate=true;assert(row.candidateOnly and row.object.networkId==112) end
 if row.kind=='native_collection_candidate_state' and row.state=='missing_or_changed' then missing=true end
 assert(row.pickupCredits==false and row.originConfirmed==false)
end
assert(candidate and missing,'candidate disappearance survives without being promoted to origin proof')
print=oldPrint
print('Throwable event probe PASS: gated bounded capture, actual reference decoder, no mutation/authority, build/owner/overlap/stop fences; modeled native read buffer')
