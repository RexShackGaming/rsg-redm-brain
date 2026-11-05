VersionerRegistry = { entries = {}, repositories = {} }

local function installedVersion(resourceName)
    local state = GetResourceState(resourceName)
    if state == 'missing' or state == 'unknown' then return VersionerResults.Err('not_installed', 'Configured resource is not installed.', { state = state }) end
    local value = GetResourceMetadata(resourceName, 'version', 0)
    if not value then return VersionerResults.Err('missing_version', 'Resource manifest has no version metadata.', { state = state }) end
    local parsed = VersionerSemver.Parse(value)
    if not parsed.ok then return VersionerResults.Err('invalid_version', 'Installed resource version is invalid.', { state = state, version = value }) end
    return VersionerResults.Ok({ parsed = parsed.value, state = state, raw = value })
end

function VersionerRegistry.Build()
    VersionerRegistry.entries, VersionerRegistry.repositories = {}, {}
    for name, policy in pairs(VersionerConfig.resources) do
        local installed = installedVersion(name)
        local entry = { name = name, label = policy.label, policy = policy, installed = installed.ok and installed.value or nil }
        if not installed.ok then entry.status = 'unknown'; entry.error = installed end
        VersionerRegistry.entries[name] = entry
        local repository = VersionerRegistry.repositories[policy.repositoryKey]
        if not repository then repository = { key = policy.repositoryKey, repository = policy.repository, resources = {} }; VersionerRegistry.repositories[policy.repositoryKey] = repository end
        repository.resources[#repository.resources + 1] = name
    end
    return VersionerResults.Ok({ resources = VersionerRegistry.entries, repositories = VersionerRegistry.repositories })
end

function VersionerRegistry.Get(name) return VersionerRegistry.entries[name] end
