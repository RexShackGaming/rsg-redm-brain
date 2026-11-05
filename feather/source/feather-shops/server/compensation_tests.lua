if not Config.DevMode then return end
RegisterCommand('ShopRefundDeliveredTest', function(source, args)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopRefundDeliveredTest] FAIL service not ready'); return end
    local target, requestId = tonumber(args[1]), args[2]
    if not ShopService.Integer(target, 1, 65535) or type(requestId) ~= 'string' or #requestId > 128
        or not requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[ShopRefundDeliveredTest] usage: ShopRefundDeliveredTest <source> <after-grant requestId>'); return
    end
    local session = exports['feather-core']:GetSessionContext(target)
    local order = DB.one([[SELECT o.*,e.`state` AS execution_state,e.`from_account_id`,e.`to_account_id`
        FROM `shop_orders` o INNER JOIN `shop_order_executions` e ON e.`order_id`=o.`order_id`
        WHERE o.`source_resource`='feather-shops' AND o.`request_id`=?]], requestId)
    if not session.ok or not order or order.buyer_character_id ~= session.value.characterId
        or order.buyer_account_id ~= session.value.accountId or order.execution_state ~= 'paid' then
        print('[ShopRefundDeliveredTest] FAIL original buyer and paid after-grant order required'); return
    end
    -- Dev-only preflight: refuse to run against a grant that has not committed.
    -- Production compensation never treats a missing receipt as no-delivery proof.
    local encoded = DB.value([[SELECT `result_json` FROM `inventory_grant_receipts`
        WHERE `source_resource`='feather-shops' AND `grant_id`=?]], 'shop-fulfillment:' .. order.order_id)
    local decoded, original = pcall(json.decode, encoded or '')
    if not decoded or type(original) ~= 'table' or original.cancelled == true
        or type(original.instanceIds) ~= 'table' or #original.instanceIds ~= tonumber(order.quantity) then
        print('[ShopRefundDeliveredTest] FAIL committed delivery receipt required; no compensation attempted'); return
    end
    local before = exports['feather-economy']:GetAccount({ accountId = order.from_account_id })
    local sink = exports['feather-economy']:GetAccount({ accountId = order.to_account_id })
    if not before.ok or not sink.ok then print('[ShopRefundDeliveredTest] FAIL balances unavailable'); return end
    local refused = ShopPurchases.Compensate(order.order_id, target)
    local repeated = ShopPurchases.Compensate(order.order_id, target)
    local row = DB.one('SELECT * FROM `shop_order_compensations` WHERE `order_id`=?', order.order_id)
    if refused.ok or refused.code ~= 'grant_already_delivered' or not row or row.state ~= 'delivery_committed' then
        print('[ShopRefundDeliveredTest] FAIL delivery protection; retain request ID'); return
    end
    local recovered = ShopPurchases.Purchase(order.order_id, target)
    local stored = DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?', order.order_id)
    local parsed, fulfillment = pcall(json.decode, stored and stored.fulfillment_json or '')
    local sameIds = parsed and type(fulfillment) == 'table' and fulfillment.replayed == true
        and json.encode(fulfillment.instanceIds) == json.encode(original.instanceIds)
    local after = exports['feather-economy']:GetAccount({ accountId = order.from_account_id })
    local sinkAfter = exports['feather-economy']:GetAccount({ accountId = order.to_account_id })
    local unchanged = after.ok and sinkAfter.ok and after.value.balance == before.value.balance
        and sinkAfter.value.balance == sink.value.balance
    local passed = not repeated.ok and repeated.code == 'grant_already_delivered'
        and row.refund_transaction_id == nil and row.cancellation_json == nil
        and recovered.ok and stored.state == 'fulfilled' and sameIds and unchanged
    print(('[ShopRefundDeliveredTest] %s order=%s refundRefused=true balancesUnchanged=%s state=%s sameInstances=%s (no additional items granted)'):format(
        passed and 'PASS' or 'FAIL', order.order_id, tostring(unchanged), tostring(stored and stored.state), tostring(sameIds)))
end, true)

