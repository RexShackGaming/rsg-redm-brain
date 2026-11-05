-- Factory only: trusted host supplies Core identity, readiness, local registry,
-- transport/native APIs and ticks. No event registration or automatic grants.
WeaponCharacterAmmoOwner={}
function WeaponCharacterAmmoOwner.New(api,registry)
    local session,identity,ped=nil,nil,nil
    local phase,reason='closed',nil
    local deathClosing=false
    local seen,order={},{} -- bounded replay defence; server epochs remain authoritative
    local T={}
    local function current()
        if phase=='frozen' then return false end
        local value=api.identity()
        return identity and type(value)=='table' and value.characterId==identity.characterId
            and value.sessionId==identity.sessionId and api.ped()==ped
    end
    local function frozen(why)
        phase,reason='frozen',why; api.block(true); return nil,why
    end
    local function matchingHints(hints,expected)
        if hints==nil then return true end
        if type(hints)~='table' then return false end
        for key,value in pairs(expected) do if hints[key]~=value then return false end end
        for key in pairs(hints) do if expected[key]==nil then return false end end
        return true
    end
    function T.Receive(bundle)
        if api.enabled()~=true then return nil,'native_owner_disabled' end
        if phase~='closed' then return nil,'native_owner_release_required' end
        if type(bundle)~='table' or type(bundle.runtime)~='table' then return nil,'invalid_owner_bundle' end
        local value=bundle.runtime
        local context=api.identity()
        if type(context)~='table' or value.characterId~=context.characterId or value.sessionId~=context.sessionId then
            return nil,'owner_identity_mismatch'
        end
        if type(value.epoch)~='string' or value.epoch=='' or seen[value.epoch] then return nil,'owner_epoch_replayed' end
        if not matchingHints(bundle.names,registry.names) or not matchingHints(bundle.limits,registry.limits) then
            return nil,'owner_registry_mismatch'
        end
        if api.ready()~=true then return nil,'world_not_ready' end
        identity={characterId=value.characterId,sessionId=value.sessionId,epoch=value.epoch}
        ped=api.ped(); phase='receiving'
        local guarded={}; for key,entry in pairs(api) do guarded[key]=entry end
        guarded.ready=function() return current() and api.ready()==true end
        guarded.creation=function(target,creationIdentity)
            local adapter=api.creation(target,creationIdentity)
            local original=adapter.current
            adapter.current=function(check) return current() and api.ready()==true and original(check)==true end
            return adapter
        end
        session=WeaponCharacterAmmoSession.New(guarded,registry)
        local ok,started,why=pcall(session.Begin,bundle)
        if not ok then return frozen('owner_creation_failed') end
        if not started then
            if session.Status().phase=='closed' then
                session,identity,ped=nil,nil,nil; phase='closed'; return nil,why
            end
            return frozen(why)
        end
        seen[value.epoch]=true; order[#order+1]=value.epoch
        if #order>256 then seen[table.remove(order,1)]=nil end
        phase=session.Status().phase
        return true
    end
    function T.Tick()
        if phase=='closed' or phase=='frozen' then return nil,reason or 'native_owner_not_ready' end
        if api.enabled()~=true then return frozen('native_owner_disabled') end
        if not current() then return frozen('owner_identity_or_ped_changed') end
        if not deathClosing and api.ready()~=true then return frozen('owner_world_lost') end
        local result,why=session.Tick()
        local status=session.Status(); phase=status.phase
        if phase=='frozen' or phase=='suspended' then return frozen(why or phase) end
        if phase=='closed' then session,identity,ped=nil,nil,nil; api.block(false) end
        return result,why
    end
    function T.Finalize()
        if not session or phase=='frozen' then return nil,'native_owner_not_ready' end
        if api.enabled()~=true then return frozen('native_owner_disabled') end
        if not current() or api.ready()~=true then return frozen('owner_world_lost') end
        return session.Finalize()
    end
    function T.Transfer(id,amount,operationId)
        if not session or phase~='active' or deathClosing then return nil,'native_owner_not_active' end
        if api.enabled()~=true then return frozen('native_owner_disabled') end
        if not current() or api.ready()~=true then return frozen('owner_world_lost') end
        return session.Transfer(id,amount,operationId)
    end
    function T.FinalizeDeath()
        if not session or phase~='active' or type(api.deathSnapshot)~='function' then
            return nil,'death_owner_not_ready'
        end
        if api.enabled()~=true or not current() then return frozen('owner_world_lost') end
        local ammo=session.Status().ammo
        if ammo.closing and not ammo.deathClosing then return nil,'orderly_seal_in_progress' end
        local ok,snapshot=pcall(api.deathSnapshot)
        if not ok or type(snapshot)~='table' or snapshot.characterId~=identity.characterId
            or snapshot.sessionId~=identity.sessionId or snapshot.ped~=ped or snapshot.lifeState~='dead' then
            return nil,'death_context_not_ready'
        end
        deathClosing=true; api.block(true)
        return session.FinalizeDeath()
    end
    function T.Cleanup()
        if deathClosing then return nil,'death_recovery_required' end
        if not session or phase=='frozen' then return nil,'native_owner_not_ready' end
        if api.enabled()~=true then return frozen('native_owner_disabled') end
        if not current() or api.ready()~=true then return frozen('owner_world_lost') end
        return session.Cleanup()
    end
    function T.RecoverDeath()
        if not session or not deathClosing or phase~='sealed' then return nil,'death_recovery_not_sealed' end
        if api.enabled()~=true or not current() then return frozen('owner_world_lost') end
        if api.ready()~=true then return nil,'death_recovery_not_alive' end
        local result,why=session.RecoverDeath()
        if result then deathClosing=false end
        return result,why
    end
    function T.Status()
        return {phase=phase,reason=reason,session=session and session.Status() or nil,
            epoch=identity and identity.epoch or nil}
    end
    return T
end
