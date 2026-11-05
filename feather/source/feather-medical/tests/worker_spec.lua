local worker = dofile('server/worker.lua')
local calls, ids = {}, 0
local repository = {
    Due = function(now) assert(now == 2000); return {{character_id = 'corrupt'}, {character_id = 'offline'}} end,
    Advance = function(characterId, now, eventId)
        calls[#calls + 1] = {characterId, now, eventId}
        if characterId == 'corrupt' then error('corrupt condition') end
        return {lifeState = 'dead'}
    end
}
local result = worker.Tick(2000, repository, function() ids = ids + 1; return 'event-' .. ids end)
assert(result.scanned == 2 and result.failures == 1 and result.advanced == 1, 'bad row must not prevent later offline bleedout')
assert(calls[2][1] == 'offline' and calls[2][2] == 2000 and calls[2][3] == 'event-2', 'server clock and generated event passed through')
repository.Due = function() error('database unavailable') end
assert(not pcall(worker.Tick, 2000, repository, function() return 'unused' end), 'scan failure must reach worker guard')
print('PASS 3 worker harness checks')
