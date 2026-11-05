DefinitionRegistry = {}
local registry = { weapon = {}, ammunition = {}, attachment = {} }
local ready = false

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

local function RegisterGroup(group, kind, errors)
    for key, definition in pairs(group or {}) do
        local valid, definitionErrors = WeaponValidation.Definition(definition, kind)
        if key ~= definition.id then
            definitionErrors[#definitionErrors + 1] = { path = "id", message = "must match catalog key " .. tostring(key) }
            valid = false
        end
        if registry[kind][definition.id] then
            definitionErrors[#definitionErrors + 1] = { path = "id", message = "is duplicated" }
            valid = false
        end
        if not valid then
            errors[#errors + 1] = { kind = kind, key = key, errors = definitionErrors }
        else
            registry[kind][definition.id] = Copy(definition)
        end
    end
end

function DefinitionRegistry.Start()
    registry = { weapon = {}, ammunition = {}, attachment = {} }
    local errors = {}
    RegisterGroup(WeaponDefinitionCatalog.ammunition, "ammunition", errors)
    RegisterGroup(WeaponDefinitionCatalog.attachments, "attachment", errors)
    RegisterGroup(WeaponDefinitionCatalog.weapons, "weapon", errors)

    for id, definition in pairs(registry.weapon) do
        for _, ammunitionType in ipairs(definition.ammunitionTypes) do
            if not registry.ammunition[ammunitionType] then
                errors[#errors + 1] = {
                    kind = "weapon",
                    key = id,
                    errors = { { path = "ammunitionTypes", message = "references unknown ammunition " .. tostring(ammunitionType) } }
                }
            end
        end
    end

    for id, definition in pairs(registry.weapon) do
        for slot, attachmentIds in pairs(definition.attachmentSlots or {}) do
            for _, attachmentId in ipairs(attachmentIds) do
                local attachment = registry.attachment[attachmentId]
                if not attachment then
                    errors[#errors + 1] = { kind = "weapon", key = id, errors = { { path = "attachmentSlots." .. slot, message = "references unknown attachment " .. attachmentId } } }
                elseif attachment.slot ~= slot then
                    errors[#errors + 1] = { kind = "weapon", key = id, errors = { { path = "attachmentSlots." .. slot, message = "attachment " .. attachmentId .. " belongs to slot " .. tostring(attachment.slot) } } }
                else
                    for _, prerequisiteId in ipairs(attachment.prerequisites or {}) do
                        local prerequisite = registry.attachment[prerequisiteId]
                        if prerequisite and prerequisite.slot == attachment.slot then
                            errors[#errors + 1] = { kind = "weapon", key = id, errors = { { path = "attachmentSlots." .. slot, message = "attachment " .. attachmentId .. " requires " .. prerequisiteId .. " in the same exclusive slot" } } }
                        elseif prerequisite then
                            local compatible = false
                            for _, allowedId in ipairs((definition.attachmentSlots or {})[prerequisite.slot] or {}) do
                                if allowedId == prerequisiteId then compatible = true; break end
                            end
                            if not compatible then
                                errors[#errors + 1] = { kind = "weapon", key = id, errors = { { path = "attachmentSlots." .. slot, message = "attachment " .. attachmentId .. " requires incompatible attachment " .. prerequisiteId } } }
                            end
                        end
                    end
                end
            end
        end
    end
    for id, attachment in pairs(registry.attachment) do
        for _, conflictId in ipairs(attachment.conflicts or {}) do
            if conflictId == id or not registry.attachment[conflictId] then
                errors[#errors + 1] = { kind = "attachment", key = id, errors = { { path = "conflicts", message = "references invalid attachment " .. tostring(conflictId) } } }
            end
        end
        for _, prerequisiteId in ipairs(attachment.prerequisites or {}) do
            if prerequisiteId == id or not registry.attachment[prerequisiteId] then
                errors[#errors + 1] = { kind = "attachment", key = id, errors = { { path = "prerequisites", message = "references invalid attachment " .. tostring(prerequisiteId) } } }
            end
            for _, conflictId in ipairs(attachment.conflicts or {}) do
                if conflictId == prerequisiteId then
                    errors[#errors + 1] = { kind = "attachment", key = id, errors = { { path = "prerequisites", message = "also conflicts with attachment " .. tostring(prerequisiteId) } } }
                end
            end
            local prerequisite = registry.attachment[prerequisiteId]
            for _, conflictId in ipairs(prerequisite and prerequisite.conflicts or {}) do
                if conflictId == id then
                    errors[#errors + 1] = { kind = "attachment", key = id, errors = { { path = "prerequisites", message = "is conflicted by attachment " .. tostring(prerequisiteId) } } }
                end
            end
        end
    end

    local visiting, visited = {}, {}
    local function VisitPrerequisites(id)
        if visiting[id] then
            errors[#errors + 1] = { kind = "attachment", key = id, errors = { { path = "prerequisites", message = "contains a cycle" } } }
            return
        end
        if visited[id] then return end
        visiting[id] = true
        local attachment = registry.attachment[id]
        for _, prerequisiteId in ipairs(attachment and attachment.prerequisites or {}) do
            if registry.attachment[prerequisiteId] then VisitPrerequisites(prerequisiteId) end
        end
        visiting[id], visited[id] = nil, true
    end
    for id in pairs(registry.attachment) do VisitPrerequisites(id) end

    ready = #errors == 0
    if not ready then
        return WeaponResult.Error(WeaponErrors.INVALID_DEFINITION, "Weapon definitions failed validation", errors)
    end
    return WeaponResult.Ok(DefinitionRegistry.Counts())
end

function DefinitionRegistry.ValidateAttachmentSet(weaponId, installed)
    local weapon = registry.weapon[weaponId]
    if not weapon then
        return WeaponResult.Error(WeaponErrors.DEFINITION_NOT_FOUND, "Definition was not found",
            { kind = "weapon", id = weaponId })
    end
    local present = {}
    for index, entry in ipairs(installed or {}) do
        local attachment = registry.attachment[entry.definitionId]
        if not attachment then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Installed attachment definition was not found",
                { index = index, attachmentId = entry.definitionId })
        end
        if entry.slot ~= attachment.slot then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                "Installed attachment slot does not match its definition",
                { index = index, attachmentId = entry.definitionId, expected = attachment.slot, actual = entry.slot })
        end
        if not DefinitionRegistry.IsAttachmentCompatible(weaponId, entry.definitionId) then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Attachment is not compatible with this weapon",
                { index = index, weaponId = weaponId, attachmentId = entry.definitionId })
        end
        present[entry.definitionId] = true
    end
    for _, entry in ipairs(installed or {}) do
        local attachment = registry.attachment[entry.definitionId]
        for _, conflictId in ipairs(attachment.conflicts or {}) do
            if present[conflictId] then
                return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Installed attachments conflict",
                    { attachmentId = entry.definitionId, conflictId = conflictId })
            end
        end
        for _, prerequisiteId in ipairs(attachment.prerequisites or {}) do
            if not present[prerequisiteId] then
                return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Attachment prerequisite is not installed",
                    { attachmentId = entry.definitionId, prerequisiteId = prerequisiteId })
            end
        end
    end
    return WeaponResult.Ok(true)
end

function DefinitionRegistry.IsAttachmentCompatible(weaponId, attachmentId)
    local weapon = registry.weapon[weaponId]
    local attachment = registry.attachment[attachmentId]
    if not weapon or not attachment then return false end
    for _, allowedId in ipairs((weapon.attachmentSlots or {})[attachment.slot] or {}) do
        if allowedId == attachmentId then return true end
    end
    return false
end

function DefinitionRegistry.ListCompatibleAttachments(weaponId)
    local weapon = registry.weapon[weaponId]
    if not weapon then
        return WeaponResult.Error(WeaponErrors.DEFINITION_NOT_FOUND, "Definition was not found",
            { kind = "weapon", id = weaponId })
    end
    local result = {}
    for _, attachmentIds in pairs(weapon.attachmentSlots or {}) do
        for _, attachmentId in ipairs(attachmentIds) do result[#result + 1] = Copy(registry.attachment[attachmentId]) end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return WeaponResult.Ok(result)
end

function DefinitionRegistry.IsReady()
    return ready
end

function DefinitionRegistry.Get(kind, id)
    local group = registry[kind]
    local definition = group and group[id]
    if not definition then
        return WeaponResult.Error(WeaponErrors.DEFINITION_NOT_FOUND, "Definition was not found", { kind = kind, id = id })
    end
    return WeaponResult.Ok(Copy(definition))
end

function DefinitionRegistry.List(kind)
    local result = {}
    for _, definition in pairs(registry[kind] or {}) do result[#result + 1] = Copy(definition) end
    table.sort(result, function(a, b) return a.id < b.id end)
    return WeaponResult.Ok(result)
end

function DefinitionRegistry.Counts()
    local counts = {}
    for kind, group in pairs(registry) do
        local count = 0
        for _ in pairs(group) do count = count + 1 end
        counts[kind] = count
    end
    return counts
end
