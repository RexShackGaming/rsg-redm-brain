dofile('tests/character_ammunition_item_spec.lua')
dofile('shared/character_ammunition.lua')
dofile('shared/character_ammunition_policy.lua')
dofile('shared/character_ammunition_materialization.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
dofile('shared/character_ammunition_runtime.lua')
Config.CharacterAmmunitionEnabled=true
local current,hook=true,nil
local registered,commits,commitHook={},0,nil
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='c',sessionId='s'}} end,
    IsSessionCurrent=function() return current end}
GetGameTimer=function() return 100 end
GetInvokingResource=function() return 'feather-inventory' end
AddEventHandler=function() end
local item={id=1,revision=2,itemName='weapon_pistol_m1899',metadata={schemaVersion=2,weaponDefinitionId='pistol_m1899',
    serialNumber='copy1',condition=100,quality=100,maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
    ammo={ownership='character',type='ammo_pistol_regular'},attachments={},cosmetics={},
    flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local policy=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)).limits
local inventory={GetCharacterFirearmRuntimeSnapshot=function(_,context,limits)
    if hook then hook() end
    local pools={}; for id in pairs(limits) do pools[id]=0 end; pools.ammo_pistol_regular=8
    return {ok=true,value={characterId=context.characterId,revision=0,pools=pools,equipment={primary=item}}}
end}
inventory.ObserveCharacterAmmunition=function(_,context,spec)
    assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec),
        'final reduction must have a current server-issued Inventory ticket')
    commits=commits+1
    if commitHook then commitHook() end
    return {ok=true,value={characterId=context.characterId,revision=spec.expectedRevision+1,pools=spec.pools}}
end
exports=setmetatable({['feather-inventory']=inventory},{__call=function(_,name,fn) registered[name]=fn end})
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local catalog=WeaponDefinitionCatalog
local original=catalog.weapons.pistol_m1899.nativeWeaponName
hook=function() catalog.weapons.pistol_m1899.nativeWeaponName='WRONG'; policy.ammo_pistol_regular=1 end
local opened=assert(S.OpenLoadout(1,catalog,policy).value)
assert(opened.creation.items[1].nativeWeaponName==original and opened.limits.ammo_pistol_regular==100,
    'catalog/policy mutation during export cannot change captured authorization')
catalog.weapons.pistol_m1899.nativeWeaponName=original; policy.ammo_pistol_regular=100; hook=nil
opened.names.ammo_pistol_regular='WRONG'; opened.limits.ammo_pistol_regular=1
assert(S.IsNativeItemBound(1) and S.ValidateLoadout(1).ok,'returned hints cannot mutate retained registry')
assert(not S.OpenLoadout(1,catalog,policy).ok,'cannot overwrite an owned loadout')
local report=opened.runtime
assert(S.ConfirmRestore(1,report).ok)
assert(S.CheckpointAndSeal(1,report).ok and S.IsNativeItemBound(1),'seal alone retains item hold')
report.cleanupComplete=true; report.remainingCopies=0
assert(S.ConfirmCleanup(1,report).ok and not S.IsNativeItemBound(1),'matched cleanup releases hold')
opened=assert(S.OpenLoadout(1,catalog,policy).value)
item.revision=3
assert(not S.ValidateLoadout(1).ok and S.IsNativeItemBound(1),'revision loss freezes but retains hold')
assert(not S.ConfirmCleanup(1,opened.runtime).ok,'frozen hold cannot be released by ordinary cleanup ack')
S.Revoke(1); item.revision=2
opened=assert(S.OpenLoadout(1,catalog,policy).value)
report=opened.runtime
assert(S.ConfirmRestore(1,report).ok)
report.pools.ammo_pistol_regular=7
local sealed=assert(S.CheckpointAndSeal(1,report).value)
assert(commits==1 and sealed.revision==1 and sealed.pools.ammo_pistol_regular==7
    and sealed.phase=='sealed' and S.IsNativeItemBound(1),
    'combined loadout final-shot commit seals while retaining exact item hold')
assert(not S.Observe(1,report).ok and commits==1,'late shot report cannot spend twice')
local staleCleanup={}; for key,value in pairs(sealed) do staleCleanup[key]=value end
staleCleanup.cleanupComplete=true; staleCleanup.remainingCopies=0; staleCleanup.revision=0
assert(not S.ConfirmCleanup(1,staleCleanup).ok and S.IsNativeItemBound(1),'stale cleanup retains hold')
sealed.cleanupComplete=true; sealed.remainingCopies=0
assert(S.ConfirmCleanup(1,sealed).ok and not S.IsNativeItemBound(1),'accepted final revision releases exact loadout')
hook=function() current=false end
assert(not S.OpenLoadout(1,catalog,policy).ok and not S.IsNativeItemBound(1),'session lost during snapshot cannot bind')
current=true; hook=nil
opened=assert(S.OpenLoadout(1,catalog,policy).value)
report=opened.runtime; assert(S.ConfirmRestore(1,report).ok)
report.pools.ammo_pistol_regular=7
commitHook=function() current=false end
local beforeCommits=commits
assert(not S.CheckpointAndSeal(1,report).ok and commits==beforeCommits+1
    and S.IsNativeItemBound(1),'session lost during final persistence must not accept ack or release hold')
