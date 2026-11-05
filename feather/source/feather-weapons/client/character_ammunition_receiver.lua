-- Dormant ingress factory: host captures CFX event origin before any yield.
-- No routes, threads, policy defaults or automatic creation registrations.
WeaponCharacterAmmoReceiver={}
function WeaponCharacterAmmoReceiver.New(api,registry)
    local owner=WeaponCharacterAmmoOwner.New(api,registry)
    local receiving,fault,quiescing=false,false,false
    local retiring
    local T={}
    -- Trusted lifecycle only. No automatic reopening of a retiring owner.
    local function quiesce(kind)
        quiescing=true
        local state=owner.Status()
        local baseline=state.session and state.session.ammo and state.session.ammo.baseline
        if type(baseline)=='table' and type(baseline.characterId)=='string'
            and type(baseline.sessionId)=='string' and type(baseline.epoch)=='string' then
            retiring={characterId=baseline.characterId,sessionId=baseline.sessionId,
                epoch=baseline.epoch,kind=kind}
        end
    end
    function T.Quiesce() quiesce('logout') end
    local function canResume(bundle)
        if not retiring or owner.Status().phase~='closed' or type(bundle)~='table'
            or type(bundle.runtime)~='table' or type(api.identity)~='function'
            or type(api.ready)~='function' then return false end
        local value=bundle.runtime
        local current=api.identity()
        if type(current)~='table' or api.ready()~=true or value.characterId~=current.characterId
            or value.sessionId~=current.sessionId or type(value.epoch)~='string'
            or value.epoch=='' or value.epoch==retiring.epoch then return false end
        -- Logout can reopen only a new independently current Core session.
        -- Same-session reopening is reserved for a completed death release;
        -- server-origin + Owner.Receive still validate the full bundle/epoch.
        local transition=bundle.equipmentTransition
        local equipment=retiring.kind=='equipment' and type(transition)=='table'
            and transition.ticket==retiring.ticket and transition.oldEpoch==retiring.epoch
        return value.sessionId~=retiring.sessionId or equipment or retiring.kind=='death'
            and value.characterId==retiring.characterId
    end
    function T.Suspend(reason)
        fault=type(reason)=='string' and reason or 'receiver_failed'
        api.block(true)
        return nil,fault
    end
    function T.Receive(bundle,serverOrigin)
        if serverOrigin~=true then return nil,'loadout_requires_server_origin' end
        if fault then return nil,'receiver_frozen' end
        if receiving then return nil,'receiver_busy' end
        if quiescing then
            local checked,resumable=pcall(canResume,bundle)
            if not checked or not resumable then return nil,'receiver_retiring' end
        end
        receiving=true -- reserve before native creation may yield
        local ok,result,reason=pcall(owner.Receive,bundle)
        receiving=false
        if not ok then return T.Suspend('receiver_failed') end
        if result then quiescing,retiring=false,nil end
        return result,reason
    end
    function T.Tick()
        if fault then return nil,'receiver_frozen' end
        if receiving then return nil,'receiver_busy' end
        return owner.Tick()
    end
    function T.Finalize()
        if fault or receiving then return nil,fault and 'receiver_frozen' or 'receiver_busy' end
        return owner.Finalize()
    end
    function T.Transfer(id,amount,operationId)
        if fault or receiving or quiescing then return nil,'receiver_not_active' end
        return owner.Transfer(id,amount,operationId)
    end
    function T.PrepareEquipmentRelease(identity,ticket)
        if fault or receiving or quiescing or type(ticket)~='string' or ticket=='' or #ticket>128 then
            return nil,'equipment_release_not_ready'
        end
        local state=owner.Status()
        local baseline=state.session and state.session.ammo and state.session.ammo.baseline
        if state.phase~='active' or type(identity)~='table' or type(baseline)~='table' then return nil,'equipment_release_not_active' end
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if identity[key]~=baseline[key] then return nil,'equipment_release_identity_changed' end
        end
        quiesce('equipment'); retiring.ticket=ticket
        return true
    end
    function T.FinalizeDeath()
        if fault or receiving then return nil,fault and 'receiver_frozen' or 'receiver_busy' end
        local result,why=owner.FinalizeDeath()
        local state=owner.Status()
        if state.session and state.session.ammo and state.session.ammo.deathClosing then quiesce('death') end
        return result,why
    end
    function T.Cleanup()
        if fault or receiving then return nil,fault and 'receiver_frozen' or 'receiver_busy' end
        return owner.Cleanup()
    end
    function T.RecoverDeath()
        if fault or receiving then return nil,fault and 'receiver_frozen' or 'receiver_busy' end
        return owner.RecoverDeath()
    end
    function T.Status()
        local value=owner.Status()
        if fault then value.phase='frozen'; value.reason=fault end
        value.receiving=receiving
        value.quiescing=quiescing
        return value
    end
    return T
end
