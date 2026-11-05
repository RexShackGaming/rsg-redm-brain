FeatherAuditSchemaRegistry.Register({
    eventType = 'admin.action.recorded', eventVersion = 1,
    actorTypes = { character = true, account = true, system = true },
    minimumTargets = 1, minimumSensitivity = 'internal', retentionClass = 'administrative',
    readProjection = { action = 'internal', actor_name = 'internal', target_name = 'internal',
        actor_character_id = 'internal', target_character_id = 'internal', details = 'restricted' },
    context = { type = 'object', fields = {
        action = { type = 'string', required = true, maxBytes = 100 },
        actor_name = { type = 'string', maxBytes = 128 },
        target_name = { type = 'string', maxBytes = 128 },
        actor_character_id = { type = 'string', maxBytes = 128 },
        target_character_id = { type = 'string', maxBytes = 128 },
        details = { type = 'string', required = true, maxBytes = 500 }
    } }
})
