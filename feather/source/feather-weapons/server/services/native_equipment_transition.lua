-- Server-owned scoped alpha equipment, dry-run and orderly-stop protocol.
-- Player intent routes remain behind explicit native/scoped development gates.
WeaponNativeEquipmentTransition={}
WeaponNativePeriodicWear={}
WeaponNativeShutdownDrain={}
-- Shutdown is required even when optional wear persistence is disabled. An
-- absent retired proof resource is inactive, just like an installed/stopped one.
function WeaponNativeShutdownDrain.RuntimeAvailable(config,proofState)
    return type(config)=='table' and config.NativeAlphaRuntime==true
        and config.CharacterAmmunitionEnabled==true and config.CharacterAmmoTransportEnabled==true
        and (proofState=='stopped' or proofState=='missing')
end
-- One-way admission latch; never stops the resource or retries an uncertain owner.
function WeaponNativeShutdownDrain.New(api)
    local run
    local T={}
    function T.IsLatched() return run~=nil end
    function T.Status() return run and {phase=run.phase,reason=run.reason,total=#run.roster,completed=run.completed} or {phase='idle'} end
    local function fail(reason) run.phase='failed'; run.reason=reason; api.report(T.Status()) end
    local function roster()
        local ok,value=pcall(api.roster)
        if not ok or type(value)~='table' then return nil end
        local seen,characters,clean={},{},{}
        for _,row in ipairs(value) do
            if type(row)~='table' or type(row.source)~='number' or row.source<1 or row.source%1~=0
                or seen[row.source] or type(row.characterId)~='string' or row.characterId=='' or characters[row.characterId]
                or type(row.sessionId)~='string' or row.sessionId==''
                or type(row.epoch)~='string' or row.epoch=='' then return nil end
            seen[row.source]=true
            characters[row.characterId]=true
            clean[#clean+1]={source=row.source,characterId=row.characterId,sessionId=row.sessionId,epoch=row.epoch}
        end
        table.sort(clean,function(a,b) return a.source<b.source end)
        return clean
    end
    local function poll()
        if run.phase~='draining' and run.phase~='ready' then return end
        if run.phase=='draining' and (api.now()-run.started)%4294967296>=90000 then return fail('drain_timeout_no_retry') end
        local current=roster()
        if run.phase=='failed' then return end -- deadline may fire while an adapter yields
        if not current or #current~=#run.roster then return fail('drain_roster_changed') end
        for i,row in ipairs(current) do
            local old=run.roster[i]
            if row.source~=old.source or row.characterId~=old.characterId or row.sessionId~=old.sessionId
                or row.epoch~=old.epoch then return fail('drain_identity_changed') end
        end
        for i=1,run.completed do
            local row=run.roster[i]
            local ok,state=pcall(api.status,row.source)
            if run.phase=='failed' then return end
            if not ok or not state or state.phase~='parked' or state.commitOutcome~='confirmed'
                or state.sessionId~=row.sessionId then return fail('drain_release_authority_changed') end
        end
        if run.phase=='ready' then api.schedule(poll); return end
        local row=run.roster[run.completed+1]
        if not row then run.phase='ready'; api.report(T.Status()); api.schedule(poll); return end
        local ok,state=pcall(api.status,row.source)
        if run.phase=='failed' then return end
        if not ok or not state or state.sessionId~=row.sessionId then return fail('drain_owner_unavailable') end
        if state.phase=='parked' and state.commitOutcome=='confirmed' then
            run.completed=run.completed+1; run.requested=false
        elseif state.phase=='frozen' then return fail('drain_owner_frozen')
        elseif not run.requested then
            run.requested=true -- reserve before any yielding preflight
            local called,result=pcall(api.begin,row.source,row)
            if not called or not result or result.ok~=true then return fail('drain_release_refused_no_retry') end
        end
        api.schedule(poll)
    end
    function T.Begin()
        if run then return false,'drain_already_latched' end
        run={phase='draining',roster={},completed=0,started=api.now()}
        if api.deadline then api.deadline(function()
            if run.phase=='draining' then fail('drain_timeout_no_retry') end
        end) end
        local value=roster()
        if run.phase=='failed' then return false,run.reason end
        if not value then fail('drain_roster_unavailable'); return false,run.reason end
        run.roster=value
        -- Preflight every owner before starting any release.
        for _,row in ipairs(value) do
            local ok,state=pcall(api.status,row.source)
            if run.phase=='failed' then return false,run.reason end
            if not ok or not state or state.sessionId~=row.sessionId
                or (state.phase~='active' and state.phase~='parked') then
                fail('drain_owner_not_idle'); return false,run.reason
            end
        end
        api.schedule(poll)
        return true
    end
    return T
end
-- Scheduling only. Existing one-use read tickets and sealed transition own I/O.
function WeaponNativePeriodicWear.New(api)
    local states={}
    local T={}
    local function match(a,b)
        return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch
    end
    function T.Step(target)
        if not api.enabled() then states[target]=nil; return nil,'disabled' end
        local interval=api.interval()
        if type(interval)~='number' or interval%1~=0 or interval<15000 or interval>300000 then return nil,'invalid_interval' end
        local status=api.status(target)
        if not status or not status.identity or status.phase~='active' or status.busy or api.busy(target) then return nil,'not_idle' end
        local now=api.now()
        local old=states[target]
        if not old or not match(old.identity,status.identity) then
            local sameSession=old and old.identity.characterId==status.identity.characterId and old.identity.sessionId==status.identity.sessionId
            states[target]={identity={characterId=status.identity.characterId,sessionId=status.identity.sessionId,epoch=status.identity.epoch},
                lastAt=now,cursor=sameSession and old.cursor or 0,unchanged=sameSession and old.unchanged or 0,
                persisted=sameSession and old.persisted or 0,lastOutcome=sameSession and old.lastOutcome or 'waiting'}
            return nil,'waiting'
        end
        if (now-old.lastAt)%4294967296<interval then return nil,'waiting' end
        old.lastAt=now -- reserve before request adapters can yield
        local items=api.items(target)
        if type(items)~='table' or #items==0 or #items>4 then return nil,'no_equipped_copies' end
        local after=api.status(target)
        if states[target]~=old or not after or not match(after.identity,old.identity) or after.phase~='active'
            or after.busy or api.busy(target) then return nil,'context_changed' end
        old.cursor=old.cursor%#items+1
        local item=items[old.cursor]
        local called,accepted=pcall(api.request,target,item.id)
        old.lastOutcome=called and accepted==true and 'read_requested' or 'read_refused'
        return called and accepted==true,old.lastOutcome
    end
    function T.Complete(target,scope,outcome)
        local state=states[target]
        if not state or not match(state.identity,scope) then return false end
        state.lastOutcome=outcome
        if outcome=='unchanged' then state.unchanged=state.unchanged+1 end
        if outcome=='persisted' then state.persisted=state.persisted+1 end
        return true
    end
    function T.Forget(target,sessionId)
        if states[target] and sessionId and states[target].identity.sessionId~=sessionId then return false end
        states[target]=nil; return true
    end
    function T.Status(target)
        local s=states[target]
        return s and {epoch=s.identity.epoch,lastOutcome=s.lastOutcome,unchanged=s.unchanged,persisted=s.persisted,
            intervalMs=api.interval(),cursor=s.cursor} or nil
    end
    return T
end
local denied,identity,same
local function copy(value)
    if type(value)~='table' then return value end
    local out={}; for key,item in pairs(value) do out[key]=copy(item) end; return out
end

-- Concrete normal-host composition; Inventory owns conditional SQL writes.
-- A one-shot diagnostic uses the normal dry-run seal/rebuild, then submits a
-- competing request and an invalid-ticket acknowledgement in the same turn.
-- It never pauses SQL, bypasses admission or changes the reserved operation.
function WeaponNativeEquipmentTransition.ProbeOverlap(coordinator,target,bound)
    local first=coordinator.Begin(target,{action='dry-run'})
    if not first or not first.ok then return first end
    local before=coordinator.Status(target)
    if not before or before.phase~='releasing' then return denied('overlap_probe_not_in_release') end
    local competing=coordinator.Begin(target,{action='dry-run'})
    local stale=coordinator.Released(target,'',copy(bound)) -- real tickets are never empty
    local after=coordinator.Status(target)
    if not competing or competing.ok or not competing.error
        or competing.error.code~='equipment_transition_in_flight'
        or not stale or stale.ok or not after or after.phase~=before.phase
        or after.sessionId~=before.sessionId or after.commitOutcome~=before.commitOutcome then
        return denied('overlap_probe_boundary_failed')
    end
    return {ok=true,value={competingRefused=true,staleAcknowledgementRefused=true,
        phase=after.phase,noEquipmentWriteRequested=true,restorePending=true}}
end
local function InstallDryRun()
WeaponNativeEquipmentBindings={}
WeaponNativeEquipmentBindings.RecoveryContract=1
local pending={}
local stopping={}
local sequence=0
local function enabled()
    return Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
end
local coordinator
local drain
local attachmentDisconnect={}
local function attachmentEnabled()
    return enabled() and Config.NativeAlphaLifecycleWearEnabled==true and type(GetConvarInt)=='function'
        and GetConvarInt('feather_native_attachment_transactions',1)==1
        and GetConvarInt('feather_native_saved_attachments',1)==1 and GetConvarInt('feather_native_guid_ownership',1)==1
end
local uiPending={}
local wearPending={}
local periodic,periodicIntent=nil,{}
local logoutPending={}
local function replyLogout(target,result)
    local request=logoutPending[target]
    if not request then return end
    logoutPending[target]=nil
    TriggerClientEvent('feather-weapons:client:native-logout-wear-result',target,request.id,request.scope,result)
end
local uiRates={}
local function allowUI(target,kind)
    local now=GetGameTimer()
    local capacity=kind=='options' and 4 or 2
    local rates=uiRates[target]
    if not rates then rates={}; uiRates[target]=rates end
    local bucket=rates[kind]
    if not bucket then bucket={tokens=capacity,updated=now}; rates[kind]=bucket end
    local elapsed=(now-bucket.updated)%4294967296
    bucket.tokens=math.min(capacity,bucket.tokens+elapsed/1000)
    bucket.updated=now
    if bucket.tokens<1 then return false end
    bucket.tokens=bucket.tokens-1
    return true
end
local adapters={
    enabled=enabled,
    prepare=function(source,intent)
        if drain and drain.IsLatched() and intent.action~='shutdown' then return denied('native_global_shutdown_latched') end
        local attachmentChange=intent.action=='attachment-install' or intent.action=='attachment-remove'
        local funding=intent.action=='throwable-funding'
        if intent.action~='dry-run' and intent.action~='shutdown' and intent.action~='equip' and intent.action~='unequip' and intent.action~='move' and intent.action~='unequip_primary' and intent.action~='options' and intent.action~='repair' and intent.action~='maintenance' and not attachmentChange and not funding then return denied('invalid_equipment_action') end
        if attachmentChange and not attachmentEnabled() then return denied('native_attachment_transactions_disabled') end
        if intent.action=='repair' and Config.NativeAlphaRepairEnabled~=true then return denied('native_repair_disabled') end
        if intent.action=='maintenance' and Config.NativeAlphaMaintenanceEnabled~=true then return denied('native_maintenance_disabled') end
        if intent.periodic==true and (intent.action~='maintenance' or Config.NativeAlphaPeriodicWearEnabled~=true) then return denied('native_periodic_wear_disabled') end
        local session=CoreAdapter.ResolveSession(source)
        local state=WeaponCharacterAmmoDispatcher.Status(source)
        if not session or not session.ok or not WeaponNativeEnrollment.Allows(Config,session.value.characterId)
            or not state or state.phase~='active' or state.busy or not same(state.identity,
                {characterId=session.value.characterId,sessionId=session.value.sessionId,epoch=state.identity and state.identity.epoch}) then
            return denied('active_scoped_native_owner_required')
        end
        local bound=copy(state.identity)
        if intent.scope and not same(intent.scope,bound) then return denied('equipment_panel_expired_reopen') end
        if intent.action=='shutdown' and Config.NativeAlphaLifecycleWearEnabled==true then
            local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
            local snapshot=exports['feather-inventory']:ReadNativeEquipmentTransition(context,nil)
            if not snapshot or not snapshot.ok or type(snapshot.value)~='table' then return denied('final_wear_snapshot_unavailable') end
            return {ok=true,value={identity=bound,spec={characterId=bound.characterId,action='shutdown',
                brokenEquipmentContract=snapshot.value.brokenEquipmentContract,
                brokenPromotionContract=snapshot.value.brokenPromotionContract,
                expected=copy(snapshot.value.expected),lifecycleSnapshot=copy(snapshot.value.equipment)}}}
        end
        if intent.action=='dry-run' or intent.action=='shutdown' then
            return {ok=true,value={identity=bound,spec={characterId=bound.characterId,action=intent.action}}}
        end
        if intent.slot=='weapon_throwable' and (intent.action=='equip' or intent.action=='unequip' or funding) then
            if not WeaponNativeThrowablePolicy or not WeaponNativeThrowablePolicy.Enabled() or not WeaponNativeThrowableItem then
                return denied('native_throwable_disabled')
            end
            local checked=WeaponCharacterAmmoService.ValidateLoadout(source)
            if not checked or not checked.ok then return denied('native_loadout_changed') end
            local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
            local read=exports['feather-inventory']:ReadNativeEquipmentTransition(context,intent.action=='equip' and intent.itemId or nil)
            if not read or not read.ok then return denied('throwable_equipment_snapshot_unavailable') end
            local preparation=copy(intent)
            if funding then
                if (intent.amount~=1 and intent.amount~=-1) or type(intent.operationId)~='string'
                    or #intent.operationId<1 or #intent.operationId>64 or intent.operationId:find('%c') then return denied('invalid_throwable_funding') end
                preparation.action='unequip'
            end
            local spec,why=WeaponNativeThrowableItem.Prepare(read.value,WeaponDefinitionCatalog,bound,preparation)
            if not spec then return denied(why) end
            if funding then
                local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
                if not registry then return denied('throwable_registry_unavailable') end
                spec.action='throwable-funding'; spec.amount=intent.amount; spec.operationId=intent.operationId
                spec.ammunitionId='ammo_tomahawk_regular'; spec.limits=copy(registry.limits)
            end
            local now=WeaponCharacterAmmoDispatcher.Status(source)
            if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                or not WeaponNativeThrowablePolicy.Enabled()
                or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
            return {ok=true,value={identity=bound,spec=spec}}
        end
        if (intent.slot=='weapon_utility' or intent.slot=='weapon_utility_secondary' or intent.slot=='weapon_utility_tertiary'
            or intent.slot=='weapon_utility_quaternary' or intent.slot=='weapon_utility_quinary'
            or intent.slot=='weapon_utility_septenary' or intent.slot=='weapon_utility_octonary' or intent.slot=='weapon_utility_senary') and (intent.action=='equip' or intent.action=='unequip') then
            if GetConvarInt('feather_native_utility',0)~=1 or not WeaponNativeUtilityItem
                or Config.NativeAlphaLifecycleWearEnabled~=true then return denied('native_utility_disabled') end
            local checked=WeaponCharacterAmmoService.ValidateLoadout(source)
            if not checked or not checked.ok then return denied('native_loadout_changed') end
            local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
            local read=exports['feather-inventory']:ReadNativeEquipmentTransition(context,intent.action=='equip' and intent.itemId or nil)
            if not read or not read.ok then return denied('utility_equipment_snapshot_unavailable') end
            local proposal={action=intent.action,slot=intent.slot,itemId=intent.itemId,selectedItemId=intent.selectedItemId}
            local logical=intent.slot:sub(8)
            local row=intent.action=='equip' and read.value.candidate
                or read.value.utilityEquipment and read.value.utilityEquipment.equipment[logical]
            local def=type(row)=='table' and type(row.metadata)=='table' and WeaponDefinitionCatalog.weapons[row.metadata.weaponDefinitionId]
            if not def then return denied('utility_definition_required') end
            local spec,why=WeaponNativeUtilityItem.Prepare(read.value,def,bound,proposal)
            if not spec then return denied(why) end
            local now=WeaponCharacterAmmoDispatcher.Status(source)
            if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                or GetConvarInt('feather_native_utility',0)~=1
                or (spec.lassoFamily and not WeaponNativeUtilityCatalog.ReinforcedEnabled())
                or (spec.davyFamily and not WeaponNativeUtilityCatalog.DavyEnabled())
                or (spec.binocularsFamily and not WeaponNativeUtilityCatalog.BinocularsEnabled())
                or (spec.cameraFamily and not WeaponNativeUtilityCatalog.CameraEnabled())
                or (spec.advancedCameraFamily and not WeaponNativeUtilityCatalog.AdvancedCameraEnabled())
                or (spec.metalDetectorFamily and not WeaponNativeUtilityCatalog.MetalDetectorEnabled())
                or (spec.fishingRodFamily and not WeaponNativeUtilityCatalog.FishingRodEnabled())
                or (spec.improvedBinocularsFamily and not WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled())
                or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
            return {ok=true,value={identity=bound,spec=spec}}
        end
        local meleeChange=false
        if WeaponNativeMeleeCatalog and GetConvarInt('feather_native_melee',0)==1 then
            for _,slot in pairs(WeaponNativeMeleeCatalog.Slots()) do
                if slot==intent.slot and (intent.action=='equip' or intent.action=='unequip') then meleeChange=true end
            end
        end
        if meleeChange then
            if Config.NativeAlphaLifecycleWearEnabled~=true then return denied('native_melee_disabled') end
            local checked=WeaponCharacterAmmoService.ValidateLoadout(source)
            if not checked or not checked.ok then return denied('native_loadout_changed') end
            local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
            local read=exports['feather-inventory']:ReadNativeEquipmentTransition(context,intent.action=='equip' and intent.itemId or nil)
            if not read or not read.ok then return denied('melee_equipment_snapshot_unavailable') end
            local spec,why=WeaponNativeMeleeCatalog.Prepare(read.value,WeaponDefinitionCatalog,bound,intent)
            if not spec then return denied(why) end
            local now=WeaponCharacterAmmoDispatcher.Status(source)
            if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                or GetConvarInt('feather_native_melee',0)~=1
                or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
            return {ok=true,value={identity=bound,spec=spec}}
        end
        local knifeChange=intent.slot=='weapon_melee' and (intent.action=='equip' or intent.action=='unequip')
        if knifeChange then
            if GetConvarInt('feather_native_knife',0)~=1 or not WeaponNativeKnife
                or Config.NativeAlphaLifecycleWearEnabled~=true then return denied('native_knife_disabled') end
            local checked=WeaponCharacterAmmoService.ValidateLoadout(source)
            if not checked or not checked.ok then return denied('native_loadout_changed') end
            local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
            local read=exports['feather-inventory']:ReadNativeEquipmentTransition(context,intent.action=='equip' and intent.itemId or nil)
            if not read or not read.ok then return denied('knife_equipment_snapshot_unavailable') end
            local spec,why=WeaponNativeKnife.Prepare(read.value,WeaponDefinitionCatalog.weapons.melee_knife,bound,intent)
            if not spec then return denied(why) end
            local now=WeaponCharacterAmmoDispatcher.Status(source)
            if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
            return {ok=true,value={identity=bound,spec=spec}}
        end
        local slots={weapon='primary',weapon_offhand='offhand',weapon_shoulder='shoulder',weapon_back='back'}
        local slot=slots[intent.slot]
        local metadataChange=intent.action=='repair' or intent.action=='maintenance' or attachmentChange
        if intent.action~='options' and not metadataChange and (not slot or (intent.action=='unequip' and intent.itemId~=nil)) then return denied('invalid_equipment_slot_or_item') end
        if metadataChange and (type(intent.itemId)~='number' or intent.itemId<1 or intent.itemId%1~=0 or intent.itemId==math.huge) then return denied('invalid_repair_item') end
        local checked=WeaponCharacterAmmoService.ValidateLoadout(source)
        if not checked or not checked.ok then return denied('native_loadout_changed') end
        local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
        local snapshot=exports['feather-inventory']:ReadNativeEquipmentTransition(context,(intent.action=='equip' or intent.action=='move' or intent.action=='options' or metadataChange) and intent.itemId or nil)
        if not snapshot or not snapshot.ok or type(snapshot.value)~='table' or snapshot.value.characterId~=bound.characterId then
            return denied('equipment_snapshot_unavailable')
        end
        local value=snapshot.value
        if type(value.expected)~='table' or type(value.equipment)~='table' then return denied('equipment_snapshot_invalid') end
        if intent.action=='options' then
            if type(value.candidate)~='table' or value.candidate.id~=intent.itemId then return denied('owned_candidate_required') end
            -- Advisory occupancy comes from this same authoritative snapshot,
            -- including slots that have no permitted action for the selected item.
            local slotOverview={}
            for _,entry in ipairs({
                {'weapon','Primary'},{'weapon_offhand','Offhand'},
                {'weapon_shoulder','Shoulder'},{'weapon_back','Back'},
                {'weapon_melee','Melee'},{'weapon_melee_secondary','Melee 2'},
                {'weapon_melee_tertiary','Melee 3'},{'weapon_melee_quaternary','Melee 4'},
                {'weapon_melee_quinary','Melee 5'},{'weapon_throwable','Throwable'},
                {'weapon_utility','Utility'},{'weapon_utility_secondary','Utility 2'},
            }) do
                local row=value.expected[entry[1]]
                slotOverview[#slotOverview+1]={slot=entry[1],label=entry[2],
                    state=row and (row.itemId==intent.itemId and 'selected' or 'occupied') or 'open',
                    itemId=row and row.itemId or nil}
            end
            if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.BinocularsEnabled() then
                local row=value.expected.weapon_utility_tertiary
                slotOverview[#slotOverview+1]={slot='weapon_utility_tertiary',label='Utility 3',
                    state=row and (row.itemId==intent.itemId and 'selected' or 'occupied') or 'open',itemId=row and row.itemId}
            end
            if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.CameraEnabled() then
                local row=value.expected.weapon_utility_quaternary
                slotOverview[#slotOverview+1]={slot='weapon_utility_quaternary',label='Utility 4',
                    state=row and (row.itemId==intent.itemId and 'selected' or 'occupied') or 'open',itemId=row and row.itemId}
            end
            if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.AdvancedCameraEnabled() then
                local row=value.expected.weapon_utility_quinary
                slotOverview[#slotOverview+1]={slot='weapon_utility_quinary',label='Utility 5',
                    state=row and (row.itemId==intent.itemId and 'selected' or 'occupied') or 'open',itemId=row and row.itemId}
            end
            if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() then
                local row=value.expected.weapon_utility_senary
                slotOverview[#slotOverview+1]={slot='weapon_utility_senary',label='Utility 6',
                    state=row and (row.itemId==intent.itemId and 'selected' or 'occupied') or 'open',itemId=row and row.itemId}
            end
            if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.MetalDetectorEnabled() then
                local row=value.expected.weapon_utility_septenary
                slotOverview[#slotOverview+1]={slot='weapon_utility_septenary',label='Utility 7',
                    state=row and (row.itemId==intent.itemId and 'selected' or 'occupied') or 'open',itemId=row and row.itemId}
            end
            if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.FishingRodEnabled() then
                local row=value.expected.weapon_utility_octonary
                slotOverview[#slotOverview+1]={slot='weapon_utility_octonary',label='Utility 8',
                    state=row and (row.itemId==intent.itemId and 'selected' or 'occupied') or 'open',itemId=row and row.itemId}
            end
            if value.candidate.metadata and value.candidate.metadata.weaponDefinitionId=='throwable_tomahawk' then
                if not WeaponNativeThrowablePolicy or not WeaponNativeThrowablePolicy.Enabled() or not WeaponNativeThrowableItem then
                    return denied('native_throwable_disabled')
                end
                local options={}
                for _,action in ipairs({'equip','unequip'}) do
                    if WeaponNativeThrowableItem.Prepare(value,WeaponDefinitionCatalog,bound,{action=action,
                        slot='weapon_throwable',itemId=action=='equip' and intent.itemId or nil,selectedItemId=intent.itemId}) then
                        options[#options+1]={action=action,slot='weapon_throwable',label=(action=='equip' and 'Equip' or 'Unequip')..' — Throwable'}
                    end
                end
                local now=WeaponCharacterAmmoDispatcher.Status(source)
                if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                    or not WeaponNativeThrowablePolicy.Enabled()
                    or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
                return {ok=true,value={identity=bound,options=options,slots=slotOverview,itemId=intent.itemId}}
            end
            if value.candidate.metadata and (value.candidate.metadata.weaponDefinitionId=='utility_lasso'
                or value.candidate.metadata.weaponDefinitionId=='utility_lasso_reinforced'
                or value.candidate.metadata.weaponDefinitionId=='utility_davy_lantern'
                or value.candidate.metadata.weaponDefinitionId=='utility_binoculars'
                or value.candidate.metadata.weaponDefinitionId=='utility_camera'
                or value.candidate.metadata.weaponDefinitionId=='utility_camera_advanced'
                or value.candidate.metadata.weaponDefinitionId=='utility_metal_detector'
                or value.candidate.metadata.weaponDefinitionId=='utility_fishing_rod'
                or value.candidate.metadata.weaponDefinitionId=='utility_binoculars_improved') then
                if not WeaponNativeUtilityCatalog or not WeaponNativeUtilityCatalog.Enabled() or not WeaponNativeUtilityItem then
                    return denied('native_utility_disabled')
                end
                local options={}
                local def=WeaponDefinitionCatalog.weapons[value.candidate.metadata.weaponDefinitionId]
                local utilitySlots={'weapon_utility','weapon_utility_secondary'}
                if WeaponNativeUtilityCatalog.BinocularsEnabled() then utilitySlots[#utilitySlots+1]='weapon_utility_tertiary' end
                if WeaponNativeUtilityCatalog.CameraEnabled() then utilitySlots[#utilitySlots+1]='weapon_utility_quaternary' end
                if WeaponNativeUtilityCatalog.AdvancedCameraEnabled() then utilitySlots[#utilitySlots+1]='weapon_utility_quinary' end
                if WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() then utilitySlots[#utilitySlots+1]='weapon_utility_senary' end
                if WeaponNativeUtilityCatalog.MetalDetectorEnabled() then utilitySlots[#utilitySlots+1]='weapon_utility_septenary' end
                if WeaponNativeUtilityCatalog.FishingRodEnabled() then utilitySlots[#utilitySlots+1]='weapon_utility_octonary' end
                for _,slot in ipairs(utilitySlots) do
                  for _,action in ipairs({'equip','unequip'}) do
                    local proposal={action=action,slot=slot,itemId=action=='equip' and intent.itemId or nil,selectedItemId=intent.itemId}
                    if WeaponNativeUtilityItem.Prepare(value,def,bound,proposal) then
                        local label=({weapon_utility='Utility',weapon_utility_secondary='Utility 2',weapon_utility_tertiary='Utility 3',weapon_utility_quaternary='Utility 4',weapon_utility_quinary='Utility 5',weapon_utility_septenary='Utility 7',weapon_utility_octonary='Utility 8',weapon_utility_senary='Utility 6'})[slot]
                        options[#options+1]={action=action,slot=slot,label=(action=='equip' and 'Equip' or 'Unequip')..' — '..label}
                    end
                  end
                end
                local now=WeaponCharacterAmmoDispatcher.Status(source)
                if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                    or not WeaponNativeUtilityCatalog.Enabled()
                    or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
                return {ok=true,value={identity=bound,options=options,slots=slotOverview,itemId=intent.itemId}}
            end
            local meleeDef=WeaponNativeMeleeCatalog and value.candidate.metadata and WeaponDefinitionCatalog.weapons
                and WeaponDefinitionCatalog.weapons[value.candidate.metadata.weaponDefinitionId]
            if WeaponNativeMeleeCatalog and WeaponNativeMeleeCatalog.Enabled() and WeaponNativeMeleeCatalog.Resolve(meleeDef) then
                local options={}
                local labels={'Melee','Melee 2','Melee 3','Melee 4','Melee 5'}
                for n,slot in ipairs({'weapon_melee','weapon_melee_secondary','weapon_melee_tertiary','weapon_melee_quaternary','weapon_melee_quinary'}) do
                    for _,action in ipairs({'equip','unequip'}) do
                        local proposal={action=action,slot=slot,itemId=action=='equip' and intent.itemId or nil,selectedItemId=intent.itemId}
                        if WeaponNativeMeleeCatalog.Prepare(value,WeaponDefinitionCatalog,bound,proposal) then
                            options[#options+1]={action=action,slot=slot,label=(action=='equip' and 'Equip' or 'Unequip')..' — '..labels[n]}
                        end
                    end
                end
                local now=WeaponCharacterAmmoDispatcher.Status(source)
                if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                    or not WeaponNativeMeleeCatalog.Enabled()
                    or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
                return {ok=true,value={identity=bound,options=options,slots=slotOverview,itemId=intent.itemId}}
            end
            if value.candidate.metadata and value.candidate.metadata.weaponDefinitionId=='melee_knife' then
                if not WeaponNativeKnife or not WeaponNativeKnife.Enabled() then return denied('native_knife_disabled') end
                local options={}
                for _,action in ipairs({'equip','unequip'}) do
                    local proposal={action=action,slot='weapon_melee',itemId=action=='equip' and intent.itemId or nil,
                        selectedItemId=intent.itemId}
                    local prepared=WeaponNativeKnife.Prepare(value,WeaponDefinitionCatalog.weapons.melee_knife,bound,proposal)
                    if prepared then options[#options+1]={action=action,slot='weapon_melee',label=(action=='equip' and 'Equip' or 'Unequip')..' — Melee'} end
                end
                local now=WeaponCharacterAmmoDispatcher.Status(source)
                if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                    or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
                return {ok=true,value={identity=bound,options=options,slots=slotOverview,itemId=intent.itemId}}
            end
            local catalog=copy(WeaponDefinitionCatalog)
            local registry=WeaponCharacterAmmoPolicy.Build(catalog)
            if not registry then return denied('equipment_catalog_unavailable') end
            local options,assigned={},nil
            for equipped,row in pairs(value.expected) do if row.itemId==intent.itemId then assigned=equipped end end
            local labels={weapon='Primary',weapon_offhand='Offhand',weapon_shoulder='Shoulder',weapon_back='Back'}
            for _,dbSlot in ipairs({'weapon','weapon_offhand','weapon_shoulder','weapon_back'}) do
                local action=assigned and assigned==dbSlot and 'unequip' or not assigned and 'equip' or nil
                if action then
                    local proposed=copy(value.equipment)
                    proposed[slots[dbSlot]]=action=='equip' and copy(value.candidate) or nil
                    local plan=WeaponCharacterAmmoMaterialization.Build(proposed,catalog,registry,bound)
                    if plan and WeaponCharacterAmmoMaterialization.Validate(plan,registry,bound)==true then
                        local occupant=value.equipment[slots[dbSlot]]
                        local definition=occupant and occupant.metadata and catalog.weapons
                            and catalog.weapons[occupant.metadata.weaponDefinitionId]
                        options[#options+1]={action=action,slot=dbSlot,
                            replacing=action=='equip' and occupant~=nil or nil,
                            occupantLabel=definition and definition.label or nil,
                            label=(action=='equip' and 'Equip — ' or 'Unequip — ')..labels[dbSlot]}
                    end
                end
            end
            local explanation
            if assigned=='weapon' or assigned=='weapon_offhand' then
                if value.equipment.primary and value.equipment.offhand then
                    local swapped=copy(value.equipment)
                    swapped.primary,swapped.offhand=swapped.offhand,swapped.primary
                    local plan=WeaponCharacterAmmoMaterialization.Build(swapped,catalog,registry,bound)
                    if plan and WeaponCharacterAmmoMaterialization.Validate(plan,registry,bound)==true then
                        options[#options+1]={action='move',slot=assigned=='weapon' and 'weapon_offhand' or 'weapon',label='Swap hands'}
                    end
                    if assigned=='weapon' then
                        local removed=copy(value.equipment); removed.primary=removed.offhand; removed.offhand=nil
                        local removal=WeaponCharacterAmmoMaterialization.Build(removed,catalog,registry,bound)
                        if removal and WeaponCharacterAmmoMaterialization.Validate(removal,registry,bound)==true then
                            options[#options+1]={action='unequip_primary',slot='weapon',label='Primary — Unequip'}
                            explanation='ui_equipment_promote_hint'
                        end
                    end
                else explanation='ui_equipment_primary_needed' end
            end
            -- Attachment buttons are advisory, read-only previews. The change
            -- coordinator independently repeats every check before payment.
            if assigned and attachmentEnabled() then
                local candidate=value.candidate
                local definition=candidate.metadata and WeaponDefinitionCatalog.weapons[candidate.metadata.weaponDefinitionId]
                local attachmentIds={}
                for id in pairs(WeaponDefinitionCatalog.attachments or {}) do attachmentIds[#attachmentIds+1]=id end
                table.sort(attachmentIds)
                for _,attachmentId in ipairs(attachmentIds) do
                local attachment=WeaponDefinitionCatalog.attachments[attachmentId]
                if definition and candidate.itemName==definition.itemName and attachment then
                    for _,action in ipairs({'install','remove'}) do
                        local plan=WeaponCharacterAttachments.Plan(candidate.metadata,definition,attachment,'attachment-'..action)
                        if plan then
                            local authorization=AttachmentService.AuthorizeNativeModification(source,context,action,definition,attachment)
                            if authorization and authorization.ok then
                                local material=exports['feather-inventory']:ReadNativeAttachmentMaterial(context,attachment.itemName)
                                if material and material.ok and (action=='remove' or
                                    (type(material.value.quantity)=='number' and material.value.quantity>=1)) then
                                    options[#options+1]={kind='attachment',action=action,attachmentId=attachment.id,
                                        label=(action=='install' and 'Install' or 'Remove')..' — '..attachment.label}
                                end
                            end
                        end
                    end
                end
                end
            end
            if Config.NativeAlphaRepairEnabled==true then
                local candidate=value.candidate
                local definition=candidate.metadata and WeaponDefinitionCatalog.weapons[candidate.metadata.weaponDefinitionId]
                if definition and candidate.itemName==definition.itemName then
                    local repaired,cost=WeaponCharacterMaintenance.Repair(candidate.metadata,definition)
                    if repaired then
                        local material=exports['feather-inventory']:ReadNativeRepairMaterial(context,cost.itemDefinitionId)
                        local quantity=material and material.ok and material.value.quantity
                        if type(quantity)=='number' and quantity%1==0 and quantity<math.huge and quantity>=cost.quantity then
                            options[#options+1]={kind='repair',action='repair',label='Clean / repair — '..cost.quantity..' '..cost.itemDefinitionId}
                        end
                    end
                end
            end
            local now=WeaponCharacterAmmoDispatcher.Status(source)
            if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
                return {ok=true,value={identity=bound,options=options,slots=slotOverview,itemId=intent.itemId,explanation=explanation}}
        end
        local spec={characterId=bound.characterId,action=intent.action,slot=intent.slot,expected=copy(value.expected)}
        spec.brokenEquipmentContract=value.brokenEquipmentContract
        spec.brokenPromotionContract=value.brokenPromotionContract
        if intent.periodic==true then spec.periodic=true end
        if Config.NativeAlphaLifecycleWearEnabled==true and (intent.action=='equip' or intent.action=='unequip' or intent.action=='move' or intent.action=='unequip_primary' or attachmentChange) then
            spec.lifecycleSnapshot=copy(value.equipment)
        end
        local proposed=copy(value.equipment)
        if metadataChange then
            local candidate=value.candidate
            if type(candidate)~='table' or candidate.id~=intent.itemId then return denied('owned_repair_item_required') end
            local definition=type(candidate.metadata)=='table' and WeaponDefinitionCatalog.weapons[candidate.metadata.weaponDefinitionId]
            if not definition or candidate.itemName~=definition.itemName then return denied('invalid_repair_definition') end
            local repaired,cost
            if attachmentChange then
                local assigned=false
                for _,row in pairs(value.expected) do if row.itemId==candidate.id then assigned=true end end
                if not assigned then
                    return denied('native_attachment_equipped_owned_item_required')
                end
                local attachment=WeaponDefinitionCatalog.attachments and WeaponDefinitionCatalog.attachments[intent.attachmentId or 'carbine_wide_sight']
                if not attachment then return denied('attachment_definition_unavailable') end
                local authorized=AttachmentService.AuthorizeNativeModification(source,context,
                    intent.action=='attachment-install' and 'install' or 'remove',definition,attachment)
                if not authorized or not authorized.ok then return authorized or denied('attachment_authorization_unavailable') end
                local projected,why=WeaponCharacterAttachments.Plan(candidate.metadata,definition,attachment,intent.action)
                if not projected then return denied(why) end
                local material=exports['feather-inventory']:ReadNativeAttachmentMaterial(context,attachment.itemName)
                if not material or not material.ok then return denied('attachment_material_definition_unavailable') end
                if intent.action=='attachment-install' and (type(material.value.quantity)~='number' or material.value.quantity<1) then
                    return denied('attachment_material_required_before_release')
                end
                spec.attachmentId=projected.attachmentId
                spec.attachmentPolicy={definitionId=attachment.id,slot=attachment.slot,itemName=attachment.itemName,
                    weaponDefinitionId=definition.id,weaponItemName=definition.itemName}
                spec.material=copy(projected.material); spec.material.definitionId=material.value.definitionId
                repaired=projected.after
            elseif intent.action=='maintenance' then
                local assigned=false
                for _,row in pairs(value.expected) do if row.itemId==candidate.id then assigned=true end end
                if not assigned or candidate.revision~=intent.itemRevision then return denied('maintenance_owned_revision_changed') end
                repaired,cost=WeaponCharacterMaintenance.Observe(candidate.metadata,definition,intent.report)
                if repaired then
                    local changed=repaired.condition~=candidate.metadata.condition
                    for key,v in pairs(repaired.maintenance) do changed=changed or v~=candidate.metadata.maintenance[key] end
                    if not changed then return denied('native_maintenance_unchanged') end
                end
            else repaired,cost=WeaponCharacterMaintenance.Repair(candidate.metadata,definition) end
            if not repaired then return denied(cost) end
            if intent.action=='repair' then
            local material=exports['feather-inventory']:ReadNativeRepairMaterial(context,cost.itemDefinitionId)
            if not material or not material.ok then return denied('repair_material_definition_unavailable') end
            if type(material.value.quantity)~='number' or material.value.quantity%1~=0
                or material.value.quantity==math.huge or material.value.quantity<cost.quantity then
                return denied('repair_material_required_before_release')
            end
            spec.material={definitionId=material.value.definitionId,itemName=cost.itemDefinitionId,quantity=cost.quantity}
            end
            spec.itemId,spec.itemRevision=candidate.id,candidate.revision
            spec.before,spec.after=copy(candidate.metadata),repaired
            for logical,row in pairs(proposed) do
                if row.id==candidate.id then row.metadata=copy(repaired) end
            end
        elseif intent.action=='move' then
            local candidate=value.candidate
            local origin
            for equipped,row in pairs(value.expected) do if row.itemId==intent.itemId then origin=equipped end end
            local sidearms={weapon=true,weapon_offhand=true}
            if not sidearms[origin] or not sidearms[intent.slot] or origin==intent.slot
                or not value.expected[intent.slot] or not candidate or candidate.id~=intent.itemId
                or candidate.revision~=value.expected[origin].revision then return denied('sidearm_swap_changed') end
            spec.fromSlot=origin; spec.itemId=candidate.id; spec.itemRevision=candidate.revision
            proposed[slots[origin]],proposed[slot]=proposed[slot],proposed[slots[origin]]
        elseif intent.action=='unequip_primary' then
            if intent.slot~='weapon' or intent.itemId~=nil or not value.expected.weapon or not value.expected.weapon_offhand
                or intent.selectedItemId~=value.expected.weapon.itemId then return denied('selected_sidearms_changed') end
            proposed.primary=proposed.offhand; proposed.offhand=nil
        elseif intent.action=='equip' then
            local candidate=value.candidate
            if type(candidate)~='table' or candidate.id~=intent.itemId then return denied('owned_candidate_required') end
            for equipped,row in pairs(value.expected) do
                if row.itemId==candidate.id then return denied('item_already_equipped') end
            end
            spec.itemId,spec.itemRevision=candidate.id,candidate.revision
            proposed[slot]=copy(candidate)
        else
            if not value.expected[intent.slot] then return denied('slot_not_equipped') end
            if intent.selectedItemId and value.expected[intent.slot].itemId~=intent.selectedItemId then
                return denied('selected_equipment_changed')
            end
            proposed[slot]=nil
        end
        local catalog=copy(WeaponDefinitionCatalog)
        if intent.action=='maintenance' then
            local detached,why=WeaponCharacterLifecycleWear.BrokenEquipment(proposed,catalog)
            if not detached then return denied(why) end
            if next(detached) and spec.brokenEquipmentContract~=1 then return denied('broken_equipment_inventory_update_required') end
            spec.brokenEquipment=detached
            if detached.weapon_offhand and detached.weapon_offhand.promote and spec.brokenPromotionContract~=1 then return denied('broken_promotion_inventory_update_required') end
            proposed=WeaponCharacterLifecycleWear.ProjectBroken(proposed,detached)
        end
        local registry=WeaponCharacterAmmoPolicy.Build(catalog)
        if not registry then return denied('equipment_catalog_unavailable') end
        local plan,reason=WeaponCharacterAmmoMaterialization.Build(proposed,catalog,registry,bound)
        if not plan then return denied(reason or 'equipment_loadout_invalid') end
        -- Reject unsupported customization before retiring the current copies.
        local valid=WeaponCharacterAmmoMaterialization.Validate(plan,registry,bound)
        if not valid then return denied('equipment_creation_not_supported') end
        local now=WeaponCharacterAmmoDispatcher.Status(source)
        if not now or now.phase~='active' or now.busy or not same(now.identity,bound) then return denied('native_owner_changed') end
        if spec.periodic and Config.NativeAlphaPeriodicWearEnabled~=true then return denied('native_periodic_wear_disabled') end
        return {ok=true,value={identity=bound,spec=spec}}
    end,
    current=function(source,identity)
        return enabled() and WeaponNativeEnrollment.Allows(Config,identity.characterId)
            and CoreAdapter.IsSessionCurrent(source,identity.sessionId,identity.characterId)==true
    end,
    released=function(source,identity)
        local state=WeaponCharacterAmmoDispatcher.Status(source)
        return state and state.phase=='released' and not state.busy and same(state.identity,identity) or false
    end,
    ticket=function(source) sequence=sequence+1; return ('equipment:%s:%s:%s'):format(source,GetGameTimer(),sequence) end,
    requestRelease=function(source,request)
        pending[source]=copy(request)
        if periodicIntent[source] and same(periodicIntent[source],request.identity) then pending[source].periodic=true end
        TriggerClientEvent('feather-weapons:client:native-equipment-release',source,request)
        local deadline=WeaponGuidAcceptanceServer and WeaponGuidAcceptanceServer.Timeout(source) or 45000
        SetTimeout(deadline,function()
            if pending[source] and pending[source].ticket==request.ticket then
                local state=coordinator.Status(source)
                if state and state.phase~='active' then coordinator.Cancel(source,request.identity.sessionId) end
            end
        end)
        return true
    end,
    finalizeSpec=function(context,spec,wear)
        if not spec.lifecycleSnapshot then return {ok=true,value=spec} end
        if Config.NativeAlphaLifecycleWearEnabled~=true then return denied('final_wear_gate_changed') end
        local changes,reason,detached=WeaponCharacterLifecycleWear.Plan(spec.lifecycleSnapshot,wear,WeaponDefinitionCatalog,context.epoch,true)
        if not changes then return denied(reason) end
        if next(detached or {}) and spec.brokenEquipmentContract~=1 then return denied('broken_equipment_inventory_update_required') end
        if detached and detached.weapon_offhand and detached.weapon_offhand.promote and spec.brokenPromotionContract~=1 then return denied('broken_promotion_inventory_update_required') end
        spec.lifecycleWear=changes
        spec.brokenEquipment=detached
        if spec.action=='throwable-funding' then
            -- Read only after final seal/release: a last throw may have advanced
            -- the durable ledger since equipment preflight.
            if not WeaponNativeThrowablePolicy.Enabled() then return denied('native_throwable_disabled') end
            local read=exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot(context,spec.limits)
            local snapshot=read and read.ok and read.value
            local approval=snapshot and WeaponNativeThrowableItem.Assigned(snapshot.throwableEquipment,
                WeaponDefinitionCatalog,{characterId=context.characterId,sessionId=context.sessionId,epoch=context.epoch},spec.limits)
            if not approval or approval.row.id~=spec.throwableId or approval.row.revision~=spec.throwableRevision then
                return denied('throwable_funding_assignment_changed')
            end
            spec.expectedRevision=snapshot.revision; spec.expectedPools=copy(snapshot.pools)
        end
        if spec.action=='attachment-install' or spec.action=='attachment-remove' then
            for _,change in ipairs(changes) do
                if change.itemId==spec.itemId then
                    spec.after.condition=change.after.condition
                    spec.after.maintenance=copy(change.after.maintenance)
                end
            end
        end
        return {ok=true,value=spec}
    end,
    commit=function(context,spec)
        if not coordinator.CanCommit(context,spec) then return denied('equipment_commit_ticket_denied') end
        if spec.periodic and Config.NativeAlphaPeriodicWearEnabled~=true then return denied('native_periodic_wear_disabled') end
        if spec.action=='shutdown' then
            if spec.lifecycleSnapshot then
                local result=exports['feather-inventory']:CommitNativeEquipmentTransition(context,spec)
                if not result or not result.ok then return result or denied('final_wear_commit_uncertain') end
            end
            stopping[context.actorSource]={characterId=context.characterId,sessionId=context.sessionId,epoch=context.epoch}
            return {ok=true,value={unchanged=true}}
        end
        if spec.action=='dry-run' then return {ok=true,value={unchanged=true}} end
        if spec.utility==true then
            if GetConvarInt('feather_native_utility',0)~=1 or not WeaponNativeUtilityItem
                or Config.NativeAlphaLifecycleWearEnabled~=true or not coordinator.CanCommit(context,spec)
                or (spec.lassoFamily and not WeaponNativeUtilityCatalog.ReinforcedEnabled())
                or (spec.davyFamily and not WeaponNativeUtilityCatalog.DavyEnabled())
                or (spec.binocularsFamily and not WeaponNativeUtilityCatalog.BinocularsEnabled())
                or (spec.cameraFamily and not WeaponNativeUtilityCatalog.CameraEnabled())
                or (spec.advancedCameraFamily and not WeaponNativeUtilityCatalog.AdvancedCameraEnabled())
                or (spec.metalDetectorFamily and not WeaponNativeUtilityCatalog.MetalDetectorEnabled())
                or (spec.fishingRodFamily and not WeaponNativeUtilityCatalog.FishingRodEnabled())
                or (spec.improvedBinocularsFamily and not WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled()) then
                return denied('native_utility_commit_disabled')
            end
            return exports['feather-inventory']:CommitNativeUtilityEquipment(context,spec)
        end
        if spec.throwable==true then
            if not WeaponNativeThrowablePolicy or not WeaponNativeThrowablePolicy.Enabled() or not WeaponNativeThrowableItem
                or not coordinator.CanCommit(context,spec) then return denied('native_throwable_commit_disabled') end
            if spec.action=='throwable-funding' then
                if pending[context.actorSource] then pending[context.actorSource].action=spec.action end
                return exports['feather-inventory']:CommitNativeThrowableFunding(context,spec)
            end
            return exports['feather-inventory']:CommitNativeThrowableEquipment(context,spec)
        end
        if spec.melee==true then
            if GetConvarInt('feather_native_melee',0)~=1 or not WeaponNativeMeleeCatalog
                or not coordinator.CanCommit(context,spec) then return denied('native_melee_commit_disabled') end
            return exports['feather-inventory']:CommitNativeMeleeEquipment(context,spec)
        end
        if spec.slot=='weapon_melee' then
            if GetConvarInt('feather_native_knife',0)~=1 or not WeaponNativeKnife
                or not coordinator.CanCommit(context,spec) then return denied('native_knife_commit_disabled') end
            return exports['feather-inventory']:CommitNativeKnifeEquipment(context,spec)
        end
        if spec.action=='attachment-install' or spec.action=='attachment-remove' then
            if not attachmentEnabled() or not WeaponNativeAttachmentMappings.Resolve(
                WeaponDefinitionCatalog.weapons[spec.before.weaponDefinitionId],
                WeaponDefinitionCatalog.attachments[spec.attachmentId],true) then return denied('native_attachment_transactions_disabled') end
            local policy=AttachmentService.AuthorizeNativeModification(context.actorSource,context,
                spec.action=='attachment-install' and 'install' or 'remove',
                WeaponDefinitionCatalog.weapons[spec.before.weaponDefinitionId],WeaponDefinitionCatalog.attachments[spec.attachmentId])
            if not policy or not policy.ok then return policy or denied('attachment_authorization_unavailable') end
            if not coordinator.CanCommit(context,spec) then return denied('attachment_commit_authority_changed') end
            local request=pending[context.actorSource]
            local probe=attachmentDisconnect[context.actorSource]
            local interrupt=probe and same(probe.identity,context) and probe.itemId==spec.itemId
                and probe.action==spec.action and probe.attachmentId==spec.attachmentId
                and GetConvarInt('feather_native_attachment_disconnect_probe',0)==1
                and GetResourceState('feather-weapons-native-proof')=='stopped'
            -- Consume before yielding into storage: never disconnect twice or replay.
            if probe then attachmentDisconnect[context.actorSource]=nil end
            local result=exports['feather-inventory']:CommitNativeAttachmentTransition(context,spec)
            if interrupt and result and result.ok and attachmentEnabled()
                and GetConvarInt('feather_native_attachment_disconnect_probe',0)==1
                and CoreAdapter.IsSessionCurrent(context.actorSource,context.sessionId,context.characterId) then
                print('[WeaponNativeAttachmentDisconnect] COMMIT confirmed; disconnecting scoped player before completion')
                DropPlayer(context.actorSource,'Scoped attachment recovery test: reconnect to verify the durable result.')
                for _=1,50 do
                    if not CoreAdapter.IsSessionCurrent(context.actorSource,context.sessionId,context.characterId) then break end
                    Wait(100)
                end
                if CoreAdapter.IsSessionCurrent(context.actorSource,context.sessionId,context.characterId) then
                    return denied('attachment_probe_retirement_unconfirmed_no_retry')
                end
                print('[WeaponNativeAttachmentDisconnect] OBSERVED old session retired before completion; verify reconnect snapshot')
            end
            if result and result.ok and request and pending[context.actorSource]==request
                and same(request.identity,context) then
                request.action=spec.action
                request.repairSpec=copy(spec)
            end
            return result
        end
        if spec.action=='repair' or spec.action=='maintenance' then
            if spec.action=='repair' and Config.NativeAlphaRepairEnabled~=true then return denied('native_repair_disabled') end
            if spec.action=='maintenance' and Config.NativeAlphaMaintenanceEnabled~=true then return denied('native_maintenance_disabled') end
            local request=pending[context.actorSource]
            local result=exports['feather-inventory']:CommitNativeRepairTransition(context,spec)
            if result and result.ok and request and pending[context.actorSource]==request
                and same(request.identity,context) then
                request.action=spec.action; request.repairSpec=copy(spec)
            end
            return result
        end
        return exports['feather-inventory']:CommitNativeEquipmentTransition(context,spec)
    end,
    rebuild=function(source)
        if WeaponGuidAcceptanceServer and WeaponGuidAcceptanceServer.Reserved(source)
            and WeaponGuidAcceptanceServer.BeforeRebuild(source)~=true then return denied('guid_suite_cleanup_unconfirmed') end
        local request=pending[source]
        local spec=request and request.repairSpec
        if spec then
            local snapshot=exports['feather-inventory']:ReadNativeEquipmentTransition(
                {actorSource=source,characterId=request.identity.characterId,sessionId=request.identity.sessionId},spec.itemId)
            if not snapshot or not snapshot.ok or type(snapshot.value)~='table' then return denied('repair_postcommit_snapshot_unavailable') end
            local value=snapshot.value
            if type(value.expected)~='table' then return denied('repair_postcommit_equipment_invalid') end
            local wearRevisions={}
            if spec.action=='attachment-install' or spec.action=='attachment-remove' then
                for _,change in ipairs(spec.lifecycleWear or {}) do wearRevisions[change.itemId]=1 end
            end
            for slot,expected in pairs(spec.expected) do
                local actual=value.expected[slot]
                local revision=expected.revision+(expected.itemId==spec.itemId and 1 or 0)+(wearRevisions[expected.itemId] or 0)
                local removed=spec.brokenEquipment and spec.brokenEquipment[slot]
                local promotion=slot=='weapon' and spec.brokenEquipment and spec.brokenEquipment.weapon_offhand
                if promotion and promotion.promote then
                    local old=spec.expected.weapon_offhand
                    if not actual or actual.itemId~=promotion.itemId or actual.revision~=old.revision+(wearRevisions[old.itemId] or 0)
                        +(old.itemId==spec.itemId and 1 or 0) then return denied('repair_postcommit_equipment_changed') end
                elseif removed and (removed.itemId~=expected.itemId or actual~=nil)
                    or not removed and (not actual or actual.itemId~=expected.itemId or actual.revision~=revision) then
                    return denied('repair_postcommit_equipment_changed')
                end
            end
            for slot in pairs(value.expected) do if not spec.expected[slot] then return denied('repair_postcommit_equipment_changed') end end
            local candidate=value.candidate
            local function equal(a,b,path)
                if type(a)~=type(b) then return false end
                if type(a)~='table' then
                    -- JSON decimal precision must not strand a confirmed wear
                    -- commit. Tolerance applies only to known unit wear fields.
                    local wear={['maintenance.degradation']=true,['maintenance.permanentDegradation']=true,
                        ['maintenance.damage']=true,['maintenance.dirt']=true,['maintenance.soot']=true}
                    if wear[path] and type(a)=='number' and a==a and b==b and a>=0 and a<=1 and b>=0 and b<=1 then
                        return math.abs(a-b)<=0.000000000001
                    end
                    return a==b
                end
                for k,v in pairs(a) do
                    if not equal(v,b[k],path and (path..'.'..tostring(k)) or tostring(k)) then return false end
                end
                for k in pairs(b) do if a[k]==nil then return false end end
                return true
            end
            if not candidate or candidate.id~=spec.itemId or candidate.revision~=spec.itemRevision+1+(wearRevisions[spec.itemId] or 0)
                or not equal(candidate.metadata,spec.after) then return denied('repair_postcommit_item_changed') end
        end
        return WeaponCharacterAmmoDispatcher.Start(source)
    end,
    restored=function(source,identity)
        local state=WeaponCharacterAmmoDispatcher.Status(source)
        return state and state.phase=='active' and not state.busy and same(state.identity,identity) or false
    end,
}
coordinator=WeaponNativeEquipmentTransition.New(adapters)
-- Development orchestrator uses the same coordinator, never console parsing or
-- a parallel equipment implementation. It cannot request economic writes.
function WeaponNativeEquipmentBindings.AcceptanceTransition(target,overlap)
    if Config.DevMode~=true or not enabled() or not (GetConvarInt('feather_native_acceptance_suite',0)==1
        or (overlap~=true and GetConvarInt('feather_native_restart_suite',0)==1))
        or GetResourceState('feather-weapons-native-proof')~='stopped' then return denied('acceptance_disabled') end
    local state=WeaponCharacterAmmoDispatcher.Status(target)
    if not state or state.phase~='active' or state.busy or not identity(state.identity) then return denied('active_owner_required') end
    return overlap and WeaponNativeEquipmentTransition.ProbeOverlap(coordinator,target,copy(state.identity))
        or coordinator.Begin(target,{action='dry-run'})
end
function WeaponNativeEquipmentBindings.GuidValidationTransition(target)
    if not WeaponGuidAcceptanceServer or not WeaponGuidAcceptanceServer.Reserved(target)
        or GetConvarInt('feather_native_guid_suite',0)~=1 or not enabled()
        or GetResourceState('feather-weapons-native-proof')~='stopped' then return denied('guid_suite_not_reserved') end
    return coordinator.Begin(target,{action='dry-run'})
end
function WeaponNativeEquipmentBindings.AcceptanceStatus(target) return coordinator.Status(target) end
exports('ReadNativeMaintenanceAuditSpec',function(target,itemId)
    if GetInvokingResource()~='feather-inventory' or not enabled() or Config.NativeAlphaMaintenanceEnabled~=true
        or type(itemId)~='number' or itemId<1 or itemId%1~=0 or itemId==math.huge then return denied('maintenance_audit_denied') end
    local session=CoreAdapter.ResolveSession(target)
    local state=WeaponCharacterAmmoDispatcher.Status(target)
    local transition=coordinator.Status(target)
    if not session or not session.ok or not WeaponNativeEnrollment.Allows(Config,session.value.characterId)
        or not state or state.phase~='active' or state.busy or not identity(state.identity)
        or (transition and transition.phase~='active') then return denied('maintenance_audit_owner_required') end
    local bound=copy(state.identity)
    if bound.characterId~=session.value.characterId or bound.sessionId~=session.value.sessionId then return denied('maintenance_audit_context_changed') end
    local read=exports['feather-inventory']:ReadNativeEquipmentTransition(
        {actorSource=target,characterId=bound.characterId,sessionId=bound.sessionId},itemId)
    local value=read and read.ok and read.value
    local item=value and value.candidate
    local assigned=false
    for _,row in pairs(value and value.expected or {}) do if row.itemId==itemId then assigned=true end end
    local definition=item and item.metadata and WeaponDefinitionCatalog.weapons[item.metadata.weaponDefinitionId]
    local now=WeaponCharacterAmmoDispatcher.Status(target)
    if not assigned or not definition or item.itemName~=definition.itemName
        or not WeaponCharacterAmmoItem.Validate(item.metadata,definition)
        or not now or now.phase~='active' or now.busy or not same(now.identity,bound)
        or not CoreAdapter.IsSessionCurrent(target,bound.sessionId,bound.characterId) then return denied('maintenance_audit_snapshot_changed') end
    return {ok=true,value={characterId=bound.characterId,itemId=itemId,itemRevision=item.revision,
        before=copy(item.metadata),conditionMaximum=definition.condition.maximum}}
end)
exports('ReadNativeRepairAuditSpec',function(target,itemId)
    if GetInvokingResource()~='feather-inventory' or not enabled()
        or Config.NativeAlphaRepairEnabled~=true or GetResourceState('feather-weapons-native-proof')~='stopped'
        or type(target)~='number' or target<1 or target%1~=0 or target==math.huge then return denied('repair_audit_denied') end
    local state=coordinator.Status(target)
    if state and state.phase~='active' then return denied('repair_transition_in_flight') end
    local result=adapters.prepare(target,{action='repair',itemId=itemId})
    if not result.ok then return result end
    state=coordinator.Status(target)
    if state and state.phase~='active' then return denied('repair_transition_in_flight') end
    return {ok=true,value=copy(result.value.spec)} -- no reservation/release/write
end)
local function replyUI(target,result)
    local request=uiPending[target]
    if not request then return end
    uiPending[target]=nil
    TriggerClientEvent('feather-weapons:client:native-equipment-result',target,request.id,request.scope,result)
end
RegisterNetEvent('feather-weapons:server:native-equipment-ui',function(id,kind,intent)
    local target=source
    if not enabled() or GetResourceState('feather-weapons-native-proof')~='stopped'
        or type(id)~='string' or #id<1 or #id>128 or type(intent)~='table'
        or not identity(intent.scope) or uiPending[target] then return end
    if kind~='options' and kind~='change' and kind~='attachment-change' and kind~='repair-change' then return end
    if kind=='repair-change' and (Config.NativeAlphaRepairEnabled~=true or intent.action~='repair') then return end
    if kind=='attachment-change' and (not attachmentEnabled()
        or (intent.action~='install' and intent.action~='remove')) then return end
    if intent.attachmentId~=nil and (type(intent.attachmentId)~='string' or #intent.attachmentId<1 or #intent.attachmentId>100) then return end
    if kind=='change' and intent.action~='equip' and intent.action~='unequip' and intent.action~='move' and intent.action~='unequip_primary' then return end
    if type(intent.itemId)~='number' or intent.itemId<1 or intent.itemId%1~=0 or intent.itemId==math.huge then return end
    local slots={weapon=true,weapon_offhand=true,weapon_shoulder=true,weapon_back=true,
        weapon_melee=WeaponNativeKnife and WeaponNativeKnife.Enabled() or nil}
    if WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled() then slots.weapon_throwable=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Enabled() then slots.weapon_utility=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Slots().weapon_utility_secondary then slots.weapon_utility_secondary=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Slots().weapon_utility_tertiary then slots.weapon_utility_tertiary=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Slots().weapon_utility_quaternary then slots.weapon_utility_quaternary=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Slots().weapon_utility_quinary then slots.weapon_utility_quinary=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Slots().weapon_utility_senary then slots.weapon_utility_senary=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Slots().weapon_utility_octonary then slots.weapon_utility_octonary=true end
    if WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Slots().weapon_utility_septenary then slots.weapon_utility_septenary=true end
    if WeaponNativeMeleeCatalog and WeaponNativeMeleeCatalog.Enabled() then
        for _,slot in pairs(WeaponNativeMeleeCatalog.Slots()) do slots[slot]=true end
    end
    if kind=='change' and (type(intent.slot)~='string' or not slots[intent.slot]) then return end
    -- Copy only the bounded protocol fields, never recursively copy arbitrary
    -- client scope keys/tables. Limits apply before Core or Inventory may yield.
    local scope={characterId=intent.scope.characterId,sessionId=intent.scope.sessionId,epoch=intent.scope.epoch}
    if not allowUI(target,kind=='options' and 'options' or 'change') then
        TriggerClientEvent('feather-weapons:client:native-equipment-result',target,id,scope,denied('equipment_rate_limited'))
        return
    end
    local request={id=id,scope=scope}; uiPending[target]=request -- reserve before Core/SQL yields
    local safe={action=kind=='options' and 'options' or intent.action,slot=kind=='change' and intent.slot or nil,
        itemId=intent.itemId,scope=copy(scope)}
    -- Native attachments use the same sealed coordinator, never the legacy RPC.
    -- Client supplies intent only; prepare resolves catalog/material/assignment.
    if kind=='attachment-change' then safe.action='attachment-'..intent.action; safe.attachmentId=intent.attachmentId end
    if kind=='repair-change' then safe.action='repair' end
    if kind=='change' then
        -- UI identifies the clicked item even for Unequip. Resolve its actual
        -- assigned slot from fresh server options, not the client's slot hint.
        local called,preview=pcall(adapters.prepare,target,{action='options',itemId=intent.itemId,scope=safe.scope})
        if uiPending[target]~=request then return end
        if not called or not preview or not preview.ok then return replyUI(target,denied('equipment_preview_changed')) end
        local valid=false
        for _,option in ipairs(preview.value.options) do if option.action==safe.action and option.slot==safe.slot then valid=true end end
        if not valid then return replyUI(target,denied('equipment_option_unavailable')) end
        if safe.action=='unequip' or safe.action=='unequip_primary' then safe.selectedItemId=safe.itemId; safe.itemId=nil end
    end
    if uiPending[target]~=request then return end
    local called,result=pcall(kind=='options' and adapters.prepare or coordinator.Begin,target,safe)
    if uiPending[target]~=request then return end
    if not called then return replyUI(target,denied('equipment_request_uncertain_no_retry')) end
    if kind=='options' or not result.ok then return replyUI(target,result) end
    SetTimeout(45000,function()
        if uiPending[target]==request then replyUI(target,denied('equipment_completion_timeout_no_retry')) end
    end)
end)
function WeaponNativeEquipmentBindings.Attach(source,bundle)
    local request=pending[source]
    local state=coordinator.Status(source)
    if request and state and state.phase=='rebuilding' then
        bundle.equipmentTransition={ticket=request.ticket,oldEpoch=request.identity.epoch}
    end
end
function WeaponNativeEquipmentBindings.IsStopping(source) return stopping[source]~=nil or (drain and drain.IsLatched()) or false end
exports('ValidateNativeEquipmentCommit',function(context,spec)
    -- Inventory cannot manufacture or reuse an intent after the writing phase.
    return GetInvokingResource()=='feather-inventory' and enabled()
        and type(spec)=='table' and (spec.action=='equip' or spec.action=='unequip' or spec.action=='move' or spec.action=='unequip_primary'
            or (spec.action=='throwable-funding' and WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled())
            or (spec.action=='repair' and Config.NativeAlphaRepairEnabled==true)
            or (spec.action=='maintenance' and Config.NativeAlphaMaintenanceEnabled==true)
            or ((spec.action=='attachment-install' or spec.action=='attachment-remove') and attachmentEnabled()
                and type(spec.before)=='table' and WeaponNativeAttachmentMappings.Resolve(
                    WeaponDefinitionCatalog.weapons[spec.before.weaponDefinitionId],WeaponDefinitionCatalog.attachments[spec.attachmentId],true)~=nil)
            or (spec.action=='shutdown' and spec.lifecycleSnapshot~=nil and Config.NativeAlphaLifecycleWearEnabled==true))
        -- Shutdown wear is a metadata-only reserved commit, not equipment removal.
        and (spec.lifecycleSnapshot==nil or Config.NativeAlphaLifecycleWearEnabled==true)
        and (spec.periodic~=true or Config.NativeAlphaPeriodicWearEnabled==true)
        -- Maintenance uses the same exact reservation and released authority.
        and coordinator.CanCommit(context,spec)==true
end)
RegisterNetEvent('feather-weapons:server:native-equipment-released',function(ticket,identity,success,wear)
    local playerSource=source
    if not enabled() then return end
    local request=pending[playerSource]
    if not request or ticket~=request.ticket or not same(identity,request.identity) then return end
    if success~=true then
        coordinator.Cancel(playerSource,request.identity.sessionId)
        replyLogout(playerSource,denied('logout_wear_release_failed_no_retry'))
        replyUI(playerSource,denied('equipment_release_failed_no_retry'))
        return print('[WeaponNativeEquipmentDryRun] FAIL client release refused; ownership retained')
    end
    local cleanWear
    if request.collectWear then
        if type(wear)~='table' or wear.epoch~=request.identity.epoch or type(wear.items)~='table' then
            return print('[WeaponNativeEquipmentTransition] FAIL final wear report missing; no commit requested')
        end
        cleanWear={epoch=wear.epoch,items={}}
        local count=0
        for index,item in pairs(wear.items) do
            count=count+1
            if count>4 or type(index)~='number' or index<1 or index>4 or index%1~=0 or type(item)~='table'
                or type(item.itemInstanceId)~='number' or item.itemInstanceId<1 or item.itemInstanceId%1~=0 or item.itemInstanceId==math.huge
                or type(item.itemRevision)~='number' or item.itemRevision<0 or item.itemRevision%1~=0 or item.itemRevision==math.huge
                or type(item.maintenance)~='table' then return print('[WeaponNativeEquipmentTransition] FAIL invalid final wear report; no commit requested') end
            local maintenance={}
            for _,key in ipairs({'degradation','permanentDegradation','damage','dirt','soot'}) do
                local v=item.maintenance[key]
                if type(v)~='number' or v~=v or v<0 or v>1 then return print('[WeaponNativeEquipmentTransition] FAIL invalid final wear values; no commit requested') end
                maintenance[key]=v
            end
            cleanWear.items[index]={itemInstanceId=item.itemInstanceId,itemRevision=item.itemRevision,maintenance=maintenance}
        end
    end
    local result=coordinator.Released(playerSource,ticket,identity,cleanWear)
    if result.ok and result.value.phase=='parked' then
        pending[playerSource]=nil
        replyLogout(playerSource,{ok=true,value={released=true}})
        print('[WeaponNativePrepareStop] PASS final seal/owned cleanup/server release; ready to stop resource; no equipment/ammo economic writes')
    end
    if not result.ok then
        if request.periodic then periodic.Complete(playerSource,request.identity,'commit_or_rebuild_refused') end
        replyLogout(playerSource,result)
        replyUI(playerSource,result)
        local state=coordinator.Status(playerSource)
        print('[WeaponNativeEquipmentTransition] FAIL '..tostring(result.error.code)
            ..' commitOutcome='..tostring(state and state.commitOutcome or 'not_started')
            ..' committed='..tostring(state and state.committed==true)
            ..' rebuildReason='..tostring(state and state.rebuildReason))
    end
end)
RegisterNetEvent('feather-weapons:server:native-logout-wear',function(id,scope)
    local target=source
    if not enabled() or Config.NativeAlphaLifecycleWearEnabled~=true
        or GetResourceState('feather-weapons-native-proof')~='stopped'
        or type(id)~='string' or #id<1 or #id>128 or not identity(scope)
        or logoutPending[target] then return end
    local bound={characterId=scope.characterId,sessionId=scope.sessionId,epoch=scope.epoch}
    if not allowUI(target,'change') then
        TriggerClientEvent('feather-weapons:client:native-logout-wear-result',target,id,bound,denied('logout_wear_rate_limited')); return
    end
    local request={id=id,scope=bound}
    logoutPending[target]=request -- reserve before Core/Inventory preflight yields
    local called,result=pcall(coordinator.Begin,target,{action='shutdown',scope=bound})
    if logoutPending[target]~=request then return end
    if not called or not result or not result.ok then
        replyLogout(target,(called and type(result)=='table') and result or denied('logout_wear_request_uncertain_no_retry')); return
    end
    SetTimeout(45000,function()
        if logoutPending[target]==request then
            coordinator.Cancel(target,bound.sessionId)
            replyLogout(target,denied('logout_wear_timeout_no_retry'))
        end
    end)
end)
RegisterNetEvent('feather-weapons:server:native-equipment-restored',function(ticket,identity)
    local playerSource=source
    if not enabled() then return end
    local result=coordinator.Restored(playerSource,ticket,identity)
    if result.ok then
        if pending[playerSource] and pending[playerSource].periodic then
            periodic.Complete(playerSource,pending[playerSource].identity,'persisted')
            print('[WeaponNativePeriodicWear] PASS changed wear persisted/restored; no ammo/material economic writes')
        end
        local repair=pending[playerSource] and pending[playerSource].action=='repair'
        local funding=pending[playerSource] and pending[playerSource].action=='throwable-funding'
        local maintenance=pending[playerSource] and pending[playerSource].action=='maintenance'
        local attachment=pending[playerSource] and (pending[playerSource].action=='attachment-install' or pending[playerSource].action=='attachment-remove')
        pending[playerSource]=nil
        replyUI(playerSource,{ok=true,value={identity=copy(identity),phase='active'}})
        local state=coordinator.Status(playerSource)
        print(funding and '[WeaponNativeThrowableFunding] PASS loose-ammo/character-ledger transaction/fresh same-session restore; no pickup credits'
            or attachment and '[WeaponNativeAttachmentChange] PASS attachment payment/metadata CAS/fresh same-session restore; no ammo economic writes'
            or maintenance and '[WeaponNativeMaintenanceCheckpoint] PASS monotonic wear CAS/fresh same-session restore; no ammo/material economic writes'
            or repair and '[WeaponNativeRepair] PASS material payment/metadata CAS/fresh same-session restore; no ammo economic writes'
            or state.committed and '[WeaponNativeEquipmentChange] PASS conditional equipment commit/fresh same-session restore; no ammo economic writes'
            or '[WeaponNativeEquipmentDryRun] PASS final seal/owned cleanup/server release/fresh same-session restore; no equipment/ammo economic writes')
    end
end)
RegisterCommand('WeaponNativeEquipmentDryRun',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 or not enabled() or GetResourceState('feather-weapons-native-proof')~='stopped' then return end
    local target=tonumber(args and args[1])
    local result=coordinator.Begin(target,{action='dry-run'})
    print('[WeaponNativeEquipmentDryRun] '..(result.ok and 'STARTED; no equipment write requested' or 'REFUSED '..tostring(result.error.code)))
end,true)
RegisterCommand('WeaponNativeOverlapProbe',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 or not enabled() or GetConvarInt('feather_native_overlap_probe',0)~=1
        or GetResourceState('feather-weapons-native-proof')~='stopped' then return end
    if not args or #args~=1 then return print('[WeaponNativeOverlapProbe] REFUSED current-server-id required') end
    local target=tonumber(args[1])
    if not target or target<1 or target%1~=0 then return print('[WeaponNativeOverlapProbe] REFUSED current-server-id required') end
    SetConvar('feather_native_overlap_probe','0') -- consume before any yielding admission
    local state=WeaponCharacterAmmoDispatcher.Status(target)
    if not state or state.phase~='active' or state.busy or not identity(state.identity) then
        return print('[WeaponNativeOverlapProbe] REFUSED active idle native owner required; opt-in consumed')
    end
    local result=WeaponNativeEquipmentTransition.ProbeOverlap(coordinator,target,copy(state.identity))
    print('[WeaponNativeOverlapProbe] '..(result and result.ok and 'PASS boundary checks; await normal restore ' or 'FAIL inspect before retry ')
        ..json.encode(result))
end,true)
RegisterCommand('WeaponNativeEquipmentChange',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 or not enabled() or GetResourceState('feather-weapons-native-proof')~='stopped' then return end
    local action=args and args[2]
    if not args or (action~='equip' and action~='unequip') or (action=='equip' and #args~=4)
        or (action=='unequip' and #args~=3) then return print('[WeaponNativeEquipmentChange] usage: serverId equip|unequip slot [itemId]') end
    local result=coordinator.Begin(tonumber(args[1]),{action=action,slot=args[3],itemId=action=='equip' and tonumber(args[4]) or nil})
    print('[WeaponNativeEquipmentChange] '..(result.ok and 'STARTED; conditional equipment write requested' or 'REFUSED '..tostring(result.error.code)))
end,true)
RegisterCommand('WeaponNativePrepareStop',function(source,args)
    if source~=0 or not WeaponNativeShutdownDrain.RuntimeAvailable(Config,GetResourceState('feather-weapons-native-proof')) then return end
    if not args or #args~=1 then return print('[WeaponNativePrepareStop] usage: current-server-id') end
    local result=coordinator.Begin(tonumber(args[1]),{action='shutdown'})
    print('[WeaponNativePrepareStop] '..(result.ok and 'STARTED; wait for PASS before stopping' or 'REFUSED '..tostring(result.error.code)))
end,true)
RegisterCommand('WeaponNativeThrowableFunding',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 or not enabled() or GetResourceState('feather-weapons-native-proof')~='stopped' then return end
    if not args or #args~=3 then return print('[WeaponNativeThrowableFunding] usage: serverId +1|-1 stable-operation-id') end
    local result=coordinator.Begin(tonumber(args[1]),{action='throwable-funding',slot='weapon_throwable',
        amount=tonumber(args[2]),operationId=args[3]})
    print('[WeaponNativeThrowableFunding] '..(result.ok and 'STARTED; released-owner funding requested' or 'REFUSED '..tostring(result.error.code)))
end,true)
drain=WeaponNativeShutdownDrain.New({
    now=GetGameTimer,
    deadline=function(fn) SetTimeout(90000,fn) end,
    schedule=function(fn) SetTimeout(500,fn) end,
    roster=function()
        if not WeaponNativeShutdownDrain.RuntimeAvailable(Config,GetResourceState('feather-weapons-native-proof'))
            or not WeaponNativeEnrollment.Validate(Config)
            then return nil end
        local rows={}
        for _,raw in ipairs(GetPlayers()) do
            local target=tonumber(raw)
            local session=CoreAdapter.ResolveSession(target)
            -- An unresolved connected player may be entering a scoped character.
            if not session or not session.ok or type(session.value)~='table' then return nil end
            local state=WeaponCharacterAmmoDispatcher.Status(target)
            if WeaponNativeEnrollment.Allows(Config,session.value.characterId) or state then
                local bound=stopping[target] or (state and state.identity)
                if not identity(bound) or bound.characterId~=session.value.characterId
                    or bound.sessionId~=session.value.sessionId then return nil end
                rows[#rows+1]={source=target,characterId=bound.characterId,sessionId=bound.sessionId,epoch=bound.epoch}
            end
        end
        return rows
    end,
    status=function(target)
        local transition=coordinator.Status(target)
        if transition and transition.phase~='active' then return transition end
        local state=WeaponCharacterAmmoDispatcher.Status(target)
        if not state or state.phase~='active' or state.busy or pending[target] or wearPending[target]
            or uiPending[target] or logoutPending[target] then return nil end
        return {phase='active',sessionId=state.identity and state.identity.sessionId}
    end,
    begin=function(target,bound) return coordinator.Begin(target,{action='shutdown',scope=bound}) end,
    report=function(state)
        print('[WeaponNativePrepareStopAll] '..(state.phase=='ready' and 'PASS all scoped connected owners sealed/released; ready to stop resource'
            or 'FAIL '..tostring(state.reason)..'; do not stop or retry; admission remains latched')
            ..' completed='..state.completed..' total='..state.total)
    end,
})
RegisterCommand('WeaponNativePrepareStopAll',function(source,args)
    if source~=0 or not enabled() then return end
    if not args or #args~=0 then return print('[WeaponNativePrepareStopAll] REFUSED no arguments expected') end
    local ok,reason=drain.Begin()
    print('[WeaponNativePrepareStopAll] '..(ok and 'STARTED; admission latched; wait for aggregate PASS before stopping'
        or 'REFUSED '..tostring(reason)))
end,true)
RegisterCommand('WeaponNativeShutdownStatus',function(source,args)
    if source~=0 or not enabled() or not args or #args~=0 then return end
    print('[WeaponNativeShutdownStatus] '..json.encode(drain.Status()))
end,true)
RegisterCommand('WeaponNativeRepair',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 or not enabled() or Config.NativeAlphaRepairEnabled~=true
        or GetResourceState('feather-weapons-native-proof')~='stopped' then return end
    if not args or #args~=2 then return print('[WeaponNativeRepair] usage: current-server-id owned-item-id') end
    local result=coordinator.Begin(tonumber(args[1]),{action='repair',itemId=tonumber(args[2])})
    print('[WeaponNativeRepair] '..(result.ok and 'STARTED; canonical repair material payment requested'
        or 'REFUSED '..tostring(result.error.code)))
end,true)
RegisterCommand('WeaponNativeRepairStatus',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 or not enabled() or Config.NativeAlphaRepairEnabled~=true then return end
    local target,itemId=tonumber(args and args[1]),tonumber(args and args[2])
    if not args or #args~=2 or not target or target<1 or target%1~=0 or target==math.huge
        or not itemId or itemId<1 or itemId%1~=0 or itemId==math.huge then
        return print('[WeaponNativeRepairStatus] REFUSED usage: current-server-id owned-item-id')
    end
    local ok,value=pcall(function()
        local state=WeaponCharacterAmmoDispatcher.Status(target)
        local session=CoreAdapter.ResolveSession(target)
        if not state or state.phase~='active' or state.busy or not identity(state.identity)
            or not session or not session.ok or not WeaponNativeEnrollment.Allows(Config,session.value.characterId)
            or session.value.characterId~=state.identity.characterId or session.value.sessionId~=state.identity.sessionId then return nil end
        local scope=copy(state.identity)
        local context={actorSource=target,characterId=scope.characterId,sessionId=scope.sessionId}
        local snapshot=exports['feather-inventory']:ReadNativeEquipmentTransition(context,itemId)
        local item=snapshot and snapshot.ok and snapshot.value.candidate
        local definition=item and item.metadata and WeaponDefinitionCatalog.weapons[item.metadata.weaponDefinitionId]
        if not definition or item.id~=itemId or item.itemName~=definition.itemName then return nil end
        local after,cost=WeaponCharacterMaintenance.Repair(item.metadata,definition)
        if not after then
            local now=WeaponCharacterAmmoDispatcher.Status(target)
            if not now or now.phase~='active' or now.busy or not same(now.identity,scope)
                or not CoreAdapter.IsSessionCurrent(target,scope.sessionId,scope.characterId)
                or Config.NativeAlphaRepairEnabled~=true then return nil end
            return {itemId=itemId,itemRevision=item.revision,repairAvailable=false,reason=cost,noSQLWrites=true,noNativeWrites=true}
        end
        local material=exports['feather-inventory']:ReadNativeRepairMaterial(context,cost.itemDefinitionId)
        local now=WeaponCharacterAmmoDispatcher.Status(target)
        local quantity=material and material.ok and material.value and material.value.quantity
        if type(quantity)~='number' or quantity<0 or quantity%1~=0 or quantity==math.huge
            or not now or now.phase~='active' or now.busy or not same(now.identity,scope)
            or not CoreAdapter.IsSessionCurrent(target,scope.sessionId,scope.characterId) or Config.NativeAlphaRepairEnabled~=true then return nil end
        return {identity=scope,itemId=itemId,itemRevision=item.revision,condition=item.metadata.condition,
            maintenance=copy(item.metadata.maintenance),materialQuantity=material.value.quantity,
            material=cost.itemDefinitionId,required=cost.quantity,repairAvailable=material.value.quantity>=cost.quantity,
            repairedCondition=after.condition,noSQLWrites=true,noNativeWrites=true}
    end)
    print('[WeaponNativeRepairStatus] '..(ok and value and json.encode(value) or 'REFUSED current repair snapshot unavailable'))
end,true)
RegisterCommand('WeaponNativeAttachmentChange',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 then return end
    if not attachmentEnabled() or GetResourceState('feather-weapons-native-proof')~='stopped' then
        return print('[WeaponNativeAttachmentChange] REFUSED scoped attachment flags/final-wear runtime required; proof must be stopped')
    end
    if not args or (#args~=3 and #args~=4) or (args[2]~='install' and args[2]~='remove') then
        return print('[WeaponNativeAttachmentChange] usage: current-server-id install|remove equipped-item-id [attachment-id]')
    end
    local result=coordinator.Begin(tonumber(args[1]),{action='attachment-'..args[2],itemId=tonumber(args[3]),attachmentId=args[4]})
    print('[WeaponNativeAttachmentChange] '..(result.ok and 'STARTED; canonical attachment payment/return requested'
        or 'REFUSED '..tostring(result.error.code)))
end,true)
RegisterCommand('WeaponNativeArmAttachmentDisconnect',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 then return end
    local target,itemId=tonumber(args and args[1]),tonumber(args and args[2])
    local action=args and args[3]
    local attachmentId=args and args[4]
    if not attachmentEnabled() or GetConvarInt('feather_native_attachment_disconnect_probe',0)~=1
        or GetResourceState('feather-weapons-native-proof')~='stopped'
        or not args or #args~=4 or not target or target<1 or target%1~=0 or target==math.huge
        or not itemId or itemId<1 or itemId%1~=0 or itemId==math.huge
        or (action~='install' and action~='remove')
        or not WeaponDefinitionCatalog.attachments[attachmentId] then
        return print('[WeaponNativeArmAttachmentDisconnect] REFUSED scoped opt-in/current-server-id owned-item-id install|remove attachment-id required')
    end
    local state=WeaponCharacterAmmoDispatcher.Status(target)
    if not state or state.phase~='active' or state.busy or not identity(state.identity)
        or not WeaponNativeEnrollment.Allows(Config,state.identity.characterId)
        or not CoreAdapter.IsSessionCurrent(target,state.identity.sessionId,state.identity.characterId)
        or (coordinator.Status(target) and coordinator.Status(target).phase~='active') then
        return print('[WeaponNativeArmAttachmentDisconnect] REFUSED current scoped idle owner required')
    end
    local probe={identity=copy(state.identity),itemId=itemId,action='attachment-'..action,attachmentId=attachmentId}
    attachmentDisconnect[target]=probe
    SetTimeout(60000,function() if attachmentDisconnect[target]==probe then attachmentDisconnect[target]=nil end end)
    print('[WeaponNativeArmAttachmentDisconnect] ARMED matching action/current epoch only; expires in 60s; confirmed commit disconnects player')
end,true)
RegisterCommand('WeaponNativeAttachmentStatus',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 then return end
    local target=tonumber(args and args[1])
    local itemId=tonumber(args and args[2])
    local attachment=WeaponDefinitionCatalog.attachments and WeaponDefinitionCatalog.attachments[args and args[3] or 'carbine_wide_sight']
    if not attachmentEnabled() or not args or (#args~=2 and #args~=3) or not attachment or not target or target<1 or target%1~=0 or target==math.huge
        or not itemId or itemId<1 or itemId%1~=0 or itemId==math.huge then
        return print('[WeaponNativeAttachmentStatus] REFUSED usage: current-server-id owned-item-id [attachment-id]; scoped flags required')
    end
    local called,value=pcall(function()
        local state=WeaponCharacterAmmoDispatcher.Status(target)
        local session=CoreAdapter.ResolveSession(target)
        if not state or state.phase~='active' or state.busy or not session or not session.ok
            or not WeaponNativeEnrollment.Allows(Config,state.identity.characterId) or state.identity.sessionId~=session.value.sessionId
            or state.identity.characterId~=session.value.characterId then return nil end
        local scope=copy(state.identity)
        local context={actorSource=target,characterId=scope.characterId,sessionId=scope.sessionId}
        local snapshot=exports['feather-inventory']:ReadNativeEquipmentTransition(context,itemId)
        local item=snapshot and snapshot.ok and snapshot.value.candidate
        local definition=item and item.metadata and WeaponDefinitionCatalog.weapons[item.metadata.weaponDefinitionId]
        if not definition or item.id~=itemId or item.itemName~=definition.itemName
            or not WeaponNativeAttachmentMappings.Resolve(definition,attachment,true) then return nil end
        local material=exports['feather-inventory']:ReadNativeAttachmentMaterial(context,attachment.itemName)
        local after=WeaponCharacterAmmoDispatcher.Status(target)
        if not snapshot or not snapshot.ok or not material or not material.ok or not after or after.phase~='active'
            or after.busy or not same(after.identity,scope) or not CoreAdapter.IsSessionCurrent(target,scope.sessionId,scope.characterId)
            or not attachmentEnabled() then return nil end
        return {identity=scope,itemId=item.id,itemRevision=item.revision,attachments=copy(item.metadata.attachments),
            attachmentId=attachment.id,materialQuantity=material.value.quantity,expected=copy(snapshot.value.expected),noSQLWrites=true,noNativeWrites=true}
    end)
    print('[WeaponNativeAttachmentStatus] '..(called and value and json.encode(value) or 'REFUSED current owned weapon/material snapshot unavailable'))
end,true)
local function requestWear(target,itemId,automatic)
    if not enabled() or Config.NativeAlphaMaintenanceEnabled~=true or GetResourceState('feather-weapons-native-proof')~='stopped' then
        return false
    end
    if not target or target<1 or target%1~=0 or target==math.huge
        or not itemId or itemId<1 or itemId%1~=0 or itemId==math.huge then
        return false
    end
    local status=WeaponCharacterAmmoDispatcher.Status(target)
    local transition=coordinator.Status(target)
    if wearPending[target] or not status or status.phase~='active' or status.busy
        or not identity(status.identity) or not WeaponNativeEnrollment.Allows(Config,status.identity.characterId)
        or (transition and transition.phase~='active') then return false end
    sequence=sequence+1
    local request={ticket=('wear:%s:%s:%s'):format(target,GetGameTimer(),sequence),identity=copy(status.identity),itemId=itemId,periodic=automatic==true}
    wearPending[target]=request
    SetTimeout(10000,function() if wearPending[target]==request then
        wearPending[target]=nil
        if request.periodic then periodic.Complete(target,request.identity,'readback_timeout')
        else print('[WeaponNativeMaintenanceCheckpoint] REFUSED readback timeout; no write requested') end
    end end)
    TriggerClientEvent('feather-weapons:client:native-maintenance-read',target,request.ticket,request.identity,request.itemId)
    return true
end
RegisterCommand('WeaponNativeMaintenanceCheckpoint',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 then return end
    if not args or #args~=2 then return print('[WeaponNativeMaintenanceCheckpoint] usage: current-server-id equipped-item-id') end
    if not requestWear(tonumber(args[1]),tonumber(args[2]),false) then print('[WeaponNativeMaintenanceCheckpoint] REFUSED scoped active idle owner required') end
end,true)
RegisterNetEvent('feather-weapons:server:native-maintenance-report',function(ticket,epoch,itemId,revision,report)
    local target=source
    local request=wearPending[target]
    if not request or ticket~=request.ticket then return end
    wearPending[target]=nil -- single-use before any yielding preflight
    if not enabled() or Config.NativeAlphaMaintenanceEnabled~=true or epoch~=request.identity.epoch or itemId~=request.itemId
        or type(revision)~='number' or revision<0 or revision%1~=0 or revision==math.huge or type(report)~='table' then
        return print('[WeaponNativeMaintenanceCheckpoint] REFUSED stale/invalid owned readback')
    end
    local clean={}
    for _,key in ipairs({'degradation','permanentDegradation','damage','dirt','soot'}) do
        local v=report[key]
        if type(v)~='number' or v~=v or v<0 or v>1 then return print('[WeaponNativeMaintenanceCheckpoint] REFUSED invalid wear values') end
        clean[key]=v
    end
    for key in pairs(report) do if clean[key]==nil then return print('[WeaponNativeMaintenanceCheckpoint] REFUSED unexpected wear field') end end
    if request.periodic then
        if Config.NativeAlphaPeriodicWearEnabled~=true then return end
        local state=WeaponCharacterAmmoDispatcher.Status(target)
        if not state or state.phase~='active' or state.busy or not same(state.identity,request.identity) then return end
        local found
        for _,item in ipairs(WeaponCharacterAmmoService.ReadBoundMaintenanceItems(target) or {}) do if item.id==itemId then found=item end end
        if not found or found.revision~=revision then return end
        local after=WeaponCharacterMaintenance.Observe(found.metadata,found.definition,clean)
        if not after then periodic.Complete(target,request.identity,'report_refused'); return end
        local changed=after.condition~=found.metadata.condition
        for key,value in pairs(after.maintenance) do changed=changed or value~=found.metadata.maintenance[key] end
        if not changed then periodic.Complete(target,request.identity,'unchanged'); return end -- no SQL/read/rebuild
        periodicIntent[target]=copy(request.identity)
    end
    local called,result=pcall(coordinator.Begin,target,{action='maintenance',itemId=itemId,itemRevision=revision,report=clean,scope=copy(request.identity),periodic=request.periodic})
    periodicIntent[target]=nil
    if not called then
        if request.periodic then periodic.Complete(target,request.identity,'preflight_uncertain') end
        return print('[WeaponNativeMaintenanceCheckpoint] REFUSED transition exception; no automatic retry')
    end
    if request.periodic and not result.ok then periodic.Complete(target,request.identity,'preflight_refused') end
    if not result.ok then
        print('[WeaponNativeMaintenanceCheckpoint] '..(result.error.code=='native_maintenance_unchanged'
            and 'PASS unchanged wear; no release/SQL writes' or 'REFUSED '..tostring(result.error.code)))
    end
end)
periodic=WeaponNativePeriodicWear.New({
    enabled=function() return enabled() and Config.NativeAlphaMaintenanceEnabled==true and Config.NativeAlphaPeriodicWearEnabled==true end,
    interval=function() return Config.NativeAlphaPeriodicWearIntervalMs or 60000 end,now=GetGameTimer,
    status=function(target)
        local status=WeaponCharacterAmmoDispatcher.Status(target)
        return status and status.identity and WeaponNativeEnrollment.Allows(Config,status.identity.characterId) and status or nil
    end,
    busy=function(target)
        local state=coordinator.Status(target)
        return wearPending[target]~=nil or pending[target]~=nil or stopping[target]~=nil or uiPending[target]~=nil
            or logoutPending[target]~=nil or (state and state.phase~='active') or false
    end,
    items=function(target) return WeaponCharacterAmmoService.ReadBoundMaintenanceItems(target) end,
    request=function(target,itemId) return requestWear(target,itemId,true) end,
})
RegisterCommand('WeaponNativePeriodicWearStatus',function(source,args)
    if Config.DevMode~=true then return end
    if source~=0 or not enabled() then return end
    local target=tonumber(args and args[1])
    print('[WeaponNativePeriodicWearStatus] '..json.encode({enabled=Config.NativeAlphaPeriodicWearEnabled==true,state=target and periodic.Status(target)}))
end,true)
if type(CreateThread)=='function' and type(GetPlayers)=='function' then
    CreateThread(function()
        while true do
            for _,target in ipairs(GetPlayers()) do
                local called=pcall(periodic.Step,tonumber(target))
                if not called then print('[WeaponNativePeriodicWear] sampler failed; no automatic mutation requested') end
            end
            Wait(1000)
        end
    end)
end
function WeaponNativeEquipmentBindings.RetireSession(target,sessionId)
    if type(target)=='number' and type(sessionId)=='string' then
        if attachmentDisconnect[target] and attachmentDisconnect[target].identity.sessionId==sessionId then attachmentDisconnect[target]=nil end
        local session={source=target,sessionId=sessionId}
        periodic.Forget(session.source,session.sessionId)
        if logoutPending[session.source] and logoutPending[session.source].scope.sessionId==session.sessionId then
            replyLogout(session.source,denied('logout_wear_session_closed_no_retry'))
        end
        coordinator.Cancel(session.source,session.sessionId)
        coordinator.Retire(session.source,session.sessionId)
        if pending[target] and pending[target].identity.sessionId==sessionId then pending[target]=nil end
        if periodicIntent[target] and periodicIntent[target].sessionId==sessionId then periodicIntent[target]=nil end
        if wearPending[session.source] and wearPending[session.source].identity.sessionId==session.sessionId then wearPending[session.source]=nil end
        if stopping[session.source] and stopping[session.source].sessionId==session.sessionId then stopping[session.source]=nil end
        local request=uiPending[session.source]
        if request and request.scope.sessionId==session.sessionId then replyUI(session.source,denied('equipment_session_closed_no_retry')) end
    end
end
function WeaponNativeEquipmentBindings.ReconcileSession(target,context)
    if not enabled() or type(context)~='table' or not WeaponNativeEnrollment.Allows(Config,context.characterId)
        or not CoreAdapter.IsSessionCurrent(target,context.sessionId,context.characterId) then return denied('recovery_session_required') end
    local state=coordinator.Status(target)
    if state and not state.sessionId then return denied('recovery_transition_identity_pending') end
    if state and state.sessionId==context.sessionId and state.phase~='active' then return denied('recovery_same_session_release_required') end
    if state and state.sessionId~=context.sessionId then
        if not coordinator.Retire(target,state.sessionId) then return denied('recovery_transition_still_current') end
        WeaponNativeEquipmentBindings.RetireSession(target,state.sessionId)
    end
    for _,map in ipairs({pending,wearPending,stopping,uiPending,logoutPending,periodicIntent}) do
        local value=map[target]
        local identity=value and (value.identity or value.scope or value)
        if identity and identity.sessionId and identity.sessionId~=context.sessionId then
            WeaponNativeEquipmentBindings.RetireSession(target,identity.sessionId)
        end
    end
    return {ok=true,value=true}
end
AddEventHandler('core.session.left.v1',function(session)
    if type(session)=='table' then WeaponNativeEquipmentBindings.RetireSession(session.source,session.sessionId) end
end)
AddEventHandler('playerDropped',function() coordinator.Cancel(source); periodic.Forget(source); periodicIntent[source]=nil; uiPending[source]=nil; uiRates[source]=nil; stopping[source]=nil; wearPending[source]=nil; logoutPending[source]=nil end)
end
denied=function(code) return {ok=false,error={code=code}} end
identity=function(value)
    if type(value)~='table' then return false end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(value[key])~='string' or value[key]=='' or #value[key]>128 then return false end
    end
    return true
end
same=function(a,b)
    return identity(a) and identity(b) and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch
end
function WeaponNativeEquipmentTransition.New(api)
    for _,key in ipairs({'enabled','prepare','current','released','requestRelease','commit','rebuild','restored','ticket'}) do
        if type(api[key])~='function' then return nil,'missing_transition_adapter_'..key end
    end
    local states,retired={},{}
    local T={}
    local function frozen(source,state,code)
        if states[source]~=state then return denied('equipment_transition_superseded') end
        state.phase,state.reason='frozen',code
        return denied(code) -- retains evidence; never auto-reverts a committed write
    end
    local function current(source,state)
        if states[source]~=state or state.phase=='frozen' or api.enabled()~=true then return false end
        local called,valid=pcall(api.current,source,copy(state.identity))
        return called and valid==true and states[source]==state and state.phase~='frozen' and api.enabled()==true
    end
    function T.Begin(source,intent)
        if api.enabled()~=true then return denied('equipment_transition_disabled') end
        if type(source)~='number' or source<1 or source%1~=0 or type(intent)~='table' then return denied('invalid_equipment_intent') end
        local previous=states[source]
        if previous and previous.phase~='active' then return denied('equipment_transition_in_flight') end
        local state={phase='preparing'}; states[source]=state
        -- prepare must resolve actual Core identity, active native epoch, owned
        -- item/catalog/slot policy and expected equipment snapshot server-side.
        local called,prepared=pcall(api.prepare,source,copy(intent))
        if states[source]~=state then return denied('equipment_transition_superseded') end
        if not called or type(prepared)~='table' or prepared.ok~=true then
            -- No release was requested, so a policy refusal must not strand an
            -- otherwise active owner. A concurrent lifecycle cancellation wins.
            if state.phase~='preparing' then return denied('equipment_context_changed') end
            states[source]=previous
            return denied(type(prepared)=='table' and prepared.error and prepared.error.code or 'equipment_preflight_failed')
        end
        local value=prepared.value
        if type(value)~='table' or not identity(value.identity) or type(value.spec)~='table'
            or value.spec.characterId~=value.identity.characterId then return frozen(source,state,'equipment_preflight_invalid') end
        state.identity,state.spec=copy(value.identity),copy(value.spec)
        if state.cancelledSessions and state.cancelledSessions[state.identity.sessionId] then
            return frozen(source,state,'equipment_transition_cancelled')
        end
        if not current(source,state) then return frozen(source,state,'equipment_context_changed') end
        local made,ticket=pcall(api.ticket,source,copy(state.identity))
        if state.phase~='preparing' or not current(source,state) then return frozen(source,state,'equipment_context_changed') end
        if not made or type(ticket)~='string' or ticket=='' or #ticket>128 then return frozen(source,state,'equipment_ticket_failed') end
        state.ticket=ticket; state.phase='releasing'
        local sent,accepted=pcall(api.requestRelease,source,{ticket=ticket,identity=copy(state.identity),collectWear=state.spec.lifecycleSnapshot~=nil})
        if states[source]~=state or state.phase~='releasing' then return denied('equipment_release_lifecycle_changed') end
        if not sent or accepted~=true then return frozen(source,state,'equipment_release_dispatch_failed') end
        return {ok=true,value={phase='releasing'}}
    end
    function T.Released(source,ticket,hint,wear)
        local state=states[source]
        if not state or state.phase~='releasing' or ticket~=state.ticket or not same(hint,state.identity) then
            return denied('stale_equipment_release')
        end
        state.phase='checking_release' -- reserve before authoritative adapters yield
        if not current(source,state) then return frozen(source,state,'equipment_context_changed') end
        local checked,released=pcall(api.released,source,copy(state.identity))
        if not checked or released~=true or not current(source,state) then return frozen(source,state,'equipment_release_not_acknowledged') end
        if api.finalizeSpec then
            state.phase='finalizing_spec'
            local context={actorSource=source,characterId=state.identity.characterId,sessionId=state.identity.sessionId,
                epoch=state.identity.epoch,ticket=state.ticket}
            local called,final=pcall(api.finalizeSpec,copy(context),copy(state.spec),copy(wear))
            if not current(source,state) or state.phase~='finalizing_spec' then return denied('final_wear_lifecycle_changed') end
            if not called or type(final)~='table' or final.ok~=true or type(final.value)~='table'
                or final.value.characterId~=state.spec.characterId or final.value.action~=state.spec.action then
                return frozen(source,state,type(final)=='table' and final.error and final.error.code or 'final_wear_plan_failed')
            end
            state.spec=copy(final.value)
        end
        state.phase='writing'
        local context={actorSource=source,characterId=state.identity.characterId,sessionId=state.identity.sessionId,
            epoch=state.identity.epoch,ticket=state.ticket}
        state.commitOutcome='pending'
        local called,committed=pcall(api.commit,copy(context),copy(state.spec))
        -- Record the observed outcome even if lifecycle cancellation occurred
        -- while Inventory yielded. This is evidence, not permission to resume.
        if not called then state.commitOutcome='uncertain'
        elseif type(committed)=='table' and committed.ok==true then
            state.commitOutcome='confirmed'
            state.committed=not (type(committed.value)=='table' and committed.value.unchanged==true)
        elseif type(committed)=='table' and committed.ok==false and
            (committed.outcome=='unknown' or (type(committed.error)=='table' and
                (committed.error.code=='transaction_outcome_unknown' or
                 (type(committed.error.details)=='table' and committed.error.details.outcome=='unknown')))) then
            state.commitOutcome='uncertain'
        elseif type(committed)=='table' and committed.ok==false then state.commitOutcome='refused'
        else state.commitOutcome='uncertain' end
        if states[source]~=state or state.phase~='writing' then return denied('equipment_commit_lifecycle_changed') end
        if state.commitOutcome=='uncertain' then return frozen(source,state,'equipment_commit_uncertain_no_retry') end
        if type(committed)~='table' or committed.ok~=true then
            if type(committed)=='table' and type(committed.error)=='table' then
                -- Preserve the provider refusal, not item metadata, for diagnosis.
                state.commitRefusal={code=type(committed.error.code)=='string' and committed.error.code:sub(1,128) or nil,
                    message=type(committed.error.message)=='string' and committed.error.message:sub(1,256) or nil}
                print('[WeaponNativeEquipmentCommit] REFUSED '..tostring(state.commitRefusal.code)..': '..tostring(state.commitRefusal.message))
            end
            return frozen(source,state,'equipment_commit_refused')
        end
        if not current(source,state) then return frozen(source,state,'equipment_committed_context_changed') end
        if state.spec.action=='shutdown' then
            if state.committed then return frozen(source,state,'shutdown_mutation_forbidden') end
            state.phase='parked'
            return {ok=true,value={phase='parked'}}
        end
        state.phase='rebuilding'
        local started,result=pcall(api.rebuild,source,copy(context))
        if states[source]~=state or state.phase~='rebuilding' then return denied('equipment_rebuild_lifecycle_changed') end
        local new=type(result)=='table' and result.ok==true and result.value
        if not started or not identity(new) or new.characterId~=state.identity.characterId
            or new.sessionId~=state.identity.sessionId or new.epoch==state.identity.epoch then
            state.rebuildReason=not started and 'rebuild_adapter_exception'
                or (type(result)=='table' and type(result.error)=='table' and type(result.error.code)=='string'
                    and result.error.code:sub(1,128)) or 'invalid_fresh_rebuild_identity'
            return frozen(source,state,'equipment_committed_rebuild_failed')
        end
        state.newIdentity=copy(new)
        return {ok=true,value={phase='rebuilding'}}
    end
    function T.CanCommit(context,spec)
        local state=type(context)=='table' and states[context.actorSource]
        if not state or state.phase~='writing' or context.ticket~=state.ticket or not same(context,state.identity)
            or type(spec)~='table' then return false end
        local function equal(a,b)
            if type(a)~=type(b) then return false end
            if type(a)~='table' then return a==b end
            for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
            for k in pairs(b) do if a[k]==nil then return false end end
            return true
        end
        if not equal(spec,state.spec) or not current(context.actorSource,state) then return false end
        local called,released=pcall(api.released,context.actorSource,copy(state.identity))
        return called and released==true and current(context.actorSource,state) and state.phase=='writing'
    end
    function T.Restored(source,ticket,hint)
        local state=states[source]
        if not state or state.phase~='rebuilding' or ticket~=state.ticket or not same(hint,state.newIdentity) then
            return denied('stale_equipment_restore')
        end
        state.phase='checking_restore'
        local called,active=pcall(api.restored,source,copy(state.newIdentity))
        if not called or active~=true or not current(source,state) then return frozen(source,state,'equipment_restore_not_acknowledged') end
        state.phase='active'
        return {ok=true,value={phase='active'}}
    end
    function T.Cancel(source,sessionId)
        local state=states[source]
        if not state then return false end
        if sessionId and not state.identity then
            -- Core/SQL preflight may be yielding. Do not let a delayed old
            -- session event cancel a different session whose identity is unread.
            state.cancelledSessions=state.cancelledSessions or {}
            state.cancelledSessions[sessionId]=true
            return true
        end
        if sessionId and sessionId~=state.identity.sessionId then return false end
        if state.phase=='active' or state.phase=='parked' then
            -- Completed restore has no outstanding write/release authority.
            -- Keep the last completed evidence, but allow next-login preflight.
            retired[source]=state; states[source]=nil; return true
        end
        state.phase,state.reason='frozen','equipment_transition_cancelled'; return true
    end
    function T.Status(source)
        local state=states[source]
        return state and {phase=state.phase,reason=state.reason,sessionId=state.identity and state.identity.sessionId,committed=state.committed==true,
            commitOutcome=state.commitOutcome,rebuildReason=state.rebuildReason,
            commitRefusal=state.commitRefusal and copy(state.commitRefusal) or nil} or nil
    end
    function T.Retire(source,sessionId)
        local state=states[source]
        if not state then return true end
        if not state.identity or state.identity.sessionId~=sessionId then return false end
        local called,valid=pcall(api.current,source,copy(state.identity))
        if not called or valid~=false or states[source]~=state then return false end
        if state.commitOutcome=='pending' then state.commitOutcome='uncertain' end
        retired[source]=state; states[source]=nil -- evidence retained, no economic replay/native cleanup claim
        return true
    end
    return T
end
if type(RegisterNetEvent)=='function' and type(RegisterCommand)=='function' then InstallDryRun() end
