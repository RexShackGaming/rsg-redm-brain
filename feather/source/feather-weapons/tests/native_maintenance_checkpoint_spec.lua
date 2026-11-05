local handler,sends=nil,0
RegisterNetEvent=function(_,fn) handler=fn end
Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaMaintenanceEnabled=true}
local identity={characterId='c',sessionId='s',epoch='e'}
local item={itemInstanceId=128,itemRevision=1,maintenance={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0,soot=0}}
WeaponCharacterAmmoActiveOwner={Status=function() return {bootstrap={runtime={session={ammo={baseline=identity}}}}} end,
 MaintenanceStatus=function() return {epoch='e',items={item}} end}
TriggerServerEvent=function(name,ticket,epoch,id,revision,report)
 assert(name=='feather-weapons:server:native-maintenance-report' and ticket=='ticket' and epoch=='e'
  and id==128 and revision==1 and report==item.maintenance); sends=sends+1
end
dofile('client/native_maintenance_checkpoint.lua')
handler('ticket',identity,128); assert(sends==1)
handler('ticket',{characterId='c',sessionId='s',epoch='old'},128); assert(sends==1)
handler('ticket',identity,112); assert(sends==1)
Config.NativeAlphaMaintenanceEnabled=false; handler('ticket',identity,128); assert(sends==1)
print('native_maintenance_checkpoint_spec PASS (opt-in exact session/epoch/copy revision readback, stale/foreign refusal, no mutation)')
