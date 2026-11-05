Config = Config or {}

-- Ingestion and persistence start after successful configuration and migrations.
-- Metadata read APIs are in development; notification delivery is not implemented.
Config.Development = {
    startupMessage = true,
    -- Enables server-console-only smoke commands and the internal smoke
    -- producer. Keep false on production servers.
    smokeCommands = true
}

-- Stable identity for this server/world. Every producer outbox must persist the
-- same value. Changing it creates a new deduplication scope.
Config.SourceInstance = 'default'

-- Server-only producer registrations. Payload sourceResource is checked against
-- the actual invoking resource and these event prefixes/versions.
Config.Producers = {
    ['feather-access'] = {
        enabled = true, sourceInstance = Config.SourceInstance,
        eventPrefixes = { 'access.grant.' }, versions = { [1] = true }, maxPerMinute = 600,
    },
    ['feather-admin'] = {
        enabled = true, sourceInstance = Config.SourceInstance,
        eventPrefixes = { 'admin.action.' }, versions = { [1] = true }, maxPerMinute = 600
    },
    -- Temporary durable fixture registration for A1/A2 acceptance only:
    ['feather-audit-smoke-producer'] = {
        enabled = true,
        sourceInstance = Config.SourceInstance,
        eventPrefixes = { 'audit.smoke.' },
        versions = { [1] = true },
        maxPerMinute = 60
    },
    -- ['feather-economy'] = {
    --     enabled = true,
    --     sourceInstance = 'default',
    --     eventPrefixes = { 'economy.' },
    --     versions = { [1] = true },
    --     maxPerMinute = 600
    -- }
}

Config.Ingestion = {
    defaultMaxPerMinute = 300
}

-- External delivery is opt-in. Secrets must be resolved from a protected
-- server-side source in a future phase; never place webhook URLs here.
Config.Notifications = {
    enabled = false,
    destinations = {},
    rules = {}
}
