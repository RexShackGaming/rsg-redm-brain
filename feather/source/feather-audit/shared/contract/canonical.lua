FeatherAuditCanonical = {}

local MAX_SAFE_INTEGER = 9007199254740991

local escapes = {
    ['"'] = '\\"',
    ['\\'] = '\\\\',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t'
}

local function encodeString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        return escapes[char] or ('\\u%04x'):format(char:byte())
    end) .. '"'
end

local function classifyTable(value, hint)
    local count, maximum = 0, 0
    for key in pairs(value) do
        if hint and hint.type == 'object' then
            if type(key) ~= 'string' then return nil, 'object_key_not_string' end
        elseif type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            if hint and hint.type == 'array' then return nil, 'mixed_array' end
            return 'object'
        end
        count = count + 1
        if type(key) == 'number' and key > maximum then maximum = key end
    end
    if hint and hint.type == 'object' then return 'object' end
    if count == 0 then return hint and hint.type == 'array' and 'array' or 'object' end
    if count ~= maximum then return nil, 'sparse_array' end
    return 'array'
end

local function encodeValue(value, hint, seen)
    local kind = type(value)
    if kind == 'nil' then return 'null' end
    if kind == 'boolean' then return value and 'true' or 'false' end
    if kind == 'string' then
        if utf8 and not utf8.len(value) then return nil, 'string_not_utf8' end
        return encodeString(value)
    end
    if kind == 'number' then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil, 'number_not_finite'
        end
        if value % 1 ~= 0 or math.abs(value) > MAX_SAFE_INTEGER then
            return nil, 'number_not_safe_integer'
        end
        if value == 0 then return '0' end
        return ('%.0f'):format(value)
    end
    if kind ~= 'table' then return nil, 'type_not_supported' end
    if seen[value] then return nil, 'table_cycle' end
    seen[value] = true

    local tableKind, classifyError = classifyTable(value, hint)
    if not tableKind then
        seen[value] = nil
        return nil, classifyError
    end

    local output = {}
    if tableKind == 'array' then
        local itemHint = hint and hint.items or nil
        for index = 1, #value do
            local encoded, err = encodeValue(value[index], itemHint, seen)
            if not encoded then
                seen[value] = nil
                return nil, err
            end
            output[#output + 1] = encoded
        end
        seen[value] = nil
        return '[' .. table.concat(output, ',') .. ']'
    end

    local keys = {}
    for key in pairs(value) do
        if type(key) ~= 'string' then
            seen[value] = nil
            return nil, 'object_key_not_string'
        end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local childHint = hint and hint.fields and hint.fields[key] or nil
        local encoded, err = encodeValue(value[key], childHint, seen)
        if not encoded then
            seen[value] = nil
            return nil, err
        end
        output[#output + 1] = encodeString(key) .. ':' .. encoded
    end
    seen[value] = nil
    return '{' .. table.concat(output, ',') .. '}'
end

local envelopeHint = {
    type = 'object',
    fields = {
        actor = { type = 'object' },
        targets = { type = 'array', items = { type = 'object' } },
        references = { type = 'array', items = { type = 'object' } },
        context = { type = 'object' }
    }
}

function FeatherAuditCanonical.Encode(value, hint)
    return encodeValue(value, hint, {})
end

function FeatherAuditCanonical.EncodeEvent(event, eventSchema)
    local hint = {
        type = envelopeHint.type,
        fields = {}
    }
    for key, value in pairs(envelopeHint.fields) do hint.fields[key] = value end
    if eventSchema and eventSchema.context then hint.fields.context = eventSchema.context end
    return encodeValue(event, hint, {})
end
