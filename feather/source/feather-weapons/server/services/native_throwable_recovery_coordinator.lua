-- Inert injected reconciliation protocol. No exports/events/threads/manifest.
-- Caller ports must provide real released authority, verified durable binding,
-- exact server projectile lifetime/proximity and transaction-backed delivery.
-- World mutation cannot roll back with SQL: uncertainty retains evidence and
-- never retries deletion or invents a replacement/refund.
WeaponNativeThrowableRecoveryCoordinator={}
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local function callable(v) return type(v)=='function' or (type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string') end
local function text(v) return type(v)=='string' and #v>0 and #v<=64 and not v:find('%c') end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function int(v,min) return finite(v) and v>=min and v%1==0 end
function WeaponNativeThrowableRecoveryCoordinator.New(api)
    for _,name in ipairs({'current','verified','inspect','consume','commit'}) do
        assert(type(api)=='table' and callable(api[name]),'Local server recovery port required')
    end
    local spends,projectiles,origins={},{},{}
    local O={}
    local function call(name,...)
        local ok,v=pcall(api[name],...); return ok,v
    end
    local function freeze(state,why)
        state.phase='frozen'; state.reason=why
        return nil,why
    end
    local function current(state)
        local ok,v=call('current',copy(state.context),copy(state.plan))
        return ok and v==true and state.phase~='frozen'
    end
    local function exactPresent(state,value)
        if type(value)~='table' or value.present~=true or value.instanceId~=state.plan.projectileInstanceId
            or value.networkId~=state.plan.networkId or value.model~='WEAPON_THROWN_TOMAHAWK'
            or value.actorAlive~=true or not int(value.bucket,0) or value.actorBucket~=value.bucket
            or type(value.position)~='table' or type(value.actorPosition)~='table' then return false end
        local distance=0
        for _,axis in ipairs({'x','y','z'}) do
            local a,b=value.position[axis],value.actorPosition[axis]
            if not finite(a) or not finite(b) then return false end
            distance=distance+(a-b)^2
        end
        return distance<=4 -- initial own-character recovery only, two metres
    end
    function O.Begin(context,plan)
        if type(context)~='table' or type(plan)~='table' or plan.kind~='projectile_binding_plan'
            or plan.version~=1 or plan.units~=1 or plan.pickupCredits~=false
            or not text(plan.spendReceiptId) or not text(plan.projectileInstanceId) or not text(plan.originEventId)
            or not int(plan.networkId,1) or type(plan.identity)~='table'
            or context.characterId~=plan.identity.characterId or context.sessionId~=plan.identity.sessionId
            or context.epoch~=plan.identity.epoch then return nil,'recovery_binding_required' end
        if spends[plan.spendReceiptId] or projectiles[plan.projectileInstanceId] or origins[plan.originEventId] then
            return nil,'recovery_already_reserved_no_retry'
        end
        local state={phase='validating',context=copy(context),plan=copy(plan),worldOutcome='not_requested',commitOutcome='not_requested'}
        -- Reserve all identities before any exported/native/SQL port can yield.
        spends[plan.spendReceiptId]=state; projectiles[plan.projectileInstanceId]=state; origins[plan.originEventId]=state
        if not current(state) then return freeze(state,'recovery_authority_changed') end
        local ok,verified=call('verified',copy(state.context),copy(state.plan))
        if not ok or verified~=true or not current(state) then return freeze(state,'recovery_verified_binding_required') end
        local seen,value=call('inspect',copy(state.plan))
        if not seen or not exactPresent(state,value) or not current(state) then return freeze(state,'recovery_projectile_or_proximity_changed') end
        state.phase='consuming'; state.worldOutcome='pending'
        local removed,result=call('consume',copy(state.plan))
        state.worldOutcome=removed and result==true and 'acknowledged' or 'uncertain'
        if state.worldOutcome~='acknowledged' or not current(state) then return freeze(state,'recovery_world_consumption_unconfirmed') end
        local checked,after=call('inspect',copy(state.plan))
        if not checked or type(after)~='table' or after.present~=false
            or after.instanceId~=state.plan.projectileInstanceId or not current(state) then
            return freeze(state,'recovery_exact_absence_unconfirmed')
        end
        state.worldOutcome='confirmed_absent'; state.phase='committing'; state.commitOutcome='pending'
        local committed,response=call('commit',copy(state.context),copy(state.plan))
        state.commitOutcome=not committed and 'uncertain' or type(response)=='table' and response.ok==false and 'refused'
            or type(response)=='table' and response.ok==true and 'confirmed' or 'uncertain'
        if state.commitOutcome~='confirmed' then return freeze(state,'recovery_world_consumed_commit_'..state.commitOutcome) end
        if not current(state) then return freeze(state,'recovery_committed_authority_changed') end
        state.phase='complete'
        return true
    end
    function O.Status(spendId)
        local state=spends[spendId]
        return state and {phase=state.phase,reason=state.reason,worldOutcome=state.worldOutcome,
            commitOutcome=state.commitOutcome,projectileInstanceId=state.plan.projectileInstanceId} or nil
    end
    return O
end