RegisterCommand('ShopDeliveryRefundConcurrencyTest',function(source,args)
    if source~=0 then return end
    local target,requestId,ordering=tonumber(args[1]),args[2],args[3] or 'delivery-first'
    if (#args~=2 and #args~=3) or (ordering~='delivery-first' and ordering~='refund-first')
        or not ShopService.Integer(target,1,65535) or type(requestId)~='string'
        or #requestId>128 or not requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[ShopDeliveryRefundConcurrencyTest] usage: ShopDeliveryRefundConcurrencyTest <active original buyer source> <paid undelivered requestId> [delivery-first|refund-first]');return
    end
    local called,failure=xpcall(function()
        assert(ShopService.IsReady(),'Shops not ready')
        local session=exports['feather-core']:GetSessionContext(target)
        assert(type(session)=='table' and session.ok,'Active buyer required')
        local order=DB.one([[SELECT o.*,e.`state` AS execution_state,e.`from_account_id`,
            e.`to_account_id`,e.`payment_transaction_id`,e.`amount`,e.`fulfillment_json`
            FROM `shop_orders` o INNER JOIN `shop_order_executions` e ON e.`order_id`=o.`order_id`
            WHERE o.`source_resource`='feather-shops' AND o.`request_id`=?]],requestId)
        assert(order and order.buyer_character_id==session.value.characterId
            and order.buyer_account_id==session.value.accountId,'Original buyer order required')
        if order.execution_state=='fulfilled' then
            local request={grantId='shop-fulfillment:'..order.order_id,characterId=order.buyer_character_id,
                itemName=order.item_name,definitionId=tonumber(order.definition_id),quantity=tonumber(order.quantity)}
            local before=exports['feather-economy']:GetAccount({accountId=order.from_account_id})
            local treasury=exports['feather-economy']:GetAccount({accountId=order.to_account_id})
            local delivery=ShopPurchases.Purchase(order.order_id,target)
            local refund=ShopPurchases.Compensate(order.order_id,target)
            local grant=exports['feather-inventory']:GrantCharacterItemOnce(request)
            local cancel=exports['feather-inventory']:CancelCharacterItemGrant(request)
            local after=exports['feather-economy']:GetAccount({accountId=order.from_account_id})
            local treasuryAfter=exports['feather-economy']:GetAccount({accountId=order.to_account_id})
            assert(before.ok and treasury.ok and after.ok and treasuryAfter.ok
                and delivery.ok and delivery.value.replayed==true
                and not refund.ok and refund.code=='compensation_not_allowed'
                and grant.ok and grant.value.replayed==true and not cancel.ok
                and cancel.error and cancel.error.code=='grant_already_delivered'
                and after.value.balance==before.value.balance
                and treasuryAfter.value.balance==treasury.value.balance,
                'Existing delivered outcome is not terminal')
            print(('[ShopDeliveryRefundConcurrencyTest] PASS outcome=delivered replay=true deliveryAndRefund=false balanceConsistent=true deliveryFence=true walletFinal=%s treasuryFinal=%s'):format(
                tostring(after.value.balance),tostring(treasuryAfter.value.balance)))
            return
        end
        local existingCompensation=DB.one('SELECT * FROM `shop_order_compensations` WHERE `order_id`=?',order.order_id)
        if order.execution_state=='paid' and existingCompensation and existingCompensation.state=='refunded' then
            local request={grantId='shop-fulfillment:'..order.order_id,characterId=order.buyer_character_id,
                itemName=order.item_name,definitionId=tonumber(order.definition_id),quantity=tonumber(order.quantity)}
            local before=exports['feather-economy']:GetAccount({accountId=order.from_account_id})
            local treasury=exports['feather-economy']:GetAccount({accountId=order.to_account_id})
            local delivery=ShopPurchases.Purchase(order.order_id,target)
            local refund=ShopPurchases.Compensate(order.order_id,target)
            local grant=exports['feather-inventory']:GrantCharacterItemOnce(request)
            local cancel=exports['feather-inventory']:CancelCharacterItemGrant(request)
            local after=exports['feather-economy']:GetAccount({accountId=order.from_account_id})
            local treasuryAfter=exports['feather-economy']:GetAccount({accountId=order.to_account_id})
            assert(before.ok and treasury.ok and after.ok and treasuryAfter.ok
                and not delivery.ok and delivery.code=='order_compensating'
                and refund.ok and refund.value.replayed==true
                and refund.value.transactionId==existingCompensation.refund_transaction_id
                and not grant.ok and grant.error and grant.error.code=='grant_cancelled'
                and cancel.ok and cancel.value.cancelled==true and cancel.value.replayed==true
                and after.value.balance==before.value.balance
                and treasuryAfter.value.balance==treasury.value.balance,
                'Existing refunded outcome is not terminal')
            print(('[ShopDeliveryRefundConcurrencyTest] PASS outcome=refunded replay=true deliveryAndRefund=false balanceConsistent=true deliveryFence=true walletFinal=%s treasuryFinal=%s'):format(
                tostring(after.value.balance),tostring(treasuryAfter.value.balance)))
            return
        end
        assert(order.execution_state=='paid' and order.payment_transaction_id
            and order.fulfillment_json==nil,'Order must be paid and undelivered')
        assert(not existingCompensation,
            'Fresh compensation state required')
        local walletBefore=exports['feather-economy']:GetAccount({accountId=order.from_account_id})
        local treasuryBefore=exports['feather-economy']:GetAccount({accountId=order.to_account_id})
        assert(walletBefore.ok and treasuryBefore.ok,'Settlement accounts unavailable')
        print('[ShopDeliveryRefundConcurrencyTest] started order='..order.order_id)
        local go,done,results=false,0,{}
        local contenders=ordering=='refund-first' and {
            {name='refund',run=function() return ShopPurchases.Compensate(order.order_id,target) end},
            {name='delivery',run=function() return ShopPurchases.Purchase(order.order_id,target) end}
        } or {
            {name='delivery',run=function() return ShopPurchases.Purchase(order.order_id,target) end},
            {name='refund',run=function() return ShopPurchases.Compensate(order.order_id,target) end}
        }
        for index=1,2 do
            local contender=index
            CreateThread(function()
                while not go do Wait(0) end
                local ok,result=xpcall(contenders[contender].run,debug.traceback)
                results[contender]=ok and result or {ok=false,code='test_exception',message=tostring(result)}
                done=done+1
                print(('[ShopDeliveryRefundConcurrencyTest] contender=%s ok=%s code=%s'):format(
                    contenders[contender].name,tostring(results[contender].ok),tostring(results[contender].code)))
            end)
        end
        go=true
        local deadline=GetGameTimer()+30000
        while done<2 and GetGameTimer()<deadline do Wait(0) end
        assert(done==2,'Timed out; inspect original order and do not replace its request ID')
        local conflicts=0
        for _,result in ipairs(results) do if not result.ok and result.code=='transaction_conflict' then conflicts=conflicts+1 end end
        assert(conflicts==1,'Runtime coordinator must admit exactly one contender')
        -- Retry both sides after serialization. Durable Inventory state decides the
        -- terminal winner; neither retry is permitted to reverse that decision.
        local delivery=ShopPurchases.Purchase(order.order_id,target)
        local refund=ShopPurchases.Compensate(order.order_id,target)
        local execution=DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?',order.order_id)
        local compensation=DB.one('SELECT * FROM `shop_order_compensations` WHERE `order_id`=?',order.order_id)
        local request={grantId='shop-fulfillment:'..order.order_id,characterId=order.buyer_character_id,
            itemName=order.item_name,definitionId=tonumber(order.definition_id),quantity=tonumber(order.quantity)}
        local grant=exports['feather-inventory']:GrantCharacterItemOnce(request)
        local cancel=exports['feather-inventory']:CancelCharacterItemGrant(request)
        local walletAfter=exports['feather-economy']:GetAccount({accountId=order.from_account_id})
        local treasuryAfter=exports['feather-economy']:GetAccount({accountId=order.to_account_id})
        assert(walletAfter.ok and treasuryAfter.ok,'Final balances unavailable')
        local delivered=execution and execution.state=='fulfilled'
            and delivery.ok and not refund.ok and refund.code=='compensation_not_allowed'
            and grant.ok and grant.value.replayed==true and not cancel.ok
            and cancel.error and cancel.error.code=='grant_already_delivered'
            and walletAfter.value.balance==walletBefore.value.balance
            and treasuryAfter.value.balance==treasuryBefore.value.balance
        local refunded=execution and execution.state=='paid'
            and compensation and compensation.state=='refunded'
            and not delivery.ok and delivery.code=='order_compensating'
            and refund.ok and not grant.ok and grant.error and grant.error.code=='grant_cancelled'
            and cancel.ok and cancel.value.cancelled==true and cancel.value.replayed==true
            and walletAfter.value.balance==walletBefore.value.balance+tonumber(order.amount)
            and treasuryAfter.value.balance==treasuryBefore.value.balance-tonumber(order.amount)
        assert(delivered~=refunded and (delivered or refunded),'Exactly one terminal delivery/refund outcome required')
        print(('[ShopDeliveryRefundConcurrencyTest] PASS outcome=%s mutexConflict=true deliveryAndRefund=false balanceConsistent=true deliveryFence=true walletFinal=%s treasuryFinal=%s'):format(
            delivered and 'delivered' or 'refunded',tostring(walletAfter.value.balance),tostring(treasuryAfter.value.balance)))
    end,debug.traceback)
    if not called then print('[ShopDeliveryRefundConcurrencyTest] FAIL '..tostring(failure)..'; retain original request ID') end
end,true)

RegisterCommand('ShopRefundLiveTest', function(source, args)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopRefundLiveTest] FAIL service not ready'); return end
    local target, requestId, mode = tonumber(args[1]), args[2], args[3] or 'refund'
    if not target or type(requestId) ~= 'string' or #requestId > 128
        or (mode ~= 'refund' and mode ~= 'interrupt' and mode ~= 'retry') then
        print('[ShopRefundLiveTest] usage: ShopRefundLiveTest <source> <paid undelivered requestId> refund|interrupt|retry'); return
    end
    local order = DB.one([[SELECT o.*,e.`from_account_id`,e.`to_account_id`
        FROM `shop_orders` o INNER JOIN `shop_order_executions` e ON e.`order_id`=o.`order_id`
        WHERE o.`source_resource`='feather-shops' AND o.`request_id`=? AND e.`state`='paid']], requestId)
    if not order then print('[ShopRefundLiveTest] FAIL paid order required'); return end
    local prior = DB.one('SELECT * FROM `shop_order_compensations` WHERE `order_id`=?', order.order_id)
    if (mode == 'retry' and (not prior or prior.state ~= 'refund_pending' and prior.state ~= 'refunded'))
        or (mode == 'interrupt' and prior) then
        print('[ShopRefundLiveTest] FAIL mode does not match existing compensation; retain request ID'); return
    end
    local before = exports['feather-economy']:GetAccount({ accountId = order.from_account_id })
    local sink = exports['feather-economy']:GetAccount({ accountId = order.to_account_id })
    if not before.ok or not sink.ok then print('[ShopRefundLiveTest] FAIL balances unavailable'); return end
    local result = ShopPurchases.Compensate(order.order_id, target, mode == 'interrupt' and 'after_refund' or nil)
    local row = DB.one('SELECT * FROM `shop_order_compensations` WHERE `order_id`=?', order.order_id)
    if not row then print('[ShopRefundLiveTest] FAIL code=' .. tostring(result.code)); return end
    if mode == 'interrupt' then
        local after = exports['feather-economy']:GetAccount({ accountId = order.from_account_id })
        local passed = not result.ok and result.code == 'test_interrupted' and row.state == 'refund_pending'
            and after.ok and after.value.balance == before.value.balance + tonumber(order.total_amount)
        print(('[ShopRefundLiveTest] %s order=%s state=%s; restart Shops then retry same request ID'):format(
            passed and 'PASS' or 'FAIL', order.order_id, row.state))
        return
    end
    local repeated = ShopPurchases.Compensate(order.order_id, target)
    local blocked = exports['feather-inventory']:GrantCharacterItemOnce({
        grantId = 'shop-fulfillment:' .. order.order_id, characterId = order.buyer_character_id,
        definitionId = tonumber(order.definition_id), itemName = order.item_name, quantity = tonumber(order.quantity) })
    local purchase = ShopPurchases.Purchase(order.order_id, target)
    local after = exports['feather-economy']:GetAccount({ accountId = order.from_account_id })
    local sinkAfter = exports['feather-economy']:GetAccount({ accountId = order.to_account_id })
    local delta = (mode == 'retry' or prior and prior.state == 'refunded') and 0 or tonumber(order.total_amount)
    local once = after.ok and sinkAfter.ok and after.value.balance == before.value.balance + delta
        and sinkAfter.value.balance == sink.value.balance - delta
    local passed = result.ok and row.state == 'refunded' and repeated.ok and repeated.value.replayed == true
        and repeated.value.transactionId == result.value.transactionId and once
        and not blocked.ok and blocked.error.code == 'grant_cancelled'
        and not purchase.ok and purchase.code == 'order_compensating'
    print(('[ShopRefundLiveTest] %s order=%s state=%s refundedOnce=%s replayed=%s deliveryBlocked=%s walletFinal=%s (no items granted)'):format(
        passed and 'PASS' or 'FAIL', order.order_id, row.state, tostring(once),
        tostring(repeated.ok and repeated.value.replayed), tostring(not blocked.ok and blocked.error.code == 'grant_cancelled'),
        tostring(after.ok and after.value.balance)))
end, true)

