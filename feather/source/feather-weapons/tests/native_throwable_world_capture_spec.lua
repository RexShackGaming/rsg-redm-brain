-- Real server capture body; file/session/entity/event ports are modeled.
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local commands,events,timers,files,docs,flags,sent={},{},{},{},{},{},{}
local sequence,time,epoch,mode=0,100,'e','normal'
local identity={characterId='john',sessionId='s',epoch='e'}
GetCurrentResourceName=function() return 'feather-weapons' end
SetConvar=function(k,v) flags[k]=tonumber(v) end
GetConvarInt=function(k,d) return flags[k] or d end
GetGameTimer=function() return time end
RegisterCommand=function(n,f) commands[n]=f end
RegisterNetEvent=function(n,f) events[n]=f end
AddEventHandler=function(n,f) events[n]=f end
SetTimeout=function(ms,f) timers[#timers+1]={ms=ms,fn=f} end
GetPlayers=function() return {'9'} end
json={encode=function(v) sequence=sequence+1;docs[tostring(sequence)]=copy(v);return tostring(sequence) end,
 decode=function(v) return copy(assert(docs[v])) end}
SaveResourceFile=function(_,path,raw)
 if mode=='storage-exception' then error('disk unavailable') end
 if mode=='storage-fail' then return false end
 files[path]=raw;return true
end
LoadResourceFile=function(_,path) return files[path] end
CoreAdapter={IsSessionCurrent=function(target,sid,cid) return target==9 and sid=='s' and cid=='john' end,
 ResolveSession=function() return {ok=true,value={characterId='john',sessionId='s'}} end}
WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity={characterId='john',sessionId='s',epoch=epoch}} end}
TriggerClientEvent=function(name,target,...) sent[#sent+1]={name=name,target=target,args={...}} end
joaat=function(name) return ({WEAPON_THROWN_TOMAHAWK=101,w_melee_tomahawk01=201,w_melee_tomahawk02=202})[name] or error(name) end
DoesEntityExist=function() return true end
NetworkGetEntityOwner=function() return 9 end
GetEntityType=function() return 3 end
GetEntityModel=function() return 201 end
NetworkGetNetworkIdFromEntity=function() return 70 end
exports=setmetatable({},{__index=function() error('capture may not call Inventory/economic/restore providers') end})
for _,n in ipairs({'GiveWeaponToPed','DeleteEntity','SetPedAmmoByType','DropPlayer'}) do _G[n]=function() error('capture mutation '..n) end end
local oldPrint=print;print=function() end
dofile('server/services/native_throwable_world_capture.lua')
local command=commands.WeaponThrowableWorldCapture
local function report() return copy(docs[files['native-throwable-world-capture.json']]) end
local function run()
 flags.feather_native_throwable_world_capture=1;command(0,{'run','9'})
 local p=sent[#sent];assert(p.name=='feather-weapons:client:throwable-capture-start');return p.args[1]
end
command(9,{'run','9'});assert(#sent==0)
command(0,{'run','9'});assert(#sent==0,'default-off')
local ticket=run()
source=8
events['feather-weapons:server:throwable-capture-report'](ticket,1,'bad');assert(#report().clientRecords==0)
source=9
local row={referenceBuild=1491,kind='network_pickup',queue=1,eventHash=-454144443,rawSlots={42,0,301,0,201,1,0,0},
 pickupHandle=42,collectorPlayerIndex=0,pickupType=301,model=201,elapsedMs=100,noWrites=true,
 originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true}
local target={kind='pickup_target_snapshot',referenceBuild=1491,elapsedMs=90,object={entity=10,networked=true,networkId=70,model=201},
 noWrites=true,originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true}
local packet=json.encode({kind='rows',first=1,rows={row,target}})
events['feather-weapons:server:throwable-capture-report']('wrong',1,packet)
events['feather-weapons:server:throwable-capture-report'](ticket,2,packet)
assert(#report().clientRecords==0,'ticket and sequence gates')
local bad=copy(row);bad.originConfirmed=true
events['feather-weapons:server:throwable-capture-report'](ticket,1,json.encode({kind='rows',first=1,rows={bad}}))
assert(#report().clientRecords==0,'client cannot upgrade observations to origin proof')
events['entityCreated'](10)
events['entityRemoved'](10)
local before=#report().serverRecords -- memory evidence saved with client packet below
events['startProjectileEvent'](9,{weaponHash=101,ownerId=90,projectileHash=201,initialPositionX=1})
events['feather-weapons:server:throwable-capture-report'](ticket,1,packet)
assert(#report().clientRecords==2 and #report().serverRecords==3)
local count=#sent
events['feather-weapons:server:throwable-capture-report'](ticket,1,packet)
assert(#report().clientRecords==2 and #sent==count+1,'duplicate report only repeats acknowledgement')
local final=json.encode({kind='complete',count=2,build=1491,reason='window_complete',frames=100,readFailures=0,truncated=false})
events['feather-weapons:server:throwable-capture-report'](ticket,2,final)
assert(report().phase=='captured' and report().originConfirmed==false and flags.feather_native_throwable_world_capture==0)
assert(#report().candidateMatches==1 and not report().candidateMatches[1].ambiguous
 and #report().candidateMatches[1].serverLifetimes==1 and not report().candidateMatches[1].originConfirmed)
count=#sent;events['feather-weapons:server:throwable-capture-report'](ticket,2,final);assert(#sent==count+1)
ticket=run();events.entityCreated(10);events.entityRemoved(10);events.entityCreated(10)
events['feather-weapons:server:throwable-capture-report'](ticket,1,packet)
events['feather-weapons:server:throwable-capture-report'](ticket,2,final)
assert(report().candidateMatches[1].ambiguous and #report().candidateMatches[1].serverLifetimes==2,
 'recycled network ID must not look like a unique paid world binding')
for _,failure in ipairs({'storage-fail','storage-exception'}) do
 mode='normal';ticket=run();count=#sent;mode=failure
 events['feather-weapons:server:throwable-capture-report'](ticket,1,packet)
 assert(#sent==count,'unpersisted evidence is never acknowledged')
 events['feather-weapons:server:throwable-capture-report'](ticket,1,packet)
 assert(#sent==count,'failed storage cannot become a duplicate-success reply')
end
mode='normal';ticket=run();epoch='new';count=#sent
events['feather-weapons:server:throwable-capture-report'](ticket,1,packet)
assert(#sent==count,'replaced native epoch is refused')
for _,timer in ipairs(timers) do if timer.ms==60000 then timer.fn() end end
assert(report().phase=='review_required' and report().reason=='capture_report_timeout_no_replay')
print=oldPrint
print('World capture server PASS: console/default-off/current epoch gates, bounded diagnostic packets, file-before-ack, safe report retry, entity lifetime evidence; no economic/native writes')
