-- Factory only. Trusted server owner calls Start; clients cannot open sessions.
-- Serializes dispatch/ack/save/seal/release and never drops a hold on timeout.
WeaponCharacterAmmoDispatch={}
WeaponCharacterAmmoDispatch.RecoveryContract=1
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local function err(code) return {ok=false,error={code=code,message=code}} end
local function identityValid(value)
    if type(value)~='table' then return false end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(value[key])~='string' or value[key]=='' then return false end
    end
    return true
end
function WeaponCharacterAmmoDispatch.New(api)
    local states={}; local T={}
    local function same(state,report)
        local id=state and state.identity
        return id and type(report)=='table' and report.characterId==id.characterId
            and report.sessionId==id.sessionId and report.epoch==id.epoch
    end
    local function freeze(source,state,reason)
        if states[source]~=state then return err('stale_dispatch') end
        state.phase='frozen'; state.reason=reason
        if state.identity then pcall(api.service.FreezeLoadout,source,state.identity) end
        return err(reason)
    end
    local function restoreTimeout(source,state)
        state.restoreGeneration=(state.restoreGeneration or 0)+1
        local generation=state.restoreGeneration
        local scheduled=pcall(api.timeout,function()
            if states[source]==state and state.phase=='restoring' and state.restoreGeneration==generation then
                freeze(source,state,'dispatch_restore_timeout')
            end
        end)
        if not scheduled then return freeze(source,state,'dispatch_timeout_unavailable') end
    end
    function T.Start(source,catalog,policy)
        if api.enabled()~=true then return err('dispatch_disabled') end
        if type(source)~='number' or source<1 or source%1~=0 then return err('invalid_source') end
        if states[source] and states[source].phase~='released' then return err('dispatch_release_required') end
        -- Reserve before the Inventory snapshot can yield.
        local state={phase='opening'}; states[source]=state
        if api.identity then
            local called,value=pcall(api.identity,source)
            if states[source]~=state then return err('dispatch_lifecycle_changed') end
            if not called or type(value)~='table' or type(value.characterId)~='string' or type(value.sessionId)~='string' then
                states[source]=nil; return err('dispatch_session_unavailable')
            end
            state.identity={characterId=value.characterId,sessionId=value.sessionId}
            if state.cancelledSessions and state.cancelledSessions[value.sessionId] then
                states[source]=nil; return err('dispatch_lifecycle_changed')
            end
        end
        local ok,result=pcall(api.service.OpenLoadout,source,catalog,policy)
        if states[source]~=state then return err('dispatch_lifecycle_changed') end
        if not ok or type(result)~='table' then return freeze(source,state,'loadout_open_failed') end
        if not result.ok then states[source]=nil; return result end
        local bundle=result.value
        if state.identity and (not bundle or not bundle.runtime or bundle.runtime.characterId~=state.identity.characterId
            or bundle.runtime.sessionId~=state.identity.sessionId) then return freeze(source,state,'dispatch_open_session_changed') end
        if type(bundle)~='table' or type(bundle.runtime)~='table' or type(bundle.creation)~='table'
            or bundle.runtime.phase~='restoring' or not identityValid(bundle.runtime)
            or not identityValid(bundle.creation.identity)
            or bundle.creation.identity.characterId~=bundle.runtime.characterId
            or bundle.creation.identity.sessionId~=bundle.runtime.sessionId
            or bundle.creation.identity.epoch~=bundle.runtime.epoch then
            return freeze(source,state,'invalid_dispatch_bundle')
        end
        state.identity={characterId=bundle.runtime.characterId,sessionId=bundle.runtime.sessionId,epoch=bundle.runtime.epoch}
        state.phase='validating'
        local checkedOk,checked=pcall(api.service.ValidateLoadout,source)
        if states[source]~=state or state.phase~='validating' then return err('dispatch_lifecycle_changed') end
        if api.enabled()~=true then return freeze(source,state,'dispatch_disabled') end
        if not checkedOk or type(checked)~='table' or not checked.ok then
            return freeze(source,state,'dispatch_binding_changed')
        end
        state.phase='restoring'
        local sent,sentValue=pcall(api.dispatch,source,copy(bundle))
        if states[source]~=state then return err('dispatch_lifecycle_changed') end
        if not sent or sentValue==false then return freeze(source,state,'dispatch_send_failed') end
        local timeoutFailure=restoreTimeout(source,state)
        if timeoutFailure then return timeoutFailure end
        return {ok=true,value=copy(state.identity)}
    end
    local function request(source,report,from,to,method)
        if api.enabled()~=true then return err('dispatch_disabled') end
        local state=states[source]
        if not same(state,report) then return err('stale_dispatch') end
        if state.busy then return err('dispatch_in_flight') end
        if state.phase~=from then
            -- Exact duplicate release is safe, but never recreate a hold.
            if not (to=='released' and state.phase=='released') then return err('dispatch_phase_mismatch') end
        end
        state.busy=true
        local before=state.phase
        local ok,result
        if method=='Transfer' then
            local spec=report.transfer
            ok,result=pcall(api.service.Transfer,source,report,spec.ammunitionId,spec.amount,spec.operationId)
        else ok,result=pcall(api.service[method],source,report) end
        if states[source]~=state then return err('dispatch_lifecycle_changed') end
        state.busy=nil
        if state.phase~=before then return err('dispatch_lifecycle_changed') end
        if api.enabled()~=true then return freeze(source,state,'dispatch_disabled') end
        if not ok or type(result)~='table' or not result.ok then
            return freeze(source,state,'dispatch_'..method..'_failed')
        end
        if not same(state,result.value) or result.value.phase~=to then return freeze(source,state,'dispatch_ack_mismatch') end
        state.phase=to
        if to=='restoring' then
            local timeoutFailure=restoreTimeout(source,state)
            if timeoutFailure then return timeoutFailure end
        end
        return result
    end
    function T.ConfirmRestore(source,report) return request(source,report,'restoring','active','ConfirmRestore') end
    function T.Observe(source,report) return request(source,report,'active','active','Observe') end
    function T.NativePickup(source,report) return request(source,report,'active','active','NativePickup') end
    function T.Transfer(source,report)
        if type(report)~='table' or type(report.transfer)~='table' then return err('invalid_transfer') end
        return request(source,report,'active','restoring','Transfer')
    end
    function T.CheckpointAndSeal(source,report) return request(source,report,'active','sealed','CheckpointAndSeal') end
    function T.ConfirmCleanup(source,report) return request(source,report,'sealed','released','ConfirmCleanup') end
    -- Trusted lifecycle hook only; owner must revoke matching runtime itself.
    function T.Forget(source,sessionId)
        local state=states[source]
        if state and sessionId and not state.identity and state.phase=='opening' and api.identity then
            state.cancelledSessions=state.cancelledSessions or {}; state.cancelledSessions[sessionId]=true
            return true -- match against resolved identity, never cancel a different new session
        end
        if state and sessionId and (not state.identity or state.identity.sessionId~=sessionId) then return false end
        states[source]=nil; return true
    end
    function T.Status(source) return copy(states[source]) end
    return T
end