RegisterCommand('ShopCompensationFenceTest', function(source, args)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopCompensationFenceTest] FAIL service not ready'); return end
    local target, requestId = tonumber(args[1]), args[2]
    if not target or type(requestId) ~= 'string' or #requestId > 128 then
        print('[ShopCompensationFenceTest] usage: ShopCompensationFenceTest <source> <fulfilled purchase requestId>'); return
    end
    local session = exports['feather-core']:GetSessionContext(target)
    if not session.ok then print('[ShopCompensationFenceTest] FAIL active buyer required'); return end
    local order = DB.one([[SELECT o.* FROM `shop_orders` o
        INNER JOIN `shop_order_executions` e ON e.`order_id`=o.`order_id`
        WHERE o.`source_resource`='feather-shops' AND o.`request_id`=? AND e.`state`='fulfilled']], requestId)
    if not order or order.buyer_character_id ~= session.value.characterId
        or order.buyer_account_id ~= session.value.accountId then
        print('[ShopCompensationFenceTest] FAIL fulfilled purchase belonging to buyer required'); return
    end
    if not exports['feather-core']:IsSessionCurrent(target, session.value.sessionId, session.value.characterId) then
        print('[ShopCompensationFenceTest] FAIL buyer session changed'); return
    end
    local request = { grantId = 'dev-cancel:' .. order.order_id,
        characterId = order.buyer_character_id, definitionId = tonumber(order.definition_id),
        itemName = order.item_name, quantity = tonumber(order.quantity) }
    local cancelled = exports['feather-inventory']:CancelCharacterItemGrant(request)
    local replayed = exports['feather-inventory']:CancelCharacterItemGrant(request)
    local blocked = exports['feather-inventory']:GrantCharacterItemOnce(request)
    local changed = ShopService.Copy(request); changed.quantity = request.quantity + 1
    local mismatch = exports['feather-inventory']:CancelCharacterItemGrant(changed)
    local deliveredRequest = ShopService.Copy(request)
    deliveredRequest.grantId = 'shop-fulfillment:' .. order.order_id
    local deliveredBlocked = exports['feather-inventory']:CancelCharacterItemGrant(deliveredRequest)
    local tests = {
        { 'durable cancellation', cancelled.ok and cancelled.value.cancelled == true and cancelled.value.delivered == false },
        { 'cancellation replayed', replayed.ok and replayed.value.replayed == true },
        { 'later grant blocked', not blocked.ok and blocked.error and blocked.error.code == 'grant_cancelled' },
        { 'mismatch rejected', not mismatch.ok and mismatch.error and mismatch.error.code == 'idempotency_conflict' },
        { 'committed delivery protected', not deliveredBlocked.ok and deliveredBlocked.error and deliveredBlocked.error.code == 'grant_already_delivered' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ShopCompensationFenceTest] %-29s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ShopCompensationFenceTest] done %d/%d passed cancellationFirstReplayed=%s (no funds moved or items granted)'):format(
        passed, #tests, tostring(cancelled.ok and cancelled.value.replayed)))
end, true)
