local Assert = _G.TestAssert

local first = { z = 2, a = 1, nested = { b = true, a = 'x' } }
local second = { nested = { a = 'x', b = true }, a = 1, z = 2 }
local encodedFirst = assert(FeatherAuditCanonical.Encode(first, { type = 'object' }))
local encodedSecond = assert(FeatherAuditCanonical.Encode(second, { type = 'object' }))

Assert.equal(encodedFirst, encodedSecond, 'object insertion order changed canonical JSON')
Assert.equal('{"a":1,"nested":{"a":"x","b":true},"z":2}', encodedFirst)

local array = assert(FeatherAuditCanonical.Encode({}, { type = 'array' }))
local object = assert(FeatherAuditCanonical.Encode({}, { type = 'object' }))
Assert.equal('[]', array)
Assert.equal('{}', object)

local unsafe, unsafeError = FeatherAuditCanonical.Encode(1.5)
Assert.equal(nil, unsafe)
Assert.equal('number_not_safe_integer', unsafeError)

local mixed, mixedError = FeatherAuditCanonical.Encode({ [1] = 'visible', hidden = 'not allowed' }, { type = 'array' })
Assert.equal(nil, mixed)
Assert.equal('mixed_array', mixedError)
