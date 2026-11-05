Config = {
    Contract = 1,
    RequiredCoreContract = 1,
    ReadinessTimeoutMs = 30000,
    DevMode = true,
    Delegation = { enabled = true },

    Outbox = {
        pollIntervalMs = 1000,
        retryDelaySeconds = 5,
        batchSize = 20
    },

    -- Registrable property types. A type only names a class of property, which
    -- holder types may hold it, and how many owners and tenants it may have at
    -- once (a property may lower these at registration). Interiors, doors,
    -- furniture, prices, taxes and menus stay with the gameplay resource. Keys are
    -- stable and must never be renamed once properties exist.
    PropertyTypes = {
        house = {
            label = 'House',
            holderTypes = { 'character', 'organization' },
            maxOwners = 4,
            maxTenants = 1
        },
        hotel_room = {
            label = 'Hotel room',
            holderTypes = { 'character' },
            maxOwners = 0,
            maxTenants = 256
        },
        business = {
            label = 'Business premises',
            holderTypes = { 'organization' },
            maxOwners = 1,
            maxTenants = 1
        }
    },

    -- Holder references point at identities Property does not own.
    -- validator = 'character' resolves the UUID through the character-profile provider;
    -- validator = 'organizations' checks it through feather-organizations;
    -- validator = false trusts the managing resource.
    HolderTypes = {
        character = { validator = 'character' },
        organization = { validator = 'organizations' }
    },

    Limits = {
        maxListLimit = 50,
        -- Upper bound for the client route; a player never pages their own properties.
        maxClientProperties = 50,
        -- How often tenancies whose valid_until has passed are ended.
        expirySweepMs = 60000,
        -- Consumer metadata is bounded generic JSON.
        maxMetadataBytes = 8192,
        maxMetadataDepth = 4,
        maxMetadataNodes = 256,
        maxMetadataString = 1024,
        -- Links (storage containers, doors, ...) one property may carry.
        maxLinksPerProperty = 32
    },

    -- Things that can be attached to a property, each identified by an external ID
    -- the owning resource chooses (an inventory container ID, a door ID, ...). One
    -- external thing belongs to at most one property. Keys are stable and must
    -- never be renamed once links exist.
    LinkTypes = {
        storage = { label = 'Storage' },
        door = { label = 'Door' }
    },

    -- Service-level policy actions, evaluated through Core. Grants live in the
    -- default policy provider (feather-admin configs/service_policy.lua).
    Authorization = {
        enabled = true,
        manageAction = 'property.property.manage',
        interestAction = 'property.interest.manage'
    },

    Access = {
        trustedReaders = {
            ['feather-doors'] = true,
            ['feather-property'] = true,
            ['feather-admin'] = true,
            ['bcc-housing'] = true
        },
        -- May register properties they will manage, and mutate properties they manage.
        trustedManagers = {
            ['feather-property'] = true,
            ['feather-admin'] = true,
            ['bcc-housing'] = true
        },
        -- May mutate properties managed by another resource.
        privilegedManagers = {
            ['feather-admin'] = true
        },
        trustedAuditors = {
            ['feather-property'] = true,
            ['feather-admin'] = true,
            ['bcc-housing'] = true
        },
        privilegedAuditors = {
            ['feather-admin'] = true
        }
    }
}

if Config.DevMode then
    Config.Access.trustedReaders['feather-doors-property-tests'] = true
    Config.Access.trustedManagers['feather-doors-property-tests'] = true
    Config.Access.trustedReaders['feather-property-access-tests'] = true
    Config.Access.trustedManagers['feather-property-access-tests'] = true
end
