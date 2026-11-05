WeaponValidation = {}

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function AddError(errors, path, message)
    errors[#errors + 1] = { path = path, message = message }
end

local function IsArray(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == #value
end

local function ValidateStringArray(errors, path, value)
    if not IsArray(value) then
        AddError(errors, path, "must be an array")
        return
    end
    local seen = {}
    for index, entry in ipairs(value) do
        if not IsNonEmptyString(entry) then
            AddError(errors, ("%s[%d]"):format(path, index), "must be a non-empty string")
        elseif seen[entry] then
            AddError(errors, ("%s[%d]"):format(path, index), "must not be duplicated")
        else
            seen[entry] = true
        end
    end
end

-- The singular field is the default; the array is the complete allowlist.
function WeaponValidation.AcceptsAmmunition(definition, ammunitionType)
    if type(definition.ammunitionTypes) ~= "table" then return false end
    for _, id in ipairs(definition.ammunitionTypes or {}) do
        if id == ammunitionType then return true end
    end
    return false
end

function WeaponValidation.EscrowMaximum(definition, ammunitionType)
    local capacity = math.max(1, math.floor(tonumber(definition and definition.capacity) or 1))
    local configured = math.max(capacity,
        math.floor(tonumber(Config and Config.Escrow and Config.Escrow.maxTotal) or capacity))
    local ammunition = WeaponDefinitionCatalog.ammunition[ammunitionType]
    local nativeMaximum = ammunition and tonumber(ammunition.maxTotal) or nil
    if nativeMaximum then configured = math.min(configured, math.floor(nativeMaximum)) end
    -- A native variant ceiling may be smaller than the weapon's regular clip
    -- capacity (for example explosive repeater ammunition).
    return math.max(0, configured)
end

function WeaponValidation.Definition(definition, expectedKind)
    local errors = {}
    if type(definition) ~= "table" then
        return false, { { path = "$", message = "definition must be a table" } }
    end

    if not IsNonEmptyString(definition.id) then AddError(errors, "id", "must be a non-empty string") end
    if definition.kind ~= expectedKind then AddError(errors, "kind", "must equal " .. tostring(expectedKind)) end
    if not IsNonEmptyString(definition.itemName) then AddError(errors, "itemName", "must be a non-empty string") end
    if not IsNonEmptyString(definition.label) then AddError(errors, "label", "must be a non-empty string") end

    if expectedKind == "weapon" then
        if definition.multiTypeAmmunition ~= nil and (type(definition.multiTypeAmmunition) ~= 'boolean'
            or (definition.multiTypeAmmunition and definition.usesAmmunition == false)) then
            AddError(errors, 'multiTypeAmmunition', 'must be boolean and requires ammunition support')
        end
        if not IsNonEmptyString(definition.nativeWeaponName) then AddError(errors, "nativeWeaponName",
                "must be a non-empty string") end
        if not WeaponConstants.WeaponSlots[definition.slot] then AddError(errors, "slot", "is not supported") end
        if definition.nativeGrantAmount ~= nil and (type(definition.nativeGrantAmount) ~= "number"
            or definition.nativeGrantAmount < 0 or definition.nativeGrantAmount % 1 ~= 0) then
            AddError(errors, "nativeGrantAmount", "must be a non-negative integer")
        end
        if definition.matchingPairSupported ~= nil then
            AddError(errors, "matchingPairSupported", "is no longer supported")
        end
        local usesAmmunition = definition.usesAmmunition ~= false
        if usesAmmunition then
            if not IsNonEmptyString(definition.ammunitionType) then AddError(errors, "ammunitionType",
                    "must reference ammunition") end
            ValidateStringArray(errors, "ammunitionTypes", definition.ammunitionTypes)
            if not WeaponValidation.AcceptsAmmunition(definition, definition.ammunitionType) then
                AddError(errors, "ammunitionTypes", "must include the default ammunitionType")
            end
            if type(definition.capacity) ~= "number" or definition.capacity < 1 or definition.capacity % 1 ~= 0 then
                AddError(errors, "capacity", "must be a positive integer")
            end
        else
            if definition.ammunitionType ~= nil then
                AddError(errors, "ammunitionType", "must be absent when ammunition is disabled")
            end
            if type(definition.ammunitionTypes) ~= "table" or #definition.ammunitionTypes ~= 0 then
                AddError(errors, "ammunitionTypes", "must be empty when ammunition is disabled")
            end
            if definition.capacity ~= 0 then
                AddError(errors, "capacity", "must be zero when ammunition is disabled")
            end
        end
        if type(definition.condition) ~= "table"
            or type(definition.condition.minimum) ~= "number"
            or type(definition.condition.maximum) ~= "number"
            or type(definition.condition.equipMinimum) ~= "number"
            or definition.condition.minimum > definition.condition.equipMinimum
            or definition.condition.equipMinimum > definition.condition.maximum then
            AddError(errors, "condition", "must define ordered minimum, equipMinimum, and maximum values")
        end
        local repair = definition.condition.repair
        if type(repair) ~= "table" or not IsNonEmptyString(repair.itemDefinitionId)
            or type(repair.quantity) ~= "number" or repair.quantity < 1 or repair.quantity % 1 ~= 0
            or type(repair.restore) ~= "number" or repair.restore <= 0 then
            AddError(errors, "condition.repair",
                "must define an item, positive integer quantity, and positive restore amount")
        end
        if type(definition.attachmentSlots) ~= "table" then
            AddError(errors, "attachmentSlots", "must be a table keyed by supported slot")
        else
            for slot, allowed in pairs(definition.attachmentSlots) do
                if not WeaponConstants.AttachmentSlots[slot] then
                    AddError(errors, "attachmentSlots." .. tostring(slot), "uses an unsupported slot")
                else
                    ValidateStringArray(errors, "attachmentSlots." .. slot, allowed)
                end
            end
        end
        if definition.attachmentDefaults ~= nil then
            if type(definition.attachmentDefaults) ~= "table" then
                AddError(errors, "attachmentDefaults", "must be a table keyed by supported slot")
            else
                for slot, label in pairs(definition.attachmentDefaults) do
                    if not WeaponConstants.AttachmentSlots[slot]
                        or type(definition.attachmentSlots) ~= "table"
                        or type(definition.attachmentSlots[slot]) ~= "table" then
                        AddError(errors, "attachmentDefaults." .. tostring(slot),
                            "must reference a declared attachment slot")
                    elseif not IsNonEmptyString(label) then
                        AddError(errors, "attachmentDefaults." .. tostring(slot),
                            "must be a non-empty label")
                    end
                end
            end
        end
    elseif expectedKind == "ammunition" then
        if not IsNonEmptyString(definition.nativeAmmoName) then AddError(errors, "nativeAmmoName",
        "must be a non-empty string") end
        if definition.maxTotal ~= nil and (type(definition.maxTotal) ~= "number"
            or definition.maxTotal < 1 or definition.maxTotal % 1 ~= 0) then
            AddError(errors, "maxTotal", "must be a positive integer when provided")
        end
    elseif expectedKind == "attachment" then
        if not WeaponConstants.AttachmentSlots[definition.slot] then AddError(errors, "slot", "is not supported") end
        if not IsNonEmptyString(definition.nativeComponentName) then AddError(errors, "nativeComponentName",
                "must be a non-empty string") end
        ValidateStringArray(errors, "conflicts", definition.conflicts)
        ValidateStringArray(errors, "prerequisites", definition.prerequisites)
        if type(definition.removable) ~= "boolean" then AddError(errors, "removable", "must be boolean") end
    end

    return #errors == 0, errors
end

function WeaponValidation.Metadata(metadata, definition)
    local errors = {}
    if type(metadata) ~= "table" then
        return false, { { path = "$", message = "metadata must be a table" } }
    end
    if tonumber(metadata.schemaVersion) ~= WeaponConstants.MetadataSchemaVersion then
        AddError(errors, "schemaVersion", "is unsupported")
    end
    if metadata.weaponDefinitionId ~= definition.id then
        AddError(errors, "weaponDefinitionId", "does not match the weapon definition")
    end
    if definition.policies.serialRequired and not IsNonEmptyString(metadata.serialNumber) then
        AddError(errors, "serialNumber", "is required")
    end

    local condition = tonumber(metadata.condition)
    if not condition or condition < definition.condition.minimum or condition > definition.condition.maximum then
        AddError(errors, "condition", "is outside the definition bounds")
    end

    if type(metadata.maintenance) ~= "table" then
        AddError(errors, "maintenance", "must be a native weapon maintenance record")
    else
        for _, field in ipairs({ "degradation", "permanentDegradation", "damage", "dirt", "soot" }) do
            local value = tonumber(metadata.maintenance[field])
            if not value or value < 0.0 or value > 1.0 then
                AddError(errors, "maintenance." .. field, "must be between 0 and 1")
            end
        end
        if tonumber(metadata.maintenance.permanentDegradation)
            and tonumber(metadata.maintenance.degradation)
            and metadata.maintenance.degradation < metadata.maintenance.permanentDegradation then
            AddError(errors, "maintenance.degradation", "cannot be below permanent degradation")
        end
    end

    if type(metadata.ammo) ~= "table" then
        AddError(errors, "ammo", "must be a table")
    else
        local usesAmmunition = definition.usesAmmunition ~= false
        if usesAmmunition
            and not WeaponValidation.AcceptsAmmunition(definition, metadata.ammo.type or definition.ammunitionType) then
            AddError(errors, "ammo.type", "must be compatible with this weapon")
        elseif not usesAmmunition and metadata.ammo.type ~= nil then
            AddError(errors, "ammo.type", "must be absent for an ammunition-free weapon")
        end
        local loaded = tonumber(metadata.ammo.loaded)
        if not loaded or loaded < 0 or loaded > (tonumber(definition.capacity) or 0) or loaded % 1 ~= 0 then
            AddError(errors, "ammo.loaded", "must be an integer within weapon capacity")
        end
        local reserve = tonumber(metadata.ammo.reserve or 0)
        local maxTotal = usesAmmunition and WeaponValidation.EscrowMaximum(
            definition, metadata.ammo.type or definition.ammunitionType) or 0
        if not reserve or reserve < 0 or reserve % 1 ~= 0 or (loaded or 0) + reserve > maxTotal then
            AddError(errors, "ammo.reserve", "must be a non-negative integer within the escrow limit")
        end
        if type(metadata.ammo.chambered) ~= "boolean" then
            AddError(errors, "ammo.chambered", "must be boolean")
        end
        if metadata.ammo.clips ~= nil then
            if definition.multiTypeAmmunition ~= true or type(metadata.ammo.clips) ~= 'table'
                or type(metadata.ammo.pools) ~= 'table' then
                AddError(errors, 'ammo.clips', 'requires multi-type pools')
            else
                for id, amount in pairs(metadata.ammo.clips) do
                    if not WeaponValidation.AcceptsAmmunition(definition, id)
                        or type(amount) ~= 'number' or amount ~= amount or amount < 0
                        or amount % 1 ~= 0 or amount > definition.capacity
                        or amount > (metadata.ammo.pools[id] or 0) then
                        AddError(errors, 'ammo.clips', 'contains an invalid per-type loaded count')
                    end
                end
                local selected = metadata.ammo.type or definition.ammunitionType
                if metadata.ammo.clips[selected] ~= loaded then
                    AddError(errors, 'ammo.clips', 'selected clip must match loaded count')
                end
            end
        end
        if metadata.ammo.pools ~= nil then
            if definition.multiTypeAmmunition ~= true or type(metadata.ammo.pools) ~= "table" then
                AddError(errors, "ammo.pools", "requires an opted-in multi-type carrier")
            else
                for id, total in pairs(metadata.ammo.pools) do
                    if not WeaponValidation.AcceptsAmmunition(definition, id)
                        or type(total) ~= "number" or total ~= total or total < 0
                        or total % 1 ~= 0
                        or total > WeaponValidation.EscrowMaximum(definition, id) then
                        AddError(errors, "ammo.pools", "contains incompatible or out-of-range ammunition")
                    end
                end
                local selected = metadata.ammo.type or definition.ammunitionType
                if metadata.ammo.pools[selected] ~= (loaded or 0) + (reserve or 0) then
                    AddError(errors, "ammo.pools", "selected pool must match loaded plus reserve")
                end
            end
        end
    end

    if not IsArray(metadata.attachments) then
        AddError(errors, "attachments", "must be an array")
    else
        local seenDefinitions = {}
        local seenSlots = {}
        for index, attachment in ipairs(metadata.attachments) do
            local path = ("attachments[%d]"):format(index)
            if type(attachment) ~= "table" then
                AddError(errors, path, "must be a table")
            else
                if not IsNonEmptyString(attachment.definitionId) then
                    AddError(errors, path .. ".definitionId", "must be a non-empty string")
                elseif seenDefinitions[attachment.definitionId] then
                    AddError(errors, path .. ".definitionId", "must not be duplicated")
                else
                    seenDefinitions[attachment.definitionId] = true
                end
                if not WeaponConstants.AttachmentSlots[attachment.slot] then
                    AddError(errors, path .. ".slot", "is not supported")
                elseif seenSlots[attachment.slot] then
                    AddError(errors, path .. ".slot", "is already occupied")
                else
                    seenSlots[attachment.slot] = true
                end
            end
        end
    end
    if type(metadata.cosmetics) ~= "table" then AddError(errors, "cosmetics", "must be a table") end
    if type(metadata.flags) ~= "table" then
        AddError(errors, "flags", "must be a table")
    else
        for _, key in ipairs({ "stolen", "evidence", "disabled" }) do
            if type(metadata.flags[key]) ~= "boolean" then AddError(errors, "flags." .. key, "must be boolean") end
        end
    end

    return #errors == 0, errors
end
