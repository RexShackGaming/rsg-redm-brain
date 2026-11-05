Config = {
    Contract = 1,
    RequiredCoreContract = 1,
    ReadinessTimeoutMs = 30000,
    DevMode = false,

    Outbox = {
        pollIntervalMs = 1000,
        retryDelaySeconds = 5,
        batchSize = 20
    },

    -- Publishes licenses.license.expired.v1 once per license after its expiry.
    -- Validity never waits for this: every read compares expiresAt with the clock.
    Expiry = {
        sweepIntervalMs = 60000,
        batchSize = 50
    },

    -- Holder references point at identities Licenses does not own.
    -- validator = 'character' resolves the UUID through the character-profile provider;
    -- validator = 'organizations' checks it through feather-organizations;
    -- validator = false trusts the issuing resource.
    HolderTypes = {
        character = { validator = 'character' },
        organization = { validator = 'organizations' }
    },

    Limits = {
        maxListLimit = 50,
        -- Upper bound for the client route; a player never pages their own licenses.
        maxClientLicenses = 50,
        -- Longest validity a definition may allow (10 years).
        maxDurationSeconds = 315360000,
        -- License scope (weapon classes, regions) is bounded generic JSON.
        maxScopeBytes = 4096,
        maxScopeDepth = 4,
        maxScopeNodes = 128,
        maxScopeString = 256
    },

    -- Service-level policy actions, evaluated through Core. Grants live in the
    -- default policy provider (feather-admin configs/service_policy.lua).
    Authorization = {
        enabled = true,
        definitionAction = 'licenses.definition.manage',
        issueAction = 'licenses.issue',
        revokeAction = 'licenses.revoke'
    },

    Access = {
        trustedReaders = {
            ['feather-licenses'] = true,
            ['feather-admin'] = true,
            ['bcc-documents'] = true,   -- licensing office (owner of its licence kinds)
            ['bcc-legendaries'] = true  -- hunting licence check before a legendary hunt
        },
        -- May register license definitions they will own.
        trustedRegistrars = {
            ['feather-licenses'] = true,
            ['feather-admin'] = true,
            ['bcc-documents'] = true
        },
        -- May change definitions owned by another resource.
        privilegedRegistrars = {
            ['feather-admin'] = true
        },
        -- May issue, renew, suspend, reinstate and revoke licenses of definitions they own.
        trustedIssuers = {
            ['feather-licenses'] = true,
            ['feather-admin'] = true,
            ['bcc-documents'] = true
        },
        -- May act on licenses of definitions owned by another resource.
        privilegedIssuers = {
            ['feather-admin'] = true
        },
        trustedAuditors = {
            ['feather-licenses'] = true,
            ['feather-admin'] = true,
            ['bcc-documents'] = true
        },
        privilegedAuditors = {
            ['feather-admin'] = true
        }
    }
}
