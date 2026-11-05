-- Explicit development switch; does not expose the server configuration.
if GetResourceMetadata(GetCurrentResourceName(), 'shops_dev_tests', 0) ~= 'true' then return end
local busy = false
local rangeQuote
local rangeRequestKey = 'shops:range-test:pending'
RegisterCommand('ShopPurchaseRangeClientTest', function(_, args)
    local mode = args[1]
    if mode ~= 'prepare' and mode ~= 'confirm' then
        print('[ShopPurchaseRangeClientTest] usage: ShopPurchaseRangeClientTest prepare|confirm'); return
    end
    if busy then print('[ShopPurchaseRangeClientTest] FAIL test already running'); return end
    busy = true
    CreateThread(function()
        local called, failure = xpcall(function()
            local saved = GetResourceKvpString(rangeRequestKey)
            if mode == 'prepare' then
                if saved then print('[ShopPurchaseRangeClientTest] FAIL unresolved saved request; use confirm, not a new quote'); return end
                local result = exports['feather-core']:CallRPCAsync('shops.quote.v1', {
                    shopId = '00000000-0000-4000-8000-000000000001',
                    offerId = '00000000-0000-4000-8000-000000000101', quantity = 1
                }, nil, 10000)
                if type(result) ~= 'table' or not result.ok or type(result.value) ~= 'table' then
                    print('[ShopPurchaseRangeClientTest] FAIL quote=' .. tostring(type(result) == 'table' and result.code or 'invalid_response')); return
                end
                rangeQuote = { quoteId = result.value.id, requestId = 'range:' .. result.value.id }
                print('[ShopPurchaseRangeClientTest] PASS prepared; walk at least 6 metres away, then confirm within 30 seconds (no purchase sent)')
                return
            end
            local request = rangeQuote
            if saved then
                local decoded, value = pcall(json.decode, saved)
                if not decoded or type(value) ~= 'table' or type(value.quoteId) ~= 'string' or type(value.requestId) ~= 'string' then
                    print('[ShopPurchaseRangeClientTest] FAIL corrupt saved request; operator resolution required'); return
                end
                request = { quoteId = value.quoteId, requestId = value.requestId }
            end
            if not request then print('[ShopPurchaseRangeClientTest] FAIL prepare a quote first'); return end
            local position = GetEntityCoords(PlayerPedId())
            if #(position - vector3(-322.13, 803.65, 117.88)) <= 6.0 then
                print('[ShopPurchaseRangeClientTest] FAIL move at least 6 metres from the test shop; purchase not sent'); return
            end
            SetResourceKvp(rangeRequestKey, json.encode(request))
            local result = exports['feather-core']:CallRPCAsync('shops.purchase.v1', request, nil, 15000)
            local passed = type(result) == 'table' and result.ok == false and result.code == 'out_of_range'
            if passed or (type(result) == 'table' and result.ok == false and type(result.details) == 'table'
                and result.details.safeToClear == true) then
                DeleteResourceKvp(rangeRequestKey); rangeQuote = nil
            end
            print(('[ShopPurchaseRangeClientTest] %s purchaseRejected=%s code=%s requestId=%s'):format(
                passed and 'PASS' or 'FAIL', tostring(passed), tostring(type(result) == 'table' and result.code), request.requestId))
        end, debug.traceback)
        busy = false
        if not called then print('[ShopPurchaseRangeClientTest] FAIL ' .. tostring(failure)) end
    end)
end, false)
local function Uuid(value)
    return type(value) == 'string' and value:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end
local function Integer(value)
    return type(value) == 'number' and value == math.floor(value) and value > 0
end
RegisterCommand('ShopQuoteClientTest', function(_, args)
    if busy then print('[ShopQuoteClientTest] FAIL test already running'); return end
    local mode = args[1] or 'near'
    if mode ~= 'near' and mode ~= 'far' then
        print('[ShopQuoteClientTest] usage: ShopQuoteClientTest near|far'); return
    end
    busy = true
    CreateThread(function()
        local called, failure = xpcall(function()
            local result = exports['feather-core']:CallRPCAsync('shops.quote.v1', {
                shopId = '00000000-0000-4000-8000-000000000001',
                offerId = '00000000-0000-4000-8000-000000000101', quantity = 2
            }, nil, 10000)
            if mode == 'far' then
                local passed = type(result) == 'table' and result.ok == false and result.code == 'out_of_range'
                print(('[ShopQuoteClientTest] %s outOfRange=%s (no funds moved)'):format(
                    passed and 'PASS' or 'FAIL', tostring(passed)))
                return
            end
            if type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table' then
                print('[ShopQuoteClientTest] FAIL code=' .. tostring(type(result) == 'table' and result.code or 'invalid_response'))
                return
            end
            local quote = result.value
            local allowed = { id = true, shopId = true, offerId = true, itemName = true,
                quantity = true, currency = true, unitPrice = true, total = true,
                catalogRevision = true, expiresAt = true }
            local isolated = true
            for key in pairs(quote) do if not allowed[key] then isolated = false end end
            local tests = {
                { 'quote identity', Uuid(quote.id) },
                { 'requested offer', quote.shopId == '00000000-0000-4000-8000-000000000001'
                    and quote.offerId == '00000000-0000-4000-8000-000000000101' },
                { 'authoritative terms', quote.itemName == 'consumable_apple' and quote.quantity == 2
                    and quote.currency == 'dollars' and quote.unitPrice == 100 and quote.total == 200 },
                { 'integer amounts', Integer(quote.unitPrice) and Integer(quote.total) },
                { 'revision and expiry', type(quote.catalogRevision) == 'string' and Integer(quote.expiresAt) },
                { 'public fields only', isolated }
            }
            local passed = 0
            for _, test in ipairs(tests) do
                if test[2] then passed = passed + 1 end
                print(('[ShopQuoteClientTest] %-25s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
            end
            print(('[ShopQuoteClientTest] done %d/%d passed (no funds moved)'):format(passed, #tests))
        end, debug.traceback)
        busy = false
        if not called then print('[ShopQuoteClientTest] FAIL ' .. tostring(failure)) end
    end)
end, false)
