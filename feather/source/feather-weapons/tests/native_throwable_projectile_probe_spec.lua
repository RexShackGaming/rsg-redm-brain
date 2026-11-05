local commands,events,timers,output={},{},{},{}
local flag,time,current,epoch=0,100,true,'e'
local objectModel=43
Config={DevMode=true}
WeaponNativeThrowablePolicy={Enabled=function() return true end}
WeaponNativeEnrollment={Allows=function() return true end}
GetConvarInt=function() return flag end
GetGameTimer=function() return time end
CoreAdapter={IsSessionCurrent=function() return current end}
WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity={characterId='john',sessionId='s',epoch=epoch}} end}
RegisterCommand=function(n,f) commands[n]=f end
AddEventHandler=function(n,f) events[n]=f end
SetTimeout=function(_,f) timers[#timers+1]=f end
json={encode=function(v) output[#output+1]=v; return 'probe-result' end}
local oldPrint=print; print=function() end
local reads=0
DoesEntityExist=function() reads=reads+1; return true end
NetworkGetNetworkIdFromEntity=function(h) return h+100 end
NetworkGetEntityOwner=function() return 2 end
GetEntityModel=function() return objectModel end
GetEntityType=function() return 3 end
GetPlayerPed=function() return 20 end
for _,name in ipairs({'DeleteEntity','SetPedAmmoByType','GiveWeaponToPed','TriggerClientEvent','RegisterNetEvent'}) do
 _G[name]=function() error('read-only probe cannot call '..name) end
end
dofile('server/services/native_throwable_projectile_probe.lua')
local probe=commands.WeaponNativeProjectileProbe
events.entityCreated(10); assert(reads==0 and #output==0)
probe(0,{'2'}); assert(output[#output].phase=='refused')
flag=1; local count=#output; probe(2,{'2'}); assert(#output==count,'console-only')
probe(0,{'2'}); assert(output[#output].phase=='armed' and #timers==1)
count=#output; events.startProjectileEvent(3,{}); assert(#output==count)
events.startProjectileEvent(2,{weaponHash=42,ownerId=120,projectileHash=50,throwTaskSequence=9,arbitrary='discard'})
local hint=output[#output]
assert(hint.kind=='projectile_start_hint' and hint.fields.weaponHash==42 and hint.fields.arbitrary==nil
 and hint.expectedPedNetworkId==120 and hint.originConfirmed==false and hint.pickupCredits==false)
events.entityCreated(10); assert(output[#output].kind=='entity_created')
events.entityRemoved(10); assert(output[#output].kind=='entity_removed')
for i=1,50 do events.startProjectileEvent(2,{}) end
local hints=0; for _,o in ipairs(output) do if o.kind=='projectile_start_hint' then hints=hints+1 end end
assert(hints==8,'bounded event output')
for i=1,50 do events.entityCreated(i) end
local entities=0; for _,o in ipairs(output) do if o.kind=='entity_created' then entities=entities+1 end end
assert(entities==32,'bounded entity output')
timers[1](); assert(output[#output].phase=='stopped')
probe(0,{'2'}); epoch='new'; events.entityCreated(10); assert(output[#output].reason=='owner_changed')
probe(0,{'2'}); flag=0; events.entityCreated(10); assert(output[#output].reason=='probe_disabled')
flag=1; probe(0,{'2'}); time=60101; events.entityCreated(10); assert(output[#output].reason=='expired')
time=60200; objectModel=0
local prior=#timers
probe(0,{'2','10'}); assert(output[#output].kind=='entity_console_readback' and output[#output].model==0)
assert(#timers==prior+4,'expiry plus three bounded settle reads')
objectModel=43; timers[prior+2]()
assert(output[#output].kind=='entity_settled_100' and output[#output].model==43)
events.entityRemoved(10); local size=#output
timers[prior+3](); assert(#output==size,'removed lifetime cannot be sampled by old callback')
probe(0,{'stop'}); size=#output; timers[prior+4](); assert(#output==size,'stopped run invalidates delayed callbacks')
local originalExists,originalModel,originalOwner=DoesEntityExist,GetEntityModel,NetworkGetEntityOwner
for _,mode in ipairs({'absent','exception','unavailable','nil','invalid','model_zero','signed_model','owner_mismatch'}) do
 DoesEntityExist=originalExists; GetEntityModel=originalModel; NetworkGetEntityOwner=originalOwner
 if mode=='absent' then DoesEntityExist=function() return false end end
 if mode=='exception' then GetEntityModel=function() error('private raw error must not be logged') end end
 if mode=='unavailable' then GetEntityModel=nil end
 if mode=='nil' then GetEntityModel=function() return nil end end
 if mode=='invalid' then GetEntityModel=function() return 0/0 end end
 if mode=='model_zero' then objectModel=0 end
 if mode=='signed_model' then objectModel=-1 end
 if mode=='owner_mismatch' then NetworkGetEntityOwner=function() return 3 end end
 probe(0,{'2','10'})
 local observation=output[#output]
 probe(0,{'stop'}); local stopped=output[#output]
 if mode=='model_zero' then
  assert(observation.modelSettled==false and stopped.modelZeroReads==1 and stopped.nativeReadFailures==0)
 elseif mode=='signed_model' then
  assert(observation.model==4294967295 and observation.modelRaw==-1 and observation.modelSettled
   and stopped.nativeReadFailures==0,'signed 32-bit model hash is not an invalid native read')
 elseif mode=='owner_mismatch' then assert(stopped.ownerMismatchReads==1 and stopped.nativeReadFailures==0)
 else
  local reason=mode=='absent' and 'entity_absent' or 'model_'..mode
  assert(observation.kind=='entity_read_failure' and observation.reason==reason
   and stopped.readFailureReasons[reason]==1 and stopped.nativeReadFailures==1)
 end
 objectModel=43
end
DoesEntityExist=originalExists; GetEntityModel=originalModel; NetworkGetEntityOwner=originalOwner
print=oldPrint
print('read-only concrete projectile probe PASS: default-off/console/epoch/expiry, bounded native+event reads, no mutations or credits')
