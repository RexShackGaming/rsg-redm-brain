Config = {
    Contract = 1,
    RequiredCoreContract = 1,
    ReadinessTimeoutMs = 30000,
    DevMode = true,
    -- Explicit organization UUID -> { jobIds = { job UUIDs }, dutyState = 'any'|'on_duty' }.
    -- Roles are exact 'grade.<grade UUID>' selectors, never grade ordinals.
    Employment = { Scopes = {} },
    Audit = {
        Enabled = true, SourceInstance = 'default',
        PollIntervalMs = 1000, BatchSize = 10, LeaseSeconds = 30,
        InitialRetrySeconds = 2, MaximumRetrySeconds = 60, TransportTimeoutMs = 3000,
    },
    Grants = { Managers = {}, Readers = {}, Auditors = {}, MaxValidityMs = 31622400000, CheckTimeoutMs = 5000 },
    Providers = {
        TimeoutMs = 2000,
        MaxInFlight = 32,
        -- Exact target type -> authoritative resource and allowed vocabulary.
        Targets = {
            ['doors.group'] = {resource = 'feather-doors', capabilities = {'door.lock','door.unlock'}},
            ['property.property'] = {resource = 'feather-property', capabilities = {'property.enter'}},
            ['assets.asset'] = {resource = 'feather-assets', capabilities = {'asset.retrieve'}},
            ['inventory.storage'] = {resource = 'feather-inventory', capabilities = {'inventory.read', 'inventory.insert', 'inventory.remove'}},
        },
        -- Organization UUID -> authoritative membership resource.
        Memberships = {},
        TrustedReaders = { ['feather-access'] = true },
    },
}

Config.Grants.Managers['feather-inventory'] = true
Config.Grants.Managers['feather-assets'] = true
Config.Grants.Managers['feather-property'] = true
Config.Grants.Readers['feather-property'] = true
Config.Providers.TrustedReaders['feather-property'] = true
-- Read-only Doors target-context integration. No grant reader/manager authority.
Config.Providers.TrustedReaders['feather-doors'] = true
Config.Grants.Readers['feather-assets'] = true
Config.Providers.TrustedReaders['feather-assets'] = true
Config.Grants.Readers['feather-inventory'] = true
Config.Providers.TrustedReaders['feather-inventory'] = true

-- Isolated acceptance resource only. Never enable this on production.
if Config.DevMode then
    Config.Grants.Readers['feather-assets-access-tests']=true
    Config.Grants.Readers['feather-property-access-tests']=true
    Config.Grants.Managers['feather-jobs-tests'] = true
    Config.Grants.Readers['feather-jobs-tests'] = true
    Config.Providers.TrustedReaders['feather-jobs-tests'] = true
    Config.Providers.Targets['access_test.employment'] = {
        resource = 'feather-jobs-tests', capabilities = { 'employment.use' },
    }
    Config.Grants.Managers['feather-access-tests'] = true
    Config.Grants.Readers['feather-access-tests'] = true
    Config.Grants.Auditors['feather-access-tests'] = true
    Config.Providers.Targets['access_test.property'] = {
        resource = 'feather-access-tests', capabilities = { 'property.enter' },
    }
    Config.Providers.Targets['access_test.asset'] = {
        resource = 'feather-access-tests', capabilities = { 'asset.retrieve' },
    }
    Config.Providers.Memberships['10000000-0000-4000-8000-000000000001'] = 'feather-access-tests'
    Config.Providers.TrustedReaders['feather-access-tests'] = true
end
