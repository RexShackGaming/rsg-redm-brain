-- Inert server observation cache. No event registration, manifest admission,
-- native mutation, economic writes or authenticated-origin assertion.
WeaponNativeThrowableProjectileObserver={}
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function integer(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=96 and not v:find('%c') end
local function callable(v)
    return type(v)=='function' or (type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string')
end
function WeaponNativeThrowableProjectileObserver.New(api)
    assert(type(api)=='table' and text(api.bootId) and integer(api.weaponHash,0) and integer(api.objectModel,0),
        'Explicit server boot namespace and independently verified weapon/object hashes required')
    for _,name in ipairs({'now','session','entity'}) do assert(callable(api[name]),'Server observation port required') end
    local namespace,weapon,model=api.bootId,api.weaponHash,api.objectModel
    local records,hints,sequence,lastTime={},{},0,nil
    local O={}
    local function now()
        local ok,n=pcall(api.now)
        if not ok or not integer(n,0) or (lastTime and n<lastTime) then
            records,hints={},{}; return nil
        end
        lastTime=n
        for id,row in pairs(records) do if n-row.createdAtMs>30000 then records[id]=nil end end
        for id,row in pairs(hints) do if n-row.observedAtMs>3000 then hints[id]=nil end end
        return n
    end
    local function session(source)
        if not integer(source,1) then return nil end
        local ok,s=pcall(api.session,source)
        if not ok or type(s)~='table' or type(s.identity)~='table' or not integer(s.pedNetworkId,1) then return nil end
        for _,k in ipairs({'characterId','sessionId','epoch'}) do if not text(s.identity[k]) then return nil end end
        return {identity=copy(s.identity),pedNetworkId=s.pedNetworkId}
    end
    function O.ProjectileHint(source,data)
        local time=now(); local s=session(source)
        if not time or not s or type(data)~='table' or data.weaponHash~=weapon or data.ownerId~=s.pedNetworkId then
            return nil,'projectile_hint_unconfirmed'
        end
        local size=0; for _ in pairs(hints) do size=size+1 end
        if size>=16 and not hints[source] then return nil,'projectile_hint_capacity' end
        -- An untrusted engine/client event can never manufacture origin proof.
        hints[source]={identity=s.identity,observedAtMs=time,weaponHash=weapon,originConfirmed=false}
        return true
    end
    function O.Created(handle)
        local time=now()
        if not time or not integer(handle,1) then return nil,'projectile_entity_unconfirmed' end
        local size=0; for _ in pairs(records) do size=size+1 end
        if records[handle] then return nil,'projectile_lifetime_already_observed' end
        if size>=64 then return nil,'projectile_observer_capacity' end
        local ok,e=pcall(api.entity,handle)
        if not ok or type(e)~='table' or e.exists~=true or e.model~=model
            or not integer(e.networkId,1) or not integer(e.ownerSource,1) then return nil,'projectile_entity_unconfirmed' end
        local s=session(e.ownerSource)
        if not s then return nil,'projectile_owner_unconfirmed' end
        -- Re-read after potentially yielding ports; ID reuse/owner migration or
        -- session replacement must not be captured as the original lifetime.
        local checked,again=pcall(api.entity,handle); local after=session(e.ownerSource)
        if not checked or type(again)~='table' or again.exists~=true or again.model~=e.model
            or again.networkId~=e.networkId or again.ownerSource~=e.ownerSource or not after
            or after.identity.sessionId~=s.identity.sessionId or after.identity.characterId~=s.identity.characterId
            or after.identity.epoch~=s.identity.epoch then return nil,'projectile_observation_changed' end
        sequence=sequence+1
        local hint=hints[e.ownerSource]
        local matched=hint and hint.identity.sessionId==s.identity.sessionId
            and hint.identity.epoch==s.identity.epoch and hint.identity.characterId==s.identity.characterId
            and time>=hint.observedAtMs and time-hint.observedAtMs<=3000 or false
        records[handle]={instanceId=namespace..':'..sequence,handle=handle,networkId=e.networkId,
            model=e.model,ownerSource=e.ownerSource,identity=s.identity,createdAtMs=time,
            correlatedHint=matched,originConfirmed=false,pickupCredits=false,kind='untrusted_projectile_observation'}
        return copy(records[handle])
    end
    function O.Removed(handle) records[handle]=nil end
    function O.Read(handle)
        if not now() then return nil end
        return records[handle] and copy(records[handle]) or nil
    end
    return O
end
