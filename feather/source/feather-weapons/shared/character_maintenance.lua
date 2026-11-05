-- Pure metadata policy. Callers still own lease checks, CAS and material payment.
WeaponCharacterMaintenance={}
local fields={'degradation','permanentDegradation','damage','dirt','soot'}
local allowed={}; for _,key in ipairs(fields) do allowed[key]=true end
local function unit(value)
    return type(value)=='number' and value==value and value>=0 and value<=1
end
local function validate(metadata,definition)
    local copy,reason=WeaponCharacterAmmoItem.Validate(metadata,definition)
    if not copy then return nil,reason end
    for _,key in ipairs(fields) do
        if not unit(copy.maintenance[key]) then return nil,'invalid_maintenance' end
    end
    if copy.flags.disabled or copy.flags.evidence then return nil,'weapon_not_serviceable' end
    if copy.weaponDefinitionId~=definition.id then return nil,'weapon_definition_mismatch' end
    return copy
end
local function condition(maintenance,definition)
    return math.floor((1-math.max(maintenance.degradation,maintenance.damage,
        maintenance.permanentDegradation))*definition.condition.maximum+0.5)
end
function WeaponCharacterMaintenance.Observe(metadata,definition,report)
    local copy,reason=validate(metadata,definition)
    if not copy then return nil,reason end
    if type(report)~='table' then return nil,'invalid_maintenance_report' end
    for key in pairs(report) do if not allowed[key] then return nil,'invalid_maintenance_report' end end
    for _,key in ipairs(fields) do
        if not unit(report[key]) then return nil,'invalid_maintenance_report' end
        -- Native floats such as 0.10000000149 must not churn durable revisions.
        if report[key]>copy.maintenance[key]+0.0001 then copy.maintenance[key]=report[key] end
    end
    local permanent=copy.maintenance.permanentDegradation
    copy.maintenance.degradation=math.max(permanent,copy.maintenance.degradation)
    copy.maintenance.damage=math.max(permanent,copy.maintenance.damage)
    copy.condition=math.min(copy.condition,condition(copy.maintenance,definition))
    return copy
end
function WeaponCharacterMaintenance.Repair(metadata,definition)
    local copy,reason=validate(metadata,definition)
    if not copy then return nil,reason end
    local recipe=definition.condition.repair
    if type(recipe)~='table' or type(recipe.itemDefinitionId)~='string' or recipe.itemDefinitionId==''
        or type(recipe.quantity)~='number' or recipe.quantity<1 or recipe.quantity==math.huge
        or recipe.quantity%1~=0 then return nil,'invalid_repair_recipe' end
    local maintenance=copy.maintenance
    local permanent=maintenance.permanentDegradation
    maintenance.degradation=permanent; maintenance.damage=permanent
    maintenance.dirt=0; maintenance.soot=0
    local restored=condition(maintenance,definition)
    if restored<copy.condition then return nil,'inconsistent_permanent_condition' end
    local changed=restored~=copy.condition
    for _,key in ipairs(fields) do changed=changed or maintenance[key]~=metadata.maintenance[key] end
    if not changed then return nil,'weapon_already_serviced' end
    copy.condition=restored
    return copy,{itemDefinitionId=recipe.itemDefinitionId,quantity=recipe.quantity}
end
