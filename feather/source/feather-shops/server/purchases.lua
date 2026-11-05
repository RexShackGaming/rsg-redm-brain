local Ok, Err = ShopService.Ok, ShopService.Err
ShopPurchases = {}
local active = {}
local schema = [[CREATE TABLE IF NOT EXISTS `shop_order_executions` (
    `order_id` CHAR(36) NOT NULL,
    `state` VARCHAR(32) NOT NULL DEFAULT 'payment_pending',
    `from_account_id` CHAR(36) NOT NULL, `to_account_id` CHAR(36) NOT NULL,
    `currency_code` VARCHAR(32) NOT NULL, `amount` BIGINT UNSIGNED NOT NULL,
    `payment_transaction_id` CHAR(36) NULL,
    `fulfillment_json` LONGTEXT NULL, `last_error` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`order_id`), KEY `idx_shop_execution_state` (`state`,`updated_at`),
    CONSTRAINT `fk_shop_execution_order` FOREIGN KEY (`order_id`) REFERENCES `shop_orders` (`order_id`),
    CONSTRAINT `chk_shop_execution_state` CHECK (`state` IN ('payment_pending','paid','fulfilled','rejected')),
    CONSTRAINT `chk_shop_execution_amount` CHECK (`amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
function ShopPurchases.Start()
    local hash = 2166136261
    for index = 1, #schema do hash = ((hash ~ schema:byte(index)) * 16777619) & 0xffffffff end
    local checksum = ('fnv1a32:%08x'):format(hash)
    local stored = DB.value('SELECT `checksum` FROM `shop_schema_migrations` WHERE `id`=?',
        '003_shop_order_executions')
    if stored and stored ~= checksum then return Err('migration_checksum_mismatch', 'Applied execution migration changed.') end
    if not stored then
        DB.exec(schema)
        DB.insert('INSERT INTO `shop_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
            '003_shop_order_executions', checksum)
    end
    local compensation = [[CREATE TABLE IF NOT EXISTS `shop_order_compensations` (
        `order_id` CHAR(36) NOT NULL PRIMARY KEY,
        `state` VARCHAR(32) NOT NULL DEFAULT 'cancellation_pending',
        `cancellation_json` LONGTEXT NULL, `refund_transaction_id` CHAR(36) NULL,
        `last_error` VARCHAR(64) NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT `fk_shop_compensation_order` FOREIGN KEY (`order_id`) REFERENCES `shop_orders` (`order_id`),
        CONSTRAINT `chk_shop_compensation_state` CHECK (`state` IN ('cancellation_pending','refund_pending','refunded','delivery_committed'))
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
    local compensationHash = 2166136261
    for index = 1, #compensation do compensationHash = ((compensationHash ~ compensation:byte(index)) * 16777619) & 0xffffffff end
    local compensationChecksum = ('fnv1a32:%08x'):format(compensationHash)
    local compensationStored = DB.value('SELECT `checksum` FROM `shop_schema_migrations` WHERE `id`=?',
        '004_shop_order_compensations')
    if compensationStored and compensationStored ~= compensationChecksum then
        return Err('migration_checksum_mismatch', 'Applied compensation migration changed.')
    end
    if not compensationStored then
        DB.exec(compensation)
        DB.insert('INSERT INTO `shop_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
            '004_shop_order_compensations', compensationChecksum)
    end
    return Ok({ applied = (stored and 0 or 1) + (compensationStored and 0 or 1) })
end
local function Execution(orderId)
    return DB.one('SELECT * FROM `shop_order_executions` WHERE `order_id`=?', orderId)
end
local function Wallet(characterId, currency)
    local found = exports['feather-economy']:FindAccountsByOwner({ ownerType = 'character', ownerId = characterId })
    if type(found) ~= 'table' or not found.ok then return found or Err('dependency_unavailable', 'Wallet lookup failed.') end
    for _, account in ipairs(found.value) do
        if account.currency == currency and account.accountType == 'wallet' then
            if account.status ~= 'open' then return Err('account_closed', 'Buyer wallet is closed.') end
            return Ok(account)
        end
    end
    local ensured = exports['feather-economy']:EnsureCharacterWallets({ characterId = characterId })
    if type(ensured) ~= 'table' or not ensured.ok then return ensured or Err('dependency_unavailable', 'Wallet provisioning failed.') end
    for _, account in ipairs(ensured.value) do
        if account.currency == currency and account.accountType == 'wallet' and account.status == 'open' then return Ok(account) end
    end
    return Err('account_not_found', 'Buyer currency wallet missing.')
end
local function Receipt(execution, replayed)
    return Ok({ orderId = execution.order_id, state = execution.state,
        transactionId = execution.payment_transaction_id,
        amount = tonumber(execution.amount), currency = execution.currency_code, replayed = replayed })
end
local function Coordinate(order, source, checkpoint, recovery)
    local session = not recovery and exports['feather-core']:GetSessionContext(source) or nil
    if not recovery and (type(session) ~= 'table' or not session.ok or session.value.characterId ~= order.buyer_character_id
        or session.value.accountId ~= order.buyer_account_id) then
        return Err('session_expired', 'Current session belonging to order buyer required.')
    end
    local function Current()
        if recovery then return true end
        return exports['feather-core']:IsSessionCurrent(source, session.value.sessionId, session.value.characterId) == true
    end
    local execution = Execution(order.order_id)
    if not Current() then return Err('session_expired', 'Buyer session changed.') end
    if execution and execution.state == 'fulfilled' then return Receipt(execution, true) end
    if execution and execution.state == 'rejected' then
        return Err(execution.last_error or 'purchase_rejected', 'This order was rejected.', { orderId = order.order_id })
    end
    local compensation = DB.one('SELECT `state` FROM `shop_order_compensations` WHERE `order_id`=?', order.order_id)
    if compensation and compensation.state ~= 'delivery_committed' then
        return Err('order_compensating', 'Delivery is blocked by durable compensation intent.', { orderId = order.order_id })
    end
    if not execution then
        if recovery then return Err('recovery_not_allowed', 'Recovery cannot create payment intent.') end
        -- First acceptance requires the original, still-current quote. Once
        -- intent exists, recovery replays it even if that temporary quote is gone.
        local validated = ShopQuotes.Validate(order.quote_id, source)
        if not validated.ok then return validated end
        if validated.value.sessionId ~= order.buyer_session_id then
            return Err('session_expired', 'Original order session is no longer current.')
        end
        local wallet = Wallet(order.buyer_character_id, order.currency_code)
        if type(wallet) ~= 'table' or not wallet.ok then return wallet or Err('dependency_unavailable', 'Wallet lookup failed.') end
        local sink = ShopOrganizations.Settlement(order.shop_id, order.currency_code)
        if type(sink) ~= 'table' or not sink.ok then return sink or Err('dependency_unavailable', 'Settlement lookup failed.') end
        if not Current() then return Err('session_expired', 'Buyer session changed.') end
        validated = ShopQuotes.Validate(order.quote_id, source)
        if not validated.ok then return validated end
        DB.insert([[INSERT IGNORE INTO `shop_order_executions`
            (`order_id`,`from_account_id`,`to_account_id`,`currency_code`,`amount`) VALUES (?,?,?,?,?)]],
            order.order_id, wallet.value.accountId, sink.value.accountId, order.currency_code, tonumber(order.total_amount))
        execution = Execution(order.order_id)
        if not execution then return Err('internal_error', 'Payment intent could not be stored.') end
    end
    if not Current() then return Err('session_expired', 'Buyer session changed; intent remains recoverable.') end
    if execution.state == 'payment_pending' then
        local paid = exports['feather-economy']:Transfer({
            fromAccountId = execution.from_account_id, toAccountId = execution.to_account_id,
            currency = execution.currency_code, amount = tonumber(execution.amount),
            reasonCode = 'shop.purchase', referenceType = 'shop_order', referenceId = order.order_id,
            idempotencyKey = 'shop-payment:' .. order.order_id
        }, { actorSource = source, actorAccountId = order.buyer_account_id,
            actorCharacterId = order.buyer_character_id, correlationId = order.order_id })
        if type(paid) ~= 'table' or not paid.ok then
            local code = type(paid) == 'table' and paid.code or 'dependency_unavailable'
            -- Only definitive insufficient funds is terminal. Uncertain errors
            -- leave the durable intent for retry with the original payment key.
            DB.exec([[UPDATE `shop_order_executions` SET `last_error`=?,`state`=?
                WHERE `order_id`=? AND `state`='payment_pending']],
                code, code == 'insufficient_funds' and 'rejected' or 'payment_pending', order.order_id)
            return Err(code, 'Payment did not complete.', { orderId = order.order_id })
        end
        if Config.DevMode and checkpoint == 'after_payment' then
            return Err('test_interrupted', 'Payment committed; restart and retry the same order.', { orderId = order.order_id })
        end
        DB.exec([[UPDATE `shop_order_executions` SET `state`='paid',
            `payment_transaction_id`=?,`last_error`=NULL WHERE `order_id`=? AND `state`='payment_pending']],
            paid.value.transactionId, order.order_id)
        execution = Execution(order.order_id)
    end
    if execution.state == 'paid' then
        if Config.DevMode and checkpoint == 'before_grant' then
            return Err('test_interrupted', 'Payment recorded; delivery deliberately not attempted.', { orderId = order.order_id })
        end
        -- Committed payment fixes buyer identity. Inventory delivery does not
        -- retarget to whichever Character a recycled player source now holds.
        local granted = exports['feather-inventory']:GrantCharacterItemOnce({
            grantId = 'shop-fulfillment:' .. order.order_id, characterId = order.buyer_character_id,
            itemName = order.item_name, definitionId = tonumber(order.definition_id), quantity = tonumber(order.quantity) })
        if type(granted) ~= 'table' or not granted.ok then
            local code = type(granted) == 'table' and granted.error and granted.error.code or 'dependency_unavailable'
            DB.exec("UPDATE `shop_order_executions` SET `last_error`=? WHERE `order_id`=? AND `state`='paid'",
                code, order.order_id)
            return Err('fulfillment_pending', 'Payment committed; fulfillment needs retry or compensation.',
                { orderId = order.order_id, cause = code })
        end
        if Config.DevMode and checkpoint == 'after_grant' then
            return Err('test_interrupted', 'Grant committed; restart and retry the same order.', { orderId = order.order_id })
        end
        DB.exec([[UPDATE `shop_order_executions` SET `state`='fulfilled',
            `fulfillment_json`=?,`last_error`=NULL WHERE `order_id`=? AND `state`='paid']],
            json.encode(granted.value), order.order_id)
        execution = Execution(order.order_id)
    end
    if execution.state ~= 'fulfilled' then return Err('purchase_pending', 'Order is incomplete.', { orderId = order.order_id }) end
    return Receipt(execution, false)
end
local function Purchase(orderId, source, checkpoint, recovery)
    if not ShopService.IsReady() then return Err('not_ready', 'Shops not ready.') end
    if not ShopService.Uuid(orderId) or (not recovery and not ShopService.Integer(source, 1, 65535)) then
        return Err('invalid_input', 'Order UUID and active buyer source required.')
    end
    if active[orderId] then return Err('transaction_conflict', 'This order is already running.') end
    active[orderId] = true
    local called, result = xpcall(function()
        local order = DB.one("SELECT * FROM `shop_orders` WHERE `order_id`=? AND `source_resource`='feather-shops'", orderId)
        if not order then return Err('order_not_found', 'Order not found.') end
        return Coordinate(order, source, checkpoint, recovery)
    end, debug.traceback)
    active[orderId] = nil
    if not called then
        print('[feather-shops] event=purchase.failed ' .. tostring(result))
        return Err('purchase_pending', 'Purchase response uncertain; retry the same order.', { orderId = orderId })
    end
    return result
end
-- Internal only until compensation acceptance passes; no payment export/RPC.
ShopPurchases.Purchase = function(orderId, source, checkpoint) return Purchase(orderId, source, checkpoint, false) end
ShopPurchases.RecoverPurchase = function(orderId) return Purchase(orderId, nil, nil, true) end

-- Internal operator workflow only. The same runtime mutex guards delivery and
-- compensation; Inventory's durable row lock is the final cross-restart fence.
local function Compensate(orderId, source, checkpoint, recovery)
    if not ShopService.IsReady() then return Err('not_ready', 'Shops not ready.') end
    if not ShopService.Uuid(orderId) or (not recovery and not ShopService.Integer(source, 1, 65535)) then
        return Err('invalid_input', 'Order UUID and buyer source required.')
    end
    if active[orderId] then return Err('transaction_conflict', 'This order is already running.') end
    active[orderId] = true
    local called, result = xpcall(function()
        local order = DB.one("SELECT * FROM `shop_orders` WHERE `order_id`=? AND `source_resource`='feather-shops'", orderId)
        local session = not recovery and exports['feather-core']:GetSessionContext(source) or nil
        if not order or (not recovery and (type(session) ~= 'table' or not session.ok or session.value.characterId ~= order.buyer_character_id
            or session.value.accountId ~= order.buyer_account_id)) then
            return Err('session_expired', 'Current original buyer required.')
        end
        local execution = Execution(orderId)
        if not execution or execution.state ~= 'paid' or not execution.payment_transaction_id then
            return Err('compensation_not_allowed', 'Only a recorded paid, incomplete delivery is eligible.')
        end
        if not recovery and not exports['feather-core']:IsSessionCurrent(source, session.value.sessionId, session.value.characterId) then
            return Err('session_expired', 'Buyer session changed.')
        end
        if recovery then
            if not DB.one('SELECT `order_id` FROM `shop_order_compensations` WHERE `order_id`=?', orderId) then
                return Err('recovery_not_allowed', 'Recovery cannot request compensation.')
            end
        else
            DB.insert('INSERT IGNORE INTO `shop_order_compensations` (`order_id`) VALUES (?)', orderId)
        end
        local row = DB.one('SELECT * FROM `shop_order_compensations` WHERE `order_id`=?', orderId)
        if row.state == 'refunded' then return Ok({ orderId = orderId, state = row.state,
            transactionId = row.refund_transaction_id, replayed = true }) end
        if row.state == 'delivery_committed' then return Err('grant_already_delivered', 'Committed delivery cannot be refunded.') end
        if row.state == 'cancellation_pending' then
            local cancelled = exports['feather-inventory']:CancelCharacterItemGrant({
                grantId = 'shop-fulfillment:' .. orderId, characterId = order.buyer_character_id,
                itemName = order.item_name, definitionId = tonumber(order.definition_id), quantity = tonumber(order.quantity) })
            if type(cancelled) ~= 'table' or not cancelled.ok then
                local code = type(cancelled) == 'table' and cancelled.error and cancelled.error.code or 'dependency_unavailable'
                DB.exec([[UPDATE `shop_order_compensations` SET `last_error`=?,`state`=?
                    WHERE `order_id`=? AND `state`='cancellation_pending']],
                    code, code == 'grant_already_delivered' and 'delivery_committed' or 'cancellation_pending', orderId)
                return Err(code, 'Cancellation did not complete; no refund attempted.')
            end
            if cancelled.value.cancelled ~= true or cancelled.value.delivered ~= false then
                return Err('dependency_invalid', 'No durable no-delivery proof; refund blocked.')
            end
            DB.exec([[UPDATE `shop_order_compensations` SET `state`='refund_pending',
                `cancellation_json`=?,`last_error`=NULL WHERE `order_id`=? AND `state`='cancellation_pending']],
                json.encode(cancelled.value), orderId)
        end
        -- Reconfirm the terminal Inventory fence on every pending refund retry.
        -- A local state label or damaged JSON is not sufficient delivery proof.
        local proof = exports['feather-inventory']:CancelCharacterItemGrant({
            grantId = 'shop-fulfillment:' .. orderId, characterId = order.buyer_character_id,
            itemName = order.item_name, definitionId = tonumber(order.definition_id), quantity = tonumber(order.quantity) })
        if type(proof) ~= 'table' or not proof.ok or type(proof.value) ~= 'table'
            or proof.value.cancelled ~= true or proof.value.delivered ~= false then
            local code = type(proof) == 'table' and proof.error and proof.error.code or 'dependency_invalid'
            DB.exec("UPDATE `shop_order_compensations` SET `last_error`=? WHERE `order_id`=? AND `state`='refund_pending'", code, orderId)
            return Err('refund_pending', 'Durable cancellation proof unavailable; refund blocked.', { cause = code })
        end
        local refund = exports['feather-economy']:ReversePayment({ transactionId = execution.payment_transaction_id },
            { actorSource = source, actorAccountId = order.buyer_account_id,
                actorCharacterId = order.buyer_character_id, correlationId = orderId })
        if type(refund) ~= 'table' or not refund.ok then
            local code = type(refund) == 'table' and refund.code or 'dependency_unavailable'
            DB.exec("UPDATE `shop_order_compensations` SET `last_error`=? WHERE `order_id`=? AND `state`='refund_pending'", code, orderId)
            return Err('refund_pending', 'Delivery cancelled; retry the same refund.', { cause = code })
        end
        if Config.DevMode and checkpoint == 'after_refund' then
            return Err('test_interrupted', 'Refund committed; acknowledgement deliberately interrupted.')
        end
        DB.exec([[UPDATE `shop_order_compensations` SET `state`='refunded',
            `refund_transaction_id`=?,`last_error`=NULL WHERE `order_id`=? AND `state`='refund_pending']],
            refund.value.transactionId, orderId)
        return Ok({ orderId = orderId, state = 'refunded', transactionId = refund.value.transactionId, replayed = refund.value.replayed })
    end, debug.traceback)
    active[orderId] = nil
    if not called then
        print('[feather-shops] event=compensation.failed ' .. tostring(result))
        return Err('compensation_pending', 'Response uncertain; retry the same order.')
    end
    return result
end
ShopPurchases.Compensate = function(orderId, source, checkpoint) return Compensate(orderId, source, checkpoint, false) end
ShopPurchases.RecoverCompensation = function(orderId) return Compensate(orderId, nil, nil, true) end

if Config.DevMode then
    RegisterCommand('ShopPurchaseInsufficientTest', function(source, args)
        if source ~= 0 then return end
        local target, requestId = tonumber(args[1]), args[2]
        if not target or type(requestId) ~= 'string' or #requestId > 128
            or not requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
            print('[ShopPurchaseInsufficientTest] usage: ShopPurchaseInsufficientTest <source near shop> <fresh requestId>'); return
        end
        if not ShopService.IsReady() then print('[ShopPurchaseInsufficientTest] FAIL service not ready'); return end
        if DB.one("SELECT `order_id` FROM `shop_orders` WHERE `source_resource`='feather-shops' AND `request_id`=?", requestId) then
            print('[ShopPurchaseInsufficientTest] FAIL fresh request ID required'); return
        end
        local session = exports['feather-core']:GetSessionContext(target)
        if not session.ok then print('[ShopPurchaseInsufficientTest] FAIL active session required'); return end
        local shop, offer = Config.Shops[1], Config.Shops[1].offers[1]
        local wallet = Wallet(session.value.characterId, offer.currency)
        if not wallet or not wallet.ok or wallet.value.balance >= offer.unitPrice * 2 then
            print('[ShopPurchaseInsufficientTest] FAIL test requires wallet below purchase price; no purchase attempted'); return
        end
        local sink = ShopOrganizations.Settlement(shop.id, offer.currency)
        if not sink.ok then print('[ShopPurchaseInsufficientTest] FAIL settlement unavailable'); return end
        local quoted = ShopQuotes.Create({ shopId = shop.id, offerId = offer.id, quantity = 2 }, target)
        if not quoted.ok then print('[ShopPurchaseInsufficientTest] FAIL quote=' .. quoted.code); return end
        local order = ShopOrders.Prepare({ quoteId = quoted.value.id, requestId = requestId }, target, 'feather-shops')
        if not order.ok then print('[ShopPurchaseInsufficientTest] FAIL order=' .. order.code); return end
        local result = Purchase(order.value.id, target)
        local retried = Purchase(order.value.id, target)
        local after = exports['feather-economy']:GetAccount({ accountId = wallet.value.accountId })
        local sinkAfter = exports['feather-economy']:GetAccount({ accountId = sink.value.accountId })
        local execution = Execution(order.value.id)
        local unchanged = after.ok and sinkAfter.ok and after.value.balance == wallet.value.balance
            and sinkAfter.value.balance == sink.value.balance
        local passed = not result.ok and result.code == 'insufficient_funds'
            and not retried.ok and retried.code == 'insufficient_funds' and unchanged
            and execution and execution.state == 'rejected'
            and execution.payment_transaction_id == nil and execution.fulfillment_json == nil
        print(('[ShopPurchaseInsufficientTest] %s order=%s state=%s balancesUnchanged=%s retryRejected=%s (no items granted)'):format(
            passed and 'PASS' or 'FAIL', order.value.id, tostring(execution and execution.state),
            tostring(unchanged), tostring(not retried.ok and retried.code == 'insufficient_funds')))
    end, true)
end
RegisterCommand('ShopPurchaseState', function(source, args)
    if source ~= 0 then return end
    if not ShopService.IsReady() or not ShopService.Uuid(args[1]) then
        print('[ShopPurchaseState] usage: ShopPurchaseState <order UUID>'); return
    end
    local execution = Execution(args[1])
    print('[ShopPurchaseState] ' .. json.encode(execution or { state = 'not_started' }))
end, true)
