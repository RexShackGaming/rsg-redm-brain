-- Dormant composition only. No instance, events, threads, exports or grants.
-- The future lifecycle owner must supply native/transport/input/dual readiness
-- adapters and explicitly create/tick this host; production activation pending.
WeaponCharacterAmmoHost={}
function WeaponCharacterAmmoHost.New(adapters)
    if type(adapters)~='table' then return nil,'invalid_host_adapters' end
    for _,name in ipairs({'ped','block','hash','read','write','creation','send','now','wait','caller'}) do
        if type(adapters[name])~='function' then return nil,'missing_host_adapter_'..name end
    end
    local context=WeaponCharacterAmmoWorldContext
    if type(context)~='table' or type(context.Identity)~='function' or type(context.Read)~='function' then
        return nil,'host_context_unavailable'
    end
    local ok,registry,reason=pcall(WeaponCharacterAmmoPolicy.Build,WeaponDefinitionCatalog)
    if not ok or not registry then return nil,ok and reason or 'host_policy_unavailable' end
    local api={}; for key,value in pairs(adapters) do api[key]=value end
    -- Caller-provided identity/readiness/enabled/registry hints are NOT authority.
    api.enabled=function()
        return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
    end
    api.identity=function() return context.Identity() end
    api.ready=function()
        local result=context.Read()
        return type(result)=='table' and result.ok==true and type(result.value)=='table'
            and result.value.ped==api.ped()
    end
    local T={}
    api.deathSnapshot=function() return T.ReadDeathObservation() end
    local receiver=WeaponCharacterAmmoReceiver.New(api,registry)
    local checkpoint=WeaponCharacterAmmoCheckpoint.New(receiver,api)
    -- Read-only evidence for a future death drain. No epoch/ticket, send, restore
    -- or cleanup authorization is derived from this snapshot.
    function T.ReadDeathObservation()
        if not api.enabled() then return nil,'native_host_disabled' end
        if type(context.ReadDeath)~='function' then return nil,'death_context_unavailable' end
        local called,before=pcall(context.ReadDeath)
        if not called or type(before)~='table' or before.ok~=true or type(before.value)~='table' then
            return nil,'death_context_not_ready'
        end
        local value=before.value
        if value.ped~=api.ped() then return nil,'death_ped_changed' end
        local native,why=WeaponCharacterAmmoNative.New(registry.names,registry.limits,api)
        if not native then return nil,why end
        local pools
        pools,why=native.Read(value.ped,true)
        if not pools then return nil,why end
        local ok,after=pcall(context.ReadDeath)
        local checked=ok and type(after)=='table' and after.ok==true and after.value
        if type(checked)~='table' or checked.characterId~=value.characterId
            or checked.sessionId~=value.sessionId or checked.ped~=value.ped
            or checked.medicalRevision~=value.medicalRevision or api.ped()~=value.ped then
            return nil,'death_context_changed'
        end
        local wear
        if Config.NativeAlphaLifecycleWearEnabled==true then
            local owner=WeaponCharacterAmmoActiveOwner
            local ok,result=pcall(function() return owner and owner.DeathWear(value) end)
            if not ok or not result then return nil,'death_wear_readback_unavailable' end
            wear=result
        end
        return {characterId=value.characterId,sessionId=value.sessionId,ped=value.ped,
            medicalRevision=value.medicalRevision,pools=pools,lifeState='dead',deathWear=wear}
    end
    function T.Receive(bundle,serverOrigin)
        if not api.enabled() then return nil,'native_host_disabled' end
        return receiver.Receive(bundle,serverOrigin)
    end
    function T.Tick()
        if not api.enabled() then return receiver.Suspend('native_host_disabled') end
        return receiver.Tick()
    end
    function T.Checkpoint(value) return checkpoint.Run(value) end
    -- Explicit orderly-release operations, also used by the release coordinator.
    function T.Finalize() return receiver.Finalize() end
    function T.Transfer(id,amount,operationId) return receiver.Transfer(id,amount,operationId) end
    function T.FinalizeDeath() return receiver.FinalizeDeath() end
    function T.Cleanup() return receiver.Cleanup() end
    function T.RecoverDeath() return receiver.RecoverDeath() end
    function T.Quiesce() return receiver.Quiesce() end
    function T.PrepareEquipmentRelease(...) return receiver.PrepareEquipmentRelease(...) end
    function T.Suspend(reason) return receiver.Suspend(reason) end
    function T.Status() return receiver.Status() end
    return T
end
