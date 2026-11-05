dofile('shared/native_acceptance_view.lua')
dofile('shared/character_ammunition.lua')
WeaponCharacterAmmoPolicy={Build=function() return {limits={ammo=100}} end}
local commands,events,flags,objects,files={},{},{},{},{}
local seq=0
json={encode=function(v) seq=seq+1;objects[tostring(seq)]=v;return tostring(seq) end,decode=function(v) return objects[v] end}
Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaLifecycleWearEnabled=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
SetConvar=function(k,v) flags[k]=tonumber(v) end
GetConvarInt=function(k) return flags[k] or 0 end
GetCurrentResourceName=function() return 'feather-weapons' end
GetResourceState=function(name) return name=='feather-weapons-native-proof' and 'stopped' or 'started' end
GetGameTimer=function() return 100 end
LoadResourceFile=function(_,p) return files[p] end
SaveResourceFile=function(_,p,raw) files[p]=raw;return true end
RegisterCommand=function(name,fn,restricted) assert(restricted);commands[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
CreateThread=function(fn) fn() end
Wait=function() error('unexpected pending wait') end
GetPlayers=function() return {'77','19','999'} end
local cids={[19]='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb',[77]='4560a489-ca6c-11f1-9ad4-e0d55eaa2deb'}
local epochs={[19]='jane:1',[77]='john:1'}
CoreAdapter={ResolveSession=function(src) return {ok=true,value={characterId=cids[src] or 'other',sessionId=tostring(src)}} end,
 IsSessionCurrent=function(src,sid,cid) return cids[src]==cid and sid==tostring(src) end}
WeaponNativeEnrollment={Allows=function() return true end}
WeaponCharacterAmmoDispatcher={Status=function(src) return {phase='active',identity={characterId=cids[src],sessionId=tostring(src),epoch=epochs[src]}} end}
local wear={damage=0,degradation=0,dirt=0,soot=0,permanentDegradation=0}
local transitions=0
WeaponNativeEquipmentBindings={IsStopping=function() return false end,
 AcceptanceTransition=function(src,overlap)
  transitions=transitions+1;epochs[src]=tostring(src)..':'..transitions
  return {ok=true,value={competingRefused=overlap,staleAcknowledgementRefused=overlap}}
 end,
 AcceptanceStatus=function(src) return {phase='active',sessionId=tostring(src)} end}
exports={['feather-inventory']={ReadNativeAcceptanceAudit=function(_,actors)
 assert(actors[1].source==19 and actors[2].source==77,'identity discovery must ignore player roster order and source changes')
 local value={}
 for i,a in ipairs(actors) do
  value[i]={items={{id=a.source,row_revision=0,metadata={maintenance=wear}}},
   equipment={{slot='weapon',inventory_items_id=a.source}},ammo={{revision=1,pools={ammo=1}}}}
 end
 return {ok=true,value=value}
end}}
TriggerClientEvent=function(name,src,ticket,bound)
 assert(name=='feather-weapons:client:acceptance-read')
 source=src
 local value={identity=bound,revision=1,pools={ammo=1},copies=1,utility={},melee={},maintenance={{id=src,revision=0,wear=wear}}}
 events['feather-weapons:server:acceptance-report']('wrong-ticket',value)
 events['feather-weapons:server:acceptance-report'](ticket,value)
 source=nil
end
dofile('server/services/native_acceptance_suite.lua')
local command=assert(commands.WeaponNativeAcceptance)
command(19,{'run'});assert(transitions==0)
command(0,{'run'});assert(transitions==0,'default off')
flags.feather_native_acceptance_suite=1;command(0,{'run'})
assert(transitions==3 and flags.feather_native_acceptance_suite==0)
local report=objects[files['native-acceptance-report.json']]
assert(report.phase=='complete' and #report.steps==3 and report.actors[1].source==19)
flags.feather_native_acceptance_suite=1;command(0,{'run'});assert(transitions==3,'completed evidence is not replayed')
command(0,{'visual','pass'});report=objects[files['native-acceptance-report.json']];assert(report.visual=='pass')
print('PASS concrete acceptance runtime: current identity discovery, console/default gates, challenged client readbacks, snapshots, lifecycle sequencing and persisted summary')
