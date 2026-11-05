local O = dofile('server/outbox.lua')
local function payload(id, char, rev)
    return {eventId = id, characterId = char, revision = rev, lifeState = 'dead', reason = 'test', occurredAt = 1000}
end
local id1, id2, id3 = string.rep('a',36), string.rep('b',36), string.rep('c',36)
local rows = {{event_id = id1, character_id = 'one', revision = 1, payload = payload(id1,'one',1)},
    {event_id = id2, character_id = 'one', revision = 2, payload = payload(id2,'one',2)},
    {event_id = id3, character_id = 'two', revision = 1, payload = payload(id3,'two',1)}}
local marked, sent, fail, loseMark = {}, {}, true, false
local repo = {PendingEvents = function()
    local result = {}; for _, row in ipairs(rows) do if not marked[row.event_id] then result[#result+1] = row end end; return result
end, MarkPublished = function(id)
    if loseMark then loseMark = false; error('lost publication acknowledgement') end
    marked[id] = true
end}
local publish = function(name, value)
    assert(name == O.event); sent[#sent+1] = value.eventId
    return {ok = true, value = {delivered = 1, failed = fail and value.eventId == id1 and 1 or 0}}
end
local decode = function(value) return value end
local first = O.Tick(repo, publish, decode, 1000)
assert(first.failures == 1 and first.published == 1 and not marked[id2] and marked[id3], 'failed character retains revision order while other character delivers')
fail = false
local nextTick = O.Tick(repo, publish, decode, 1001)
assert(nextTick.published == 2 and sent[3] == id1 and sent[4] == id2, 'stable ID replay precedes next revision')
marked[id1], marked[id2], loseMark = nil, true, true
O.Tick(repo, publish, decode, 1002)
assert(not marked[id1], 'publication mark failure retains fact')
O.Tick(repo, publish, decode, 1003)
assert(marked[id1] and sent[#sent] == id1, 'lost mark replays same ID')
local bad = payload(id1,'one',1); bad.privateMedicalDetails = 'never publish'
assert(not O.Validate(bad), 'unexpected/private fields rejected')
print('PASS 5 outbox delivery checks')
