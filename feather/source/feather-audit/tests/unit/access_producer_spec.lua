local Assert = dofile('tests/support/bootstrap.lua')
dofile('schemas/access/grant_v1.lua')
local registration = Config.Producers['feather-access']
Assert.truthy(registration and registration.enabled)
Assert.equal(Config.SourceInstance, registration.sourceInstance)
Assert.equal('access.grant.', registration.eventPrefixes[1])
Assert.equal(1, #registration.eventPrefixes)
local function Event(eventType)
    return FeatherAuditProducerEvent.Build({
        eventId = 'access-event-1', eventType = eventType, eventVersion = 1,
        sourceResource = 'feather-access', sourceInstance = 'default',
        actor = { type = 'system', id = 'service:fixture', resource = 'feather-access' },
        targets = { { type = 'access_grant', id = 'grant-1', role = 'subject' },
            { type = 'access_target', id = 'target-1', role = 'object' }, { type = 'character', id = 'character-1', role = 'grantee' } },
        references = {}, result = 'success', reasonCode = 'grant_created', summary = 'Access grant fact',
        context = { target_type = 'storage.test', capability = 'storage.read', status = 'active', revision = 1,
            target_epoch = 1, grantee_type = 'character', valid_from = 1000, valid_until = 2000, role_ids = {},
            requestor_resource = 'fixture', reason_code = 'storage.share', provenance_type = 'fixture' },
        sensitivityClass = 'restricted', retentionClass = 'security',
    })
end
for _, name in ipairs({ 'access.grant.created', 'access.grant.revoked' }) do
    local event, validation = Event(name)
    Assert.truthy(event, validation and (tostring(validation.code) .. ':' .. tostring(validation.path)))
    Assert.truthy(validation.canonical:find('"role_ids":[]', 1, true))
    event.context.secret = 'must reject'
    Assert.falsy(FeatherAuditValidator.Validate(event).ok)
end
local unknown = Event('access.grant.unconfigured')
Assert.falsy(unknown)
local preserved=Event('access.grant.created')
preserved.eventType='access.grant.preserved'
Assert.falsy(FeatherAuditValidator.Validate(preserved).ok)
preserved.context.manifest_id='manifest-1'
preserved.context.source_epoch=1
preserved.context.transfer_resource='fixture'
preserved.context.transfer_request_id='transfer-1'
Assert.truthy(FeatherAuditValidator.Validate(preserved).ok)
