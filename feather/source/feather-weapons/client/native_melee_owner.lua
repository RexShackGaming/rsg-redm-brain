-- Staged aggregate companion. The existing session remains the sole authority;
-- this module has no events, exports, commands, admission or automatic grants.
WeaponNativeMeleeOwner={}
local function copy(v)
    if type(v)~='table' then return v end
    local result={}; for k,x in pairs(v) do result[k]=copy(x) end; return result
end
function WeaponNativeMeleeOwner.New(approval,catalog,identity,factory,current)
    local bound,why=WeaponNativeMeleeCatalog.ValidateApproval(approval,catalog,identity)
    if not bound then return nil,why end
    assert(type(factory)=='function' and type(current)=='function','Local melee adapters required')
    local phase,reason,owners='idle',nil,{}
    local function live()
        local ok,value=pcall(current,copy(bound.identity)); return ok and value==true
    end
    local function retain(why) phase='retained'; reason=why; return nil,why end
    local T={}
    function T.Status()
        local items={}
        for n,entry in ipairs(bound.items) do
            local state={phase='not_created'}
            if owners[n] then
                local ok,value=pcall(owners[n].Status)
                state=ok and type(value)=='table' and value or {phase='unconfirmed'}
            end
            items[n]={itemId=entry.row.id,equipmentSlot=entry.equipmentSlot,phase=state.phase,
                reason=state.reason,entity=state.entity,itemRevision=state.itemRevision,
                cleanupEvidence=copy(state.cleanupEvidence),observation=copy(state.observation),
                guidOwnershipCaptured=state.guidOwnershipCaptured==true}
        end
        return {phase=phase,reason=reason,items=items}
    end
    function T.Create()
        if phase~='idle' then return nil,'melee_creation_already_attempted' end
        if not live() then return nil,'melee_world_changed' end
        phase='creating' -- reserve aggregate before a factory can yield/reenter
        for n,entry in ipairs(bound.items) do
            if not live() then return retain('melee_creation_world_changed') end
            -- Pass private row/identity copies from a freshly validated approval.
            local private=assert(WeaponNativeMeleeCatalog.ValidateApproval(bound,catalog,bound.identity))
            local ok,owner=pcall(factory,copy(catalog.weapons[entry.row.metadata.weaponDefinitionId]),private.identity)
            if not ok or type(owner)~='table' or type(owner.Create)~='function'
                or type(owner.Release)~='function' or type(owner.Status)~='function' then
                return retain('melee_factory_unconfirmed')
            end
            owners[n]=owner -- retain even if Create throws after its native grant
            local made,value=pcall(owner.Create,private.items[n].row)
            if not made or not value or not live() then return retain('melee_creation_unconfirmed') end
        end
        phase='active'; return true
    end
    function T.Release(deathRecovery)
        if phase=='released' then return true end
        -- Never compensate uncertain partial creation with a model-wide wipe.
        if phase~='active' then return nil,'melee_exact_cleanup_unavailable' end
        phase='releasing'
        for n=#owners,1,-1 do
            if not live() then return retain('melee_cleanup_world_changed') end
            local ok,value=pcall(owners[n].Release,deathRecovery==true)
            if not ok or value~=true or not live() then return retain('melee_cleanup_unconfirmed') end
            local checked,state=pcall(owners[n].Status)
            if not checked or type(state)~='table' or state.phase~='released' then return retain('melee_cleanup_not_released') end
        end
        phase='released'; return true
    end
    return T
end
