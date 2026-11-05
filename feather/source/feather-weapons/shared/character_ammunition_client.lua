-- Dormant pure client checkpoint state. No natives, events, grants, or timers.
WeaponCharacterAmmoClient={}
function WeaponCharacterAmmoClient.New()
    local C={}; local baseline,limits,ped,pending,phase,sequence=nil,nil,nil,nil,'closed',0
    local function copy(v)
        if type(v)~='table' then return v end
        local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
    end
    local function same(a,b)
        return a.characterId==b.characterId and a.sessionId==b.sessionId
            and a.epoch==b.epoch and a.revision==b.revision
    end
    function C.Begin(value,caps,currentPed)
        if phase~='closed' then return nil,'not_closed' end
        if type(value)~='table' or value.phase~='restoring' or type(value.characterId)~='string'
            or value.characterId=='' or type(value.sessionId)~='string' or value.sessionId==''
            or type(value.epoch)~='string' or value.epoch=='' or type(value.revision)~='number'
            or value.revision<0 or value.revision%1~=0 or value.revision==math.huge
            or type(currentPed)~='number' or currentPed<=0 or type(caps)~='table'
            or next(caps)==nil then return nil,'invalid_baseline' end
        local pools,reason=WeaponCharacterAmmunition.Validate(value.pools,caps)
        if not pools then return nil,reason end
        for id in pairs(caps) do if value.pools[id]==nil then return nil,'incomplete_baseline' end end
        baseline=copy(value); baseline.pools=pools; limits=copy(caps); ped=currentPed; phase='restoring'
        return copy(baseline)
    end
    local function prepare(currentPed,pools,worldReady,finish)
        if phase~='active' and phase~='restoring' then return nil,'not_ready' end
        if currentPed~=ped then phase='suspended'; pending=nil; return nil,'ped_changed' end
        if worldReady~=true then return nil,'world_not_ready' end
        if pending then return nil,'in_flight' end
        if finish and phase~='active' then return nil,'not_active' end
        local report=copy(baseline); report.pools=copy(pools); report.phase=nil
        local observed,reason=WeaponCharacterAmmunition.Observe(baseline,report,limits)
        if not observed then phase='frozen'; return nil,reason end
        if phase=='restoring' and observed.changed then phase='frozen'; return nil,'restore_mismatch' end
        if phase=='active' and not observed.changed and not finish then return {unchanged=true} end
        sequence=sequence+1
        pending={id=sequence,kind=finish and 'seal' or (phase=='restoring' and 'restore' or 'observe'),report=report,expected=observed}
        return copy(pending)
    end
    function C.Prepare(currentPed,pools,worldReady) return prepare(currentPed,pools,worldReady,false) end
    function C.PrepareFinal(currentPed,pools,worldReady) return prepare(currentPed,pools,worldReady,true) end
    function C.PrepareNativePickup(currentPed,pools,worldReady)
        if phase~='active' then return nil,'pickup_not_active' end
        if currentPed~=ped then phase='suspended'; pending=nil; return nil,'ped_changed' end
        if worldReady~=true or pending then return nil,'pickup_world_or_request_pending' end
        local observed=WeaponCharacterAmmunition.Validate(pools,limits)
        if not observed or limits.ammo_tomahawk_regular~=1 or baseline.pools.ammo_tomahawk_regular~=0
            or observed.ammo_tomahawk_regular~=1 then return nil,'pickup_one_unit_increase_required' end
        for id in pairs(limits) do
            if pools[id]==nil or (id~='ammo_tomahawk_regular' and observed[id]~=baseline.pools[id]) then
                return nil,'pickup_other_pool_changed'
            end
        end
        sequence=sequence+1
        local report=copy(baseline); report.pools=copy(observed); report.phase=nil
        pending={id=sequence,kind='pickup',report=report,expected={revision=baseline.revision+1,pools=copy(observed)}}
        return copy(pending)
    end
    function C.PrepareTransfer(currentPed,pools,worldReady,ammunitionId,amount,operationId)
        if phase~='active' then return nil,'not_active' end
        if currentPed~=ped then phase='suspended'; pending=nil; return nil,'ped_changed' end
        if worldReady~=true then return nil,'world_not_ready' end
        if pending then return nil,'in_flight' end
        if type(operationId)~='string' or #operationId<1 or #operationId>64 then return nil,'invalid_operation_id' end
        if type(amount)~='number' or math.abs(amount)>1000 then return nil,'invalid_transfer' end
        local report=copy(baseline); report.pools=copy(pools); report.phase=nil
        local observed,reason=WeaponCharacterAmmunition.Observe(baseline,report,limits)
        if not observed then return nil,reason end
        if observed.changed then return nil,'checkpoint_required' end
        local expected
        expected,reason=WeaponCharacterAmmunition.Transfer(baseline,ammunitionId,amount,limits)
        if not expected then return nil,reason end
        sequence=sequence+1
        pending={id=sequence,kind='transfer',report=report,expected=expected,
            ammunitionId=ammunitionId,amount=amount,operationId=operationId}
        pending.report.transfer={ammunitionId=ammunitionId,amount=amount,operationId=operationId}
        return copy(pending)
    end
    function C.PrepareCleanup(currentPed)
        if phase~='sealed' or pending then return nil,'cleanup_requires_seal' end
        if currentPed~=ped then return nil,'ped_changed' end
        sequence=sequence+1
        local report=copy(baseline); report.phase=nil
        report.cleanupComplete=true; report.remainingCopies=0
        pending={id=sequence,kind='cleanup',report=report,
            expected={revision=baseline.revision,pools=copy(baseline.pools)}}
        return copy(pending)
    end
    function C.Accept(id,result,currentPed)
        if currentPed~=ped then phase='suspended'; pending=nil; return nil,'ped_changed' end
        if not pending or pending.id~=id then return nil,'stale_reply' end
        local expected=copy(baseline); expected.revision=pending.expected.revision
        local value=type(result)=='table' and result.ok==true and result.value
        local nextPhase=pending.kind=='cleanup' and 'released' or (pending.kind=='seal' and 'sealed'
            or (pending.kind=='transfer' and 'restoring' or 'active'))
        local valid=type(value)=='table' and same(expected,value) and value.phase==nextPhase
        local pools=valid and WeaponCharacterAmmunition.Validate(value.pools,limits)
        for ammo,count in pairs(pending.expected.pools) do
            valid=valid and pools and value.pools[ammo]~=nil and pools[ammo]==count
        end
        pending=nil
        if not valid then phase='frozen'; return nil,'invalid_ack' end
        baseline=copy(value); phase=nextPhase; return copy(baseline)
    end
    function C.Close()
        baseline,limits,ped,pending,phase=nil,nil,nil,nil,'closed'
        -- Sequence deliberately survives reset so old replies cannot match new work.
    end
    function C.Status() return {phase=phase,pending=pending~=nil,pendingKind=pending and pending.kind,
        ped=ped,baseline=copy(baseline)} end
    return C
end
