local file = assert(io.open('tests/archive/server/adapters/feather_inventory.lua', 'r'))
local source = file:read('*a') file:close()
local body = assert(source:match('(function FeatherInventoryProvider.Transaction%([%s%S]-)\nfunction FeatherInventoryProvider.MutateWeaponMetadataBatch'))
local items = { [86] = { id = 86, inventoryId = 1, metadataRevision = 1, metadata = { total = 8 } },
    [305] = { id = 305, inventoryId = 1, metadataRevision = 1, metadata = { total = 10 } } }
local reject, batches = false, 0
local Inventory = { GetItemForCharacter = function(_, id) return { ok = true, value = items[id] } end,
    MutateItem = function() error('Multi-item batch must not use single-item mutation') end,
    MutateItems = function(_, spec)
        batches = batches + 1
        assert(#spec.items == 2 and spec.items[1].itemInstanceId == 86)
        if reject then return { ok = false, error = { code = 'conflict' } } end
        for _, mutation in ipairs(spec.items) do items[mutation.itemInstanceId].metadata = mutation.metadata end
        return { ok = true }
    end }
local provider = {}
assert(load(body, 'real adapter', 't', setmetatable({ FeatherInventoryProvider = provider,
    Inventory = Inventory, NormalizeItem = function(value) return value end, Config = { DevMode = false },
    WeaponResult = { Ok = function(value) return { ok = true, value = value } end,
        Error = function(code, message) return { ok = false, error = { code = code, message = message } } end },
    WeaponErrors = { OPERATION_CONFLICT = 'conflict' }
}, { __index = _G })))()
local function write(tx)
    local primary = tx:GetItemForUpdate(86)
    assert(tx:SetMetadata(86, { total = 7 }, primary.metadataRevision))
    local offhand = tx:GetItemForUpdate(305)
    assert(tx:SetMetadata(305, { total = 9 }, offhand.metadataRevision))
    return { slots = { primary = 7, offhand = 9 } }
end
assert(provider.Transaction({ characterId = 1 }, write).ok)
assert(items[86].metadata.total == 7 and items[305].metadata.total == 9 and batches == 1)
reject = true
assert(not provider.Transaction({ characterId = 1 }, write).ok)
assert(items[86].metadata.total == 7 and items[305].metadata.total == 9)
print('Real Inventory adapter multi-item atomic routing checks passed')
