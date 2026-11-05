local Assert = _G.TestAssert
local oldJson = json
local context = { sequence = 7, message = 'sensitive test message', padding_a = 'unapproved', actor_id = 'private' }
json = { decode = function(encoded)
    if encoded == 'broken' then error('malformed') end
    return context
end }
dofile('schemas/audit/smoke_ingested_v1.lua')
local ordinary = FeatherAuditProjection.Context('audit.smoke.ingested', 1, '{}', false)
Assert.equal(7, ordinary.context.sequence)
Assert.equal(nil, ordinary.context.message)
Assert.equal(nil, ordinary.context.padding_a)
Assert.equal(nil, ordinary.context.actor_id)
local elevated = FeatherAuditProjection.Context('audit.smoke.ingested', 1, '{}', true)
Assert.equal('sensitive test message', elevated.context.message)
Assert.equal(nil, FeatherAuditProjection.Context('unknown.event', 1, '{}', true))
Assert.equal(nil, FeatherAuditProjection.Context('audit.smoke.ingested', 2, '{}', true))
Assert.equal(nil, FeatherAuditProjection.Context('audit.smoke.ingested', 1, 'broken', true))
context = { sequence = math.huge, message = string.rep('x', 129) }
Assert.equal(nil, next(FeatherAuditProjection.Context('audit.smoke.ingested', 1, '{}', true).context))
local registered = FeatherAuditSchemaRegistry.Register({ eventType = 'test.badprojection', eventVersion = 1,
    context = { type = 'object', fields = { nested = { type = 'object', fields = {} } } },
    readProjection = { nested = 'internal' } })
Assert.falsy(registered, 'nested/unbounded content cannot be approved')
local sqlSeen, accesses = nil, 0
context = { sequence = 7, message = 'private message' }
DB = { transaction = function(callback)
    return callback({ query = function(sql)
        sqlSeen = sql
        return { { eventType = 'audit.smoke.ingested', eventVersion = 1, projectedContext = '{}' } }
    end, exec = function() accesses = accesses + 1 end })
end }
dofile('server/repositories/search.lua')
local read = FeatherAuditSearchRepository.Read({ fromEpoch = 1, toEpoch = 2, limit = 1,
    operation = 'audit.event.get.v1' }, { type = 'character', id = 'test', sensitive = false })
Assert.equal(7, read.events[1].content.context.sequence)
Assert.equal(nil, read.events[1].content.context.message)
Assert.equal(nil, read.events[1].projectedContext)
Assert.falsy(sqlSeen:find('canonical_payload', 1, true))
Assert.equal(1, accesses)
json = oldJson
