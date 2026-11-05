-- Explicit owning composition. Construction is inert; Start remains opt-in.
-- The same lease owns zero-ammo creation, dual setup and sealed cleanup.
WeaponCharacterAmmoNativeOwner={}
function WeaponCharacterAmmoNativeOwner.New(dependencies)
    local d=dependencies or {
        context=WeaponCharacterAmmoWorldContext.Read,
        ped=PlayerPedId,
        dual=WeaponCharacterAmmoDualNative.New,
        creation=WeaponCharacterAmmoCreationNative.Scoped,
        knife=WeaponNativeKnifeOwner and WeaponNativeKnifeOwner.Scoped,
        throwable=WeaponNativeThrowableAdapter and WeaponNativeThrowableAdapter.Scoped,
        utility=WeaponNativeUtilityAdapter and WeaponNativeUtilityAdapter.Scoped,
        bootstrap=WeaponCharacterAmmoClientBindings.Bootstrap,
    }
    for _,name in ipairs({'context','ped','dual','creation','bootstrap'}) do
        if type(d[name])~='function' then return nil,'missing_native_owner_'..name end
    end
    local bootstrap,lease,phase,reason=nil,nil,'dormant',nil
    local function enabled()
        return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
    end
    local function current(expected,ped)
        if not enabled() or d.ped()~=ped then return false end
        local called,result=pcall(d.context)
        local value=called and type(result)=='table' and result.ok==true and result.value
        return type(value)=='table' and value.characterId==expected.characterId
            and value.sessionId==expected.sessionId and value.ped==ped
    end
    local function create(ped,identity)
        if type(identity)~='table' or type(identity.epoch)~='string' or identity.epoch==''
            or not current(identity,ped) then return nil,'native_owner_world_changed' end
        if lease and not lease.cleaned then return nil,'native_owner_cleanup_required' end
        local expected={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
        local owned={identity=expected,ped=ped,cleaned=false}
        -- Reserve before any native factory can yield. Failure retains the
        -- reservation rather than claiming partial setup has been removed.
        lease=owned
        local dual
        local adapter,reason=d.creation(ped,expected,function()
            if not current(expected,ped) then return false end
            -- Primary-only plans must not read/write offhand appearance.
            if not dual then dual=d.dual(ped,function() return current(expected,ped) end) end
            return dual.Ensure()==true
        end,function()
            if lease~=owned or not current(expected,ped) then return nil,'native_owner_cleanup_world_changed' end
            if owned.records and #owned.records>0 then return nil,'native_owner_copies_remain' end
            if owned.knifeAttempted and (not owned.knife or owned.knife.Status().phase~='released') then
                return nil,'native_owner_knife_cleanup_required'
            end
            if owned.throwableAttempted and (not owned.throwable or owned.throwable.Status().phase~='released') then
                return nil,'native_owner_throwable_cleanup_required'
            end
            if owned.utilityAttempted and (not owned.utility or owned.utility.Status().phase~='released') then
                return nil,'native_owner_utility_cleanup_required'
            end
            local removed,why=true,nil
            if dual then removed,why=dual.Cleanup() end
            if removed==true then owned.cleaned=true end
            return removed,why
        end)
        if not adapter then return nil,reason end
        owned.adapter=adapter
        return adapter
    end
    local function track(adapter,records)
        assert(lease and lease.adapter==adapter and not lease.cleaned,'native_owner_tracking_mismatch')
        lease.records=records -- Session mutates this exact list during cleanup.
    end
    local function knife(ped,identity)
        local owned=lease
        if Config.NativeAlphaRuntime~=true or GetConvarInt('feather_native_knife',0)~=1
            or not owned or owned.cleaned or owned.knifeAttempted or owned.ped~=ped
            or type(identity)~='table' or type(d.knife)~='function' then return nil,'native_knife_owner_unavailable' end
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if identity[key]~=owned.identity[key] then return nil,'native_knife_owner_changed' end
        end
        owned.knifeAttempted=true
        local value,why=d.knife(ped,owned.identity,function(check)
            return lease==owned and not owned.cleaned and current(owned.identity,ped)
                and check.characterId==owned.identity.characterId and check.sessionId==owned.identity.sessionId
                and check.epoch==owned.identity.epoch
        end)
        owned.knife=value
        return value,why
    end
    local function melee(ped,identity,approval)
        local owned=lease
        if Config.NativeAlphaRuntime~=true or GetConvarInt('feather_native_melee',0)~=1
            or not WeaponNativeMeleeOwner or not WeaponNativeMeleeCatalog or not owned or owned.cleaned
            or owned.knifeAttempted or owned.ped~=ped or type(identity)~='table' or type(d.knife)~='function' then
            return nil,'native_melee_owner_unavailable'
        end
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if identity[key]~=owned.identity[key] then return nil,'native_melee_owner_changed' end
        end
        local checked,why=WeaponNativeMeleeCatalog.ValidateApproval(approval,WeaponDefinitionCatalog,identity)
        if not checked then return nil,why end
        owned.knifeAttempted=true -- same parent ownership/cleanup barrier, not a second lease
        local function live(check)
            return GetConvarInt('feather_native_melee',0)==1 and lease==owned and not owned.cleaned
                and current(owned.identity,ped) and check.characterId==owned.identity.characterId
                and check.sessionId==owned.identity.sessionId and check.epoch==owned.identity.epoch
        end
        local value
        value,why=WeaponNativeMeleeOwner.New(checked,WeaponDefinitionCatalog,identity,function(def,bound)
            return d.knife(ped,bound,live,def)
        end,live)
        owned.knife=value
        return value,why
    end
    local function throwable(ped,identity,sealed,registry)
        local owned=lease
        if Config.NativeAlphaRuntime~=true or GetConvarInt('feather_native_throwable',0)~=1
            or not owned or owned.cleaned or owned.throwableAttempted or owned.ped~=ped
            or type(identity)~='table' or type(d.throwable)~='function' then return nil,'native_throwable_owner_unavailable' end
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if identity[key]~=owned.identity[key] then return nil,'native_throwable_owner_changed' end
        end
        owned.throwableAttempted=true
        local value,why=d.throwable(ped,owned.identity,function(check)
            return lease==owned and not owned.cleaned and GetConvarInt('feather_native_throwable',0)==1
                and current(owned.identity,ped) and check.characterId==owned.identity.characterId
                and check.sessionId==owned.identity.sessionId and check.epoch==owned.identity.epoch
        end,sealed,WeaponDefinitionCatalog,registry)
        owned.throwable=value; return value,why
    end
    local function utility(ped,identity,sealed,definition)
        local owned=lease
        if definition and definition.id=='native_utility_collection' then
            if not WeaponNativeUtilityCatalog.DavyEnabled() or not WeaponNativeUtilityCollection then return nil,'native_davy_lantern_disabled' end
            return WeaponNativeUtilityCollection.New(utility,ped,identity,sealed)
        end
        if Config.NativeAlphaRuntime~=true or GetConvarInt('feather_native_utility',0)~=1
            or not owned or owned.cleaned or owned.ped~=ped
            or type(identity)~='table' or type(d.utility)~='function' then return nil,'native_utility_owner_unavailable' end
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if identity[key]~=owned.identity[key] then return nil,'native_utility_owner_changed' end
        end
        definition=definition or WeaponDefinitionCatalog.weapons.utility_lasso
        owned.utilityModels=owned.utilityModels or {}
        if owned.utilityModels[definition.id] or (owned.utilityAttempted and not WeaponNativeUtilityCatalog.DavyEnabled()) then return nil,'native_utility_owner_unavailable' end
        owned.utilityModels[definition.id]=true
        local reinforced=definition.id=='utility_lasso_reinforced'
        local davy=definition.id=='utility_davy_lantern'
        local binoculars=definition.id=='utility_binoculars'
        local camera=definition.id=='utility_camera'
        local advancedCamera=definition.id=='utility_camera_advanced'
        local improvedBinoculars=definition.id=='utility_binoculars_improved'
        local fishingRod=definition.id=='utility_fishing_rod'
        local metalDetector=definition.id=='utility_metal_detector'
        if improvedBinoculars and not WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() then return nil,'native_improved_binoculars_disabled' end
        if fishingRod and not WeaponNativeUtilityCatalog.FishingRodEnabled() then return nil,'native_fishing_rod_disabled' end
        if metalDetector and not WeaponNativeUtilityCatalog.MetalDetectorEnabled() then return nil,'native_metal_detector_disabled' end
        if advancedCamera and not WeaponNativeUtilityCatalog.AdvancedCameraEnabled() then return nil,'native_advanced_camera_disabled' end
        if camera and not WeaponNativeUtilityCatalog.CameraEnabled() then return nil,'native_camera_disabled' end
        if binoculars and not WeaponNativeUtilityCatalog.BinocularsEnabled() then return nil,'native_binoculars_disabled' end
        if davy and not WeaponNativeUtilityCatalog.DavyEnabled() then return nil,'native_davy_lantern_disabled' end
        if reinforced and GetConvarInt('feather_native_lasso_reinforced',0)~=1 then return nil,'native_reinforced_lasso_disabled' end
        owned.utilityAttempted=true
        local value,why=d.utility(ped,owned.identity,function(check)
            return lease==owned and not owned.cleaned and GetConvarInt('feather_native_utility',0)==1
                and (not reinforced or GetConvarInt('feather_native_lasso_reinforced',0)==1)
                and (not davy or WeaponNativeUtilityCatalog.DavyEnabled())
                and (not binoculars or WeaponNativeUtilityCatalog.BinocularsEnabled())
                and (not camera or WeaponNativeUtilityCatalog.CameraEnabled())
                and (not advancedCamera or WeaponNativeUtilityCatalog.AdvancedCameraEnabled())
                and (not improvedBinoculars or WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled())
                and (not fishingRod or WeaponNativeUtilityCatalog.FishingRodEnabled())
                and (not metalDetector or WeaponNativeUtilityCatalog.MetalDetectorEnabled())
                and current(owned.identity,ped) and check.characterId==owned.identity.characterId
                and check.sessionId==owned.identity.sessionId and check.epoch==owned.identity.epoch
        end,sealed,definition)
        if owned.utility and value then
            local prior=owned.utility
            owned.utility={Status=function()
                return {phase=prior.Status().phase=='released' and value.Status().phase=='released' and 'released' or 'retained'}
            end}
        else owned.utility=value end
        return value,why
    end
    local T={}
    function T.ProbeGuidComponent(action)
        local owned=lease
        local function guard()
            local state=bootstrap and bootstrap.Status().runtime
            local ammo=state and state.session and state.session.ammo
            local baseline=ammo and ammo.baseline
            local flag=action and 'feather_native_child_component_probe' or 'feather_native_guid_component_probe'
            if Config.DevMode~=true or Config.NativeAlphaRuntime~=true or GetConvarInt(flag,0)~=1
                or lease~=owned or not owned or owned.cleaned or phase~='started' or not state or state.phase~='active'
                or state.runtimeBusy or state.receiving or state.quiescing or not ammo or ammo.phase~='active'
                or ammo.pending or ammo.closing or ammo.deathClosing or not baseline
                or not WeaponNativeEnrollment.Allows(Config,baseline.characterId) or baseline.epoch~=owned.identity.epoch
                or baseline.sessionId~=owned.identity.sessionId or not current(owned.identity,owned.ped) then return false end
            for _,amount in pairs(baseline.pools or {}) do if amount~=0 then return false end end
            return true
        end
        local method=owned and owned.adapter and (action and owned.adapter.probeInventoryComponent or owned.adapter.probeGuidComponent)
        if not guard() or type(method)~='function' then return nil,'guid_probe_settled_empty_scope_required' end
        for _,record in ipairs(owned.records or {}) do
            if record.itemInstanceId==135 then return method(record,owned.identity,guard,action) end
        end
        return nil,'guid_probe_equipped135_required'
    end
    function T.InspectTrackedEntities()
        local owned=lease
        local state=bootstrap and bootstrap.Status().runtime
        if Config.DevMode~=true or not owned or owned.cleaned or phase~='started'
            or not state or state.phase~='active' or state.runtimeBusy or state.receiving or state.quiescing
            or not current(owned.identity,owned.ped) or type(owned.adapter.inspectTrackedEntity)~='function' then
            return nil,'diagnostic_settled_owner_required'
        end
        local out={epoch=owned.identity.epoch,items={},noNativeWrites=true,noSQLWrites=true}
        for _,record in ipairs(owned.records or {}) do
            local value,why=owned.adapter.inspectTrackedEntity(record,owned.identity)
            if not value then return nil,why end
            out.items[#out.items+1]=value
        end
        if lease~=owned or not current(owned.identity,owned.ped) then return nil,'diagnostic_owner_changed' end
        return out
    end
    function T.MaintenanceStatus(allowReserved)
        local owned=lease
        local state=bootstrap and bootstrap.Status().runtime
        if phase~='started' or not owned or owned.cleaned or not state or state.phase~='active'
            or (state.runtimeBusy and allowReserved~=true) or state.receiving or state.quiescing or not current(owned.identity,owned.ped)
            or type(owned.adapter.readMaintenance)~='function' then return nil,'maintenance_owner_not_settled' end
        local ammo=state.session and state.session.ammo
        if not ammo or ammo.phase~='active' or ammo.pending or ammo.closing or ammo.deathClosing then
            return nil,'maintenance_owner_not_settled'
        end
        local baseline=ammo.baseline
        if not baseline or baseline.epoch~=owned.identity.epoch then return nil,'maintenance_epoch_changed' end
        local out={epoch=baseline.epoch,items={}}
        for _,record in ipairs(owned.records or {}) do
            local called,values=pcall(owned.adapter.readMaintenance,record,owned.identity)
            if not called or not values then return nil,'maintenance_readback_unavailable' end
            out.items[#out.items+1]={itemInstanceId=record.itemInstanceId,itemRevision=record.itemRevision,
                name=record.name,maintenance=values}
        end
        if lease~=owned or not current(owned.identity,owned.ped) then return nil,'maintenance_owner_changed' end
        return out
    end
    function T.FinalWear(identity)
        if not lease or type(identity)~='table' then return nil,'final_wear_owner_missing' end
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if identity[key]~=lease.identity[key] then return nil,'final_wear_owner_changed' end
        end
        return T.MaintenanceStatus(true) -- only the runtime release reservation may already be busy
    end
    function T.DeathWear(context)
        local owned=lease
        local state=bootstrap and bootstrap.Status().runtime
        local ammo=state and state.session and state.session.ammo
        if Config.NativeAlphaLifecycleWearEnabled~=true or phase~='started' or not owned or owned.cleaned
            or not state or state.phase~='active' or state.receiving or state.quiescing or state.fault
            or not ammo or ammo.phase~='active' or not ammo.baseline or ammo.baseline.epoch~=owned.identity.epoch
            or type(owned.adapter.readDeathMaintenance)~='function' or type(context)~='table'
            or context.characterId~=owned.identity.characterId or context.sessionId~=owned.identity.sessionId
            or context.ped~=owned.ped or d.ped()~=owned.ped or context.lifeState~='dead' then return nil,'death_wear_owner_not_settled' end
        local out={epoch=owned.identity.epoch,medicalRevision=context.medicalRevision,items={}}
        for _,record in ipairs(owned.records or {}) do
            local called,values=pcall(owned.adapter.readDeathMaintenance,record,owned.identity)
            if not called or not values then return nil,'death_wear_readback_unavailable' end
            out.items[#out.items+1]={itemInstanceId=record.itemInstanceId,itemRevision=record.itemRevision,maintenance=values}
        end
        local called,result=pcall(WeaponCharacterAmmoWorldContext.ReadDeath)
        local after=called and type(result)=='table' and result.ok==true and result.value
        if lease~=owned or not after or after.characterId~=context.characterId or after.sessionId~=context.sessionId
            or after.ped~=context.ped or after.medicalRevision~=context.medicalRevision then return nil,'death_wear_context_changed' end
        return out
    end
    function T.StopZeroAmmo()
        -- Synchronous, narrowly safe stop cleanup. No SQL/transport, pool reset,
        -- seal/release acknowledgement or recovery claim is made here.
        if phase~='started' or not bootstrap or not lease or lease.cleaned then return nil,'stop_owner_not_tracked' end
        local owned=lease
        local state=bootstrap.Status().runtime
        local ammo=state and state.session and state.session.ammo
        local baseline=ammo and ammo.baseline
        if not state or state.phase~='active' or state.runtimeBusy or state.receiving or state.quiescing or state.fault
            or not ammo or ammo.phase~='active' or ammo.pending or ammo.closing or ammo.deathClosing
            or not baseline or baseline.epoch~=owned.identity.epoch or not current(owned.identity,owned.ped)
            or type(owned.records)~='table' then return nil,'stop_owner_not_settled' end
        local function read()
            if d.readPools then return d.readPools(owned.ped) end
            local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
            if not registry then return nil end
            local native=WeaponCharacterAmmoNative.New(registry.names,registry.limits)
            return native and native.Read(owned.ped,true)
        end
        local function empty()
            if lease~=owned or not current(owned.identity,owned.ped) then return false end
            local called,pools=pcall(read)
            if not called or type(pools)~='table' or next(pools)==nil or type(baseline.pools)~='table' then return false end
            for id,count in pairs(pools) do if count~=0 or baseline.pools[id]~=0 then return false end end
            for id,count in pairs(baseline.pools) do if count~=0 or pools[id]~=0 then return false end end
            return true
        end
        if not empty() then return nil,'stop_nonzero_or_unreadable_ammo_requires_orderly_release' end
        if owned.utilityAttempted and (not owned.utility or owned.utility.Status().phase~='released') then
            return nil,'stop_utility_requires_orderly_release'
        end
        for i=#owned.records,1,-1 do
            if not empty() then return nil,'stop_cleanup_context_changed' end
            local called,removed=pcall(owned.adapter.remove,owned.records[i])
            if not called or removed~=true then return nil,'stop_owned_copy_cleanup_failed' end
            table.remove(owned.records,i)
        end
        if not empty() then return nil,'stop_cleanup_context_changed' end
        if owned.throwableAttempted and (not owned.throwable or owned.throwable.Status().phase~='released') then
            return nil,'stop_throwable_requires_orderly_release'
        end
        if owned.knifeAttempted then
            if not owned.knife then return nil,'stop_knife_cleanup_unconfirmed' end
            local ok,removed=pcall(owned.knife.Release)
            if not ok or removed~=true or owned.knife.Status().phase~='released' or not empty() then return nil,'stop_knife_cleanup_failed' end
        end
        local called,cleaned=pcall(owned.adapter.cleanupSetup)
        if not called or cleaned~=true then return nil,'stop_owned_setup_cleanup_failed' end
        phase,reason='stopped','zero_ammo_owned_stop_cleanup'
        return true
    end
    function T.Start()
        if phase~='dormant' then return nil,'native_owner_already_started' end
        if not enabled() then return nil,'character_ammunition_disabled' end
        phase='starting'
        local called,value,why=pcall(d.bootstrap,create,track,knife,melee,throwable,utility)
        if not called or type(value)~='table' or type(value.Start)~='function'
            or type(value.Status)~='function' then
            phase,reason='failed',why or 'native_owner_bootstrap_failed'; return nil,reason
        end
        bootstrap=value
        if not enabled() then phase,reason='failed','character_ammunition_disabled'; return nil,reason end
        local started,result,failure=pcall(bootstrap.Start)
        if not started or result~=true then
            phase,reason='failed',failure or 'native_owner_start_failed'; return nil,reason
        end
        phase='started'; return true
    end
    function T.Status()
        return {phase=phase,reason=reason,bootstrap=bootstrap and bootstrap.Status() or {phase='dormant'},
            ownedCopies=lease and lease.records and #lease.records or 0,
            cleanupComplete=lease==nil or lease.cleaned==true}
    end
    function T.Readiness()
        if not enabled() or phase~='started' or not bootstrap then return nil,'native_owner_not_started' end
        local state=bootstrap.Status()
        if state.phase~='started' or not state.runtime or state.runtime.phase~='closed'
            or state.runtime.fault or state.runtime.runtimeBusy then return nil,'native_owner_not_closed' end
        if lease and not lease.cleaned then return nil,'native_owner_cleanup_required' end
        if lease and lease.records and #lease.records>0 then return nil,'native_owner_copies_remain' end
        local called,result=pcall(d.context)
        local value=called and type(result)=='table' and result.ok==true and result.value
        if type(value)~='table' or value.ped~=d.ped() then return nil,'native_owner_world_not_ready' end
        -- No pool, limit, slot, item or epoch credit is exposed as readiness.
        return {characterId=value.characterId,sessionId=value.sessionId}
    end
    function T.BindReadiness()
        if phase~='started' then return nil,'native_owner_not_started' end
        return WeaponCharacterAmmoClientBindings.Readiness(T)
    end
    function T.Transfer(id,amount,operationId,scope)
        if not enabled() or phase~='started' or not bootstrap then return nil,'native_owner_not_started' end
        local result=d.context()
        local value=type(result)=='table' and result.ok==true and result.value
        if type(value)~='table' or not lease or lease.cleaned
            or not current(lease.identity,lease.ped) then return nil,'native_owner_world_not_ready' end
        if type(scope)~='table' or scope.characterId~=lease.identity.characterId
            or scope.sessionId~=lease.identity.sessionId or scope.epoch~=lease.identity.epoch then
            return nil,'ammunition_panel_expired_reopen'
        end
        return bootstrap.Transfer(id,amount,operationId)
    end
    function T.Recovery()
        local hint=T.Readiness()
        if not hint or not lease or not lease.cleaned then return nil end
        local state=bootstrap.Status().runtime
        local recovery=state and state.deathRecovery
        if type(recovery)~='table' or recovery.characterId~=hint.characterId
            or recovery.sessionId~=hint.sessionId or recovery.ped~=lease.ped
            or recovery.epoch~=lease.identity.epoch then return nil end
        return {characterId=hint.characterId,sessionId=hint.sessionId,epoch=recovery.epoch}
    end
    return T
end
