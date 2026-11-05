-- Dormant per-frame driver. No threads/events/exports/grants are registered here.
-- Identity/native death are checked every frame; ordinary pool samples are 250ms.
WeaponCharacterAmmoDriver={}
function WeaponCharacterAmmoDriver.New(host,api)
    if type(host)~='table' or type(api)~='table' then return nil,'invalid_driver' end
    for _,key in ipairs({'ped','identity','life','now','block'}) do
        if type(api[key])~='function' then return nil,'missing_driver_adapter_'..key end
    end
    for _,key in ipairs({'Status','Receive','Tick','Suspend','FinalizeDeath','RecoverDeath'}) do
        if type(host[key])~='function' then return nil,'missing_driver_host_'..key end
    end
    local identity,ped,lifecycle,lastSample,lastLife,fault,receiving=nil,nil,nil,nil,nil,nil,false
    local T={}
    local stepping=false
    local deathRecovery
    local function recordRecovery()
        if not lifecycle or not lifecycle.Status().recovering or not identity then return end
        deathRecovery={characterId=identity.characterId,sessionId=identity.sessionId,
            epoch=identity.epoch,ped=ped}
    end
    local function fail(why)
        fault=why
        -- Preserve the latch even if an adapter throws while shutting down.
        pcall(api.block,true); pcall(host.Suspend,why)
        return nil,why
    end
    local function current()
        local value=api.identity()
        return identity and type(value)=='table' and value.characterId==identity.characterId
            and value.sessionId==identity.sessionId and api.ped()==ped
    end
    function T.Receive(bundle,origin)
        if stepping then return nil,'driver_step_in_flight' end
        if receiving then return nil,'driver_receiving' end
        if fault then return nil,fault end
        if host.Status().phase~='closed' then return nil,'driver_release_required' end
        if origin~=true or type(bundle)~='table' or type(bundle.runtime)~='table' then
            return nil,'driver_server_bundle_required'
        end
        local value=bundle.runtime
        identity={characterId=value.characterId,sessionId=value.sessionId,epoch=value.epoch}; ped=api.ped()
        receiving=true
        local called,opened,why=pcall(host.Receive,bundle,origin)
        receiving=false
        if not called then return fail('driver_receive_failed') end
        if not opened then
            if host.Status().phase=='closed' then identity,ped=nil,nil end
            return nil,why
        end
        local valid,live=pcall(current)
        if not valid or live~=true then return fail('driver_identity_or_ped_changed') end
        lifecycle=assert(WeaponCharacterAmmoLifecycle.New(host,{current=current,life=api.life,block=api.block}))
        lastSample,lastLife=nil,nil
        return true
    end
    local function step()
        if fault then api.block(true); return nil,fault end
        if receiving then api.block(true); return nil,'driver_receiving' end
        local state=host.Status()
        if state.phase=='closed' then
            recordRecovery()
            identity,ped,lifecycle=nil,nil,nil; return true,'closed'
        end
        -- Creation may freeze before a lifecycle can bind. Preserve that
        -- original failure instead of replacing it with driver_not_bound.
        if state.phase=='frozen' or state.phase=='suspended' then
            return fail(state.reason or 'driver_host_failed')
        end
        if not lifecycle then return fail('driver_not_bound') end
        local valid,live=pcall(current)
        if not valid or live~=true then return fail('driver_identity_or_ped_changed') end
        local lifeOk,life=pcall(api.life)
        if not lifeOk or (life~='alive' and life~='dead' and life~='not_ready') then return fail('driver_invalid_life') end
        -- Never leave firing enabled while death/context settlement is pending.
        if life~='alive' then api.block(true) end
        local now=api.now()
        if type(now)~='number' or now~=now or now==math.huge or now==-math.huge then return fail('driver_invalid_clock') end
        local ammo=state.session and state.session.ammo
        local immediate=life~=lastLife or state.phase~='active'
            or (ammo and (ammo.closing or ammo.phase=='restoring' or ammo.pendingKind=='transfer'))
        if not immediate and lastSample and now>=lastSample and now-lastSample<250 then return true,'sample_not_due' end
        lastSample,lastLife=now,life
        local result,why=lifecycle.Step()
        -- A transport/native callback may yield across an identity boundary.
        local stillValid,stillCurrent=pcall(current)
        if not stillValid or stillCurrent~=true then return fail('driver_identity_or_ped_changed') end
        local after=host.Status()
        if after.phase=='frozen' or after.phase=='suspended' then
            return fail(after.reason or 'driver_host_failed')
        end
        local failure=lifecycle.Status().fault
        if failure then return fail(failure) end
        if after.phase=='closed' then recordRecovery() end
        return result,why
    end
    function T.Step()
        if stepping then pcall(api.block,true); return nil,'driver_step_in_flight' end
        stepping=true
        local called,result,why=pcall(step)
        stepping=false
        if not called then return fail('driver_step_failed') end
        return result,why
    end
    function T.Status()
        local recovery
        if deathRecovery then
            recovery={}; for key,value in pairs(deathRecovery) do recovery[key]=value end
        end
        return {host=host.Status(),fault=fault,lastSample=lastSample,receiving=receiving,
            stepping=stepping,deathRecovery=recovery}
    end
    return T
end
