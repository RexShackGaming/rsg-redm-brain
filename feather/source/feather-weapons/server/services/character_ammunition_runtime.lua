-- Server-owned authority only. No net routes/client integration are enabled yet.
WeaponCharacterAmmoService={}
local S=WeaponCharacterAmmoService
local runtime=WeaponCharacterAmmoRuntime.New(function(source,session,character)
    return Config.CharacterAmmunitionEnabled==true and CoreAdapter.IsSessionCurrent(source,session,character)
end)
local sequence=0
local loadouts={}
local opening={}
local deathWrites={}
local retirements,recoverySnapshots={},{}
local function copy(value)
    if type(value)~='table' then return value end
    local out={}; for key,item in pairs(value) do out[key]=copy(item) end; return out
end
local function failure(code) return {ok=false,error={code=code,message=code}} end
local function enabled() return Config.CharacterAmmunitionEnabled==true end
function S.Open(source,limits)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] then return failure('native_loadout_release_required') end
    limits=copy(limits)
    local reservation=opening[source]
    local resolved=CoreAdapter.ResolveSession(source)
    if not resolved.ok then return resolved end
    local session=resolved.value
    if not reservation or opening[source]~=reservation then return failure('open_reservation_lost') end
    reservation.sessionId=session.sessionId
    local context={actorSource=source,characterId=session.characterId,sessionId=session.sessionId}
    local ok,baseline=pcall(function() return exports['feather-inventory']:GetCharacterAmmunitionSnapshot(context,copy(limits)) end)
    if not ok then return failure('inventory_snapshot_unavailable') end
    if type(baseline)~='table' then return failure('invalid_snapshot') end
    if not baseline.ok then return baseline end
    if opening[source]~=reservation or not enabled()
        or not CoreAdapter.IsSessionCurrent(source,session.sessionId,session.characterId) then
        return failure('open_context_changed')
    end
    sequence=sequence+1
    local epoch=('%s:%s:%s:%s'):format(session.sessionId,os.time(),GetGameTimer(),sequence)
    local value,reason=runtime.Open({source=source,characterId=session.characterId,sessionId=session.sessionId},baseline.value,limits,epoch)
    return value and {ok=true,value=value} or failure(reason)
end
function S.ConfirmRestore(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] then
        local live=runtime.Get(source)
        if not live or type(report)~='table' or report.epoch~=live.epoch
            or report.sessionId~=live.sessionId or report.characterId~=live.characterId then
            return failure('stale_loadout_restore')
        end
        local checked=S.ValidateLoadout(source)
        if not checked.ok then return checked end
    end
    local value,reason=runtime.ConfirmRestore(source,report)
    return value and {ok=true,value=value} or failure(reason)
