FeatherAuditProjection = {}

-- Only explicitly approved scalar context fields can leave the detail boundary.
function FeatherAuditProjection.Context(eventType, version, encoded, sensitive)
    local schema = FeatherAuditSchemaRegistry.Get(eventType, tonumber(version))
    if not schema or not schema.readProjection then return nil end
    if type(encoded) ~= 'string' or #encoded > FeatherAuditConstants.limits.contextBytes then return nil end
    local decoded, context = pcall(json.decode, encoded)
    if not decoded or type(context) ~= 'table' then return nil end
    local output = {}
    for field, class in pairs(schema.readProjection) do
        if class == 'internal' or (class == 'restricted' and sensitive == true) then
            local value, spec = context[field], schema.context.fields[field]
            local valid = (spec.type == 'string' and type(value) == 'string' and #value <= spec.maxBytes)
                or (spec.type == 'boolean' and type(value) == 'boolean')
                or (spec.type == 'integer' and type(value) == 'number' and value == value
                    and value ~= math.huge and value ~= -math.huge and value % 1 == 0
                    and (not spec.minimum or value >= spec.minimum)
                    and (not spec.maximum or value <= spec.maximum))
            if valid and spec.enum then
                valid = false
                for _, allowed in ipairs(spec.enum) do if value == allowed then valid = true break end end
            end
            if valid then output[field] = value end
        end
    end
    return { context = output, projectionVersion = 1 }
end
