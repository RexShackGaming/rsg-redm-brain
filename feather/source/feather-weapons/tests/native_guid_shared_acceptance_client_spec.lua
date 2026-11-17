local events,threads={},{}
RegisterNetEvent=function(name,fn) events[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end
GetGameTimer=function() return 0 end
Wait=function() error('unexpected wait after immediate report acknowledgement') end
PlayerPedId=function() return 42 end
DoesEntityExist=function() return true end
IsEntityDead=function() return false end
local closed=true
WeaponCharacterAmmoActiveOwner={Status=function() return {ownedCopies=closed and 0 or 1,cleanupComplete=closed,bootstrap={runtime={phase=closed and 'closed' or 'active'}}} end}
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId='collector',sessionId='collector-sid',ped=42}} end}
WeaponCharacterAmmoPolicy={Build=function() return {limits={ammo=2}} end}
WeaponNativeThrowablePolicy={RegistryFromLimits=function(_,limits) assert(limits.ammo_tomahawk_regular==3);return {limits=limits,names={}} end}
WeaponDefinitionCatalog={}
WeaponCharacterAmmoNative={New=function() return {Read=function() return {ammo=0,ammo_tomahawk_regular=0} end} end}
local paused,resumed,captures,stops,ready,reports,hints=0,0,0,0,0,0,0
WeaponNativeThrowablePickupClient={BeginNativeLoan=function() paused=paused+1;return true end,EndNativeLoan=function() resumed=resumed+1 end}
WeaponNativeThrowableAdapter={Scoped=function() return {} end}
local observer
WeaponNativeThrowableEventProbe={StartReleased=function(bound,current,_,observed,duration)
 assert(bound.characterId=='collector' and current().epoch=='native-loan:ticket:collector' and duration==180000)
 observer=observed;captures=captures+1;return true
end,Stop=function() stops=stops+1 end,Records=function() return {} end,LoanStage=function(stage) assert(stage=='awaiting_pickup') end}
json={encode=function() return 'bounded-report' end}
TriggerServerEvent=function(name,ticket,kind)
 assert(ticket=='ticket')
 if name=='feather-weapons:server:guid-suite-shared-ready' then ready=ready+1
 elseif name=='feather-weapons:server:guid-suite-collection-hint' then assert(kind=='collection_event');hints=hints+1
 elseif name=='feather-weapons:server:guid-suite-shared-result' then
  reports=reports+1;local old=source;source=65535;events['feather-weapons:client:guid-suite-shared-ack'](ticket);source=old
 else error(name) end
end
WeaponNativeThrowableCollectorLoanTest={Run=function(api,identity,origin)
 assert(api.current() and identity.epoch=='native-loan:ticket:collector' and origin.characterId=='thrower')
 assert(not WeaponGuidAcceptanceClient.AllowTemporaryFiring(),'collector may collect but is never allowed to throw')
 api.ready();observer({kind='ai_pickup'},'collection_event')
 return {id='throwable:shared-collector',phase='passed',cleanupComplete=true,captured=true,syntheticNativeOnly=true,economicWrites=0}
end}
dofile('client/native_guid_acceptance.lua')
local run=events['feather-weapons:client:guid-suite-shared-collector']
local bound={characterId='collector',sessionId='collector-sid',epoch='old'}
local origin={characterId='thrower',sessionId='thrower-sid',epoch='native-loan:ticket'}
source=7;run('ticket',bound,origin);assert(#threads==0)
source=65535;closed=false;run('ticket',bound,origin);assert(#threads==0)
closed=true;run('ticket',{characterId='foreign',sessionId='collector-sid'},origin);assert(#threads==0)
run('ticket',bound,origin);assert(#threads==1);threads[1]()
assert(paused==1 and resumed==1 and captures==1 and stops==1 and ready==1 and reports==1 and hints==1)
run('ticket',bound,origin);assert(#threads==1,'used collector ticket cannot replay native recapture')
print('PASS shared collector client wiring: server source, closed owner/scope, three-minute capture, no firing admission, report acknowledgement and no replay')
