-- Canonical final-release wear plan; never trusts client item ownership/cost.
WeaponCharacterLifecycleWear={}
-- Bound untrusted death reports before any recursive copying or SQL yield.
function WeaponCharacterLifecycleWear.DeathReport(value)
    if type(value)~='table' or type(value.epoch)~='string' or #value.epoch<1 or #value.epoch>128
        or type(value.medicalRevision)~='number' or value.medicalRevision<0 or value.medicalRevision%1~=0
        or value.medicalRevision==math.huge or type(value.items)~='table' then return nil end
    local out={epoch=value.epoch,medicalRevision=value.medicalRevision,items={}}
    local count=0
    for index,item in pairs(value.items) do
        count=count+1
        if count>4 or type(index)~='number' or index<1 or index>4 or index%1~=0 or type(item)~='table'
            or type(item.itemInstanceId)~='number' or item.itemInstanceId<1 or item.itemInstanceId%1~=0 or item.itemInstanceId==math.huge
            or type(item.itemRevision)~='number' or item.itemRevision<0 or item.itemRevision%1~=0 or item.itemRevision==math.huge
            or type(item.maintenance)~='table' then return nil end
        local values={}
        for _,key in ipairs({'degradation','permanentDegradation','damage','dirt','soot'}) do
            local v=item.maintenance[key]
            if type(v)~='number' or v~=v or v<0 or v>1 then return nil end
            values[key]=v
        end
        out.items[index]={itemInstanceId=item.itemInstanceId,itemRevision=item.itemRevision,maintenance=values}
    end
    for index=1,count do if not out.items[index] then return nil end end
    return out
end
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
function WeaponCharacterLifecycleWear.BrokenEquipment(rows,catalog)
    local slots={primary='weapon',offhand='weapon_offhand',shoulder='weapon_shoulder',back='weapon_back'}
    local detached={}
    for logical,row in pairs(rows) do
        local definition=type(row)=='table' and row.metadata and catalog.weapons[row.metadata.weaponDefinitionId]
        if not slots[logical] or not definition or row.itemName~=definition.itemName
            or type(row.metadata.condition)~='number' or row.metadata.condition~=row.metadata.condition
            or type(definition.condition.equipMinimum)~='number' then return nil,'broken_equipment_snapshot_invalid' end
        if row.metadata.condition<definition.condition.equipMinimum then
            detached[slots[logical]]={itemId=row.id,minimum=definition.condition.equipMinimum,reason='broken'}
        end
    end
    if detached.weapon and rows.offhand and not detached.weapon_offhand then
        detached.weapon_offhand={itemId=rows.offhand.id,reason='primary_broken'}
        local definition=catalog.weapons[rows.offhand.metadata.weaponDefinitionId]
        if definition.slot=='sidearm' and not (rows.offhand.metadata.flags or {}).disabled
            and not (rows.offhand.metadata.flags or {}).evidence then
            detached.weapon_offhand.promote=true
            detached.weapon_offhand.minimum=definition.condition.equipMinimum
        end
    end
    return detached
end
function WeaponCharacterLifecycleWear.ProjectBroken(rows,detached)
    local projected=copy(rows)
    local offhand=projected.offhand
    local slots={weapon='primary',weapon_offhand='offhand',weapon_shoulder='shoulder',weapon_back='back'}
    for slot in pairs(detached) do projected[slots[slot]]=nil end
    if detached.weapon_offhand and detached.weapon_offhand.promote then projected.primary=offhand end
    return projected
end
function WeaponCharacterLifecycleWear.Plan(rows,readback,catalog,epoch,allowBroken)
    if type(rows)~='table' or type(readback)~='table' or readback.epoch~=epoch
        or type(readback.items)~='table' then return nil,'final_wear_readback_required' end
    local expected,count={},0
    for _,row in pairs(rows) do
        if type(row)~='table' or expected[row.id] then return nil,'final_wear_snapshot_invalid' end
        expected[row.id]=row; count=count+1
    end
    if count>4 then return nil,'final_wear_snapshot_invalid' end
    local seen,changes,projected={},{},copy(rows)
    for index,item in pairs(readback.items) do
        if type(index)~='number' or index<1 or index>4 or index%1~=0 or type(item)~='table' then return nil,'final_wear_report_invalid' end
        local row=expected[item.itemInstanceId]
        if not row or seen[row.id] or item.itemRevision~=row.revision then return nil,'final_wear_copy_revision_changed' end
        local definition=row.metadata and catalog.weapons[row.metadata.weaponDefinitionId]
        if not definition or row.itemName~=definition.itemName then return nil,'final_wear_definition_invalid' end
        local after,reason=WeaponCharacterMaintenance.Observe(row.metadata,definition,item.maintenance)
        if not after then return nil,reason end
        -- Broken-loadout policy must be explicit, not a hidden unequip/heal.
        if after.condition<definition.condition.equipMinimum and allowBroken~=true then return nil,'final_wear_broken_policy_pending' end
        for _,value in pairs(projected) do if value.id==row.id then value.metadata=copy(after) end end
        local changed=after.condition~=row.metadata.condition
        for key,value in pairs(after.maintenance) do changed=changed or value~=row.metadata.maintenance[key] end
        if changed then changes[#changes+1]={itemId=row.id,itemRevision=row.revision,before=copy(row.metadata),after=after} end
        seen[row.id]=true
    end
    for id in pairs(expected) do if not seen[id] then return nil,'final_wear_copy_missing' end end
    for index=1,count do if not readback.items[index] then return nil,'final_wear_report_sparse' end end
    table.sort(changes,function(a,b) return a.itemId<b.itemId end)
    local detached,reason=WeaponCharacterLifecycleWear.BrokenEquipment(projected,catalog)
    if not detached then return nil,reason end
    return changes,nil,detached
end
