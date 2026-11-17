-- Isolated diagnostic under the existing server-challenged release/rebuild
-- reservation. This fixture has NO Inventory/equipment/ammunition-ledger rows.
WeaponNativeThrowableLoanTest={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return WeaponNativeAcceptanceView.Equal(a,b) end
function WeaponNativeThrowableLoanTest.Run(api,identity,registry)
    local row={captureVersion=4,id='throwable:world-capture',phase='failed',cleanupComplete=false,syntheticNativeOnly=true,
        observations={},pickupEvents={},worldEvidence={},economicWrites=0}
    local owner,baseline,sealed,thrown,picked,attempted,external
    local stage='preflight'
    local started=api.now()
    local duration=api.durationMs==180000 and 180000 or 90000
    local units=api.unitCount==2 and 2 or 1
    local function setStage(value) stage=value;api.stage(value) end
    local seen={}
    local ok,reason=pcall(function()
        assert(type(registry)=='table' and type(registry.limits)=='table'
            and registry.limits.ammo_tomahawk_regular==3,'loan_physical_registry_required')
        assert(api.current(),'loan_released_owner_required')
        baseline=assert(api.pools(),'loan_pools_unreadable')
        assert(baseline.ammo_tomahawk_regular==0 and api.quantity()==0,'loan_empty_native_tomahawk_required')
        local snapshot={contract=2,kind='physical_throwable_units',characterId=identity.characterId,identity=copy(identity),
            revision=1,pools=copy(baseline),units={{id=900000001,revision=0,itemName='weapon_thrown_tomahawk',
            metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber=api.serialNumber or 'NATIVE-LOAN-'..started}))}}}
        snapshot.pools.ammo_tomahawk_regular=1
        if units==2 then
            local second=copy(snapshot.units[1]);second.id=900000002
            second.metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='ISOLATED-COMPETING-SECOND'}))
            snapshot.units[2]=second;snapshot.pools.ammo_tomahawk_regular=2
        end
        row.expectedUnits=units
        sealed={phase='sealed',characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,
            revision=1,pools=copy(snapshot.pools)}
        owner=assert(api.owner(function() return copy(sealed) end),'loan_owner_unavailable')
        attempted=true
        assert(owner.Create(snapshot),'loan_native_creation_unconfirmed')
        setStage('awaiting_throw')
        while (api.now()-started)%4294967296<duration do
            assert(api.current(),'loan_session_or_ped_changed')
            assert(not api.cancelled(),'loan_cancelled')
            for _,event in ipairs(api.events() or {}) do
                local object=event.object or {}
                local key=event.kind..':'..tostring(event.state)..':'..tostring(event.name)..':'..tostring(object.entity)..':'..tostring(object.networkId)..':'..table.concat(event.rawSlots or {},',')
                local pickup=event.kind=='network_pickup' or event.kind=='ai_pickup'
                    or event.kind=='game_event' and event.name:lower():find('pickup',1,true)
                local rows=pickup and row.pickupEvents or row.worldEvidence
                if not seen[key] and #rows<(pickup and 6 or 12) then seen[key]=true;rows[#rows+1]=copy(event) end
            end
            local count=api.quantity()
            assert(type(count)=='number' and count%1==0 and count>=0 and count<=units,'loan_native_quantity_unconfirmed')
            if units==2 and not thrown and count==1 then setStage('awaiting_pickup') end
            if not thrown and count==0 then
                assert(owner.Observe().quantity==0,'loan_throw_observation_unconfirmed')
                thrown=true;sealed.revision=2;sealed.pools.ammo_tomahawk_regular=0
                row.observations[#row.observations+1]={stage='throw',quantity=0,elapsedMs=(api.now()-started)%4294967296}
                setStage('awaiting_pickup')
            elseif thrown and count==0 and api.remoteCollected and api.remoteCollected()==true then
                picked=true;external=true;row.foreignCollector=true
                row.observations[#row.observations+1]={stage='foreign_pickup_cleanup_confirmed',quantity=0,elapsedMs=(api.now()-started)%4294967296}
                setStage('cleaning');break
            elseif thrown and count==1 then
                assert(units==1,'competing_thrower_must_not_collect')
                local before=copy(snapshot);before.units={};before.revision=2;before.pools=copy(sealed.pools)
                local after=copy(snapshot);after.revision=3;after.units[1].revision=2
                local receipt={characterId=identity.characterId,collector=copy(identity),origin=copy(identity),
                    itemId=after.units[1].id,itemRevision=2,revision=3,pools=copy(after.pools),
                    throwableUnitsSnapshot=copy(after),projectileInstanceId='native-loan-diagnostic-only',
                    nativeAmmoDelta=0,looseInventoryDelta=0}
                -- Synthetic receipt exercises the real read-only native recapture
                -- method inside this isolated fixture. It is NEVER sent to SQL.
                assert(owner.AcceptPhysicalPickup(before,after,receipt),'loan_pickup_guid_recapture_unconfirmed')
                picked=true;sealed.revision=3;sealed.pools=copy(after.pools)
                row.observations[#row.observations+1]={stage='pickup',quantity=1,elapsedMs=(api.now()-started)%4294967296}
                -- The native pool may update before the engine delivers its event.
                -- Keep the same capture open briefly; never create another unit.
                setStage('settling_events')
                local settled=api.now()
                while (api.now()-settled)%4294967296<750 do
                    assert(api.current(),'loan_session_or_ped_changed')
                    api.wait(0)
                end
                for _,event in ipairs(api.events() or {}) do
                    local pickup=event.kind=='network_pickup' or event.kind=='ai_pickup'
                        or event.kind=='game_event' and event.name:lower():find('pickup',1,true)
                    local object=event.object or {}
                    local key=event.kind..':'..tostring(event.state)..':'..tostring(event.name)..':'..tostring(object.entity)..':'..tostring(object.networkId)..':'..table.concat(event.rawSlots or {},',')
                    local rows=pickup and row.pickupEvents or row.worldEvidence
                    if not seen[key] and #rows<(pickup and 6 or 12) then
                        seen[key]=true;rows[#rows+1]=copy(event)
                    end
                end
                setStage('cleaning');break
            end
            api.wait(0)
        end
        assert(thrown and picked,'loan_throw_or_pickup_timeout')
    end)
    pcall(setStage,'cleaning') -- presentation failure must not suppress compensation
    -- A thrown but uncollected test object is still in the world. Do not certify
    -- cleanup from a zero ped pool or delete an arbitrary same-model prop.
    local cleaned=false
    local cleanupCall,cleanupResult=pcall(function()
        if not attempted then return baseline~=nil and api.current() and same(api.pools(),baseline) end
        if owner and (not thrown or picked) and api.current() and api.quantity()==(external and 0 or units) then
            return owner.Release()==true and api.current() and same(api.pools(),baseline)
        end
        return false
    end)
    cleaned=cleanupCall and cleanupResult==true
    row.cleanupComplete=cleaned
    row.reason=not ok and tostring(reason) or (not cleaned and 'loan_cleanup_unconfirmed' or not external and #row.pickupEvents==0 and 'pickup_events_not_observed' or nil)
    if thrown and not picked then row.reason='uncollected_test_projectile_retained_no_retry' end
    row.phase=ok and cleaned and (external or #row.pickupEvents>0) and 'passed' or 'failed'
    pcall(setStage,cleaned and 'complete' or 'retained')
    return {phase=row.phase=='passed' and 'complete' or 'review_required',passed=row.phase=='passed' and 1 or 0,
        total=1,cleanupComplete=cleaned,cases={row},reason=row.reason,
        candidate='native_throwable_world_capture',coverage='temporary native unit; no paid pickup authority or Inventory writes'}
end
