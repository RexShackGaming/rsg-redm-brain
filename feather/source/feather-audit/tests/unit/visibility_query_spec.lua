local Assert = _G.TestAssert
local expectedSensitive, writes = false, 0
DB = { transaction = function(callback)
    return callback({ query = function(sql, ...)
        Assert.falsy(sql:find("'sealed'", 1, true), 'sealed must never be in a visible class set')
        Assert.truthy(sql:find(expectedSensitive and "IN ('public', 'internal', 'restricted')"
            or "IN ('public', 'internal')", 1, true))
        Assert.truthy(sql:find('context_json AS projectedContext', 1, true))
        for _, column in ipairs({ 'canonical_payload', 'summary', 'actor_id', 'display_name' }) do
            Assert.falsy(sql:find(column, 1, true), 'protected column must not be selected')
        end
        local _, placeholders = sql:gsub('%?', '')
        Assert.equal(placeholders, select('#', ...))
        return {}
    end, exec = function(_, ...)
        writes = writes + 1
        local arguments = table.pack(...)
        Assert.equal('audit.event.get.v1', arguments[3])
    end })
end }
dofile('server/repositories/search.lua')
local request = { fromEpoch = 1, toEpoch = 100, limit = 1, eventId = 'event-id', operation = 'audit.event.get.v1' }
FeatherAuditSearchRepository.Read(request, { type = 'character', id = 'test', sensitive = false })
expectedSensitive = true
FeatherAuditSearchRepository.Read(request, { type = 'character', id = 'test', sensitive = true })
Assert.equal(2, writes, 'each permitted lookup records access even when nothing is visible')
