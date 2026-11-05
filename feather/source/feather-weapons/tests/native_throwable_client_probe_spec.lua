local command,encoded
Config={DevMode=true}
WeaponNativeThrowablePolicy={Enabled=function() return true end}
local flag,time,epoch,pending=0,100,'e',false
GetConvarInt=function() return flag end
GetGameTimer=function() return time end
RegisterCommand=function(n,f) assert(n=='weaponNativeProjectileSnapshot'); command=f end
json={encode=function(v) encoded=v; return 'diagnostic' end}
local oldPrint=print; print=function() end
WeaponCharacterAmmoActiveOwner={Status=function()
 return {phase='started',bootstrap={runtime={phase='active',epoch=epoch,session={ammo={pending=pending,
  baseline={characterId='john',sessionId='s',revision=11}}}}}}
end}
PlayerPedId=function() return 7 end
DoesEntityExist=function() return true end
IsEntityDead=function() return false end
GetEntityCoords=function(entity) return {x=entity==9 and 100 or entity==7 and 0 or 1,y=0,z=0} end
GetEntityModel=function() return -1 end
NetworkGetEntityIsNetworked=function(h) return h~=8 end
NetworkGetNetworkIdFromEntity=function(h) assert(h~=8,'never query network ID for local-only prop'); return h+100 end
IsEntityAttached=function(h) return h==8 end
local poolCalls,change=0,false
GetGamePool=function(name)
 assert(name=='CObject'); poolCalls=poolCalls+1; if change then epoch='new' end; return {8,9,10}
end
for _,name in ipairs({'DeleteEntity','GiveWeaponToPed','SetPedAmmoByType','TriggerServerEvent',
 'NetworkRequestControlOfEntity','SetEntityAsMissionEntity'}) do
 _G[name]=function() error('read-only probe cannot call '..name) end
end
dofile('client/native_throwable_projectile_probe.lua')
command(0,{}); assert(encoded.reason=='explicit_client_probe_gate_required' and poolCalls==0)
flag=1; command(0,{})
assert(encoded.phase=='snapshot' and #encoded.objects==2 and encoded.ledgerRevision==11
 and encoded.noWrites and encoded.clientDiagnosticOnly and encoded.pickupCredits==false)
assert(encoded.objects[1].model==4294967295 and encoded.objects[1].modelRaw==-1
 and encoded.objects[1].networkId==110 and encoded.objects[1].networked and not encoded.objects[1].attached)
assert(encoded.objects[2].handle==8 and not encoded.objects[2].networked and encoded.objects[2].networkId==nil
 and not encoded.objects[2].networkReadConfirmed and encoded.objects[2].attached)
command(0,{}); assert(encoded.reason=='probe_rate_limited' and poolCalls==1)
time=time+6000; pending=true; command(0,{}); assert(encoded.reason=='active_alive_owner_required'); pending=false
time=time+6000; change=true; command(0,{}); assert(encoded.reason=='owner_changed_during_probe'); change=false
time=time+6000; GetGamePool=function() local r={}; for i=1,1000 do r[i]=i+100 end; return r end
command(0,{}); assert(encoded.phase=='snapshot' and #encoded.objects==16 and encoded.scanned==512
 and encoded.partial and encoded.outputPartial and encoded.poolPartial)
time=time+6000; GetGamePool=nil; command(0,{}); assert(encoded.reason=='object_pool_unavailable')
print=oldPrint
print('read-only client projectile snapshot PASS: explicit gate/epoch/alive/signed model/network evidence, bounded reads/cooldown, no network/economic/native mutations')
