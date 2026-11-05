dofile('shared/character_ammunition.lua')
local A = WeaponCharacterAmmunition
local limits = { regular = 200, express = 100 }
local record = { characterId = 'character-a', sessionId = 'session-a', epoch = 'epoch-a',
    revision = 4, pools = { regular = 8, express = 4 } }
local function report()
    return { characterId = record.characterId, sessionId = record.sessionId, epoch = record.epoch,
        revision = 4, pools = { regular = 7, express = 4 } }
end
local accepted = assert(A.Observe(record, report(), limits))
assert(accepted.pools.regular == 7 and accepted.revision == 5)
assert(record.pools.regular == 8 and record.revision == 4)
local idle=report(); idle.pools.regular=8
local unchanged=assert(A.Observe(record,idle,limits))
assert(unchanged.revision==4 and unchanged.changed==false)
assert(accepted.changed==true)
for _, key in ipairs({ 'characterId', 'sessionId', 'epoch', 'revision' }) do
    local value = report(); value[key] = 'foreign'
    assert(not A.Observe(record, value, limits))
end
local value = report(); value.pools.regular = 9
assert(not A.Observe(record, value, limits))
value = report(); value.pools.express = nil
assert(not A.Observe(record, value, limits))
value = report(); value.pools.foreign = 1
assert(not A.Observe(record, value, limits))
for _, bad in ipairs({ -1, 1.5, math.huge, 0/0, '4' }) do
    value = report(); value.pools.express = bad
    assert(not A.Observe(record, value, limits))
end
local loaded, inventory = A.Transfer(record, 'regular', 10, limits)
assert(loaded.pools.regular == 18 and inventory.inventoryDelta == -10)
local unloaded, returned = A.Transfer(loaded, 'regular', -18, limits)
assert(unloaded.pools.regular == 0 and returned.inventoryDelta == 18)
assert(unloaded.pools.express == 4 and record.pools.regular == 8)
assert(not A.Transfer(record, 'regular', -9, limits))
assert(not A.Transfer(record, 'regular', 193, limits))
assert(not A.Transfer(record, 'regular', 0, limits))
assert(not A.Transfer(record, 'foreign', 1, limits))
print('character ammunition contract PASS')
