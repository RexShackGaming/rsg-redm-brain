Config = {
    Enabled = true,
    CheckOnStart = true,
    StartupDelaySeconds = 15,
    IntervalMinutes = 720,
    ResponseDeadlineSeconds = 15,
    CacheTtlMinutes = 120,
    ManualRefreshCooldownSeconds = 60,
    MaxBackoffMinutes = 240,
    JitterPercent = 10,
    MaxConcurrentRequests = 2,
    MaxResponseBytes = 1048576,
    MaxReleases = 50,
    MaxReleaseTitleBytes = 160,
    ReportCurrent = false,
    ReportSummary = true,
    ConsoleColors = true,
    IncludeReleaseTitle = true,
    ReportNewerThanPin = false,
    AllowManifestDiscovery = false,
    AllowedOwners = { 'FeatherFramework' },
    CacheFile = 'versioner-cache.json',
    Resources = {
        ['feather-loadscreen'] = {
            repository = 'FeatherFramework/feather-loadscreen',
            channel = 'stable'
        },
        ['feather-menu-v2'] = {
            repository = 'FeatherFramework/feather-menu-v2',
            channel = 'prerelease'
        },
        ['feather-core'] = {
            repository = 'FeatherFramework/feather-core',
            channel = 'stable'
        },
        ['feather-economy'] = {
            repository = 'FeatherFramework/feather-economy',
            channel = 'stable'
        },
        ['feather-routing'] = {
            repository = 'FeatherFramework/feather-routing',
            channel = 'stable'
        },
        ['feather-notify'] = {
            repository = 'FeatherFramework/feather-notify',
            channel = 'stable'
        },
        ['feather-world'] = {
            repository = 'FeatherFramework/feather-world',
            channel = 'stable'
        },
        ['feather-pvp'] = {
            repository = 'FeatherFramework/feather-pvp',
            channel = 'stable'
        },
        ['feather-toolkit'] = {
            repository = 'FeatherFramework/feather-toolkit',
            channel = 'stable'
        },
        ['feather-hud'] = {
            repository = 'FeatherFramework/feather-hud',
            channel = 'stable'
        },
        ['feather-character'] = {
            repository = 'FeatherFramework/feather-character',
            channel = 'stable'
        },
        ['feather-inventory'] = {
            repository = 'FeatherFramework/feather-inventory',
            channel = 'stable'
        },
        ['feather-weapons'] = {
            repository = 'FeatherFramework/feather-weapons',
            channel = 'stable'
        },
        ['feather-organizations'] = {
            repository = 'FeatherFramework/feather-organizations',
            channel = 'stable'
        },
        ['feather-authority'] = {
            repository = 'FeatherFramework/feather-authority',
            channel = 'stable'
        },
        ['feather-admin'] = {
            repository = 'FeatherFramework/feather-admin',
            channel = 'stable'
        },
        ['feather-shops'] = {
            repository = 'FeatherFramework/feather-shops',
            channel = 'stable'
        },
        ['feather-settings'] = {
            repository = 'FeatherFramework/feather-settings',
            channel = 'stable'
        },
        ['feather-chat'] = {
            repository = 'FeatherFramework/feather-chat',
            channel = 'stable'
        },
        ['feather-medical'] = {
            repository = 'FeatherFramework/feather-medical',
            channel = 'stable'
        },
        ['feather-audit'] = {
            repository = 'FeatherFramework/feather-audit',
            channel = 'stable'
        },
        ['feather-jobs'] = {
            repository = 'FeatherFramework/feather-jobs',
            channel = 'stable'
        },
        ['feather-assets'] = {
            repository = 'FeatherFramework/feather-assets',
            channel = 'stable'
        },
        ['feather-property'] = {
            repository = 'FeatherFramework/feather-property',
            channel = 'stable'
        },
        ['feather-contracts'] = {
            repository = 'FeatherFramework/feather-contracts',
            channel = 'stable'
        },
        ['feather-versioner'] = {
            repository = 'FeatherFramework/feather-versioner',
            channel = 'stable'
        },
    }
}
