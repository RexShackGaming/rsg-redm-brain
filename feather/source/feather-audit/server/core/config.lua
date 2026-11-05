FeatherAuditConfig = {}

local function validName(value)
    return type(value) == 'string' and value ~= '' and #value <= 128
        and value:match('^[A-Za-z0-9][A-Za-z0-9%._:%-]*$') ~= nil
end

function FeatherAuditConfig.Validate()
    if not validName(Config.SourceInstance) then return false, 'invalid_source_instance' end
    if type(Config.Producers) ~= 'table' then return false, 'invalid_producers' end
    if type(Config.Ingestion) ~= 'table'
        or type(Config.Ingestion.defaultMaxPerMinute) ~= 'number'
        or Config.Ingestion.defaultMaxPerMinute < 1
        or Config.Ingestion.defaultMaxPerMinute % 1 ~= 0 then
        return false, 'invalid_default_rate_limit'
    end
    for resource, registration in pairs(Config.Producers) do
        if type(resource) ~= 'string' or not resource:match('^[a-z0-9][a-z0-9_%-]*$')
            or type(registration) ~= 'table' then return false, 'invalid_producer_registration' end
        if registration.enabled ~= false then
            if not validName(registration.sourceInstance or Config.SourceInstance)
                or type(registration.eventPrefixes) ~= 'table' or #registration.eventPrefixes < 1
                or type(registration.versions) ~= 'table' then
                return false, 'invalid_producer_registration:' .. resource
            end
            for _, prefix in ipairs(registration.eventPrefixes) do
                if type(prefix) ~= 'string' or #prefix < 2 or #prefix > 128
                    or not prefix:match('^[a-z][a-z0-9_%.]*%.$')
                    or prefix:find('%.%.', 1, false) then
                    return false, 'invalid_producer_prefix:' .. resource
                end
            end
            local hasVersion = false
            for version, allowed in pairs(registration.versions) do
                if type(version) ~= 'number' or version < 1 or version % 1 ~= 0 or allowed ~= true then
                    return false, 'invalid_producer_version:' .. resource
                end
                hasVersion = true
            end
            if not hasVersion then return false, 'invalid_producer_versions:' .. resource end
            if registration.maxPerMinute ~= nil and (type(registration.maxPerMinute) ~= 'number'
                or registration.maxPerMinute < 1 or registration.maxPerMinute % 1 ~= 0) then
                return false, 'invalid_producer_rate_limit:' .. resource
            end
        end
    end
    return true
end
