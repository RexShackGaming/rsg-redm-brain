-- Dormant owner: creation -> pool restore -> server acknowledgement -> active.
-- Owner must provide input blocking, native creation adapter and lifecycle ticks.
WeaponCharacterAmmoSession={}
function WeaponCharacterAmmoSession.New(api,registry)
    local phase,records,creator='closed',nil,nil
    local knife,knifeFactoryUnconfirmed,meleeMode
    local throwable,throwableFactoryUnconfirmed,throwableSnapshot
    local utility,utilityFactoryUnconfirmed
    local controller=WeaponCharacterAmmoController.New(api,function(baseline)
        if not throwable or type(throwable.AcceptNativePickup)~='function' then return nil end
        local accepted,why=throwable.AcceptNativePickup(baseline)
        if accepted then
            print(('[WeaponNativeThrowablePickup] PASS ledger acknowledged/read-only GUID rebind revision=%s; no loose/native ammo grant'):format(tostring(baseline.revision)))
        end
        return accepted,why
    end)
    local T={}
    local function blocked(value) api.block(value) end
    local function freeze(reason) phase='frozen'; blocked(true); return nil,reason end
    function T.Begin(bundle)
        if phase~='closed' then return nil,'native_session_not_closed' end
        if type(bundle)~='table' then return nil,'invalid_creation_bundle' end
        local valid,reason=WeaponCharacterAmmoMaterialization.Validate(bundle.creation,registry,bundle.runtime)
        if not valid then return nil,reason end
        local utilityApproval,utilityDefinition
        if bundle.utility~=nil then
            if not WeaponNativeUtilityItem or type(api.utility)~='function' then return nil,'utility_lifecycle_unavailable' end
            if type(bundle.utility)=='table' and bundle.utility.items~=nil then
                utilityApproval,reason=WeaponNativeUtilityItem.ValidateCollection(bundle.utility,WeaponDefinitionCatalog,bundle.creation.identity)
                utilityDefinition={id='native_utility_collection'}
                if not utilityApproval then return nil,reason end
            else
            local row=type(bundle.utility)=='table' and bundle.utility.row
            utilityDefinition=type(row)=='table' and type(row.metadata)=='table'
                and WeaponDefinitionCatalog.weapons[row.metadata.weaponDefinitionId]
            if not utilityDefinition then return nil,'utility_definition_required' end
            utilityApproval,reason=WeaponNativeUtilityItem.ValidateApproval(bundle.utility,utilityDefinition,bundle.creation.identity)
            if not utilityApproval then return nil,reason end
            end
        end
        local knifeApproval
        if bundle.melee~=nil then
            if bundle.knife~=nil or type(api.melee)~='function' or not WeaponNativeMeleeCatalog then
                return nil,'melee_lifecycle_not_available'
            end
            knifeApproval,reason=WeaponNativeMeleeCatalog.ValidateApproval(bundle.melee,WeaponDefinitionCatalog,bundle.runtime)
            if not knifeApproval then return nil,reason end
        end
        if bundle.knife~=nil then
            if type(api.knife)~='function' or not WeaponNativeKnife or not WeaponDefinitionCatalog then
                return nil,'knife_lifecycle_not_available'
            end
            knifeApproval,reason=WeaponNativeKnife.ValidateApproval(bundle.knife,WeaponDefinitionCatalog.weapons.melee_knife,bundle.runtime)
            if not knifeApproval then return nil,reason end
        end
        throwableSnapshot=nil
        if bundle.throwable~=nil then
            if not WeaponNativeThrowableItem or type(api.throwable)~='function' then return nil,'throwable_lifecycle_unavailable' end
            local assigned,why=WeaponNativeThrowableItem.Assigned(bundle.throwable,WeaponDefinitionCatalog,bundle.creation.identity,registry.limits)
            if not assigned then return nil,why or 'throwable_assignment_required' end
            if bundle.throwable.revision~=bundle.runtime.revision or type(bundle.runtime.pools)~='table' then return nil,'throwable_ledger_revision_changed' end
            for id in pairs(registry.limits) do
                if bundle.throwable.pools[id]~=bundle.runtime.pools[id] then return nil,'throwable_ledger_balance_changed' end
            end
            -- Private authoritative data, not a mutable caller snapshot.
            local function copy(v)
                if type(v)~='table' then return v end
                local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
            end
            throwableSnapshot=copy(bundle.throwable)
        end
        -- Preflight every ammo value before granting any weapon. Names/limits
        -- come from the owner's trusted registry, never from bundle credit hints.
        local check=WeaponCharacterAmmoClient.New()
        local ped=api.ped()
        local baseline
        baseline,reason=check.Begin(bundle.runtime,registry.limits,ped)
        if not baseline or api.ready()~=true then return nil,reason or 'world_not_ready' end
        local native
        native,reason=WeaponCharacterAmmoNative.New(registry.names,registry.limits,api)
        if not native then return nil,reason end
        local before
        before,reason=native.Read(ped,true)
        if not before then return nil,reason end
        blocked(true); phase='creating'
        meleeMode=bundle.melee~=nil
        local ok,adapter=pcall(api.creation,ped,bundle.creation.identity)
        if not ok or type(adapter)~='table' then return freeze('creation_adapter_unavailable') end
        creator=adapter
        if utilityApproval then
            utilityFactoryUnconfirmed=true
            local called,value=pcall(api.utility,ped,bundle.creation.identity,function(approval)
                local state=controller.Status()
                local baseline=state.baseline
                return state.phase=='sealed' and type(baseline)=='table'
                    and baseline.characterId==approval.identity.characterId
                    and baseline.sessionId==approval.identity.sessionId and baseline.epoch==approval.identity.epoch
            end,utilityDefinition)
            if not called or type(value)~='table' or type(value.Create)~='function'
                or type(value.Release)~='function' or type(value.Status)~='function' then return freeze('utility_factory_unconfirmed') end
            utility=value; utilityFactoryUnconfirmed=false
            local made,result=pcall(utility.Create,utilityApproval)
            if not made or result~=true or api.ped()~=ped or api.ready()~=true then return freeze('utility_creation_unconfirmed') end
        end
        if throwableSnapshot then
            throwableFactoryUnconfirmed=true
            local called,value=pcall(api.throwable,ped,bundle.creation.identity,function()
                local state=controller.Status()
                return state.phase=='sealed' and state.baseline or nil
            end,registry)
            if not called or type(value)~='table' or type(value.Create)~='function' or type(value.Observe)~='function'
                or type(value.Release)~='function' or type(value.Status)~='function' then return freeze('throwable_factory_unconfirmed') end
            throwable=value; throwableFactoryUnconfirmed=false
            local made,result=pcall(throwable.Create,throwableSnapshot)
            if not made or result~=true or api.ped()~=ped or api.ready()~=true then return freeze('throwable_creation_unconfirmed') end
        end
        if knifeApproval then
            knifeFactoryUnconfirmed=true -- retain uncertainty before a possibly yielding factory
            local called,value=pcall(meleeMode and api.melee or api.knife,ped,knifeApproval.identity,meleeMode and knifeApproval or nil)
            if not called or type(value)~='table' or type(value.Create)~='function'
                or type(value.Release)~='function' or type(value.Status)~='function' then return freeze('knife_factory_unconfirmed') end
            knife=value; knifeFactoryUnconfirmed=false
            local made,result=pcall(knife.Create,knifeApproval.row)
            if not made or not result then return freeze('knife_creation_unconfirmed') end
            if api.ped()~=ped or api.ready()~=true then return freeze('knife_creation_world_changed') end
        end
        local executor=WeaponCharacterAmmoLoadout.New(adapter)
        local created,partial
        created,reason,partial=executor.Create(bundle.creation)
        if not created then
            -- Failed native/attachment compensation still belongs to this
            -- session. Preserve exact records for diagnostics and cleanup veto;
            -- do not restore ammo, ack activation or invent a server release.
            records=type(partial)=='table' and partial.handles or {}
            if api.owned then api.owned(creator,records) end
            return freeze(reason)
        end
        records=created.handles
        if api.owned then api.owned(creator,records) end
        if api.ped()~=ped or api.ready()~=true then return freeze('creation_world_changed') end
        local after
        after,reason=native.Read(ped,true)
        if not after then return freeze(reason) end
        for id,count in pairs(before) do
            local authorized=throwableSnapshot and id=='ammo_tomahawk_regular' and throwableSnapshot.pools[id] or count
            if after[id]~=authorized then return freeze('creation_changed_native_pool') end
        end
        phase='restoring'
        local opened
        opened,reason=controller.Begin(baseline,registry.names,registry.limits)
        if not opened then return freeze(reason) end
        return true
    end
    function T.Tick()
        if phase=='closed' or phase=='creating' or phase=='frozen' then return nil,'native_session_not_ready' end
        local state=controller.Status()
        if phase=='cleanup_pending' then
            if state.phase=='released' then
                controller.Close(); creator,records,knife,throwable,utility=nil,nil,nil,nil,nil; phase='closed'; return true,'released'
            end
            if state.phase=='frozen' or state.phase=='suspended' then return freeze('cleanup_ack_failed') end
            return nil,'cleanup_ack_pending'
        end
        phase=state.phase
        blocked(phase~='active' or state.closing==true or state.pendingKind=='transfer' or state.pendingKind=='pickup')
        if phase=='frozen' or phase=='suspended' or phase=='sealed' then return nil,phase end
        -- The controller owns the identity-checked dead-ped snapshot/seal.
        -- Ordinary child polling uses alive context and must not invalidate an
        -- owner while the death checkpoint is pending (or readiness just fell).
        if throwable and phase=='active' and not state.deathClosing and api.ready()==true then
            local ok,observation=pcall(throwable.Observe,state.baseline)
            if not ok or not observation then return freeze('throwable_observation_unconfirmed') end
        end
        local result,reason=controller.Tick()
        state=controller.Status(); phase=state.phase
        blocked(phase~='active' or state.closing==true or state.pendingKind=='transfer' or state.pendingKind=='pickup')
        return result,reason
    end
    function T.Finalize()
        local state=controller.Status()
        if state.phase~='active' then return nil,'native_session_not_active' end
        blocked(true)
        return controller.Finalize()
    end
    function T.Transfer(id,amount,operationId)
        if throwable and id=='ammo_tomahawk_regular' then return nil,'throwable_transfer_requires_rebuild' end
        return controller.Transfer(id,amount,operationId)
    end
    function T.FinalizeDeath()
        if controller.Status().phase~='active' then return nil,'death_seal_not_active' end
        blocked(true)
        return controller.FinalizeDeath()
    end
    local deathCleanup=false
    function T.Cleanup()
        if controller.Status().deathClosing then return nil,'death_recovery_required' end
        if phase=='cleanup_pending' then return nil,'cleanup_ack_pending' end
        -- Never close an unsealed active session and lose its final observations.
        if controller.Status().phase~='sealed' and phase~='frozen' then return nil,'seal_required_before_cleanup' end
        blocked(true)
        if utilityFactoryUnconfirmed then return freeze('utility_factory_cleanup_unconfirmed') end
        if utility then
            local ok,removed=pcall(utility.Release)
            local checked,status=pcall(utility.Status)
            if not ok or removed~=true or not checked or type(status)~='table' or status.phase~='released' then
                return freeze('utility_cleanup_unconfirmed')
            end
        end
        if throwableFactoryUnconfirmed then return freeze('throwable_factory_cleanup_unconfirmed') end
        if throwable then
            local ok,removed=pcall(throwable.Release)
            local checked,status=pcall(throwable.Status)
            if not ok or removed~=true or not checked or type(status)~='table' or status.phase~='released' then
                return freeze('throwable_cleanup_unconfirmed')
            end
        end
        for index=#(records or {}),1,-1 do
            local ok,removed=pcall(creator.remove,records[index])
            if not ok or removed~=true then return freeze('native_cleanup_failed') end
            table.remove(records,index)
        end
        -- Companion cleanup belongs to the SAME seal/release acknowledgement.
        -- Neither logout, prepared stop nor doctor recovery may release a server
        -- hold while a knife factory/copy remains unresolved.
        if knifeFactoryUnconfirmed then return freeze('knife_factory_cleanup_unconfirmed') end
        if knife then
            local called,removed=pcall(knife.Release,deathCleanup)
            if not called or removed~=true then return freeze('knife_cleanup_unconfirmed') end
            local checked,state=pcall(knife.Status)
            if not checked or type(state)~='table' or state.phase~='released' then return freeze('knife_cleanup_not_released') end
        end
        -- Appearance cleanup can close the owning lease only after the knife.
        if creator and creator.cleanupSetup then
            local ok,cleaned=pcall(creator.cleanupSetup)
            if not ok or cleaned~=true then return freeze('native_setup_cleanup_failed') end
        end
        local confirmed,reason=controller.ConfirmCleanup()
        if not confirmed then return freeze(reason) end
        phase='cleanup_pending'
        -- Keep input blocked and ownership until the exact server ack arrives.
        return true
    end
    function T.RecoverDeath()
        local allowed,why=controller.AllowDeathCleanup()
        if not allowed then return nil,why end
        deathCleanup=true
        local ok,reason=T.Cleanup()
        deathCleanup=false
        return ok,reason
    end
    function T.Status()
        local companion
        if knife then
            local ok,value=pcall(knife.Status)
            companion=ok and value or {phase='unconfirmed'}
        elseif knifeFactoryUnconfirmed then companion={phase='factory_unconfirmed'} end
        local thrown
        if throwable then
            local ok,value=pcall(throwable.Status); thrown=ok and value or {phase='unconfirmed'}
        elseif throwableFactoryUnconfirmed then thrown={phase='factory_unconfirmed'} end
        local tool
        if utility then
            local ok,value=pcall(utility.Status); tool=ok and value or {phase='unconfirmed'}
        elseif utilityFactoryUnconfirmed then tool={phase='factory_unconfirmed'} end
        return {phase=phase,ammo=controller.Status(),copies=records and #records or 0,
            knife=not meleeMode and companion or nil,melee=meleeMode and companion or nil,throwable=thrown,utility=tool}
    end
    return T
end
