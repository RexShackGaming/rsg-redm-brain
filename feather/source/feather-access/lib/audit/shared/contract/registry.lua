FeatherAuditSchemaRegistry = {}

local schemas = {}

local function schemaKey(eventType, eventVersion)
    return ('%s@%s'):format(eventType, eventVersion)
end

local allowedValueTypes = { string = true, integer = true, boolean = true, array = true, object = true }

local function validEventType(value)
    if type(value) ~= 'string' or #value > FeatherAuditConstants.limits.keyBytes
        or value:sub(-1) == '.' or value:find('%.%.', 1, false)
        or not value:find('.', 1, true) then return false end
    for segment in value:gmatch('[^%.]+') do
        if not segment:match('^[a-z][a-z0-9_]*$') then return false end
    end
    return true
end

local function validateValueSpec(spec, depth)
    if type(spec) ~= 'table' or not allowedValueTypes[spec.type] or depth > 5 then return false end
    if spec.required ~= nil and type(spec.required) ~= 'boolean' then return false end
    if spec.type == 'array' then return validateValueSpec(spec.items, depth + 1) end
    if spec.type == 'object' then
        if type(spec.fields) ~= 'table' then return false end
        for key, child in pairs(spec.fields) do
            if type(key) ~= 'string' or not key:match('^[a-z][a-z0-9_]*$')
                or not validateValueSpec(child, depth + 1) then return false end
        end
    end
    if spec.enum ~= nil and type(spec.enum) ~= 'table' then return false end
    if spec.minimum ~= nil and type(spec.minimum) ~= 'number' then return false end
    if spec.maximum ~= nil and type(spec.maximum) ~= 'number' then return false end
    if spec.maxBytes ~= nil and (type(spec.maxBytes) ~= 'number' or spec.maxBytes < 1) then return false end
    if spec.maxItems ~= nil and (type(spec.maxItems) ~= 'number' or spec.maxItems < 0) then return false end
    return true
end

function FeatherAuditSchemaRegistry.Register(schema)
    if type(schema) ~= 'table' or not validEventType(schema.eventType)
        or type(schema.eventVersion) ~= 'number' or schema.eventVersion < 1
        or schema.eventVersion % 1 ~= 0 or not validateValueSpec(schema.context, 0) then
        return false, FeatherAuditResults.fieldInvalid
    end
    if schema.minimumSensitivity and not FeatherAuditConstants.sensitivityClasses[schema.minimumSensitivity] then
        return false, FeatherAuditResults.fieldInvalid
    end
    if schema.retentionClass and not FeatherAuditConstants.retentionClasses[schema.retentionClass] then
        return false, FeatherAuditResults.fieldInvalid
    end
    if schema.minimumTargets and (type(schema.minimumTargets) ~= 'number'
        or schema.minimumTargets < 0 or schema.minimumTargets % 1 ~= 0
        or schema.minimumTargets > FeatherAuditConstants.limits.targets) then
        return false, FeatherAuditResults.fieldInvalid
    end
    if schema.readProjection ~= nil then
        if type(schema.readProjection) ~= 'table' or schema.context.type ~= 'object' then
            return false, FeatherAuditResults.fieldInvalid
        end
        for field, class in pairs(schema.readProjection) do
            local spec = schema.context.fields[field]
            if not spec or (class ~= 'internal' and class ~= 'restricted')
                or (spec.type ~= 'string' and spec.type ~= 'integer' and spec.type ~= 'boolean')
                or (spec.type == 'string' and (not spec.maxBytes or spec.maxBytes > 1024)) then
                return false, FeatherAuditResults.fieldInvalid
            end
        end
    end
    local key = schemaKey(schema.eventType, schema.eventVersion)
    if schemas[key] then return false, 'schema_already_registered' end
    schemas[key] = schema
    return true
end

function FeatherAuditSchemaRegistry.Get(eventType, eventVersion)
    return schemas[schemaKey(eventType, eventVersion)]
end

function FeatherAuditSchemaRegistry.HasEventType(eventType)
    local prefix = eventType .. '@'
    for key in pairs(schemas) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

function FeatherAuditSchemaRegistry.ResetForTests()
    schemas = {}
end
