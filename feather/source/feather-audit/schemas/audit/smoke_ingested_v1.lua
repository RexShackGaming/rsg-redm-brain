FeatherAuditSchemaRegistry.Register({
    eventType = 'audit.smoke.ingested',
    eventVersion = 1,
    actorTypes = { system = true },
    minimumTargets = 1,
    minimumSensitivity = 'internal',
    retentionClass = 'operational',
    readProjection = { sequence = 'internal', message = 'restricted' },
    context = {
        type = 'object',
        fields = {
            sequence = { type = 'integer', required = true, minimum = 1 },
            message = { type = 'string', required = true, maxBytes = 128 },
            padding_a = { type = 'string', maxBytes = 9000 },
            padding_b = { type = 'string', maxBytes = 9000 }
        }
    }
})
