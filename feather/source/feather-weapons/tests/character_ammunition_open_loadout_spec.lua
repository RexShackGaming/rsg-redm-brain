Config={CharacterAmmunitionEnabled=false,AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
for _,name in ipairs({'validation','character_ammunition','character_ammunition_runtime','character_ammunition_catalog',
    'character_ammunition_item','character_ammunition_materialization','character_ammunition_loadout_lease'}) do dofile('shared/'..name..'.lua') end
local current=true
CoreAdapter={IsSessionCurrent=function() return current end,
    ResolveSession=function() return {ok=true,value={characterId='c',sessionId='s'}} end}
GetGameTimer=function() return 10 end
GetInvokingResource=function() return 'feather-inventory' end
AddEventHandler=function() end
local registered,inventory={},{}
exports=setmetatable({['feather-inventory']=inventory},{__call=function(_,name,fn) registered[name]=fn end})
local equipment={primary={id=1,revision=5,itemName='weapon_pistol_m1899',metadata={schemaVersion=2,
    weaponDefinitionId='pistol_m1899',serialNumber='serial-1',condition=100,quality=100,
    maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
    ammo={ownership='character',type='ammo_pistol_regular'},attachments={},cosmetics={},
    flags={stolen=false,evidence=false,disabled=false},provenance={}}}}
inventory.GetCharacterFirearmRuntimeSnapshot=setmetatable({__cfx_functionReference='test'},
    {__call=function(_,self,context,limits)
        local pools={}; for id in pairs(limits) do pools[id]=0 end; pools.ammo_pistol_regular=7
        return {ok=true,value={characterId=context.characterId,revision=2,pools=pools,equipment=equipment}}
    end})
dofile('server/services/character_ammunition_runtime.lua')
local catalog,policy=WeaponDefinitionCatalog,{}
for _,weapon in pairs(catalog.weapons) do
    if ({pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true})[weapon.family]
        and weapon.nativeWeaponName~='WEAPON_REVOLVER_LEMAT' then
        for _,id in ipairs(weapon.ammunitionTypes) do policy[id]=catalog.ammunition[id].maxTotal or 200 end
    end
end
local service=WeaponCharacterAmmoService
assert(not service.OpenLoadout(1,catalog,policy).ok)
Config.CharacterAmmunitionEnabled=true
local result=service.OpenLoadout(1,catalog,policy)
assert(result.ok and result.value.runtime.phase=='restoring')
assert(result.value.runtime.pools.ammo_pistol_regular==7 and result.value.creation.items[1].itemRevision==5)
assert(result.value.runtime.epoch==result.value.creation.identity.epoch)
assert(result.value.creation.items[1].ammo==nil and result.value.creation.items[1].point==2)
assert(service.IsNativeItemBound(1) and service.ValidateLoadout(1).ok)
local report={characterId='c',sessionId='s',epoch=result.value.runtime.epoch,revision=2,pools=result.value.runtime.pools}
local wrong={characterId='c',sessionId='s',epoch='old',revision=2,pools=result.value.runtime.pools}
assert(not service.ConfirmRestore(1,wrong).ok and service.IsNativeItemBound(1),'late ack cannot revoke current binding')
assert(service.ConfirmRestore(1,report).ok,'restore activation includes fresh binding check')
result.value.creation.items[1].itemRevision=999
assert(service.ValidateLoadout(1).ok,'caller must not mutate stored revision binding')
equipment.primary.revision=6
assert(not service.ValidateLoadout(1).ok and service.IsNativeItemBound(1),'changed revision revokes ammo but retains native item hold')
assert(not service.OpenLoadout(1,catalog,policy).ok,'frozen native copies must be released before replacement')
service.Revoke(1,'old-session'); assert(service.IsNativeItemBound(1),'stale lifecycle event cannot release current copies')
equipment.primary.revision=5
service.Revoke(1)
dofile('shared/character_ammunition_dispatch.lua')
local bundle,timer
local owner=WeaponCharacterAmmoDispatch.New({service=service,enabled=function() return true end,
    dispatch=function(_,value) bundle=value; assert(service.IsNativeItemBound(1),'hold before dispatch') end,
    timeout=function(fn) timer=fn end})
assert(owner.Start(1,catalog,policy).ok)
report={characterId='c',sessionId='s',epoch=bundle.runtime.epoch,revision=2,pools=bundle.runtime.pools}
assert(owner.ConfirmRestore(1,report).ok and owner.Status(1).phase=='active')
timer(); assert(owner.Status(1).phase=='active')
assert(owner.Observe(1,report).ok)
assert(owner.CheckpointAndSeal(1,report).ok and service.IsNativeItemBound(1))
report.cleanupComplete=true; report.remainingCopies=0
assert(owner.ConfirmCleanup(1,report).ok and not service.IsNativeItemBound(1))
assert(owner.Start(1,catalog,policy).ok)
timer(); assert(owner.Status(1).phase=='frozen' and service.IsNativeItemBound(1))
assert(not service.ValidateLoadout(1).ok,'actual service timeout revokes ammo authority but keeps native hold')
service.Revoke(1); owner.Forget(1)
assert(not service.IsNativeItemBound(1))
equipment.primary.metadata.ammo.loaded=0
assert(not service.OpenLoadout(1,catalog,policy).ok,'legacy quantity cannot open a native runtime')
equipment.primary.metadata.ammo.loaded=nil; current=false
assert(not service.OpenLoadout(1,catalog,policy).ok,'stale session cannot open')
current=true
result=service.OpenLoadout(1,catalog,policy); assert(result.ok)
report={characterId='c',sessionId='s',epoch=result.value.runtime.epoch,revision=2,pools=result.value.runtime.pools}
assert(service.ConfirmRestore(1,report).ok)
assert(service.CheckpointAndSeal(1,report).ok and service.IsNativeItemBound(1),'seal alone retains item hold')
report.cleanupComplete=true; report.remainingCopies=1
assert(not service.ConfirmCleanup(1,report).ok and service.IsNativeItemBound(1),'incomplete cleanup retains hold')
report.remainingCopies=0
local epoch=report.epoch; report.epoch='stale'
assert(not service.ConfirmCleanup(1,report).ok and service.IsNativeItemBound(1),'stale cleanup retains hold')
report.epoch=epoch
assert(service.ConfirmCleanup(1,report).ok and not service.IsNativeItemBound(1),'matched release alone clears hold')
result=service.OpenLoadout(1,catalog,policy); assert(result.ok)
local identity=result.value.creation.identity
assert(not service.FreezeLoadout(1,{epoch='old',sessionId='s',characterId='c'}).ok)
assert(service.ValidateLoadout(1).ok,'old timeout cannot freeze newer lease')
assert(service.FreezeLoadout(1,identity).ok and service.IsNativeItemBound(1))
assert(not service.ValidateLoadout(1).ok and not service.OpenLoadout(1,catalog,policy).ok,'frozen dispatch retains hold')
service.Revoke(1)
print('character_ammunition_open_loadout_spec PASS (callable snapshot, item revisions, shared epoch, gate and strict metadata)')
local snapshot=inventory.GetCharacterFirearmRuntimeSnapshot
inventory.GetCharacterFirearmRuntimeSnapshot=function(...)
    coroutine.yield('snapshot_wait')
    return snapshot(...)
end
local returned
local function startOpen()
    local thread=coroutine.create(function() returned=service.OpenLoadout(1,catalog,policy) end)
    local ok,why=coroutine.resume(thread); assert(ok and why=='snapshot_wait')
    return thread
end
local thread=startOpen()
assert(service.OpenLoadout(1,catalog,policy).error.code=='open_in_flight')
assert(service.Open(1,policy).error.code=='open_in_flight','both open paths reserve the same source')
service.Revoke(1,'old-session')
assert(service.OpenLoadout(1,catalog,policy).error.code=='open_in_flight','stale departure cannot cancel current open')
service.Revoke(1,'s')
local newer=startOpen()
assert(coroutine.resume(thread) and not returned.ok and returned.error.code=='open_context_changed')
assert(service.OpenLoadout(1,catalog,policy).error.code=='open_in_flight','old completion cannot clear newer reservation')
assert(coroutine.resume(newer) and returned.ok and service.IsNativeItemBound(1))
service.Revoke(1)
thread=startOpen(); Config.CharacterAmmunitionEnabled=false
assert(coroutine.resume(thread) and not returned.ok and not service.IsNativeItemBound(1))
Config.CharacterAmmunitionEnabled=true
thread=startOpen(); current=false
assert(coroutine.resume(thread) and not returned.ok and not service.IsNativeItemBound(1))
current=true
inventory.GetCharacterFirearmRuntimeSnapshot=function() error('injected snapshot exception') end
assert(not service.OpenLoadout(1,catalog,policy).ok)
inventory.GetCharacterFirearmRuntimeSnapshot=snapshot
assert(service.OpenLoadout(1,catalog,policy).ok,'failed open releases its own reservation')
service.Revoke(1)
print('open reservation PASS (yielded overlap, cross-path exclusion, stale departure, cancelled/new owner, disable/session loss, exception retry)')
local resolve=CoreAdapter.ResolveSession
CoreAdapter.ResolveSession=function(...) coroutine.yield('core_wait'); return resolve(...) end
thread=coroutine.create(function() returned=service.OpenLoadout(1,catalog,policy) end)
local ok,why=coroutine.resume(thread); assert(ok and why=='core_wait')
service.Revoke(1)
newer=coroutine.create(function() returned=service.OpenLoadout(1,catalog,policy) end)
ok,why=coroutine.resume(newer); assert(ok and why=='core_wait')
assert(coroutine.resume(thread) and returned.error.code=='open_reservation_lost')
assert(service.Open(1,policy).error.code=='open_in_flight','old Core resolution cannot adopt newer reservation')
assert(coroutine.resume(newer) and returned.ok)
service.Revoke(1)
CoreAdapter.ResolveSession=resolve
