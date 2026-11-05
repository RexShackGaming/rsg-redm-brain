-- Orderly alive-world teardown only. Host drives Step; no threads/exports/routes.
-- Failure retains ownership and blocks input. Never treats timeout as release.
WeaponCharacterAmmoRelease={}
function WeaponCharacterAmmoRelease.New(receiver,api)
    local phase,epoch,deadline,reason='idle',nil,nil,nil
    local finalizing,cleaning=false,false
    local T={}
    local function fail(code)
        phase,reason='failed',code
        receiver.Suspend(code)
        return nil,code
    end
    function T.Request(timeoutMs)
        if phase=='waiting' then return true,'release_pending' end
        if phase=='failed' then return nil,reason end
        if type(timeoutMs)~='number' or timeoutMs%1~=0 or timeoutMs<1 or timeoutMs>15000 then
            return nil,'invalid_release_timeout'
        end
        local status=receiver.Status()
        if status.phase=='closed' and not status.receiving then phase='released'; return true,'already_released' end
        if status.receiving then return nil,'receiver_busy' end
        if status.phase~='active' and status.phase~='restoring' then return nil,'release_requires_current_session' end
        epoch=status.epoch
        if type(epoch)~='string' or epoch=='' then return nil,'release_identity_missing' end
        deadline=api.now()+timeoutMs; phase='waiting'; finalizing,cleaning=false,false
        api.block(true)
        return true
    end
    function T.Step()
        if phase=='released' then return true,'released' end
        if phase=='failed' then api.block(true); return nil,reason end
        if phase~='waiting' then return nil,'release_not_requested' end
        local before=receiver.Status()
        if before.phase~='closed' and before.epoch~=epoch then return fail('release_owner_changed') end
        if api.now()>=deadline then return fail('release_timeout') end
        -- Seal before the first tick can issue an ordinary observation. Any
        -- pending save still settles under Finalize's closing barrier.
        if before.phase=='active' and not finalizing then
            finalizing=true
            local ok,result=pcall(receiver.Finalize)
            if not ok or not result then return fail('release_seal_failed') end
        end
        local called=pcall(receiver.Tick)
        api.block(true)
        if not called then return fail('release_tick_failed') end
        local status=receiver.Status()
        if status.phase=='closed' then phase='released'; api.block(false); return true,'released' end
        if status.epoch~=epoch then return fail('release_owner_changed') end
        if status.phase=='frozen' or status.phase=='suspended' then return fail('release_world_or_session_lost') end
        if status.phase=='active' and not finalizing then
            finalizing=true
            local ok,result=pcall(receiver.Finalize)
            if not ok or not result then return fail('release_seal_failed') end
        elseif status.phase=='sealed' and before.phase=='sealed' and not cleaning then
            cleaning=true
            local ok,result=pcall(receiver.Cleanup)
            if not ok or not result then return fail('release_cleanup_failed') end
        end
        return nil,'release_pending'
    end
    function T.Status() return {phase=phase,epoch=epoch,reason=reason} end
    return T
end
