if GetResourceMetadata(GetCurrentResourceName(), 'shops_dev_tests', 0) ~= 'true' then return end
local busy = false
RegisterCommand('ShopPurchaseClientTest', function(_, args)
    local requestId = args[1]
    if type(requestId) ~= 'string' or #requestId > 100
        or not requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[ShopPurchaseClientTest] usage: ShopPurchaseClientTest <stable requestId>'); return
    end
    if busy then print('[ShopPurchaseClientTest] FAIL test already running'); return end
    busy = true
    CreateThread(function()
        local called, failure = xpcall(function()
            local key = 'shops:purchase-test:' .. requestId
            local saved = GetResourceKvpString(key)
            local request
            if saved then
                local decoded, value = pcall(json.decode, saved)
                if not decoded or type(value) ~= 'table' or value.requestId ~= requestId
                    or type(value.quoteId) ~= 'string' then
                    print('[ShopPurchaseClientTest] FAIL saved request invalid; do not create another purchase to recover'); return
                end
                request = { requestId = value.requestId, quoteId = value.quoteId }
            else
                local quote = exports['feather-core']:CallRPCAsync('shops.quote.v1', {
                    shopId = '00000000-0000-4000-8000-000000000001',
                    offerId = '00000000-0000-4000-8000-000000000101', quantity = 2
                }, nil, 10000)
                if type(quote) ~= 'table' or quote.ok ~= true or type(quote.value) ~= 'table'
                    or type(quote.value.id) ~= 'string' then
                    print('[ShopPurchaseClientTest] FAIL quote=' .. tostring(type(quote) == 'table' and quote.code or 'invalid_response')); return
                end
                -- Save BEFORE sending a mutating RPC, including across client/resource
                -- restarts. An uncertain response must never mint a new quote/key.
                request = { requestId = requestId, quoteId = quote.value.id }
                SetResourceKvp(key, json.encode(request))
            end
            local result = exports['feather-core']:CallRPCAsync('shops.purchase.v1', request, nil, 15000)
            if type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table' then
                print('[ShopPurchaseClientTest] FAIL code=' .. tostring(type(result) == 'table' and result.code or 'invalid_response')
                    .. '; retain requestId=' .. requestId .. ' for retry'); return
            end
            -- Keep under Core's purchase rate limit, including rapid manual reruns.
            Wait(1100)
            local repeated = exports['feather-core']:CallRPCAsync('shops.purchase.v1', request, nil, 15000)
            local receipt = result.value
            local allowed = { orderId = true, state = true, quantity = true,
                currency = true, total = true, replayed = true }
            local isolated = true
            for field in pairs(receipt) do if not allowed[field] then isolated = false end end
            local replayed = type(repeated) == 'table' and repeated.ok == true and type(repeated.value) == 'table'
                and repeated.value.replayed == true and repeated.value.orderId == receipt.orderId
                and repeated.value.state == 'fulfilled' and repeated.value.total == receipt.total
                and repeated.value.quantity == receipt.quantity and repeated.value.currency == receipt.currency
            local passed = receipt.state == 'fulfilled' and receipt.quantity == 2 and receipt.currency == 'dollars'
                and receipt.total == 200 and type(receipt.orderId) == 'string' and isolated and replayed
            print(('[ShopPurchaseClientTest] %s order=%s state=%s total=%s replayed=%s publicFieldsOnly=%s requestId=%s'):format(
                passed and 'PASS' or 'FAIL', tostring(receipt.orderId), tostring(receipt.state),
                tostring(receipt.total), tostring(replayed), tostring(isolated), requestId))
            print('[ShopPurchaseClientTest] Verify server balances and delivery with ShopPurchaseLiveTest <source> ' .. requestId)
        end, debug.traceback)
        busy = false
        if not called then print('[ShopPurchaseClientTest] FAIL ' .. tostring(failure) .. '; retain requestId=' .. requestId) end
    end)
end, false)
