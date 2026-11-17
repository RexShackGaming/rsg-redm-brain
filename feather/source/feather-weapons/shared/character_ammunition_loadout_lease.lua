-- Server-owned revision binding; a snapshot is not a permanent item lease.
WeaponCharacterAmmoLoadoutLease={}
-- Same synchronous no-SQL guard is used by production registration and the
-- disposable cross-resource rollback probe. The predicate is server-owned.
function WeaponCharacterAmmoLoadoutLease.Guard(isBound)
    return function(instance)
        if isBound(instance.id) then
            return false,'Native loadout still owns this item; complete its release first.'
        end
        return true
    end
end
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function throwableBinding(assigned)
    if not assigned then return nil end
    if assigned.contract==3 then return {contract=3,units={}} end
    local value={row=copy(assigned.row),equipmentSlot=assigned.equipmentSlot}
    if assigned.contract==2 then value.contract=2;value.units=copy(assigned.units) end
    return value
end
local function throwableRows(binding) return binding and (binding.units or {binding.row}) or {} end
function WeaponCharacterAmmoLoadoutLease.New(plan,knifeApproval,meleeApproval,throwableSnapshot,limits,utilitySnapshot)
    assert(type(plan)=='table' and type(plan.identity)=='table' and type(plan.items)=='table','Creation plan required')
    local expected=copy(plan)
    local knife=knifeApproval and copy(knifeApproval) or nil
    local melee
    if meleeApproval then
        assert(not knife,'Companion approvals must not overlap')
        melee=assert(WeaponNativeMeleeCatalog.ValidateApproval(meleeApproval,WeaponDefinitionCatalog,expected.identity))
        for _,entry in ipairs(melee.items) do
            for _,item in ipairs(expected.items) do assert(item.itemInstanceId~=entry.row.id,'Melee/firearm item alias forbidden') end
        end
    end
    if knife then
        assert(WeaponNativeKnife and WeaponNativeKnife.ValidateApproval(knife,WeaponDefinitionCatalog.weapons.melee_knife,expected.identity),
            'Valid assigned knife approval required')
        for _,item in ipairs(expected.items) do assert(item.itemInstanceId~=knife.row.id,'Knife/firearm item alias forbidden') end
    end
    local throwable
    if throwableSnapshot then
        assert(WeaponNativeThrowableItem,'Throwable contract required')
        local assigned,why=WeaponNativeThrowableItem.Assigned(throwableSnapshot,WeaponDefinitionCatalog,expected.identity,limits)
        assert(assigned~=nil,why)
        if assigned then
            throwable=throwableBinding(assigned)
            for _,row in ipairs(throwableRows(throwable)) do
                for _,item in ipairs(expected.items) do assert(item.itemInstanceId~=row.id,'Throwable/firearm alias forbidden') end
                assert(not knife or knife.row.id~=row.id,'Throwable/knife alias forbidden')
                if melee then for _,entry in ipairs(melee.items) do assert(entry.row.id~=row.id,'Throwable/melee alias forbidden') end end
            end
        end
    end
    local utility
    if utilitySnapshot then
        assert(WeaponNativeUtilityItem,'Utility contract required')
        local assigned,why=WeaponNativeUtilityItem.AssignedSnapshot(utilitySnapshot,WeaponDefinitionCatalog,expected.identity)
        assert(assigned~=nil,why)
        utility=assigned or nil
        if utility then
            for _,tool in ipairs(utility.items or {utility}) do
                for _,item in ipairs(expected.items) do assert(item.itemInstanceId~=tool.row.id,'Utility/firearm alias forbidden') end
                assert(not knife or knife.row.id~=tool.row.id,'Utility/knife alias forbidden')
                for _,row in ipairs(throwableRows(throwable)) do assert(row.id~=tool.row.id,'Utility/throwable alias forbidden') end
                if melee then for _,entry in ipairs(melee.items) do assert(entry.row.id~=tool.row.id,'Utility/melee alias forbidden') end end
            end
        end
    end
    return {RecoverThrowable=function(before,after,receipt,catalog,registry)
        if not throwableSnapshot or throwableSnapshot.contract~=2 then return false,'physical_throwable_lease_required' end
        local prior,why=WeaponNativeThrowableItem.AssignedUnits(before,catalog,expected.identity,registry.limits)
        if prior==nil then return false,why end
        if not equal(throwableBinding(prior),throwable) then return false,'throwable_prior_lease_changed' end
        local recovered;recovered,why=WeaponNativeThrowableItem.Recovered(before,after,receipt,catalog,expected.identity,registry.limits)
        if not recovered then return false,why end
        local id=recovered.unit.id
        for _,item in ipairs(expected.items) do if item.itemInstanceId==id then return false,'throwable_firearm_alias' end end
        if knife and knife.row.id==id then return false,'throwable_knife_alias' end
        if melee then for _,entry in ipairs(melee.items) do if entry.row.id==id then return false,'throwable_melee_alias' end end end
        if utility then for _,tool in ipairs(utility.items or {utility}) do
            if tool.row.id==id then return false,'throwable_utility_alias' end
        end end
        -- Mutate only after every receipt, balance, identity and companion check.
        throwable=throwableBinding(recovered.approval)
        return true
    end,AdvanceThrowable=function(snapshot,catalog,registry)
        if not throwable or throwable.contract~=2 then return false,'physical_throwable_lease_required' end
        local assigned,why=WeaponNativeThrowableItem.Assigned(snapshot,catalog,expected.identity,registry.limits)
        if assigned==nil then return false,why end
        local now=throwableBinding(assigned)
        local remaining=throwableRows(now)
        if #remaining>=#throwable.units then return false,'throwable_spend_decrease_required' end
        for index,row in ipairs(remaining) do
            if not equal(row,throwable.units[index]) then return false,'throwable_remaining_units_changed' end
        end
        throwable=now
        return true
    end,Validate=function(snapshot,catalog,registry)
        if type(snapshot)~='table' or snapshot.characterId~=expected.identity.characterId
            or type(snapshot.equipment)~='table' then return false,'loadout_identity_changed' end
        local actual,reason=WeaponCharacterAmmoMaterialization.Build(snapshot.equipment,catalog,registry,expected.identity)
        if not actual then return false,reason end
        if not equal(actual,expected) then return false,'loadout_revision_or_content_changed' end
        if utilitySnapshot or snapshot.utilityEquipment~=nil then
            if not WeaponNativeUtilityItem or type(snapshot.utilityEquipment)~='table' then return false,'utility_snapshot_required' end
            local assigned,why=WeaponNativeUtilityItem.AssignedSnapshot(snapshot.utilityEquipment,catalog,expected.identity)
            if assigned==nil then return false,why end
            if not equal(assigned or nil,utility) then return false,'utility_revision_or_content_changed' end
        end
        if throwableSnapshot or snapshot.throwableEquipment~=nil then
            if not WeaponNativeThrowableItem or type(snapshot.throwableEquipment)~='table' then return false,'throwable_snapshot_required' end
            local assigned,why=WeaponNativeThrowableItem.Assigned(snapshot.throwableEquipment,catalog,expected.identity,registry.limits)
            if assigned==nil then return false,why end
            local now=throwableBinding(assigned)
            if not equal(now,throwable) then return false,'throwable_revision_or_content_changed' end
        end
        if melee or snapshot.meleeEquipment~=nil then
            if not WeaponNativeMeleeCatalog or type(snapshot.meleeEquipment)~='table' then return false,'melee_snapshot_required' end
            local actualMelee,why=WeaponNativeMeleeCatalog.Project(snapshot.meleeEquipment,catalog,expected.identity)
            if not actualMelee then return false,why end
            if not equal(actualMelee,melee) then return false,'melee_revision_or_content_changed' end
        end
        if knife or snapshot.knifeEquipment~=nil then
            if not WeaponNativeKnife or type(snapshot.knifeEquipment)~='table' then return false,'knife_snapshot_required' end
            local assigned,why=WeaponNativeKnife.Assigned(snapshot.knifeEquipment,catalog.weapons.melee_knife,expected.identity)
            if assigned==nil then return false,why end
            if not equal(assigned or nil,knife) then return false,'knife_revision_or_content_changed' end
        end
        return true
    end,Contains=function(itemId)
        if utility then for _,tool in ipairs(utility.items or {utility}) do if tool.row.id==tonumber(itemId) then return true end end end
        for _,row in ipairs(throwableRows(throwable)) do if row.id==tonumber(itemId) then return true end end
        if melee then for _,entry in ipairs(melee.items) do if entry.row.id==tonumber(itemId) then return true end end end
        if knife and knife.row.id==tonumber(itemId) then return true end
        for _,item in ipairs(expected.items) do if item.itemInstanceId==tonumber(itemId) then return true end end
        return false
    end}
end
