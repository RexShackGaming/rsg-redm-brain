-- Activation owner factory. Readiness is a hint, never loadout authority.
-- Kept dormant until normal startup/legacy quarantine is composed.
WeaponCharacterAmmoActivation={}
function WeaponCharacterAmmoActivation.New(api)
    local pending={}
    local function denied(code) return {ok=false,error={code=code}} end
    local function valid(id)
        return type(id)=='table' and type(id.characterId)=='string' and id.characterId~=''
            and type(id.sessionId)=='string' and id.sessionId~=''
    end
    local T={}
    function T.Ready(source,hint)
        if api.enabled()~=true then return denied('activation_disabled') end
        if type(source)~='number' or source<1 or source%1~=0 or not valid(hint) then
            return denied('invalid_activation_hint')
        end
        if pending[source] then return denied('activation_in_flight') end
        -- Copy before Core can yield; retain only identity, never client pools.
        local reservation={characterId=hint.characterId,sessionId=hint.sessionId}
        pending[source]=reservation
        local function finish(result)
            if pending[source]==reservation then pending[source]=nil end
            return result
        end
        local called,identity=pcall(api.identity,source)
        if pending[source]~=reservation then return denied('activation_cancelled') end
        if api.enabled()~=true then return finish(denied('activation_disabled')) end
        if not called or not valid(identity) or identity.characterId~=reservation.characterId
            or identity.sessionId~=reservation.sessionId then
            return finish(denied('activation_identity_changed'))
        end
        local inspected,state=pcall(api.dispatcher.Status,source)
        if not inspected then return finish(denied('activation_status_failed')) end
        if pending[source]~=reservation then return denied('activation_cancelled') end
        if api.enabled()~=true then return finish(denied('activation_disabled')) end
        if state and state.phase~='released' then
            -- Repeated readiness must not grant, replace or thaw a held owner.
            return finish(denied('activation_release_required'))
        end
        -- Dispatcher independently revalidates Core + Inventory across yields.
        local started,result=pcall(api.dispatcher.Start,source)
        if not started then return finish(denied('activation_start_failed')) end
        return finish(result)
    end
    function T.Cancel(source,sessionId)
        local owner=pending[source]
        if owner and (sessionId==nil or sessionId==owner.sessionId) then
            pending[source]=nil; return true
        end
        return false
    end
    return T
end
