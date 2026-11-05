-- Pure server lifecycle coordinator. It neither grants native ammo nor owns SQL.
-- Callers must obtain baselines/epochs from server authority, never client input.
WeaponCharacterAmmoRuntime={}
WeaponCharacterAmmoRuntime.RecoveryContract=1
function WeaponCharacterAmmoRuntime.New(isCurrent)
    assert(type(isCurrent)=='function','local session validator required')
    local sessions,issued={},{}
    local R={}
    local function clone(v)
        if type(v)~='table' then return v end
        local out={}; for k,x in pairs(v) do out[k]=clone(x) end; return out
    end
    local function current(s)
        return s and isCurrent(s.source,s.sessionId,s.characterId)==true
    end
    local function match(s,request)
        return current(s) and type(request)=='table' and request.characterId==s.characterId
            and request.sessionId==s.sessionId and request.epoch==s.epoch
            and request.revision==s.revision
    end
    local function snapshot(s)
        return {characterId=s.characterId,sessionId=s.sessionId,epoch=s.epoch,
            revision=s.revision,pools=clone(s.pools),phase=s.phase}
    end
    function R.Open(context,baseline,limits,epoch)
        if type(context)~='table' or type(context.source)~='number' or context.source<1
            or context.source%1~=0 or type(context.characterId)~='string' or context.characterId==''
            or type(context.sessionId)~='string' or context.sessionId==''
            or type(epoch)~='string' or epoch=='' or #epoch>128
            or type(baseline)~='table' or type(baseline.revision)~='number'
            or baseline.revision<0 or baseline.revision%1~=0 or baseline.revision==math.huge
            or baseline.characterId~=context.characterId or type(limits)~='table'
            or next(limits)==nil then return nil,'invalid_baseline' end
        if not current(context) then return nil,'stale_session' end
        local old=sessions[context.source]
        if old and current(old) and old.phase~='sealed' and old.phase~='released' then return nil,'runtime_not_sealed' end
        if issued[epoch] then return nil,'epoch_reused' end
        local pools,reason=WeaponCharacterAmmunition.Validate(baseline.pools,limits)
        if not pools then return nil,reason end
        local s={source=context.source,characterId=context.characterId,sessionId=context.sessionId,
            epoch=epoch,revision=baseline.revision,pools=pools,limits=clone(limits),phase='restoring',sequence=0}
        issued[epoch]=true; sessions[context.source]=s
        return snapshot(s)
    end
    function R.ConfirmRestore(source,report)
        local s=sessions[source]
        if not match(s,report) then return nil,'stale_runtime' end
        if s.phase~='restoring' then return nil,'not_restoring' end
        local observed,reason=WeaponCharacterAmmunition.Observe(s,report,s.limits)
        if not observed then return nil,reason end
        if observed.changed then return nil,'restore_mismatch' end
        s.phase='active'; return snapshot(s)
    end
    local function prepareObservation(source,report,sealAfter,finalWear)
        local s=sessions[source]
        if not match(s,report) then return nil,'stale_runtime' end
        if s.phase~='active' then return nil,'not_active' end
        if s.pending then return nil,'operation_in_flight' end
        local proposed,reason=WeaponCharacterAmmunition.Observe(s,report,s.limits)
        if not proposed then return nil,reason end
        -- Idle observations are acknowledged locally: no DB polling/revision churn.
        if not proposed.changed and finalWear==nil then
            if sealAfter then s.phase='sealed' end
            return {unchanged=true,value=snapshot(s)}
        end
        s.sequence=s.sequence+1
        s.pending={ticket=s.epoch..':'..s.sequence,proposed=proposed,operation='observe',sealAfter=sealAfter==true,finalWear=clone(finalWear)}
        return {context={actorSource=source,characterId=s.characterId,sessionId=s.sessionId,
            runtimeEpoch=s.epoch,runtimeTicket=s.pending.ticket},
            spec={expectedRevision=s.revision,pools=clone(proposed.pools),limits=clone(s.limits),finalWear=clone(finalWear)}}
    end
    function R.PrepareObservation(source,report) return prepareObservation(source,report,false) end
    function R.PrepareFinalObservation(source,report,finalWear) return prepareObservation(source,report,true,finalWear) end
    -- `plan` is produced by the server recovery planner from its committed
    -- receipt, never supplied by the client transport.
    function R.PrepareNativePickup(source,report,plan)
        local s=sessions[source]
        if not match(s,report) then return nil,'stale_runtime' end
        if s.phase~='active' or s.pending then return nil,'not_idle' end
        if type(plan)~='table' or plan.version~=1 or plan.kind~='native_pickup_ledger_plan'
            or plan.policy~='same_session_native_spend_credit_v1' or plan.units~=1
            or type(plan.identity)~='table' or plan.identity.characterId~=s.characterId
            or plan.identity.sessionId~=s.sessionId or plan.identity.epoch~=s.epoch
            or plan.expectedRevision~=s.revision or plan.revision~=s.revision+1
            or plan.requiresAtomicSpendClaim~=true or plan.requiresLedgerCAS~=true
            or plan.looseInventoryDelta~=0 or plan.nativeAmmoDelta~=0
            or plan.pickupCredits~=false or plan.originConfirmed~=false
            or s.limits.ammo_tomahawk_regular~=1 then return nil,'native_pickup_plan_required' end
        local pools=WeaponCharacterAmmunition.Validate(report.pools,s.limits)
        if not pools or type(plan.pools)~='table' or s.pools.ammo_tomahawk_regular~=0
            or pools.ammo_tomahawk_regular~=1 then return nil,'native_pickup_one_unit_required' end
        for id in pairs(s.limits) do
            if report.pools[id]==nil or plan.pools[id]~=pools[id]
                or (id~='ammo_tomahawk_regular' and pools[id]~=s.pools[id]) then return nil,'native_pickup_other_pool_changed' end
        end
        for id in pairs(plan.pools) do if s.limits[id]==nil then return nil,'native_pickup_unknown_pool' end end
        s.sequence=s.sequence+1
        s.pending={ticket=s.epoch..':'..s.sequence,operation='pickup',nativePickupPlan=clone(plan),
            proposed={characterId=s.characterId,revision=s.revision+1,pools=clone(pools),changed=true}}
        return {context={actorSource=source,characterId=s.characterId,sessionId=s.sessionId,
            runtimeEpoch=s.epoch,runtimeTicket=s.pending.ticket},spec={expectedRevision=s.revision,
            pools=clone(pools),limits=clone(s.limits),nativePickupPlan=clone(plan)}}
    end
    function R.PrepareTransfer(source,report,id,amount,operationId)
        local s=sessions[source]
        if not match(s,report) then return nil,'stale_runtime' end
        if s.phase~='active' or s.pending then return nil,'not_idle' end
        if type(operationId)~='string' or #operationId<1 or #operationId>64 then return nil,'invalid_operation_id' end
        if type(amount)~='number' or math.abs(amount)>1000 then return nil,'invalid_transfer' end
        local observed,reason=WeaponCharacterAmmunition.Observe(s,report,s.limits)
        if not observed then return nil,reason end
        if observed.changed then return nil,'checkpoint_required' end
        local proposed
        proposed,reason=WeaponCharacterAmmunition.Transfer(s,id,amount,s.limits)
        if not proposed then return nil,reason end
        s.sequence=s.sequence+1
        s.pending={ticket=s.epoch..':'..s.sequence,proposed=proposed,operation='transfer',
            id=id,amount=amount,operationId=operationId}
        return {context={actorSource=source,characterId=s.characterId,sessionId=s.sessionId,
            runtimeEpoch=s.epoch,runtimeTicket=s.pending.ticket},
            spec={expectedRevision=s.revision,ammunitionId=id,amount=amount,
                operationId=operationId,limits=clone(s.limits)}}
    end
    function R.IsOperationCurrent(context,operation,spec)
        if type(context)~='table' then return false end
        local s=sessions[context.actorSource]
        local valid=current(s) and s.phase=='active' and s.pending~=nil
            and context.characterId==s.characterId and context.sessionId==s.sessionId
            and context.runtimeEpoch==s.epoch and context.runtimeTicket==s.pending.ticket
        if not valid or not operation then return valid end
        if operation~=s.pending.operation or type(spec)~='table' or spec.expectedRevision~=s.revision then return false end
        local function equal(a,b)
            if type(a)~=type(b) then return false end
            if type(a)~='table' then return a==b end
            for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
            for k in pairs(b) do if a[k]==nil then return false end end
            return true
        end
        if not equal(spec.finalWear,s.pending.finalWear) then return false end
        if not equal(spec.nativePickupPlan,s.pending.nativePickupPlan) then return false end
        if type(spec.limits)~='table' then return false end
        for id,limit in pairs(s.limits) do if spec.limits[id]~=limit then return false end end
        for id in pairs(spec.limits) do if s.limits[id]==nil then return false end end
        if operation=='transfer' then
            return spec.ammunitionId==s.pending.id and spec.amount==s.pending.amount
                and spec.operationId==s.pending.operationId
        end
        if type(spec.pools)~='table' then return false end
        for id,amount in pairs(s.pending.proposed.pools) do if spec.pools[id]~=amount then return false end end
        for id in pairs(spec.pools) do if s.limits[id]==nil then return false end end
        return true
    end
    function R.Complete(context,result)
        if not R.IsOperationCurrent(context) then return nil,'stale_operation' end
        local s=sessions[context.actorSource]
        if type(result)~='table' or result.ok~=true or type(result.value)~='table' then
            s.pending=nil; s.phase='frozen'; return nil,'persistence_failed'
        end
        local value,expected=result.value,s.pending.proposed
        local accepted=WeaponCharacterAmmunition.Validate(value.pools,s.limits)
        local valid=value.characterId==s.characterId and value.revision==expected.revision and accepted~=nil
        for id,count in pairs(expected.pools) do valid=valid and accepted and accepted[id]==count end
        if not valid then s.pending=nil; s.phase='frozen'; return nil,'persistence_mismatch' end
        local sealAfter=s.pending.sealAfter
        s.pools,s.revision,s.pending=accepted,value.revision,nil
        if sealAfter then s.phase='sealed'
        elseif expected.changed==nil then s.phase='restoring' end -- economic change needs native baseline ack
        return snapshot(s)
    end
    function R.Seal(source,sessionId,epoch)
        local s=sessions[source]
        if not current(s) or s.sessionId~=sessionId or s.epoch~=epoch then return nil,'stale_runtime' end
        if s.pending then return nil,'operation_in_flight' end
        if s.phase~='active' then return nil,'not_active' end
        s.phase='sealed'; return snapshot(s)
    end
    function R.Revoke(source,sessionId)
        -- Logout/drop invalidates in-flight tickets; Inventory must check before commit.
        if sessionId and sessions[source] and sessions[source].sessionId~=sessionId then return end
        local s=sessions[source]
        local evidence=s and snapshot(s) or nil
        if evidence then evidence.pendingOperation=s.pending and s.pending.operation or nil end
        sessions[source]=nil
        return evidence -- diagnostic only; not a flush, seal, grant or cleanup ack
    end
    function R.ConfirmCleanup(source,report)
        local s=sessions[source]
        if not match(s,report) then return nil,'stale_runtime' end
        if s.phase~='sealed' and s.phase~='released' then return nil,'cleanup_requires_seal' end
        if report.cleanupComplete~=true or report.remainingCopies~=0 then return nil,'cleanup_incomplete' end
        -- This is a lifecycle acknowledgement of owned-copy cleanup, not a new
        -- native ammo observation. Retain the final sealed persisted belt.
        local observed,reason=WeaponCharacterAmmunition.Observe(s,report,s.limits)
        if not observed then return nil,reason end
        if observed.changed then return nil,'cleanup_belt_mismatch' end
        s.phase='released'; return snapshot(s) -- exact duplicate ack is harmless
    end
    function R.Get(source)
        local s=sessions[source]; return current(s) and snapshot(s) or nil
    end
    return R
end
