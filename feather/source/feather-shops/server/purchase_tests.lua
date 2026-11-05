if not Config.DevMode then return end
local concurrencyRunning=false
RegisterCommand('ShopPurchaseConcurrencyTest',function(source,args)
    if source~=0 then return end
    local target,base=tonumber(args[1]),args[2]
    if #args~=2 or not ShopService.Integer(target,1,65535) or type(base)~='string'
        or #base>110 or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[ShopPurchaseConcurrencyTest] usage: ShopPurchaseConcurrencyTest <nearby buyer source> <fresh requestId>');return
    end
    if concurrencyRunning then print('[ShopPurchaseConcurrencyTest] FAIL another concurrency test is running');return end
    concurrencyRunning=true
    local ids={}
    local pending=0
    local called,failure=xpcall(function()
        assert(ShopService.IsReady(),'Shops not ready')
        local session=exports['feather-core']:GetSessionContext(target)
        assert(session.ok,'Active buyer session required')
        local shop,offer=Config.Shops[1],Config.Shops[1].offers[1]
        local total=offer.unitPrice*2
        local accounts=exports['feather-economy']:FindAccountsByOwner({ownerType='character',ownerId=session.value.characterId})
        local wallet
        for _,account in ipairs(accounts.ok and accounts.value or {}) do
            if account.accountType=='wallet' and account.currency==offer.currency then wallet=account end
        end
        assert(wallet and wallet.balance==total,'Wallet must equal exactly one two-item purchase; no funds changed')
        for _,suffix in ipairs({'a','b'}) do
            assert(not DB.one("SELECT `order_id` FROM `shop_orders` WHERE `source_resource`='feather-shops' AND `request_id`=?",base..':'..suffix),
                'Fresh request ID required; inspect previous orders instead of rerunning')
        end
        local settlement=ShopOrganizations.Settlement(shop.id,offer.currency)
        assert(settlement.ok and settlement.value.accountType=='treasury','Business treasury unavailable')
        local quote=ShopQuotes.Create({shopId=shop.id,offerId=offer.id,quantity=2},target)
        assert(quote.ok,'Quote failed: '..tostring(quote.code))
        for index,suffix in ipairs({'a','b'}) do
            local prepared=ShopOrders.Prepare({quoteId=quote.value.id,requestId=base..':'..suffix},target,'feather-shops')
            assert(prepared.ok,'Prepare failed: '..tostring(prepared.code))
            ids[index]=prepared.value.id
        end
        print(('[ShopPurchaseConcurrencyTest] started orderA=%s orderB=%s'):format(ids[1],ids[2]))
        local go,done,results=false,0,{}
        for index=1,2 do
            local contender=index
            pending=pending+1
            CreateThread(function()
                while not go do Wait(0) end
                local ok,result=xpcall(function() return ShopPurchases.Purchase(ids[contender],target) end,debug.traceback)
                results[contender]=ok and result or {ok=false,code='test_exception',message=tostring(result)}
                done=done+1
                pending=pending-1
                print(('[ShopPurchaseConcurrencyTest] contender=%d ok=%s code=%s'):format(contender,tostring(results[contender].ok),tostring(results[contender].code)))
                if not results[contender].ok then
                    print('[ShopPurchaseConcurrencyTest] failureDetails='..json.encode(results[contender]))
                end
            end)
        end
        go=true
        local deadline=GetGameTimer()+30000
        while done<2 and GetGameTimer()<deadline do Wait(0) end
        assert(done==2,'Timed out; operations may still complete. Retain printed order IDs; do not rerun with new IDs')
        local winner,loser,committed,insufficient=nil,nil,0,0
        for index,result in ipairs(results) do
            if result.ok and result.value.state=='fulfilled' then winner=index;committed=committed+1
            elseif not result.ok and result.code=='insufficient_funds' then loser=index;insufficient=insufficient+1 end
        end
        assert(committed==1 and insufficient==1,'Expected one fulfilled purchase and one insufficient-funds rejection')
        local won=DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?',ids[winner])
        local lost=DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?',ids[loser])
        assert(won and lost and won.state=='fulfilled' and lost.state=='rejected'
            and lost.payment_transaction_id==nil and lost.fulfillment_json==nil,'Unexpected durable executions')
        assert(won.to_account_id==settlement.value.accountId and lost.to_account_id==settlement.value.accountId,'Settlement destination changed')
        local replay=ShopPurchases.Purchase(ids[winner],target)
        local denied=ShopPurchases.Purchase(ids[loser],target)
        assert(replay.ok and replay.value.replayed==true and replay.value.transactionId==won.payment_transaction_id
            and not denied.ok and denied.code=='insufficient_funds','Replay changed outcome')
        local grant=exports['feather-inventory']:GrantCharacterItemOnce({grantId='shop-fulfillment:'..ids[winner],
            characterId=session.value.characterId,itemName=offer.itemName,definitionId=quote.value.definitionId,quantity=2})
        local decoded,receipt=pcall(json.decode,won.fulfillment_json or '')
        assert(grant.ok and grant.value.replayed==true and decoded and type(receipt)=='table'
            and json.encode(grant.value.instanceIds)==json.encode(receipt.instanceIds),'Winner delivery replay changed instances')
        local after=exports['feather-economy']:GetAccount({accountId=wallet.accountId})
        local treasury=exports['feather-economy']:GetAccount({accountId=settlement.value.accountId})
        assert(after.ok and treasury.ok and after.value.balance==0
            and treasury.value.balance==settlement.value.balance+total,'Balances not conserved or concurrent unrelated activity occurred')
        print(('[ShopPurchaseConcurrencyTest] PASS committed=1 insufficient=1 conserved=true winnerReplayed=true sameInstances=true losingExecutionUnfulfilled=true walletFinal=0 treasuryDelta=%s (two items purchased; funds not restored)'):format(total))
    end,debug.traceback)
    -- An uncertain timeout must not permit a second overlapping test.
    if pending==0 then concurrencyRunning=false end
    if not called then
        print('[ShopPurchaseConcurrencyTest] FAIL '..tostring(failure)..' orders='..json.encode(ids)..'; inspect existing orders before any retry')
    end
end,true)
RegisterCommand('ShopPurchaseConcurrencyReplayTest',function(source,args)
    if source~=0 then return end
    local target,base=tonumber(args[1]),args[2]
    if #args~=2 or not ShopService.Integer(target,1,65535) or type(base)~='string'
        or #base>110 or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[ShopPurchaseConcurrencyReplayTest] usage: ShopPurchaseConcurrencyReplayTest <active buyer source> <existing requestId>');return
    end
    local called,failure=xpcall(function()
        assert(ShopService.IsReady(),'Shops not ready')
        local session=exports['feather-core']:GetSessionContext(target)
        assert(type(session)=='table' and session.ok,'Active buyer session required')
        local orders={}
        for index,suffix in ipairs({'a','b'}) do
            orders[index]=DB.one([[SELECT o.*,e.`state` AS execution_state,e.`payment_transaction_id`,
                e.`fulfillment_json`,e.`from_account_id`,e.`to_account_id`,e.`amount`
                FROM `shop_orders` o INNER JOIN `shop_order_executions` e ON e.`order_id`=o.`order_id`
                WHERE o.`source_resource`='feather-shops' AND o.`request_id`=?]],base..':'..suffix)
            assert(orders[index] and orders[index].buyer_character_id==session.value.characterId
                and orders[index].buyer_account_id==session.value.accountId,'Original buyer concurrency order required')
        end
        local winner,loser
        for _,order in ipairs(orders) do
            if order.execution_state=='fulfilled' then winner=order
            elseif order.execution_state=='rejected' and order.payment_transaction_id==nil
                and order.fulfillment_json==nil then loser=order end
        end
        assert(winner and loser,'Expected one fulfilled and one uncharged rejected execution')
        assert(winner.from_account_id==loser.from_account_id and winner.to_account_id==loser.to_account_id,
            'Concurrency pair account binding changed')
        local walletBefore=exports['feather-economy']:GetAccount({accountId=winner.from_account_id})
        local treasuryBefore=exports['feather-economy']:GetAccount({accountId=winner.to_account_id})
        assert(walletBefore.ok and treasuryBefore.ok,'Settlement accounts unavailable')
        local won=ShopPurchases.Purchase(winner.order_id,target)
        local denied=ShopPurchases.Purchase(loser.order_id,target)
        assert(won.ok and won.value.replayed==true and won.value.transactionId==winner.payment_transaction_id,
            'Winner did not replay original payment')
        assert(not denied.ok and denied.code=='insufficient_funds','Rejected loser outcome changed')
        local grant=exports['feather-inventory']:GrantCharacterItemOnce({
            grantId='shop-fulfillment:'..winner.order_id,characterId=winner.buyer_character_id,
            itemName=winner.item_name,definitionId=tonumber(winner.definition_id),quantity=tonumber(winner.quantity)})
        local decoded,receipt=pcall(json.decode,winner.fulfillment_json or '')
        assert(grant.ok and grant.value.replayed==true and decoded and type(receipt)=='table'
            and json.encode(grant.value.instanceIds)==json.encode(receipt.instanceIds),'Winner delivery identity changed')
        local walletAfter=exports['feather-economy']:GetAccount({accountId=winner.from_account_id})
        local treasuryAfter=exports['feather-economy']:GetAccount({accountId=winner.to_account_id})
        assert(walletAfter.ok and treasuryAfter.ok and walletAfter.value.balance==walletBefore.value.balance
            and treasuryAfter.value.balance==treasuryBefore.value.balance,'Replay changed balances')
        local loserAfter=DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?',loser.order_id)
        assert(loserAfter and loserAfter.state=='rejected' and loserAfter.payment_transaction_id==nil
            and loserAfter.fulfillment_json==nil,'Rejected loser acquired effects')
        print(('[ShopPurchaseConcurrencyReplayTest] PASS winner=%s loser=%s winnerReplayed=true sameInstances=true loserStillRejected=true balancesUnchanged=true wallet=%s treasury=%s'):format(
            winner.order_id,loser.order_id,tostring(walletAfter.value.balance),tostring(treasuryAfter.value.balance)))
    end,debug.traceback)
    if not called then print('[ShopPurchaseConcurrencyReplayTest] FAIL '..tostring(failure)) end
end,true)
RegisterCommand('ShopPurchaseRecoveryTest', function(source, args)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopPurchaseRecoveryTest] FAIL service not ready'); return end
    local target, requestId, operation = tonumber(args[1]), args[2], args[3]
    if not target or type(requestId) ~= 'string' or #requestId > 128
        or not requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or (operation ~= 'payment' and operation ~= 'grant' and operation ~= 'undelivered' and operation ~= 'retry') then
        print('[ShopPurchaseRecoveryTest] usage: ShopPurchaseRecoveryTest <source> <requestId> payment|grant|undelivered|retry'); return
    end
    local session = exports['feather-core']:GetSessionContext(target)
    if type(session) ~= 'table' or not session.ok then print('[ShopPurchaseRecoveryTest] FAIL buyer session required'); return end
    local order = DB.one([[SELECT * FROM `shop_orders`
        WHERE `source_resource`='feather-shops' AND `request_id`=?]], requestId)
    if operation ~= 'retry' and order then print('[ShopPurchaseRecoveryTest] FAIL fresh request ID required'); return end
    if operation == 'retry' and not order then print('[ShopPurchaseRecoveryTest] FAIL prepared recovery order missing'); return end
    if order and (order.buyer_character_id ~= session.value.characterId or order.buyer_account_id ~= session.value.accountId) then
        print('[ShopPurchaseRecoveryTest] FAIL order belongs to another buyer'); return
    end
    local shop, offer = Config.Shops[1], Config.Shops[1].offers[1]
    local currency = order and order.currency_code or offer.currency
    local wallets = exports['feather-economy']:EnsureCharacterWallets({ characterId = session.value.characterId })
    local wallet
    for _, account in ipairs(wallets.ok and wallets.value or {}) do
        if account.currency == currency then wallet = account; break end
    end
    local sink = ShopOrganizations.Settlement(order and order.shop_id or shop.id, currency, order and order.order_id)
    if not wallet or not sink.ok then print('[ShopPurchaseRecoveryTest] FAIL wallet/settlement unavailable'); return end
    if not order then
        if wallet.balance < offer.unitPrice * 2 then print('[ShopPurchaseRecoveryTest] FAIL fund wallet first'); return end
        local quoted = ShopQuotes.Create({ shopId = shop.id, offerId = offer.id, quantity = 2 }, target)
        if not quoted.ok then print('[ShopPurchaseRecoveryTest] FAIL quote=' .. quoted.code); return end
        local prepared = ShopOrders.Prepare({ requestId = requestId, quoteId = quoted.value.id }, target, 'feather-shops')
        if not prepared.ok then print('[ShopPurchaseRecoveryTest] FAIL order=' .. prepared.code); return end
        order = DB.one('SELECT * FROM `shop_orders` WHERE `order_id`=?', prepared.value.id)
    end
    local beforeExecution = DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?', order.order_id)
    if operation == 'retry' and (not beforeExecution or
        (beforeExecution.state ~= 'payment_pending' and beforeExecution.state ~= 'paid' and beforeExecution.state ~= 'fulfilled')) then
        print('[ShopPurchaseRecoveryTest] FAIL execution is not recoverable'); return
    end
    local checkpoint = operation == 'payment' and 'after_payment' or operation == 'grant' and 'after_grant'
        or operation == 'undelivered' and 'before_grant' or nil
    local result = ShopPurchases.Purchase(order.order_id, target, checkpoint)
    local after = exports['feather-economy']:GetAccount({ accountId = wallet.accountId })
    local sinkAfter = exports['feather-economy']:GetAccount({ accountId = sink.value.accountId })
    local stored = DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?', order.order_id)
    if operation ~= 'retry' then
        local expected = operation == 'payment' and 'payment_pending' or 'paid'
        local passed = not result.ok and result.code == 'test_interrupted' and stored and stored.state == expected
            and stored.fulfillment_json == nil and after.ok and sinkAfter.ok
            and after.value.balance == wallet.balance - tonumber(order.total_amount)
            and sinkAfter.value.balance == sink.value.balance + tonumber(order.total_amount)
            and (operation ~= 'payment' or stored.payment_transaction_id == nil)
        print(('[ShopPurchaseRecoveryTest] %s interrupted=%s order=%s state=%s walletFinal=%s; restart Shops then retry same request ID'):format(
            passed and 'PASS' or 'FAIL', operation, order.order_id,
            tostring(stored and stored.state), tostring(after.ok and after.value.balance)))
        return
    end
    if not result.ok then print('[ShopPurchaseRecoveryTest] FAIL order=' .. order.order_id .. ' code=' .. result.code); return end
    local unchanged = after.ok and sinkAfter.ok and after.value.balance == wallet.balance
        and sinkAfter.value.balance == sink.value.balance
    local payment = exports['feather-economy']:Transfer({
        fromAccountId = stored.from_account_id, toAccountId = stored.to_account_id,
        currency = stored.currency_code, amount = tonumber(stored.amount), reasonCode = 'shop.purchase',
        referenceType = 'shop_order', referenceId = order.order_id, idempotencyKey = 'shop-payment:' .. order.order_id
    }, { actorSource = target, actorAccountId = order.buyer_account_id,
        actorCharacterId = order.buyer_character_id, correlationId = order.order_id })
    local grant = exports['feather-inventory']:GrantCharacterItemOnce({
        grantId = 'shop-fulfillment:' .. order.order_id, characterId = order.buyer_character_id,
        itemName = order.item_name, definitionId = tonumber(order.definition_id), quantity = tonumber(order.quantity) })
    local decoded, fulfillment = pcall(json.decode, stored.fulfillment_json or '')
    local sameIds = grant.ok and decoded and type(fulfillment) == 'table'
        and json.encode(grant.value.instanceIds) == json.encode(fulfillment.instanceIds)
    local paymentReplayed = payment.ok and payment.value.replayed == true
        and payment.value.transactionId == stored.payment_transaction_id
    local grantReplayed = grant.ok and grant.value.replayed == true and sameIds
    local grantRecovered = decoded and type(fulfillment) == 'table' and fulfillment.replayed == true
    local passed = stored.state == 'fulfilled' and unchanged and paymentReplayed and grantReplayed
        and (beforeExecution.state ~= 'paid' or grantRecovered)
    print(('[ShopPurchaseRecoveryTest] %s order=%s state=%s noSecondCharge=%s paymentReplayed=%s grantReplayed=%s grantRecovered=%s walletFinal=%s'):format(
        passed and 'PASS' or 'FAIL', order.order_id, stored.state, tostring(unchanged),
        tostring(paymentReplayed), tostring(grantReplayed), tostring(grantRecovered), tostring(after.value.balance)))
