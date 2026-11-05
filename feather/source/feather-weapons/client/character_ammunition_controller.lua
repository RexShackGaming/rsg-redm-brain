-- Dormant orchestration. The owner supplies world readiness, transport and lifecycle ticks.
-- No threads/routes, weapon grants, clip writes or ammunition selection here.
WeaponCharacterAmmoController={}
function WeaponCharacterAmmoController.New(api,pickupAck)
    local C=WeaponCharacterAmmoClient.New()
    local adapter,phase,closing=nil,'closed',false
    local deathClosing=false
    local failureReason
    local T={}
    local function fail(reason) failureReason=reason; phase='frozen'; return nil,reason end
    function T.Begin(value,names,limits)
        if phase~='closed' then return nil,'not_closed' end
        if api.ready()~=true then return nil,'world_not_ready' end
        local ped=api.ped()
        local reason
        adapter,reason=WeaponCharacterAmmoNative.New(names,limits,api)
        if not adapter then return nil,reason end
        local baseline
        baseline,reason=C.Begin(value,limits,ped)
        if not baseline then adapter=nil; return nil,reason end
        phase='restoring'
        -- Only this explicit baseline transition writes ammo, never Tick/ack.
        local restored
        restored,reason=adapter.Restore(baseline,ped,true)
        if not restored then return fail(reason) end
        return T.Tick()
    end
    local function send(request,ped)
        if request.unchanged then return true,'unchanged' end
        local ok=pcall(api.send,request.kind,request.id,request.report,function(result)
            -- Close/new Begin invalidates old work; request sequence survives Close.
            if phase=='closed' then return end
            local accepted,reason=C.Accept(request.id,result,api.ped())
            if not accepted then
                if reason=='stale_reply' then return end
                failureReason=type(result)=='table' and result.error and result.error.code or reason
                phase=reason=='ped_changed' and 'suspended' or 'frozen'; return
            end
            phase=accepted.phase
            if request.kind=='pickup' then
                if closing or api.ready()~=true or type(pickupAck)~='function' then return fail('pickup_owner_ack_unavailable') end
                local ok,value=pcall(pickupAck,accepted)
                if not ok or value~=true then return fail('pickup_owner_rebind_unconfirmed') end
            end
            if request.kind=='transfer' then
                if closing or api.ready()~=true then return fail('transfer_world_changed') end
                local restored,why=adapter.Restore(accepted,api.ped(),true)
                if not restored then return fail(why) end
                -- Exact committed baseline is the only economic native write.
                -- Keep firing blocked until a separate restore ack is accepted.
                T.Tick()
            end
        end)
        if not ok then return fail('transport_failed') end
        return true
    end
    function T.Tick()
        if phase~='active' and phase~='restoring' then return nil,'not_ready' end
        local status=C.Status()
        if api.ped()~=status.ped then phase='suspended'; C.Close(); return nil,'ped_changed' end
        if not deathClosing and api.ready()~=true then return nil,'world_not_ready' end
        if status.pending then return nil,'in_flight' end
        local pools,reason,deathWear
        if deathClosing then
            local ok,snapshot,why=pcall(api.deathSnapshot)
            local baseline=status.baseline
            if not ok or type(snapshot)~='table' or snapshot.ped~=status.ped
                or snapshot.characterId~=baseline.characterId or snapshot.sessionId~=baseline.sessionId
                or snapshot.lifeState~='dead' then return fail(why or 'death_snapshot_unavailable') end
            pools=snapshot.pools
            deathWear=snapshot.deathWear
        else pools,reason=adapter.Read(status.ped,true) end
        if not pools then return fail(reason) end
        local request
        if not closing and Config and Config.DevMode==true and type(GetConvarInt)=='function'
            and GetConvarInt('feather_native_throwable_pickup',0)==1
            and status.baseline.pools.ammo_tomahawk_regular==0 and pools.ammo_tomahawk_regular==1 then
            request,reason=C.PrepareNativePickup(status.ped,pools,true)
            if request and type(api.block)=='function' then api.block(true) end
        elseif closing then request,reason=C.PrepareFinal(status.ped,pools,true)
        else request,reason=C.Prepare(status.ped,pools,true) end
        if not request then return fail(reason) end
        if deathClosing and Config and Config.NativeAlphaLifecycleWearEnabled==true then
            if not deathWear then return fail('death_wear_readback_required') end
            request.report.deathWear=deathWear
        end
        return send(request,status.ped)
    end
    function T.Finalize()
        if phase~='active' then return nil,'not_active' end
        closing=true
        -- If a save is pending, the owner keeps ticking; the next complete sample
        -- includes any additional shots and asks the server to seal atomically.
        return T.Tick()
    end
    function T.Transfer(ammunitionId,amount,operationId)
        if phase~='active' or closing then return nil,'transfer_not_active' end
        if api.ready()~=true or type(api.block)~='function' then return nil,'world_not_ready' end
        local pools,why=adapter.Read(api.ped(),true)
        if not pools then return fail(why) end
        local request
        request,why=C.PrepareTransfer(api.ped(),pools,true,ammunitionId,amount,operationId)
        if not request then return nil,why end
        api.block(true)
        return send(request,api.ped())
    end
    function T.FinalizeDeath()
        if phase~='active' or type(api.deathSnapshot)~='function' then return nil,'death_seal_not_ready' end
        if closing and not deathClosing then return nil,'orderly_seal_in_progress' end
        closing,deathClosing=true,true
        return T.Tick()
    end
    function T.Close()
        C.Close(); adapter=nil; phase='closed'; closing=false; deathClosing=false; failureReason=nil
    end
    function T.AllowDeathCleanup()
        local state=C.Status()
        if not deathClosing or phase~='sealed' or state.ped~=api.ped() or api.ready()~=true then
            return nil,'death_cleanup_not_ready'
        end
        deathClosing=false
        return true
    end
    function T.ConfirmCleanup()
        local request,reason=C.PrepareCleanup(api.ped())
        if not request then return nil,reason end
        return send(request,api.ped())
    end
    function T.Status()
        local status=C.Status(); status.phase=phase; status.closing=closing; status.deathClosing=deathClosing; status.reason=failureReason; return status
    end
    return T
end
