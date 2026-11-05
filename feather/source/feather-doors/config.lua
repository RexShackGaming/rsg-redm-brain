DoorsConfig = {
    -- Exact server resource names. Each caller manages/reads only its own groups.
    TrustedResources = {},
    -- Exact resource -> exact door key -> true. State control only; no CRUD,
    -- grants or wildcard authority. Example (disabled):
    -- ['bcc-banks'] = { ['global.valentine.bank.entry'] = true }
    ServiceControllers = {},
    -- Acceptance starts with manual server-console drain; resume enables a
    -- bounded 20-row poll each second until pause or Doors restart.
    Outbox = { Enabled=false },
}