current=true; commitHook=nil
assert(not S.CheckpointAndSeal(1,report).ok and commits==beforeCommits+1,
    'regained session cannot replay the interrupted final commit')
assert(not S.ConfirmCleanup(1,report).ok and S.IsNativeItemBound(1),
    'interrupted persistence cannot authorize ordinary cleanup')
S.Revoke(1)
dofile('shared/character_ammunition_dispatch.lua')
local dispatched
local dispatcher=WeaponCharacterAmmoDispatch.New({enabled=function() return true end,service=S,
    dispatch=function(_,bundle) dispatched=bundle end,timeout=function() end})
assert(dispatcher.Start(1,catalog,policy).ok and S.IsNativeItemBound(1))
assert(not dispatcher.Start(1,catalog,policy).ok,'serial dispatcher reserves existing loadout')
report=dispatched.runtime
assert(dispatcher.ConfirmRestore(1,report).ok)
report.pools.ammo_pistol_regular=7
local persisted=assert(dispatcher.CheckpointAndSeal(1,report).value)
assert(persisted.revision==1 and dispatcher.Status(1).phase=='sealed' and S.IsNativeItemBound(1))
persisted.cleanupComplete=true; persisted.remainingCopies=0
assert(dispatcher.ConfirmCleanup(1,persisted).ok and not S.IsNativeItemBound(1)
    and dispatcher.Status(1).phase=='released','serial service composition releases only after persisted seal')
assert(dispatcher.ConfirmCleanup(1,persisted).ok,'exact duplicate cleanup is idempotent')
inventory.MutateCharacterAmmunition=function(_,context,spec)
    assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'transfer',spec))
    local pools={}; for id in pairs(spec.limits) do pools[id]=0 end
    pools.ammo_pistol_regular=8+spec.amount
    return {ok=true,value={characterId=context.characterId,revision=spec.expectedRevision+1,pools=pools}}
end
assert(dispatcher.Start(1,catalog,policy).ok)
report=dispatched.runtime; assert(dispatcher.ConfirmRestore(1,report).ok)
report.transfer={ammunitionId='ammo_pistol_regular',amount=2,operationId='load'}
local economic=assert(dispatcher.Transfer(1,report).value)
assert(economic.phase=='restoring' and economic.pools.ammo_pistol_regular==10 and S.IsNativeItemBound(1))
assert(not dispatcher.Transfer(1,report).ok,'economic grant has serialized restore barrier')
assert(dispatcher.ConfirmRestore(1,economic).ok)
persisted=assert(dispatcher.CheckpointAndSeal(1,economic).value)
persisted.cleanupComplete=true; persisted.remainingCopies=0
assert(dispatcher.ConfirmCleanup(1,persisted).ok)
assert(dispatcher.Start(1,catalog,policy).ok)
report=dispatched.runtime; assert(dispatcher.ConfirmRestore(1,report).ok)
local mutations=0
local mutate=inventory.MutateCharacterAmmunition
inventory.MutateCharacterAmmunition=function(...) mutations=mutations+1; return mutate(...) end
item.revision=3
report.transfer={ammunitionId='ammo_pistol_regular',amount=2,operationId='invalid-lease-load'}
assert(not dispatcher.Transfer(1,report).ok and mutations==0 and S.IsNativeItemBound(1),
    'changed weapon lease must refuse Inventory economic mutation before issuing transfer')
assert(dispatcher.Status(1).phase=='frozen')
S.Revoke(1); dispatcher.Forget(1); item.revision=2
assert(dispatcher.Start(1,catalog,policy).ok)
report=dispatched.runtime; assert(dispatcher.ConfirmRestore(1,report).ok)
report.pools.ammo_pistol_regular=7; commitHook=function() current=false end
assert(not dispatcher.CheckpointAndSeal(1,report).ok and dispatcher.Status(1).phase=='frozen'
    and S.IsNativeItemBound(1),'serial dispatch freezes interrupted final commit and keeps holds')
current=true; commitHook=nil
assert(not dispatcher.ConfirmCleanup(1,report).ok and S.IsNativeItemBound(1))
print('loadout server service PASS (immutable snapshots, item holds, revision freeze, matched release, yielded session loss; mocked Inventory)')
S.Revoke(1); item.revision=2
assert(S.OpenLoadout(1,catalog,policy).ok)
hook=function() coroutine.yield(); return end
local late
local worker=coroutine.create(function() late=S.ValidateLoadout(1) end)
assert(coroutine.resume(worker))
hook=nil
S.Revoke(1)
local replacement=assert(S.OpenLoadout(1,catalog,policy).value)
item.revision=3
assert(coroutine.resume(worker) and not late.ok and late.error.code=='loadout_lifecycle_changed')
item.revision=2
assert(S.ConfirmRestore(1,replacement.runtime).ok and S.IsNativeItemBound(1),
    'late validation must not revoke or invalidate successor loadout')
print('loadout validation successor isolation PASS')
