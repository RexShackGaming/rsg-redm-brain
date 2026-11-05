-- Dormant lifecycle ordering. No registrations, threads, grants or activation.
-- life() is a local trusted native-life adapter, not a network-supplied hint.
WeaponCharacterAmmoLifecycle={}
function WeaponCharacterAmmoLifecycle.New(host,api)
    if type(host)~='table' or type(api)~='table' or type(api.life)~='function'
        or type(api.block)~='function' or type(api.current)~='function' then
        return nil,'invalid_lifecycle_adapters'
    end
    for _,name in ipairs({'Status','Tick','FinalizeDeath','RecoverDeath','Suspend'}) do
        if type(host[name])~='function' then return nil,'missing_lifecycle_host_'..name end
    end
    local deathSeen,recovering,fault=false,false,nil
    local T={}
    local function fail(why)
        fault=why; api.block(true); host.Suspend(why); return nil,why
    end
    function T.Step()
        if fault then return nil,fault end
        local status=host.Status()
        if status.phase=='closed' then return true,'closed' end
        local currentOk,current=pcall(api.current)
        if not currentOk or current~=true then return fail('lifecycle_identity_or_ped_changed') end
        if status.phase=='frozen' or status.phase=='suspended' then
            return fail(status.reason or 'lifecycle_host_failed')
        end
        local ok,life=pcall(api.life)
        if not ok or (life~='alive' and life~='dead' and life~='not_ready') then
            return fail('invalid_lifecycle_life')
        end
        if life=='dead' then deathSeen=true; api.block(true) end
        if deathSeen and not recovering then
            local ammo=status.session and status.session.ammo
            if status.phase=='active' and not (ammo and ammo.deathClosing) then
                local started,why=host.FinalizeDeath()
                if not started and why~='in_flight' then
                    -- Medical's authoritative dead context may trail native death.
                    -- Never run ordinary Tick while waiting for that context.
                    if why=='death_context_not_ready' then return nil,why end
                    return fail(why or 'death_finalize_failed')
                end
            elseif status.phase~='sealed' and not (ammo and ammo.deathClosing) then
                return fail('death_during_unsealed_transition')
            end
            status=host.Status()
            if status.phase=='sealed' then
                if life~='alive' then return nil,'death_recovery_waiting' end
                local result,why=host.RecoverDeath()
                if not result then
                    if why=='death_recovery_not_alive' then return nil,why end
                    return fail(why or 'death_recovery_failed')
                end
                recovering=true
            end
        end
        return host.Tick()
    end
    function T.Status() return {deathSeen=deathSeen,recovering=recovering,fault=fault} end
    return T
end
