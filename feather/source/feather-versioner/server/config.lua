VersionerConfig = { resources = {}, owners = {} }

local numericLimits = {
    StartupDelaySeconds = { 0, 3600 }, IntervalMinutes = { 5, 10080 }, ResponseDeadlineSeconds = { 1, 120 },
    CacheTtlMinutes = { 1, 10080 }, ManualRefreshCooldownSeconds = { 0, 3600 }, MaxBackoffMinutes = { 1, 10080 },
    JitterPercent = { 0, 50 }, MaxConcurrentRequests = { 1, 8 }, MaxResponseBytes = { 1024, 4194304 },
    MaxReleases = { 1, 100 }, MaxReleaseTitleBytes = { 1, 512 }
}

local function validateNumber(name)
    local bounds, value = numericLimits[name], tonumber(Config[name])
    if not value or value ~= value or value % 1 ~= 0 or value < bounds[1] or value > bounds[2] then
        return VersionerResults.Err('invalid_config', ('Config.%s must be a finite integer between %s and %s.'):format(name, bounds[1], bounds[2]))
    end
    Config[name] = value
    return VersionerResults.Ok(value)
end

function VersionerConfig.Validate()
    if type(Config.AllowedOwners) ~= 'table' or type(Config.Resources) ~= 'table' then
        return VersionerResults.Err('invalid_config', 'AllowedOwners and Resources must be tables.')
    end
    for _, name in ipairs({ 'Enabled', 'CheckOnStart', 'ReportCurrent', 'ReportSummary', 'ConsoleColors',
        'IncludeReleaseTitle', 'ReportNewerThanPin', 'AllowManifestDiscovery' }) do
        if type(Config[name]) ~= 'boolean' then return VersionerResults.Err('invalid_config', ('Config.%s must be boolean.'):format(name)) end
    end
    for name in pairs(numericLimits) do local result = validateNumber(name); if not result.ok then return result end end
    if type(Config.CacheFile) ~= 'string' or not Config.CacheFile:match('^[A-Za-z0-9_][A-Za-z0-9_.-]*$') or #Config.CacheFile > 80 then
        return VersionerResults.Err('invalid_config', 'Config.CacheFile must be a local filename.')
    end
    if Config.AllowManifestDiscovery == true then return VersionerResults.Err('unsupported_config', 'Manifest discovery is reserved for a later contract and must remain disabled.') end
    VersionerConfig.owners = {}
    for _, owner in ipairs(type(Config.AllowedOwners) == 'table' and Config.AllowedOwners or {}) do
        if type(owner) ~= 'string' or #owner > 100 or not owner:match('^[A-Za-z0-9][A-Za-z0-9_.-]*$') then return VersionerResults.Err('invalid_config', 'AllowedOwners contains an invalid owner.') end
        VersionerConfig.owners[owner:lower()] = true
    end
    VersionerConfig.resources = {}
    for resourceName, policy in pairs(type(Config.Resources) == 'table' and Config.Resources or {}) do
        if type(resourceName) ~= 'string' or not resourceName:match('^[A-Za-z0-9_.-]+$') or #resourceName > 100 or type(policy) ~= 'table' then
            return VersionerResults.Err('invalid_config', 'Configured resource identity or policy is invalid.')
        end
        if policy.enabled ~= nil and type(policy.enabled) ~= 'boolean' then return VersionerResults.Err('invalid_config', 'Resource enabled must be boolean.') end
        if policy.enabled ~= false then
            local repository = VersionerSanitize.Repository(policy.repository)
            if not repository.ok then return VersionerResults.Err('invalid_config', repository.message, { resource = resourceName }) end
            if next(VersionerConfig.owners) and not VersionerConfig.owners[repository.value.owner:lower()] then
                return VersionerResults.Err('owner_not_allowed', 'Repository owner is not allowed.', { resource = resourceName, owner = repository.value.owner })
            end
            local channel = policy.channel or 'stable'
            if channel ~= 'stable' and channel ~= 'prerelease' then return VersionerResults.Err('invalid_config', 'Channel must be stable or prerelease.', { resource = resourceName }) end
            local pin
            if policy.pin then pin = VersionerSemver.Parse(policy.pin); if not pin.ok then return VersionerResults.Err('invalid_config', 'Configured pin is invalid.', { resource = resourceName }) end end
            local ignored = {}
            for _, value in ipairs(type(policy.ignore) == 'table' and policy.ignore or {}) do
                local parsed = VersionerSemver.Parse(value); if not parsed.ok then return VersionerResults.Err('invalid_config', 'Ignored version is invalid.', { resource = resourceName, version = value }) end
                ignored[parsed.value.normalized:match('^[^+]+')] = true
            end
            VersionerConfig.resources[resourceName] = {
                name = resourceName, label = VersionerSanitize.Text(policy.label or resourceName, 100),
                repository = repository.value.owner .. '/' .. repository.value.repository, repositoryKey = repository.value.key,
                channel = channel, pin = pin and pin.value or nil, ignored = ignored
            }
        end
    end
    return VersionerResults.Ok({ count = (function() local n=0;for _ in pairs(VersionerConfig.resources) do n=n+1 end;return n end)() })
end
