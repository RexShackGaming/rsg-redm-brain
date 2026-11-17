dofile('shared/native_guid_acceptance.lua')
local events,threads,rows,encoded={},{},{},{}
local sequence,time,alive,closed,invocations=0,0,true,true,0
local world={ok=true,value={characterId='c',sessionId='s',ped=42}}
RegisterNetEvent=function(name,fn) events[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end
GetGameTimer=function() return time end
Wait=function() time=time+1 end
PlayerPedId=function() return 42 end
DoesEntityExist=function() return true end
IsEntityDead=function() return not alive end
joaat=function() return 100 end
GetPedAmmoByType=function() return 1 end
WeaponCharacterAmmoActiveOwner={Status=function() return {ownedCopies=0,cleanupComplete=closed,
 bootstrap={runtime={phase=closed and 'closed' or 'active'}}} end}
WeaponCharacterAmmoWorldContext={Read=function() return world end}
WeaponCharacterAmmoPolicy={Build=function() return {limits={ammo_revolver_regular=10}} end}
WeaponDefinitionCatalog={}
local paused,resumed=0,0
WeaponNativeThrowablePickupClient={BeginNativeLoan=function() paused=paused+1;return true end,
 EndNativeLoan=function() resumed=resumed+1 end}
WeaponNativeThrowablePolicy={UnitsEnabled=function() return true end,RegistryFromLimits=function(_,limits)
 assert(limits.ammo_tomahawk_regular==3);return {limits=limits,names={}} end}
WeaponCharacterAmmoNative={New=function() return {Read=function() return {ammo_tomahawk_regular=0} end} end}
WeaponNativeThrowableAdapter={Scoped=function() return {} end}
local stopped=0
WeaponNativeThrowableEventProbe={LoanStage=function() end,StartReleased=function(bound,current)
 local state=current();assert(state.ped==42 and state.epoch==bound.epoch);return true
 end,Stop=function() stopped=stopped+1 end,Records=function() return {} end}
WeaponNativeThrowableLoanTest={Run=function(api,identity)
 invocations=invocations+1
 assert(identity.epoch=='native-loan:ticket' and api.current() and not WeaponGuidAcceptanceClient.AllowTemporaryFiring())
 api.stage('awaiting_throw');assert(WeaponGuidAcceptanceClient.AllowTemporaryFiring())
 alive=false;assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring());alive=true
 time=90001;assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring());time=0
 api.stage('awaiting_pickup');assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring())
 return {phase='complete',passed=1,total=1,cleanupComplete=true,
 cases={{id='throwable:world-capture',phase='passed',cleanupComplete=true}}}
end}
json={encode=function(v) sequence=sequence+1;encoded[tostring(sequence)]=v;return tostring(sequence) end}
TriggerServerEvent=function(name,ticket,index,raw)
 rows[#rows+1]=encoded[raw]
 local previous=source;source=65535
 events['feather-weapons:client:guid-suite-report-ack'](ticket,name:match('guid%-suite%-(.+)$'),index)
 source=previous
end
dofile('client/native_guid_acceptance.lua')
assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring())
local run=events['feather-weapons:client:guid-suite-throwable']
source=7;run('ticket',{characterId='c',sessionId='s'},1);assert(#threads==0)
source=65535;closed=false;run('ticket',{characterId='c',sessionId='s'},1);assert(#threads==0)
closed=true;run('ticket',{characterId='other',sessionId='s'},1);assert(#threads==0)
run('ticket',{characterId='c',sessionId='s'},1);assert(#threads==1)
run('ticket',{characterId='c',sessionId='s'},1);assert(#threads==1,'no duplicate creation')
threads[1]()
assert(invocations==1 and stopped==1 and #rows==2 and WeaponGuidAcceptanceClient.Delivery.ok)
assert(paused==1 and resumed==1,'paid registry stays admitted while isolated native pickup temporarily pauses interaction')
assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring())
run('ticket',{characterId='c',sessionId='s'},1);assert(#threads==1,'used ticket cannot replay')
-- A paired negative probe permits the second isolated throw, never a third
-- or a normal-session firing exemption.
local pairedQuantity=2
GetPedAmmoByType=function() return pairedQuantity end
WeaponNativeThrowableLoanTest.Run=function(api,identity)
 assert(api.unitCount==2 and api.durationMs==180000 and identity.epoch=='native-loan:paired')
 api.stage('awaiting_throw');assert(WeaponGuidAcceptanceClient.AllowTemporaryFiring())
 pairedQuantity=1;api.stage('awaiting_pickup');assert(WeaponGuidAcceptanceClient.AllowTemporaryFiring())
 pairedQuantity=0;assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring())
 pairedQuantity=3;assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring())
 pairedQuantity=1;time=180001;assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring());time=0
 return {phase='complete',passed=1,total=1,cleanupComplete=true,
  cases={{id='throwable:world-capture',phase='passed',cleanupComplete=true}}}
end
run('paired',{characterId='c',sessionId='s'},1,'shared-competing')
assert(#threads==2);threads[2]()
assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring())
-- The ordinary runtime blocks firing unless the narrowly scoped local predicate
-- succeeds; callback exceptions fail closed.
local blocks=0;DisablePlayerFiring=function() blocks=blocks+1 end;PlayerId=function() return 1 end
dofile('client/character_ammunition_client_runtime.lua')
local nativeApi,enforce=WeaponCharacterAmmoNativeAdapters.New(function() end,function() end,function() end)
enforce();assert(blocks==1)
WeaponGuidAcceptanceClient.AllowTemporaryFiring=function() error('unavailable') end
enforce();assert(blocks==2)
WeaponNativeThrowablePolicy={UnitsEnabled=function() return true end}
WeaponNativeThrowablePickupClient={Ready=function() return false end}
WeaponGuidAcceptanceClient.AllowTemporaryFiring=function() return true end
enforce();assert(blocks==2,'isolated server-challenged throw is allowed while pickup host is paused')
nativeApi.block(false) -- real equipment release clears this flag once closed
enforce();assert(blocks==2,'closed-owner release must not skip the isolated throw predicate')
WeaponGuidAcceptanceClient.AllowTemporaryFiring=function() return false end
enforce();assert(blocks==3,'ordinary firing stays blocked when paid pickup host is unavailable')
WeaponGuidAcceptanceClient.AllowTemporaryFiring=function() error('unavailable') end
enforce();assert(blocks==4,'predicate failure still blocks firing after a completed release')
print('PASS throwable loan admission: server source, closed owner, exact session, single ticket, bounded firing and report-only transport')
