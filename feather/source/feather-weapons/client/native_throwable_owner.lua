-- Inert dependency-injected owner. No native ports/events/exports/admission yet.
-- The existing character-ammo controller owns observation persistence and seals.
WeaponNativeThrowableOwner={}
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
function WeaponNativeThrowableOwner.New(api,catalog,identity,limits)
    for _,name in ipairs({'current','sealed','present','quantity','createFunded','removeOwned','releaseSpent'}) do
        assert(type(api)=='table' and type(api[name])=='function','Local throwable adapter required: '..name)
    end
    local bound=copy(identity)
    local phase,reason,approval,handle,last='idle',nil,nil,nil,nil
    local nativeIncrease,pickupAcceptedRevision,creationPreflight
    local T={}
    local function call(name,...)
        local ok,value,detail=pcall(api[name],...); return ok,value,detail
    end
    local function current()
        local ok,value=call('current',copy(bound)); return ok and value==true
    end
    local function retain(why) phase='retained'; reason=why; return nil,why end
    local function quantity()
        local ok,n=call('quantity',copy(bound))
        if not ok or type(n)~='number' or n%1~=0 or n<0 or n>1 or not current() then return nil end
        return n
    end
    local function pickupEnabled()
        if type(api.pickupEnabled)~='function' then return false end
        local ok,value=call('pickupEnabled'); return ok and value==true
    end
    function T.Status()
        return {phase=phase,reason=reason,itemId=approval and approval.row.id,
            itemRevision=approval and approval.row.revision,fundedQuantity=approval and approval.fundedQuantity,
            observedQuantity=last,pickupCredits=pickupEnabled(),guidCaptured=handle~=nil,
            nativeIncrease=copy(nativeIncrease),pickupAcceptedRevision=pickupAcceptedRevision,
            creationPreflight=copy(creationPreflight)}
    end
    function T.Create(snapshot)
        if phase~='idle' then return nil,'throwable_creation_already_attempted' end
        local value,why=WeaponNativeThrowableItem.Assigned(snapshot,catalog,bound,limits)
        if not value then return nil,why or 'assigned_throwable_required' end
        if not current() then return nil,'throwable_world_changed' end
        approval=value; phase='preflight' -- reserve before any adapter can yield
        local checked,present=call('present',copy(bound))
        local existingQuantity=quantity()
        -- The character belt can retain approved ammunition while its carrier
        -- is unequipped. A matching pool is not a pre-existing weapon copy.
        -- The concrete factory must still prove weapon/inventory GUID absence.
        if not checked or present~=false or existingQuantity==nil
            or (existingQuantity~=0 and existingQuantity~=approval.fundedQuantity) then
            creationPreflight={presenceConfirmed=checked,weaponPresent=present,
                quantity=existingQuantity,approvedQuantity=approval.fundedQuantity}
            return retain('throwable_preexisting_or_unconfirmed')
        end
        last=approval.fundedQuantity
        if last==0 then phase='empty'; return true end -- no native grant for an unfunded carrier
        phase='creating'
        local ok,created,detail=call('createFunded',copy(approval))
        if not ok then return retain('throwable_funded_adapter_exception') end
        if created==nil and type(detail)=='string' and #detail<=96
            and detail:match('^throwable_[a-z_]+$') then return retain(detail) end
        if not ok or type(created)~='table' or type(created.entity)~='number'
            or (created.entity<1 and not (created.entity==0 and created.inventoryOnly==true))
            or created.entity%1~=0 or created.entity==math.huge or type(created.guid)~='string'
            or #created.guid~=32 or not created.guid:match('^[0-9a-f]+$') or created.guid==string.rep('0',32)
            or not current() then return retain('throwable_funded_creation_unconfirmed') end
        handle=copy(created)
        local seen,owned=call('present',copy(bound))
        if quantity()~=1 or not seen or owned~=true or not current() then return retain('throwable_funded_readback_failed') end
        phase='active'; return true
    end
    -- A decrease is an observation only: no second ledger or persistence claim.
    function T.Observe(baseline)
        if phase~='active' and phase~='empty' then return nil,'throwable_not_active' end
        local n=quantity()
        if n==nil then return retain('throwable_quantity_unconfirmed') end
        if n>last then
            if nativeIncrease and nativeIncrease.pending==true then
                if not pickupEnabled() then return retain('throwable_pickup_gate_changed') end
                return {ammunitionId=approval.ammunitionId,quantity=last,pickupCandidate=true}
            end
            -- The previous single-type implementation detected native pickup
            -- through this pool increase, not through a landed-object search.
            -- Preserve the readback for diagnosis, but do not accept it as
            -- ownership or proof that our previously thrown unit was collected.
            nativeIncrease={kind='native_pool_increase',identity=copy(bound),
                itemId=approval.row.id,itemRevision=approval.row.revision,
                ammunitionId=approval.ammunitionId,previousQuantity=last,
                observedQuantity=n,units=n-last,pickupConfirmed=false,
                pickupCredits=false,clientDiagnosticOnly=true}
            if pickupEnabled() and handle and type(baseline)=='table' and baseline.phase=='active'
                and baseline.characterId==bound.characterId and baseline.sessionId==bound.sessionId
                and baseline.epoch==bound.epoch and type(baseline.revision)=='number'
                and baseline.revision%1==0 and baseline.revision>=approval.ledgerRevision
                and baseline.revision<math.huge and type(baseline.pools)=='table'
                and baseline.pools[approval.ammunitionId]==0 and last==0 then
                nativeIncrease.pending=true; nativeIncrease.expectedRevision=baseline.revision
                return {ammunitionId=approval.ammunitionId,quantity=last,pickupCandidate=true}
            end
            return retain('throwable_native_increase_no_pickup_credit')
        end
        last=n
        return {ammunitionId=approval.ammunitionId,quantity=n}
    end
    function T.AcceptNativePickup(baseline)
        if phase~='active' or not nativeIncrease or nativeIncrease.pending~=true or not pickupEnabled()
            or type(baseline)~='table' or baseline.phase~='active'
            or baseline.characterId~=bound.characterId or baseline.sessionId~=bound.sessionId
            or baseline.epoch~=bound.epoch or baseline.revision~=nativeIncrease.expectedRevision+1
            or type(baseline.pools)~='table' or baseline.pools[approval.ammunitionId]~=1
            or quantity()~=1 or type(api.rebindPickup)~='function' then return retain('throwable_pickup_ack_unconfirmed') end
        local ok,rebound=call('rebindPickup',copy(handle),copy(bound))
        if not ok or type(rebound)~='table' or type(rebound.guid)~='string' or #rebound.guid~=32
            or not rebound.guid:match('^[0-9a-f]+$') or rebound.guid==string.rep('0',32)
            or rebound.entity~=0 or rebound.inventoryOnly~=true or rebound.itemId~=approval.row.id
            or rebound.itemRevision~=approval.row.revision or quantity()~=1 or not current() then
            return retain('throwable_pickup_rebind_unconfirmed')
        end
        handle=copy(rebound); last=1; approval.ledgerRevision=baseline.revision; nativeIncrease=nil
        pickupAcceptedRevision=baseline.revision
        return true
    end
    function T.Release()
        if phase=='released' then return true end
        if phase~='active' and phase~='empty' then return nil,'throwable_exact_cleanup_unavailable' end
        if nativeIncrease and nativeIncrease.pending then return nil,'throwable_pickup_pending' end
        local ok,sealed=call('sealed',copy(bound))
        if not ok or type(sealed)~='table' or sealed.phase~='sealed'
            or sealed.characterId~=bound.characterId or sealed.sessionId~=bound.sessionId or sealed.epoch~=bound.epoch
            or type(sealed.revision)~='number' or sealed.revision%1~=0 or sealed.revision==math.huge
            or sealed.revision<approval.ledgerRevision or not current() then return nil,'throwable_seal_required' end
        local pools=WeaponCharacterAmmunition.Validate(sealed.pools,limits)
        if not pools then return nil,'throwable_sealed_pools_required' end
        for id in pairs(limits) do if sealed.pools[id]==nil then return nil,'throwable_sealed_pools_required' end end
        local observed,why=T.Observe()
        if not observed then return nil,why end
        local minimumRevision=approval.ledgerRevision+(last<approval.fundedQuantity and 1 or 0)
        if pools[approval.ammunitionId]~=last or sealed.revision<minimumRevision then
            return retain('throwable_final_observation_not_sealed')
        end
        phase='releasing'
        if handle then
            local name=last==0 and 'releaseSpent' or 'removeOwned'
            -- Spent proof must verify the captured native entry left the ped;
            -- never delete a world projectile or invent a recovered item.
            local called,cleaned,detail=call(name,copy(handle),copy(bound))
            if called and cleaned~=true and type(detail)=='string' and #detail<=96
                and detail:match('^throwable_[a-z_]+$') then return retain(detail) end
            if not called or cleaned~=true or not current() then return retain('throwable_cleanup_unconfirmed') end
        end
        local checked,present=call('present',copy(bound))
        if not checked or present~=false or quantity()~=0 then return retain('throwable_cleanup_readback_unconfirmed') end
        phase='released'; return true
    end
    return T
end
