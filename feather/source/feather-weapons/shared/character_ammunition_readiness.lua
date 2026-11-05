-- Readiness handshake only. No item, pool, limit or epoch credit from clients.
WeaponCharacterAmmoReadiness={}
local function identity(value)
    if type(value)~='table' then return false end
    for _,key in ipairs({'characterId','sessionId'}) do
        if type(value[key])~='string' or #value[key]<1 or #value[key]>128 then return false end
    end
    for key in pairs(value) do if key~='characterId' and key~='sessionId' then return false end end
    return true
end
local function idValid(id) return type(id)=='number' and id>=1 and id<=2147483647 and id%1==0 end
function WeaponCharacterAmmoReadiness.Server(api)
    local reservations,last={},{}
    local T={}
    function T.Receive(source,id,hint)
        if api.enabled()~=true or not idValid(id) or not identity(hint)
            or type(source)~='number' or source<1 or source%1~=0 then return false end
        local now=api.now()
        if reservations[source] or last[source] and now-last[source].time<1000 then return false end
        local token={sessionId=hint.sessionId}; reservations[source]=token
        last[source]={time=now,sessionId=hint.sessionId}
        local captured={characterId=hint.characterId,sessionId=hint.sessionId}
        local called,result=pcall(api.owner.Ready,source,captured)
        if reservations[source]~=token then return false end
        reservations[source]=nil
        if api.enabled()~=true then return false end
        local accepted=called and type(result)=='table' and result.ok==true
        local reason=not accepted and (called and type(result)=='table' and type(result.error)=='table'
            and result.error.code or 'activation_failed') or nil
        -- Never echo the authoritative bundle or caller-provided credit fields.
        api.reply(source,id,captured,accepted,reason)
        return true
    end
    function T.Cancel(source,sessionId)
        local removed=false
        if reservations[source] and (sessionId==nil or reservations[source].sessionId==sessionId) then
            reservations[source]=nil; removed=true
        end
        if last[source] and (sessionId==nil or last[source].sessionId==sessionId) then
            last[source]=nil; removed=true
        end
        return removed
    end
    return T
end
function WeaponCharacterAmmoReadiness.Client(api)
    local sequence,pending,accepted,attempts,nextTry,cycle,parked=0,nil,nil,0,0,nil,nil
    local usedRecovery
    local function same(a,b)
        return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId
    end
    local T={}
    function T.Step()
        if api.enabled()~=true then
            pending,accepted,cycle,parked,attempts,nextTry=nil,nil,nil,nil,0,0
            return nil,'readiness_disabled'
        end
        local hint=api.owner.Readiness()
        if not hint then
            -- Never reopen the same identity in the gap between logout cleanup
            -- and Character selection. Death recovery needs explicit rearming,
            -- not an inference from a transient closed/world-ready frame.
            if cycle then parked={characterId=cycle.characterId,sessionId=cycle.sessionId} end
            pending=nil; return false
        end
        if not identity(hint) then return nil,'invalid_local_readiness' end
        if not same(cycle,hint) then
            pending,accepted,parked,attempts,nextTry=nil,nil,nil,0,0
            cycle={characterId=hint.characterId,sessionId=hint.sessionId}
        end
        if same(parked,hint) then
            local recovery=type(api.owner.Recovery)=='function' and api.owner.Recovery() or nil
            if not same(recovery,hint) or type(recovery.epoch)~='string' or recovery.epoch==''
                or recovery.epoch==usedRecovery then return nil,'readiness_lifecycle_rearm_required' end
            -- Local driver emits this only after death cleanup + server release;
            -- owner also checks the current alive world and exact creation lease.
            usedRecovery=recovery.epoch
            pending,accepted,parked,attempts,nextTry=nil,nil,nil,0,0
        end
        if accepted and same(accepted,hint) then return true end
        if accepted then accepted=nil; attempts=0 end
        local now=api.now()
        if pending then
            if not same(pending.identity,hint) then pending=nil; attempts=0
            elseif now<pending.deadline then return false
            else pending=nil; nextTry=now+1000 end
        end
        if attempts>=6 then return nil,'readiness_retry_exhausted' end
        if now<nextTry then return false end
        sequence=sequence+1; if sequence>2147483647 then return nil,'readiness_id_exhausted' end
        attempts=attempts+1
        pending={id=sequence,identity={characterId=hint.characterId,sessionId=hint.sessionId},deadline=now+10000}
        api.send(sequence,pending.identity)
        return false
    end
    function T.Reply(id,hint,ok,reason,serverOrigin)
        if serverOrigin~=true or api.enabled()~=true or not pending or id~=pending.id
            or not identity(hint) or not same(hint,pending.identity) or type(ok)~='boolean' then return false end
        local current=api.owner.Readiness()
        if not same(current,hint) then pending=nil; return false end
        pending=nil
        if ok then accepted={characterId=hint.characterId,sessionId=hint.sessionId}
        else nextTry=api.now()+2000 end
        return true,reason
    end
    return T
end