end
-- Dormant combined-open path. The Inventory snapshot binds belt + equipped item
-- revisions in one transaction; the caller still needs lifecycle movement guards
-- before dispatching creation. This function does not send/grant anything.
function S.OpenLoadout(source,catalog,policy)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] then return failure('native_loadout_release_required') end
    -- Preserve the exact policy/catalog used before the Inventory export yields.
    catalog,policy=copy(catalog),copy(policy)
    local registry,reason
    if WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled() then
        registry,reason=WeaponNativeThrowablePolicy.RegistryFromLimits(catalog,policy)
    else registry,reason=WeaponCharacterAmmoCatalog.Build(catalog,policy) end
    if not registry then return failure(reason) end
    local reservation=opening[source]
    local resolved=CoreAdapter.ResolveSession(source)
    if not resolved.ok then return resolved end
    local session=resolved.value
    if not reservation or opening[source]~=reservation then return failure('open_reservation_lost') end
    reservation.sessionId=session.sessionId
    local context={actorSource=source,characterId=session.characterId,sessionId=session.sessionId}
    local ok,snapshot=pcall(function()
        return exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot(context,registry.limits)
    end)
    if not ok or type(snapshot)~='table' then return failure('inventory_runtime_snapshot_unavailable') end
    if not snapshot.ok then return snapshot end
    if opening[source]~=reservation or not enabled()
        or not CoreAdapter.IsSessionCurrent(source,session.sessionId,session.characterId) then
        return failure('open_context_changed')
    end
    if type(snapshot.value)~='table' or snapshot.value.characterId~=session.characterId
        or type(snapshot.value.equipment)~='table' then return failure('invalid_runtime_snapshot') end
    sequence=sequence+1
    local epoch=('%s:%s:%s:%s'):format(session.sessionId,os.time(),GetGameTimer(),sequence)
    local plan
    plan,reason=WeaponCharacterAmmoMaterialization.Build(snapshot.value.equipment,catalog,registry,
        {characterId=session.characterId,sessionId=session.sessionId,epoch=epoch})
    if not plan then return failure(reason) end
    local knife,melee
    if type(GetConvarInt)=='function' and GetConvarInt('feather_native_melee',0)==1 then
        if not WeaponNativeMeleeCatalog or type(snapshot.value.meleeEquipment)~='table'
            or snapshot.value.knifeEquipment~=nil then return failure('native_melee_components_not_ready') end
        melee,reason=WeaponNativeMeleeCatalog.Project(snapshot.value.meleeEquipment,catalog,plan.identity)
        if not melee then return failure(reason) end
    elseif snapshot.value.meleeEquipment~=nil then return failure('native_melee_gate_changed')
    elseif type(GetConvarInt)=='function' and GetConvarInt('feather_native_knife',0)==1 then
        if not WeaponNativeKnife or type(snapshot.value.knifeEquipment)~='table' then return failure('native_knife_components_not_ready') end
        knife,reason=WeaponNativeKnife.Assigned(snapshot.value.knifeEquipment,catalog.weapons.melee_knife,plan.identity)
        if knife==nil then return failure(reason) end
        if knife==false then knife=nil end
    elseif snapshot.value.knifeEquipment~=nil then return failure('native_knife_gate_changed') end
    local throwableSnapshot,throwable
    if WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled() then
        if not WeaponNativeThrowableItem or type(snapshot.value.throwableEquipment)~='table'
            or registry.limits.ammo_tomahawk_regular~=1 then return failure('native_throwable_components_not_ready') end
        throwableSnapshot=copy(snapshot.value.throwableEquipment)
        if throwableSnapshot.revision~=snapshot.value.revision or type(throwableSnapshot.pools)~='table'
            or type(snapshot.value.pools)~='table' then return failure('native_throwable_ledger_changed') end
        for id in pairs(registry.limits) do
            if throwableSnapshot.pools[id]~=snapshot.value.pools[id] then return failure('native_throwable_ledger_changed') end
        end
        throwable,reason=WeaponNativeThrowableItem.Assigned(throwableSnapshot,catalog,plan.identity,registry.limits)
        if throwable==nil then return failure(reason) end
    elseif snapshot.value.throwableEquipment~=nil then return failure('native_throwable_gate_changed') end
    local utilitySnapshot,utility
    if type(GetConvarInt)=='function' and GetConvarInt('feather_native_utility',0)==1 then
        if not WeaponNativeUtilityItem or type(snapshot.value.utilityEquipment)~='table' then return failure('native_utility_components_not_ready') end
        utilitySnapshot=copy(snapshot.value.utilityEquipment)
        utility,reason=WeaponNativeUtilityItem.AssignedSnapshot(utilitySnapshot,catalog,plan.identity)
        if utility==nil then return failure(reason) end
        if utility==false then utility=nil end
    elseif snapshot.value.utilityEquipment~=nil then return failure('native_utility_gate_changed') end
    local opened
    opened,reason=runtime.Open({source=source,characterId=session.characterId,sessionId=session.sessionId},
        snapshot.value,registry.limits,epoch)
    if not opened then return failure(reason) end
    loadouts[source]={sessionId=session.sessionId,characterId=session.characterId,epoch=epoch,registry=registry,catalog=catalog,
        lease=WeaponCharacterAmmoLoadoutLease.New(plan,knife,melee,throwableSnapshot,registry.limits,utilitySnapshot),equipment=copy(snapshot.value.equipment),
        throwableSnapshot=throwable and copy(throwableSnapshot) or nil}
    local items={}
    for _,item in ipairs(plan.items) do items[#items+1]={itemId=item.itemInstanceId,revision=item.itemRevision} end
    if knife then items[#items+1]={itemId=knife.row.id,revision=knife.row.revision} end
    if melee then for _,entry in ipairs(melee.items) do items[#items+1]={itemId=entry.row.id,revision=entry.row.revision} end end
    if throwable then items[#items+1]={itemId=throwable.row.id,revision=throwable.row.revision} end
    if utility then for _,tool in ipairs(utility.items or {utility}) do items[#items+1]={itemId=tool.row.id,revision=tool.row.revision} end end
    recoverySnapshots[source]={characterId=session.characterId,sessionId=session.sessionId,epoch=epoch,
        policy='last_durable_snapshot',ledgerRevision=snapshot.value.revision,itemRevisions=items,
        prior=copy(retirements[session.characterId]),economicReplay=false,nativeAdoption=false}
    return {ok=true,value={runtime=opened,creation=plan,knife=copy(knife),melee=copy(melee),
        throwable=throwable and copy(throwableSnapshot) or nil,utility=copy(utility),names=copy(registry.names),limits=copy(registry.limits)}}
end
function S.ReadRecoveryStatus(source)
    local value=recoverySnapshots[source]
    if not value or not enabled() or not CoreAdapter.IsSessionCurrent(source,value.sessionId,value.characterId) then return nil end
    local out=copy(value)
    out.currentAcknowledged=runtime.Get(source)
    out.contract={runtime=WeaponCharacterAmmoRuntime.RecoveryContract,dispatch=WeaponCharacterAmmoDispatch and WeaponCharacterAmmoDispatch.RecoveryContract,
        activation=WeaponCharacterAmmoDispatcher and WeaponCharacterAmmoDispatcher.RecoveryContract,
        transitions=WeaponNativeEquipmentBindings and WeaponNativeEquipmentBindings.RecoveryContract}
    return out
end
-- Trusted activation only. A new current Core session may retire obsolete
-- server reservations; this never proves old native copies were cleaned up.
function S.ReconcileSession(source,identity)
    if not enabled() or Config.NativeAlphaRuntime~=true or type(identity)~='table'
        or not WeaponNativeEnrollment.Allows(Config,identity.characterId)
        or not CoreAdapter.IsSessionCurrent(source,identity.sessionId,identity.characterId) then return failure('recovery_current_scope_required') end
    local stale={}
    for target,bound in pairs(loadouts) do
        if (target==source or bound.characterId==identity.characterId) and bound.sessionId~=identity.sessionId then
            if CoreAdapter.IsSessionCurrent(target,bound.sessionId,bound.characterId) then return failure('recovery_old_session_still_current') end
            stale[#stale+1]={source=target,sessionId=bound.sessionId}
        end
    end
    for target,reservation in pairs(opening) do
        if target==source and reservation.sessionId and reservation.sessionId~=identity.sessionId then
            if CoreAdapter.IsSessionCurrent(target,reservation.sessionId,identity.characterId) then return failure('recovery_old_open_still_current') end
            local found=false
            for _,old in ipairs(stale) do if old.source==target and old.sessionId==reservation.sessionId then found=true end end
            if not found then stale[#stale+1]={source=target,sessionId=reservation.sessionId} end
        end
    end
    if not CoreAdapter.IsSessionCurrent(source,identity.sessionId,identity.characterId) then return failure('recovery_session_changed') end
    for _,old in ipairs(stale) do S.Revoke(old.source,old.sessionId,'retired_session') end
    return {ok=true,value={retired=stale}}
end
-- Explicit recheck for lifecycle dispatch/ack integration. Does not authorize
-- arbitrary client plans, dispatch grants, or silently refresh stale revisions.
function S.ValidateLoadout(source)
    if not enabled() then return failure('character_ammunition_disabled') end
    local bound=loadouts[source]
    if not bound then return failure('loadout_not_bound') end
    if bound.invalid then return failure('loadout_frozen_release_required') end
    if not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then
        runtime.Revoke(source); bound.invalid=true; return failure('loadout_session_changed')
    end
    local ok,snapshot=pcall(function()
        return exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot(
            {actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId},bound.registry.limits)
    end)
    if loadouts[source]~=bound then return failure('loadout_lifecycle_changed') end
    if not enabled() or bound.invalid then return failure('loadout_frozen_release_required') end
    local valid,reason
    if ok and type(snapshot)=='table' and snapshot.ok then
        valid,reason=bound.lease.Validate(snapshot.value,bound.catalog,bound.registry)
    end
    if not valid or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then
        -- Stop accepting ammo reports, but retain movement/destruction holds
        -- until trusted lifecycle cleanup releases the old native copies.
        runtime.Revoke(source); bound.invalid=true; return failure(reason or 'loadout_recheck_failed')
    end
    return {ok=true,value=true}
end
function S.IsNativeItemBound(itemId)
    for _,bound in pairs(loadouts) do if bound.lease.Contains(itemId) then return true end end
    return false
end
function S.CanReleaseInventoryGuards()
    -- No callback removal while an item lease/open/final persistence operation
    -- remains owned. Orderly ConfirmCleanup clears loadouts only after release.
    return next(loadouts)==nil and next(opening)==nil and next(deathWrites)==nil
end
-- Server-only retained lease data for idle periodic sampling. No SQL/readiness
-- hints from clients, and no metadata authority outside the release coordinator.
function S.ReadBoundMaintenanceItems(source)
    local bound=loadouts[source]
    local live=runtime.Get(source)
    if not enabled() or not bound or bound.invalid or not live or live.phase~='active'
        or bound.epoch~=live.epoch then return nil end
    local items={}
    for _,row in pairs(bound.equipment or {}) do
        local definition=row.metadata and bound.catalog.weapons[row.metadata.weaponDefinitionId]
        if not definition or definition.itemName~=row.itemName then return nil end
        items[#items+1]={id=row.id,revision=row.revision,metadata=copy(row.metadata),definition=copy(definition)}
    end
    table.sort(items,function(a,b) return a.id<b.id end)
    return items
end
function S.IsDeathWearWriteAuthorized(itemId,context)
    if Config.NativeAlphaLifecycleWearEnabled~=true or not enabled() or type(context)~='table'
        or context.operation~='metadata_write' or context.resource~='feather-weapons' then return false end
    local request=deathWrites[context.actorSource]
    if not request or context.runtimeEpoch~=request.context.runtimeEpoch or context.runtimeTicket~=request.context.runtimeTicket
        or not runtime.IsOperationCurrent(request.context,'observe',request.spec) then return false end
    local function equal(a,b,path)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then
            local fields={['maintenance.degradation']=true,['maintenance.permanentDegradation']=true,
                ['maintenance.damage']=true,['maintenance.dirt']=true,['maintenance.soot']=true}
            if fields[path] and type(a)=='number' and a==a and b==b and a>=0 and a<=1 and b>=0 and b<=1 then return math.abs(a-b)<=1e-12 end
            return a==b
        end
        for k,v in pairs(a) do if not equal(v,b[k],path and (path..'.'..tostring(k)) or tostring(k)) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    for _,change in ipairs(request.spec.finalWear.lifecycleWear) do
        if change.itemId==itemId and change.itemRevision==context.expectedRevision and equal(change.after,context.metadata) then return true end
    end
    return false
end
function S.IsDeathEquipmentWriteAuthorized(itemId,context)
    if Config.NativeAlphaLifecycleWearEnabled~=true or Config.NativeAlphaRuntime~=true
        or not enabled() or type(context)~='table' or context.operation~='equipment_write'
        or context.resource~='feather-weapons' then return false end
    local request=deathWrites[context.actorSource]
    if not request or context.characterId~=request.context.characterId or context.sessionId~=request.context.sessionId
        or context.runtimeEpoch~=request.context.runtimeEpoch or context.runtimeTicket~=request.context.runtimeTicket
        or not runtime.IsOperationCurrent(request.context,'observe',request.spec) then return false end
    local plan=request.spec.finalWear
    local detach=plan and plan.brokenEquipment and plan.brokenEquipment[context.equipmentSlot]
    local target=plan and plan.expected and plan.expected[context.equipmentSlot]
    if context.equipmentAction=='equip' then
        local promotion=plan and plan.brokenEquipment and plan.brokenEquipment.weapon_offhand
        if context.equipmentSlot~='weapon' or not promotion or promotion.promote~=true
            or context.equipmentItemId~=promotion.itemId then return false end
    elseif context.equipmentAction~='unequip' or not detach or not target
        or detach.itemId~=target.itemId or target.itemId~=context.equipmentItemId then return false end
    -- Conditional equipment validates all retained assignments, not just the
    -- target. This permits guard checks only for that exact reserved unequip.
    for _,row in pairs(plan.expected) do
        if row.itemId==itemId then return runtime.IsOperationCurrent(request.context,'observe',request.spec)==true end
    end
    return false
end
-- Dispatch failure/timeout invalidates ammo authority but retains native holds.
-- Only a trusted lifecycle recovery may release a frozen materialization.
function S.FreezeLoadout(source,identity)
    local bound=loadouts[source]
    if not bound or type(identity)~='table' or identity.epoch~=bound.epoch
        or identity.sessionId~=bound.sessionId or identity.characterId~=bound.characterId then
        return failure('stale_loadout_freeze')
    end
    bound.retirementEvidence=runtime.Revoke(source); bound.invalid=true
    return {ok=true,value=true}
end
local function commit(request,method)
    local bound=loadouts[request.context.actorSource]
    if bound then bound.providerOutcome='pending' end
    local ok,result=pcall(function() return exports['feather-inventory'][method](exports['feather-inventory'],request.context,request.spec) end)
    if bound then bound.providerOutcome=ok and type(result)=='table' and (result.ok==true and 'confirmed' or result.ok==false and 'refused') or 'uncertain' end
    local value,reason=runtime.Complete(request.context,ok and result or {ok=false})
    if value and bound and loadouts[request.context.actorSource]==bound and bound.epoch==request.context.runtimeEpoch then
        if method=='ReconcileNativeThrowablePickup' then bound.nativePickupCredit=nil
        elseif type(result.value.nativePickupSpend)=='table' then bound.nativePickupCredit=copy(result.value.nativePickupSpend) end
    end
    return value and {ok=true,value=value} or failure(reason)
end
function S.Observe(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    local request,reason=runtime.PrepareObservation(source,report)
    if not request then return failure(reason) end
    if request.unchanged then return {ok=true,value=request.value} end
    return commit(request,'ObserveCharacterAmmunition')
end
function S.NativePickup(source,report)
    if not enabled() or Config.DevMode~=true or Config.NativeAlphaRuntime~=true
        or type(GetConvarInt)~='function' or GetConvarInt('feather_native_throwable_pickup',0)~=1
        or not WeaponNativeThrowablePolicy or not WeaponNativeThrowablePolicy.Enabled()
        or not WeaponNativeThrowableRecovery then return failure('native_pickup_disabled') end
    report=copy(report)
    local bound=loadouts[source]
    if not bound or not bound.nativePickupCredit or not bound.throwableSnapshot then return failure('native_pickup_credit_required') end
    local checked=S.ValidateLoadout(source)
    if not checked.ok or loadouts[source]~=bound then return failure('native_pickup_loadout_changed') end
    local live=runtime.Get(source)
    if not live or type(report)~='table' then return failure('native_pickup_runtime_required') end
    local snapshot=copy(bound.throwableSnapshot)
    snapshot.revision=live.revision; snapshot.pools=copy(live.pools)
    report.phase='active' -- the server runtime, not a client phase flag, is authority
    local plan,why=WeaponNativeThrowableRecovery.NativePickupPlan(bound.nativePickupCredit,live,snapshot,
        report,bound.catalog,bound.registry.limits)
    if not plan then return failure(why) end
    local request; request,why=runtime.PrepareNativePickup(source,report,plan)
    if not request then return failure(why) end
    return commit(request,'ReconcileNativeThrowablePickup')
end
function S.Transfer(source,report,id,amount,operationId)
    if not enabled() then return failure('character_ammunition_disabled') end
    -- Throwable quantities require retiring/rebuilding the owned native carrier;
    -- never trust the client's matching refusal as the economic boundary.
    if id=='ammo_tomahawk_regular' then return failure('throwable_transfer_requires_rebuild') end
    if loadouts[source] then
        local live=runtime.Get(source)
        if not live or type(report)~='table' or report.epoch~=live.epoch
            or report.sessionId~=live.sessionId or report.characterId~=live.characterId then
            return failure('stale_loadout_transfer')
        end
        local checked=S.ValidateLoadout(source)
        if not checked.ok then return checked end
    end
    local request,reason=runtime.PrepareTransfer(source,report,id,amount,operationId)
    if not request then return failure(reason) end
    return commit(request,'MutateCharacterAmmunition')
end
local function readMedical(source,context)
    local called,result=pcall(function() return exports['feather-medical']:ReadNativeWeaponCondition(source,context) end)
    return called and type(result)=='table' and result.ok==true and type(result.value)=='table' and result.value or nil
end
local function deathPlan(source,report)
    local bound=loadouts[source]
    local gate=Config.NativeAlphaLifecycleWearEnabled==true
    if not gate then
        if type(report)=='table' and report.deathWear~=nil then return nil,'death_wear_disabled' end
        return nil
    end
    if not bound then return nil,'death_wear_loadout_required' end
    if Config.NativeAlphaRuntime~=true or not WeaponNativeEnrollment.Allows(Config,bound.characterId)
        or bound.invalid then return nil,'death_wear_scope_required' end
    local live=runtime.Get(source)
    if not live or live.phase~='active' or type(report)~='table' or report.characterId~=live.characterId
        or report.sessionId~=live.sessionId or report.epoch~=live.epoch or report.revision~=live.revision then return nil,'stale_death_wear' end
    local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
    local medical=readMedical(source,context)
    if not medical or loadouts[source]~=bound then return nil,'death_wear_medical_unavailable' end
    if medical.lifeState~='dead' then
        if report.deathWear~=nil then return nil,'death_wear_not_dead' end
        return nil -- ordinary alive equipment/logout release uses its own wear protocol
    end
    local wear=WeaponCharacterLifecycleWear.DeathReport(report.deathWear)
    if not wear or wear.epoch~=live.epoch or wear.medicalRevision~=medical.revision then return nil,'death_wear_revision_required' end
    local called,snapshot=pcall(function()
        return exports['feather-inventory']:ReadNativeEquipmentTransition(context,nil,bound.registry.limits)
    end)
    if not called or not snapshot or not snapshot.ok or loadouts[source]~=bound then return nil,'death_wear_snapshot_unavailable' end
    local valid=bound.lease.Validate(snapshot.value,bound.catalog,bound.registry)
    if not valid then return nil,'death_wear_loadout_changed' end
    local changes,why,detached=WeaponCharacterLifecycleWear.Plan(snapshot.value.equipment,wear,bound.catalog,live.epoch,true)
    if not changes then return nil,why end
    if next(detached or {}) and snapshot.value.brokenDeathEquipmentContract~=1 then return nil,'broken_death_inventory_update_required' end
    if detached.weapon_offhand and detached.weapon_offhand.promote and snapshot.value.brokenPromotionContract~=1 then return nil,'broken_promotion_inventory_update_required' end
    return {characterId=bound.characterId,action='death',expected=copy(snapshot.value.expected),lifecycleWear=changes,
        brokenEquipment=detached,
        medicalRevision=medical.revision,episodeId=medical.episodeId}
end
function S.CheckpointAndSeal(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    local function refused(code)
        print(('[WeaponNativeCheckpointAndSeal] REFUSED source=%s code=%s'):format(tostring(source),tostring(code)))
        return failure(code)
    end
    local wear,reason=deathPlan(source,report)
    if reason then return refused(reason) end
    local request
    request,reason=runtime.PrepareFinalObservation(source,report,wear)
    if not request then return refused(reason) end
    if request.unchanged then return {ok=true,value=request.value} end
    -- Final reductions must commit before the old epoch is eligible for reset.
    -- Complete seals in the same pure transition that accepts the DB result.
    if wear then deathWrites[source]=request end
    local called,result=pcall(commit,request,'ObserveCharacterAmmunition')
    if deathWrites[source]==request then deathWrites[source]=nil end
    if called and result and result.ok and wear then
        print(('[feather-weapons] death final wear persisted changes=%s medicalRevision=%s; final ammo seal acknowledged'):format(#wear.lifecycleWear,wear.medicalRevision))
    end
    return called and result or failure('death_final_observation_failed')
end
function S.ConfirmCleanup(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] and loadouts[source].invalid then return failure('loadout_frozen_release_required') end
    local released,reason=runtime.ConfirmCleanup(source,report)
    if not released then return failure(reason) end
    loadouts[source]=nil
    return {ok=true,value=released}
end
function S.Revoke(source,sessionId,reason)
    if deathWrites[source] and (not sessionId or deathWrites[source].context.sessionId==sessionId) then deathWrites[source]=nil end
    if opening[source] and (not sessionId or opening[source].sessionId==sessionId) then opening[source]=nil end
    local bound=loadouts[source]
    local evidence=runtime.Revoke(source,sessionId)
    local matches=bound and (not sessionId or bound.sessionId==sessionId)
    if matches and not evidence then evidence=bound.retirementEvidence end
    if reason and evidence then
        retirements[evidence.characterId]={source=source,sessionId=evidence.sessionId,epoch=evidence.epoch,
            lastAcknowledgedLedgerRevision=evidence.revision,phase=evidence.phase,pendingOperation=evidence.pendingOperation,
            reason=reason,kind=evidence.phase=='released' and 'orderly_release' or 'retired_unreleased',
            nativeCleanupConfirmed=evidence.phase=='released',finalObservationInvented=false,
            providerOutcome=bound and bound.providerOutcome or 'not_requested',
            unresolvedPersistence=evidence.pendingOperation~=nil or bound and (bound.providerOutcome=='pending' or bound.providerOutcome=='uncertain') or false}
    end
    if matches then loadouts[source]=nil end
    if recoverySnapshots[source] and (not sessionId or recoverySnapshots[source].sessionId==sessionId) then recoverySnapshots[source]=nil end
end
-- Reserve before Core/Inventory may yield. Both open paths share the slot.
-- A cancelled coroutine cannot clear a newer reservation when it resumes.
for _,name in ipairs({'Open','OpenLoadout'}) do
    local implementation=S[name]
    S[name]=function(source,...)
        if not enabled() then return failure('character_ammunition_disabled') end
        if opening[source] then return failure('open_in_flight') end
        local reservation={}
        opening[source]=reservation
        local called,result=pcall(implementation,source,...)
        if opening[source]==reservation then opening[source]=nil end
        if not called then return failure('open_failed') end
        return result
    end
end
exports('ValidateCharacterAmmoRuntimeOperation',function(context,operation,spec)
    if GetInvokingResource()~='feather-inventory' or not enabled()
        or runtime.IsOperationCurrent(context,operation,spec)~=true then return false end
    if operation=='pickup' then
        if Config.DevMode~=true or Config.NativeAlphaRuntime~=true or type(GetConvarInt)~='function'
            or GetConvarInt('feather_native_throwable_pickup',0)~=1 then return false end
        local medical=readMedical(context.actorSource,context)
        return medical and medical.lifeState=='alive' and runtime.IsOperationCurrent(context,operation,spec)==true or false
    end
    if type(spec)=='table' and spec.finalWear~=nil then
        if operation~='observe' or Config.NativeAlphaLifecycleWearEnabled~=true
            or Config.NativeAlphaRuntime~=true or not WeaponNativeEnrollment.Allows(Config,context.characterId) then return false end
        local medical=readMedical(context.actorSource,context)
        return medical and medical.lifeState=='dead' and medical.revision==spec.finalWear.medicalRevision
            and medical.episodeId==spec.finalWear.episodeId and runtime.IsOperationCurrent(context,operation,spec)==true or false
    end
    return true
end)
if type(RegisterCommand)=='function' then RegisterCommand('WeaponNativeRecoveryStatus',function(source,args)
    if source~=0 or Config.DevMode~=true or Config.NativeAlphaRuntime~=true then return end
    local value=S.ReadRecoveryStatus(tonumber(args and args[1]))
    print('[WeaponNativeRecoveryStatus] '..json.encode(value or {error='current_native_session_required'}))
end,true) end
AddEventHandler('playerDropped',function() S.Revoke(source,nil,'player_dropped') end)
AddEventHandler('core.session.left.v1',function(session)
    -- Local Core lifecycle event, not a client-triggerable net route.
    if type(session)=='table' and session.source and session.sessionId then S.Revoke(session.source,session.sessionId,'session_left') end
end)
