Config = {
    Contract = 1,
    RequiredCoreContract = 1,
    ReadinessTimeoutMs = 30000,
    DevMode = true,
    Delegation = { enabled = true }, -- optional Access provider; no startup dependency

    Outbox = {
        pollIntervalMs = 1000,
        retryDelaySeconds = 5,
        batchSize = 20
    },

    -- Registrable asset types. A type only names a class of asset and which holder
    -- types may own it; spawning, handling, feed/fuel, condition and stable/garage
    -- presentation stay with the gameplay resource. Keys are stable and must never
    -- be renamed once assets exist.
    --
    -- Master plan A1/A4: horses first (bcc-stables); wagons and boats share the
    -- same service with no type-specific code (see ASSETS_PLAN.md).
    AssetTypes = {
        horse = {
            label = 'Horse',
            holderTypes = { 'character', 'organization' }
        },
        wagon = {
            label = 'Wagon',
            holderTypes = { 'character', 'organization' }
        },
        boat = {
            label = 'Boat',
            holderTypes = { 'character', 'organization' }
        }
    },

    -- Holder references point at identities Assets does not own.
    -- validator = 'character' resolves the UUID through the character-profile provider;
    -- validator = 'organizations' checks it through feather-organizations;
    -- validator = false trusts the managing resource.
    HolderTypes = {
        character = { validator = 'character' },
        organization = { validator = 'organizations' }
    },

    Limits = {
        maxListLimit = 50,
        -- Upper bound for the client route; a player never pages their own assets.
        maxClientAssets = 50,
        -- Consumer metadata (name, coat, components) is bounded generic JSON.
        maxMetadataBytes = 8192,
        maxMetadataDepth = 4,
        maxMetadataNodes = 256,
        maxMetadataString = 1024
    },

    -- Service-level policy actions, evaluated through Core. Grants live in the
    -- default policy provider (feather-admin configs/service_policy.lua).
    Authorization = {
        enabled = true,
        manageAction = 'assets.asset.manage',
        transferAction = 'assets.ownership.transfer'
    },

    Access = {
        trustedReaders = {
            ['feather-assets'] = true,
            ['feather-admin'] = true,
            ['bcc-stables'] = true
        },
        -- May register assets they will manage, and mutate assets they manage.
        trustedManagers = {
            ['feather-assets'] = true,
            ['feather-admin'] = true,
            ['bcc-stables'] = true
        },
        -- May mutate assets managed by another resource.
        privilegedManagers = {
            ['feather-admin'] = true
        },
        trustedAuditors = {
            ['feather-assets'] = true,
            ['feather-admin'] = true,
            ['bcc-stables'] = true
        },
        privilegedAuditors = {
            ['feather-admin'] = true
        }
    }
}

-- Isolated domain acceptance resource; never grants privileged cross-manager access.
if Config.DevMode then
    Config.Access.trustedReaders['feather-assets-access-tests'] = true
    Config.Access.trustedManagers['feather-assets-access-tests'] = true
end
