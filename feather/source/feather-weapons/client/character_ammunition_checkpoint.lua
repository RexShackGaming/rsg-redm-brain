-- Dormant Character-compatible voluntary checkpoint. No registration/exports.
-- Independent host identity, not the supplied checkpoint context, is authority.
WeaponCharacterAmmoCheckpoint={}
-- Wait outside the runtime reservation: the server-requested release must be
-- able to enter that reservation while Character's logout export is yielding.
function WeaponCharacterAmmoCheckpoint.Lifecycle(api)
    local pending,sequence=nil,0
    local T={}
    local function err(code) return {ok=false,error={code=code},code=code} end
    local function same(a,b)
        return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId
            and a.sessionId==b.sessionId and a.epoch==b.epoch
    end
    function T.Reply(id,scope,result,serverOrigin)
        if serverOrigin~=true or not pending or pending.result or pending.id~=id or not same(scope,pending.scope) then return false end
        if type(result)~='table' or type(result.ok)~='boolean' then return false end
        pending.result=result; return true
    end
    function T.Run(context)
        if api.caller()~='feather-character' then return err('checkpoint_caller_denied') end
        if pending then return err('checkpoint_in_flight') end
        if type(context)~='table' or (context.reason~='logout' and context.reason~='save_quit') then return err('invalid_checkpoint_context') end
        local current=api.identity()
        local state=api.status()
        local baseline=state and state.session and state.session.ammo and state.session.ammo.baseline
        if not api.enabled() or not current or current.characterId~=context.characterId
            or not baseline or baseline.characterId~=current.characterId or baseline.sessionId~=current.sessionId
            or type(baseline.epoch)~='string' or state.phase~='active' or state.runtimeBusy
            or state.receiving or state.quiescing then return err('logout_wear_owner_not_settled') end
        sequence=sequence+1
        local request={id='logout-wear:'..sequence,scope={characterId=baseline.characterId,sessionId=baseline.sessionId,epoch=baseline.epoch}}
        pending=request
        local called,result=pcall(function()
            api.send(request.id,request.scope)
            local started=api.now()
            while not request.result do
                local value=api.identity()
                if not api.enabled() or not value or value.characterId~=request.scope.characterId or value.sessionId~=request.scope.sessionId then
                    return err('logout_wear_context_changed')
                end
                if (api.now()-started)%4294967296>=45000 then return err('logout_wear_timeout_no_retry') end
                api.wait(0)
            end
            if not request.result.ok then return request.result end
            local value=api.identity()
            if not api.enabled() or not value or value.characterId~=request.scope.characterId or value.sessionId~=request.scope.sessionId
                or api.status().phase~='closed' then return err('logout_wear_release_not_confirmed') end
            return {ok=true,value={released=true,characterId=request.scope.characterId,sessionId=request.scope.sessionId}}
        end)
        pending=nil
        if not called then return err('logout_wear_failed_no_retry') end
        return result
    end
    return T
end
function WeaponCharacterAmmoCheckpoint.New(receiver,api)
    local running=false
    local T={}
    local function err(code) return {ok=false,error={code=code},code=code} end
    function T.Run(context)
        if api.caller()~='feather-character' then return err('checkpoint_caller_denied') end
        if running then return err('checkpoint_in_flight') end
        if type(context)~='table' or (context.reason~='logout' and context.reason~='save_quit') then
            return err('invalid_checkpoint_context')
        end
        local identity=api.identity()
        if type(identity)~='table' or identity.characterId~=context.characterId
            or type(identity.sessionId)~='string' or identity.sessionId=='' then
            return err('checkpoint_identity_mismatch')
        end
        -- Reserve before the first yield. Even after successful cleanup, this
        -- retiring receiver cannot accept another loadout during logout RPC.
        running=true; receiver.Quiesce()
        local ok,result=pcall(function()
            local release=WeaponCharacterAmmoRelease.New(receiver,api)
            local requested,reason=release.Request(10000)
            if not requested then return err(reason) end
            while true do
                local current=api.identity()
                if type(current)~='table' or current.characterId~=identity.characterId
                    or current.sessionId~=identity.sessionId then
                    receiver.Suspend('checkpoint_world_changed'); return err('checkpoint_world_changed')
                end
                local done,why=release.Step()
                if done then
                    if receiver.Status().phase~='closed' then return err('checkpoint_not_released') end
                    return {ok=true,value={released=true,characterId=identity.characterId,sessionId=identity.sessionId}}
                end
                if release.Status().phase=='failed' then return err(why) end
                api.wait(0)
            end
        end)
        running=false
        if not ok then receiver.Suspend('checkpoint_failed'); return err('checkpoint_failed') end
        return result
    end
    return T
end
