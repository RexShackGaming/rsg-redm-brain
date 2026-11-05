json = { encode = function() return 'encoded' end,
    decode = function(value) if value == 'corrupt' then error('bad json') end; return { regular = 3 } end }
dofile('server/services/character_ammunition_repository.lua')
local R = CharacterAmmunitionRepository
local id = 'e5e9955d-c29e-11f1-9ae2-e0d55eaa2deb'
local calls, response = {}, {}
local function query(sql, params)
    calls[#calls + 1] = { sql = sql, params = params }
    return response
end
assert(not R.Lock(query, id))
assert(calls[1].sql:find('FOR UPDATE', 1, true))
response = { { character_id = id, revision = '5', pools = 'encoded' } }
local record = assert(R.Lock(query, id))
assert(record.revision == 5 and record.pools.regular == 3)
response[1].pools = 'corrupt'
assert(not R.Lock(query, id))
response = { affectedRows = 0 }
record.revision = 6
assert(not R.Write(query, record, 5))
response.affectedRows = 1
assert(R.Write(query, record, 5))
assert(calls[#calls].params[4] == 5)
assert(not pcall(R.Write, query, record, 4))
assert(not pcall(R.Lock, query, 'license:someone'))
response = {}
R.Create(query, id, {})
assert(calls[#calls].sql:find('INSERT INTO', 1, true))
assert(not calls[#calls].sql:find('IGNORE', 1, true))
assert(not R.Receipt(query, id, 'operation-1'))
R.RecordReceipt(query, id, 'operation-1', {})
assert(calls[#calls].params[2] == 'operation-1')
assert(not pcall(R.RecordReceipt, query, id, string.rep('x', 65), {}))
print('character ammunition repository contract PASS (mock SQL only)')
