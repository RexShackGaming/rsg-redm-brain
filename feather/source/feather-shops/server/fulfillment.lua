-- Development acceptance only. Production fulfillment requires payment first.
if not Config.DevMode then return end
RegisterCommand('ShopFulfillmentLiveTest', function(source, args)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopFulfillmentLiveTest] FAIL service not ready'); return end
    local target, requestId = tonumber(args[1]), args[2]
    if not target or type(requestId) ~= 'string' or #requestId > 128 then
        print('[ShopFulfillmentLiveTest] usage: ShopFulfillmentLiveTest <active source> <prepared requestId>'); return
    end
    local session = exports['feather-core']:GetSessionContext(target)
    if type(session) ~= 'table' or not session.ok then
        print('[ShopFulfillmentLiveTest] FAIL active session required'); return
    end
    local order = DB.one([[SELECT * FROM `shop_orders`
        WHERE `source_resource`='feather-shops' AND `request_id`=?]], requestId)
    if not order or order.status ~= 'prepared'
        or order.buyer_character_id ~= session.value.characterId
        or order.buyer_account_id ~= session.value.accountId then
        print('[ShopFulfillmentLiveTest] FAIL prepared order belonging to buyer required'); return
    end
    if not exports['feather-core']:IsSessionCurrent(target, session.value.sessionId, session.value.characterId) then
        print('[ShopFulfillmentLiveTest] FAIL buyer session changed'); return
    end
    local request = { grantId = 'dev-order:' .. order.order_id,
        characterId = order.buyer_character_id, itemName = order.item_name,
        definitionId = tonumber(order.definition_id), quantity = tonumber(order.quantity) }
    local first = exports['feather-inventory']:GrantCharacterItemOnce(request)
    if type(first) ~= 'table' or not first.ok then
        print('[ShopFulfillmentLiveTest] FAIL inventory=' .. json.encode(first)); return
    end
    local replayed = exports['feather-inventory']:GrantCharacterItemOnce(request)
    local mismatchRequest = ShopService.Copy(request)
    mismatchRequest.quantity = request.quantity + 1
    local mismatch = exports['feather-inventory']:GrantCharacterItemOnce(mismatchRequest)
    local sameIds = type(replayed) == 'table' and replayed.ok
        and json.encode(first.value.instanceIds) == json.encode(replayed.value.instanceIds)
    local passed = sameIds and replayed.value.replayed == true
        and first.value.quantity == request.quantity and mismatch and not mismatch.ok
        and mismatch.error and mismatch.error.code == 'idempotency_conflict'
    print(('[ShopFulfillmentLiveTest] %s order=%s quantity=%s firstReplayed=%s replayed=%s sameInstances=%s mismatchRejected=%s (no funds moved)'):format(
        passed and 'PASS' or 'FAIL', order.order_id, tostring(request.quantity),
        tostring(first.value.replayed), tostring(replayed and replayed.ok and replayed.value.replayed),
        tostring(sameIds), tostring(mismatch and not mismatch.ok and mismatch.error
            and mismatch.error.code == 'idempotency_conflict')))
end, true)
