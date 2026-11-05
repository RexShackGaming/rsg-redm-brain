-- Reference schema only. Feather Economy owns the production schema and must
-- review/register it during onboarding.
return {
    eventType = 'economy.transfer.completed',
    eventVersion = 1,
    actorTypes = {
        character = true,
        staff = true,
        organization = true,
        resource = true,
        system = true
    },
    minimumTargets = 2,
    minimumSensitivity = 'internal',
    retentionClass = 'financial',
    context = {
        type = 'object',
        fields = {
            amount = { type = 'integer', required = true, minimum = 1 },
            currency = {
                type = 'string',
                required = true,
                maxBytes = 32,
                pattern = '^[a-z][a-z0-9_]*$'
            }
        }
    }
}
