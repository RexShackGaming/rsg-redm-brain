-- Dormant orchestration. No public/net Open, enrollment or automatic Start.
-- Production Start binds only the canonical catalog and validated policy.
WeaponCharacterAmmoDispatcher=WeaponCharacterAmmoDispatch.New({
    enabled=function() return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true end,
    service=WeaponCharacterAmmoService,
    identity=function(source)
        local result=CoreAdapter.ResolveSession(source)
        return result and result.ok and result.value or nil
    end,
    dispatch=function(source,bundle)
        if WeaponNativeEquipmentBindings then WeaponNativeEquipmentBindings.Attach(source,bundle) end
        TriggerClientEvent('feather-weapons:client:character-ammo-loadout',source,bundle)
    end,
    timeout=function(callback) SetTimeout(15000,callback) end,
})
local start=WeaponCharacterAmmoDispatcher.Start
WeaponCharacterAmmoDispatcher.RecoveryContract=1
local function copy(value)
    if type(value)~='table' then return value end
    local out={}; for key,item in pairs(value) do out[key]=copy(item) end; return out
end
function WeaponCharacterAmmoDispatcher.Start(source)
    if WeaponNativeEquipmentBindings and WeaponNativeEquipmentBindings.IsStopping
        and WeaponNativeEquipmentBindings.IsStopping(source)==true then
        return {ok=false,error={code='native_shutdown_prepared',message='native_shutdown_prepared'}}
    end
    if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
        return {ok=false,error={code='dispatch_disabled',message='dispatch_disabled'}}
    end
    -- Snapshot before any Inventory yield; callers cannot substitute limits or
    -- mutate the shared definition tables while a transaction is in flight.
    local catalog=copy(WeaponDefinitionCatalog)
    local ok,registry,reason=pcall(WeaponCharacterAmmoPolicy.Build,catalog)
    if not ok or not registry then
        local code=ok and reason or 'approved_policy_unavailable'
        return {ok=false,error={code=code,message=code}}
    end
    return start(source,catalog,registry.limits)
end
AddEventHandler('playerDropped',function() WeaponCharacterAmmoDispatcher.Forget(source) end)
AddEventHandler('core.session.left.v1',function(session)
    if type(session)=='table' and session.source and session.sessionId then
        WeaponCharacterAmmoDispatcher.Forget(session.source,session.sessionId)
    end
end)

-- Trusted activation composition only. No client event or automatic startup
-- calls Ready yet; native-only provider and client hosting must be ready first.
WeaponCharacterAmmoActivationOwner=WeaponCharacterAmmoActivation.New({
    enabled=function()
        return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
            and WeaponCharacterAmmoInventoryProvider.Status()=='ready'
    end,
    identity=function(source)
        local result=CoreAdapter.ResolveSession(source)
        local identity=type(result)=='table' and result.ok==true and result.value or nil
        if Config.NativeAlphaRuntime~=true or type(identity)~='table'
            or not WeaponNativeEnrollment.Allows(Config,identity.characterId) then return nil end
        if type(WeaponCharacterAmmoService.ReconcileSession)=='function' then
            local reconciled=WeaponCharacterAmmoService.ReconcileSession(source,identity)
            if not reconciled or not reconciled.ok then return nil end
            for _,old in ipairs(reconciled.value.retired) do
                WeaponCharacterAmmoDispatcher.Forget(old.source,old.sessionId)
                if WeaponNativeEquipmentBindings and WeaponNativeEquipmentBindings.RetireSession then
                    WeaponNativeEquipmentBindings.RetireSession(old.source,old.sessionId)
                end
            end
        end
        if WeaponNativeEquipmentBindings and WeaponNativeEquipmentBindings.ReconcileSession then
            local result=WeaponNativeEquipmentBindings.ReconcileSession(source,identity)
            if not result or not result.ok then return nil end
        end
        return identity
    end,
    dispatcher=WeaponCharacterAmmoDispatcher,
})
AddEventHandler('playerDropped',function() WeaponCharacterAmmoActivationOwner.Cancel(source) end)
AddEventHandler('core.session.left.v1',function(session)
    if type(session)=='table' and session.source and session.sessionId then
        WeaponCharacterAmmoActivationOwner.Cancel(session.source,session.sessionId)
    end
end)
