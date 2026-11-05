EconomyCurrencies = {}

local catalog = {}

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local output = {}
    for key, child in pairs(value) do output[key] = Copy(child) end
    return output
end

local function ValidCode(value)
    return type(value) == 'string' and #value >= 1 and #value <= 32
        and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

local function Normalize(code, definition)
    if not ValidCode(code) or type(definition) ~= 'table'
        or type(definition.label) ~= 'string' or definition.label == ''
        or #definition.label > 64
        or type(definition.precision) ~= 'number'
        or definition.precision < 0 or definition.precision > 6
        or definition.precision ~= math.floor(definition.precision)
        or type(definition.enabled) ~= 'boolean' then
        return EconomyResults.Err('invalid_config',
            'An Economy currency definition is invalid.', { currency = tostring(code) })
    end
    return EconomyResults.Ok({
        code = code,
        label = definition.label,
        precision = definition.precision,
        enabled = definition.enabled
    })
end

function EconomyCurrencies.Start()
    local configured = Config and Config.Currencies
    if type(configured) ~= 'table' or next(configured) == nil then
        return EconomyResults.Err('invalid_config',
            'Config.Currencies must define at least one currency.')
    end

    local normalized = {}
    for code, definition in pairs(configured) do
        local result = Normalize(code, definition)
        if not result.ok then return result end
        normalized[code] = result.value
    end

    local rows = DB.query([[
        SELECT `currency_code`,`precision` FROM `economy_currencies`
    ]]) or {}
    for _, row in ipairs(rows) do
        local definition = normalized[row.currency_code]
        if not definition then
            return EconomyResults.Err('currency_config_missing',
                'A persisted currency is missing from Economy configuration.', {
                    currency = row.currency_code
                })
        end
        if tonumber(row.precision) ~= definition.precision then
            return EconomyResults.Err('currency_precision_conflict',
                'A configured currency precision differs from persisted Economy state.', {
                    currency = row.currency_code,
                    configured = definition.precision,
                    persisted = tonumber(row.precision)
                })
        end
    end

    local codes = {}
    for code in pairs(normalized) do codes[#codes + 1] = code end
    table.sort(codes)
    for _, code in ipairs(codes) do
        local definition = normalized[code]
        DB.exec([[
            INSERT INTO `economy_currencies`
                (`currency_code`,`label`,`precision`,`enabled`)
            VALUES (?,?,?,?)
            ON DUPLICATE KEY UPDATE
                `revision` = IF(`label` <> VALUES(`label`) OR `enabled` <> VALUES(`enabled`),
                    `revision` + 1, `revision`),
                `label` = VALUES(`label`),
                `enabled` = VALUES(`enabled`)
        ]], code, definition.label, definition.precision, definition.enabled and 1 or 0)
    end

    local persisted = DB.query([[
        SELECT `currency_code`,`label`,`precision`,`enabled`,`revision`,
               `created_at`,`updated_at`
        FROM `economy_currencies` ORDER BY `currency_code`
    ]]) or {}
    catalog = {}
    for _, row in ipairs(persisted) do
        catalog[row.currency_code] = {
            code = row.currency_code,
            label = row.label,
            precision = tonumber(row.precision),
            enabled = row.enabled == true or tonumber(row.enabled) == 1,
            revision = tonumber(row.revision),
            createdAt = row.created_at,
            updatedAt = row.updated_at
        }
    end
    return EconomyResults.Ok({ configured = #codes, persisted = #persisted })
end

function EconomyCurrencies.Get(code)
    if not ValidCode(code) then
        return EconomyResults.Err('invalid_input', 'currency must be a valid currency code.')
    end
    local currency = catalog[code]
    if not currency then
        return EconomyResults.Err('currency_not_found', 'Currency was not found.')
    end
    return EconomyResults.Ok(Copy(currency))
end

function EconomyCurrencies.List()
    local values = {}
    for _, currency in pairs(catalog) do values[#values + 1] = Copy(currency) end
    table.sort(values, function(left, right) return left.code < right.code end)
    return EconomyResults.Ok(values)
end

function EconomyCurrencies.Count()
    local count = 0
    for _ in pairs(catalog) do count = count + 1 end
    return count
end