end, true)
RegisterCommand('ShopPurchaseLiveTest', function(source, args)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopPurchaseLiveTest] FAIL service not ready'); return end
    local target, requestId = tonumber(args[1]), args[2]
    if not target or type(requestId) ~= 'string' or #requestId > 128
        or not requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[ShopPurchaseLiveTest] usage: ShopPurchaseLiveTest <active source near shop> <requestId>'); return
    end
    local session = exports['feather-core']:GetSessionContext(target)
    if type(session) ~= 'table' or not session.ok then print('[ShopPurchaseLiveTest] FAIL active buyer required'); return end
    local order = DB.one([[SELECT * FROM `shop_orders`
        WHERE `source_resource`='feather-shops' AND `request_id`=?]], requestId)
    if order and (order.buyer_character_id ~= session.value.characterId or order.buyer_account_id ~= session.value.accountId) then
        print('[ShopPurchaseLiveTest] FAIL request belongs to another buyer'); return
    end
    local execution = order and DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?', order.order_id)
    if order and (not execution or execution.state ~= 'fulfilled') then
        print('[ShopPurchaseLiveTest] FAIL existing incomplete order requires recovery; do not use a new request ID'); return
    end
    local shop, offer = Config.Shops[1], Config.Shops[1].offers[1]
    local currency = order and order.currency_code or offer.currency
    local total = order and tonumber(order.total_amount) or offer.unitPrice * 2
    local wallets = exports['feather-economy']:EnsureCharacterWallets({ characterId = session.value.characterId })
    local wallet
    for _, account in ipairs(wallets.ok and wallets.value or {}) do
        if account.currency == currency then wallet = account; break end
    end
    if not wallet then print('[ShopPurchaseLiveTest] FAIL wallet unavailable'); return end
    local sink = ShopOrganizations.Settlement(order and order.shop_id or shop.id, currency, order and order.order_id)
    if not sink.ok then print('[ShopPurchaseLiveTest] FAIL settlement unavailable'); return end
    if not order and (sink.value.accountType ~= 'treasury' or sink.value.ownerType ~= 'organization'
        or sink.value.ownerId ~= ShopOrganizations.GetId(shop.id)) then
        print('[ShopPurchaseLiveTest] FAIL new purchase must settle to canonical business treasury'); return
    end
    local existing = order ~= nil
    if not order then
        if wallet.balance < total then print('[ShopPurchaseLiveTest] FAIL fund wallet first; no order created'); return end
        local quoted = ShopQuotes.Create({ shopId = shop.id, offerId = offer.id, quantity = 2 }, target)
        if not quoted.ok then print('[ShopPurchaseLiveTest] FAIL quote=' .. quoted.code); return end
        local prepared = ShopOrders.Prepare({ requestId = requestId, quoteId = quoted.value.id }, target, 'feather-shops')
        if not prepared.ok then print('[ShopPurchaseLiveTest] FAIL prepare=' .. prepared.code); return end
        order = DB.one('SELECT * FROM `shop_orders` WHERE `order_id`=?', prepared.value.id)
    end
    local result = ShopPurchases.Purchase(order.order_id, target)
    if not result.ok then
        print('[ShopPurchaseLiveTest] FAIL order=' .. order.order_id .. ' code=' .. result.code .. '; retain request ID for recovery'); return
    end
    local replayed = ShopPurchases.Purchase(order.order_id, target)
    local walletAfter = exports['feather-economy']:GetAccount({ accountId = wallet.accountId })
    local sinkAfter = exports['feather-economy']:GetAccount({ accountId = sink.value.accountId })
    local chargedOnce = walletAfter.ok and sinkAfter.ok
        and walletAfter.value.balance == wallet.balance - (existing and 0 or total)
        and sinkAfter.value.balance == sink.value.balance + (existing and 0 or total)
    -- A fulfilled receipt must already exist. This exact grant retry checks that
    -- Inventory returns it rather than creating another delivery.
    local delivered = exports['feather-inventory']:GrantCharacterItemOnce({
        grantId = 'shop-fulfillment:' .. order.order_id, characterId = order.buyer_character_id,
        definitionId = tonumber(order.definition_id), itemName = order.item_name, quantity = tonumber(order.quantity) })
    local stored = DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?', order.order_id)
    chargedOnce = chargedOnce and stored and stored.to_account_id == sink.value.accountId
    local sameDelivery = false
    if stored and stored.fulfillment_json and delivered.ok then
        local decoded, original = pcall(json.decode, stored.fulfillment_json)
        sameDelivery = decoded and json.encode(original.instanceIds) == json.encode(delivered.value.instanceIds)
    end
    local passed = result.value.state == 'fulfilled' and replayed.ok and replayed.value.replayed == true
        and replayed.value.transactionId == result.value.transactionId and chargedOnce
        and delivered.ok and delivered.value.replayed == true and sameDelivery
    print(('[ShopPurchaseLiveTest] %s order=%s state=%s amount=%s chargedOnce=%s replayed=%s fulfillmentReplayed=%s sameInstances=%s walletFinal=%s settlementType=%s settlementOwner=%s settlementFinal=%s'):format(
        passed and 'PASS' or 'FAIL', order.order_id, result.value.state, tostring(total),
        tostring(chargedOnce), tostring(replayed.ok and replayed.value.replayed),
        tostring(delivered.ok and delivered.value.replayed), tostring(sameDelivery),
        tostring(walletAfter.ok and walletAfter.value.balance), tostring(sink.value.accountType),
        tostring(sink.value.ownerId), tostring(sinkAfter.ok and sinkAfter.value.balance)))
end, true)
