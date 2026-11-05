local Assert = _G.TestAssert
dofile('server/services/search.lua')
local queries, accesses = 0, 0
local fail = false
DB = { transaction = function(callback)
    if fail then return false end
    return callback({
        query = function(sql, ...)
            queries = queries + 1
            Assert.falsy(sql:find('canonical_payload', 1, true))
            Assert.falsy(sql:find('context_json', 1, true))
            Assert.falsy(sql:find('actor_id', 1, true))
            Assert.truthy(sql:find("sensitivity_class IN ('public', 'internal')", 1, true))
            local _, placeholders = sql:gsub('%?', '')
            Assert.equal(placeholders, select('#', ...))
            return { { eventId = 'test-id', eventType = 'audit.smoke.ingested' } }
        end,
        exec = function(sql, ...)
            accesses = accesses + 1
            local _, placeholders = sql:gsub('%?', '')
            Assert.equal(placeholders, select('#', ...))
        end
    })
end }
dofile('server/repositories/search.lua')
local request = { fromEpoch = 1000, toEpoch = 2000, limit = 5, sourceResource = 'test' }
local denied = FeatherAuditSearch.Read(request, { allowed = false })
Assert.equal('forbidden', denied.code)
Assert.equal(0, queries)
local deniedMalformed = FeatherAuditSearch.Read(false, { allowed = false })
Assert.equal('forbidden', deniedMalformed.code)
local identity = { allowed = true, type = 'system', id = 'fixture', sensitive = false }
local result = FeatherAuditSearch.Read(request, identity)
Assert.truthy(result.ok)
Assert.equal(1, queries)
Assert.equal(1, accesses)
for _, invalid in ipairs({
    { fromEpoch = 0, toEpoch = 8 * 86400 },
    { fromEpoch = 1, toEpoch = 2, limit = 51 },
    { fromEpoch = 2, toEpoch = 1 },
    { fromEpoch = 1, toEpoch = 2, sourceResource = "bad' OR 1=1" },
    { fromEpoch = 1, toEpoch = 2, actorId = 'unapproved-filter' }
}) do
    Assert.equal('invalid_request', FeatherAuditSearch.Read(invalid, identity).code)
end
Assert.equal(1, queries)
fail = true
Assert.equal('read_unavailable', FeatherAuditSearch.Read(request, identity).code)
Assert.equal(1, accesses, 'transaction rejection must prevent read success')
