local Assert = _G.TestAssert
dofile('server/services/search.lua')
local tokenIndex, calls = 0, 0
DB = { value = function()
    tokenIndex = tokenIndex + 1
    return ('00000000-0000-0000-0000-%012d'):format(tokenIndex)
end }
local dataset = {
    { eventId = 'event-c', positionTime = '2026-10-08 00:00:00.000000' },
    { eventId = 'event-b', positionTime = '2026-10-08 00:00:00.000000' },
    { eventId = 'event-a', positionTime = '2026-10-08 00:00:00.000000' }
}
FeatherAuditSearchRepository = { Read = function(request)
    calls = calls + 1
    local rows = {}
    for _, row in ipairs(dataset) do
        if (not request.positionId or row.eventId < request.positionId)
            and (not request.eventId or row.eventId == request.eventId) then
            rows[#rows + 1] = { eventId = row.eventId, positionTime = row.positionTime }
        end
        if #rows == request.limit + 1 then break end
    end
    return { events = rows, limit = request.limit }
end }
local identity = { allowed = true, id = 'character', caller = 'admin', sessionId = 'session', sensitive = false }
local request = { fromEpoch = 1, toEpoch = 100, limit = 1, correlationId = 'workflow' }
local first = FeatherAuditSearch.Read(request, identity)
Assert.equal('event-c', first.value.events[1].eventId)
Assert.equal(nil, first.value.events[1].positionTime)
Assert.truthy(first.value.nextCursor)
request.cursor = first.value.nextCursor
local second = FeatherAuditSearch.Read(request, identity)
Assert.equal('event-b', second.value.events[1].eventId)
request.cursor = second.value.nextCursor
local third = FeatherAuditSearch.Read(request, identity)
Assert.equal('event-a', third.value.events[1].eventId)
Assert.equal(nil, third.value.nextCursor)
request.cursor = first.value.nextCursor
request.limit = 2
Assert.equal('invalid_cursor', FeatherAuditSearch.Read(request, identity).code)
request.limit = 1
identity.sessionId = 'different-session'
Assert.equal('invalid_cursor', FeatherAuditSearch.Read(request, identity).code)
identity.sessionId, identity.sensitive = 'session', true
Assert.equal('invalid_cursor', FeatherAuditSearch.Read(request, identity).code)
identity.sensitive = false
local before = calls
Assert.equal('invalid_cursor', FeatherAuditSearch.Read(request, identity, 'audit.correlation.get.v1').code)
Assert.equal(before, calls, 'cursor from another operation must not reach the repository')
local detail = FeatherAuditSearch.Read({ fromEpoch = 1, toEpoch = 100, eventId = 'event-b' }, identity, 'audit.event.get.v1')
Assert.equal('event-b', detail.value.event.eventId)
local missing = FeatherAuditSearch.Read({ fromEpoch = 1, toEpoch = 100, eventId = 'absent' }, identity, 'audit.event.get.v1')
Assert.truthy(missing.ok)
Assert.equal(nil, missing.value.event)
Assert.equal('invalid_request', FeatherAuditSearch.Read({ fromEpoch = 1, toEpoch = 100 }, identity, 'audit.correlation.get.v1').code)
local originalTime = os.time
local now = originalTime()
os.time = function() return now + 301 end
Assert.equal('invalid_cursor', FeatherAuditSearch.Read(request, identity).code)
os.time = originalTime
