local Ok, Err, Copy = ShopService.Ok, ShopService.Err, ShopService.Copy
ShopOrders = {}
local schema = [[CREATE TABLE IF NOT EXISTS `shop_orders` (
    `order_id` CHAR(36) NOT NULL,
    `source_resource` VARCHAR(100) NOT NULL,
    `request_id` VARCHAR(128) NOT NULL,
    `quote_id` CHAR(36) NOT NULL,
    `buyer_account_id` CHAR(36) NOT NULL,
    `buyer_character_id` CHAR(36) NOT NULL,
    `buyer_session_id` CHAR(36) NOT NULL,
    `shop_id` CHAR(36) NOT NULL,
    `offer_id` CHAR(36) NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `definition_id` BIGINT UNSIGNED NOT NULL,
    `quantity` INT UNSIGNED NOT NULL,
    `currency_code` VARCHAR(32) NOT NULL,
    `unit_price` BIGINT UNSIGNED NOT NULL,
    `total_amount` BIGINT UNSIGNED NOT NULL,
    `catalog_revision` VARCHAR(64) NOT NULL,
    `status` VARCHAR(32) NOT NULL DEFAULT 'prepared',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`order_id`),
    UNIQUE KEY `uq_shop_order_request` (`source_resource`,`request_id`),
    KEY `idx_shop_order_buyer` (`buyer_character_id`,`created_at`),
    CONSTRAINT `fk_shop_order_offer` FOREIGN KEY (`offer_id`) REFERENCES `shop_offers` (`offer_id`),
    CONSTRAINT `chk_shop_order_quantity` CHECK (`quantity` BETWEEN 1 AND 100),
    CONSTRAINT `chk_shop_order_total` CHECK (`unit_price` > 0 AND `total_amount` = `unit_price` * `quantity`),
    CONSTRAINT `chk_shop_order_status` CHECK (`status` = 'prepared')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]

function ShopOrders.Start()
    local hash = 2166136261
    for index = 1, #schema do hash = ((hash ~ schema:byte(index)) * 16777619) & 0xffffffff end
    local checksum = ('fnv1a32:%08x'):format(hash)
    local stored = DB.value(
        'SELECT `checksum` FROM `shop_schema_migrations` WHERE `id`=?', '002_shop_orders')
    if stored and stored ~= checksum then
        return Err('migration_checksum_mismatch', 'Applied shop order migration has changed.')
    end
    if not stored then
        DB.exec(schema)
        DB.insert('INSERT INTO `shop_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
            '002_shop_orders', checksum)
    end
    return Ok({ applied = stored and 0 or 1 })
end
local function RequestId(value)
    return type(value) == 'string' and #value <= 128
        and value:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end
local function Snapshot(row, replayed)
    return { id = row.order_id, requestId = row.request_id, quoteId = row.quote_id,
        characterId = row.buyer_character_id, accountId = row.buyer_account_id,
        sessionId = row.buyer_session_id, shopId = row.shop_id, offerId = row.offer_id,
        itemName = row.item_name, definitionId = tonumber(row.definition_id),
        quantity = tonumber(row.quantity), currency = row.currency_code,
        unitPrice = tonumber(row.unit_price), total = tonumber(row.total_amount),
        catalogRevision = row.catalog_revision, status = row.status, replayed = replayed }
end
local function Replay(row, request, session)
    if row.quote_id ~= request.quoteId or row.buyer_character_id ~= session.characterId
        or row.buyer_account_id ~= session.accountId then
        return Err('idempotency_conflict', 'Request ID is bound to a different quote or buyer.')
    end
    return Ok(Snapshot(row, true))
end
local function Find(resource, requestId)
    return DB.one([[SELECT * FROM `shop_orders`
        WHERE `source_resource`=? AND `request_id`=?]], resource, requestId)
end
local function Prepare(request, source, resource)
    if Config.Quotes.trustedCallers[resource or ''] ~= true then
        return Err('authorization_denied', 'Order caller is not trusted.')
    end
    if not ShopService.IsReady() then return Err('not_ready', 'Shops is not ready.') end
    if type(request) ~= 'table' or not RequestId(request.requestId)
        or not ShopService.Uuid(request.quoteId) or not ShopService.Integer(source, 1, 65535) then
        return Err('invalid_input', 'Stable request ID, quote UUID, and active source required.')
    end
    for key in pairs(request) do
        if key ~= 'requestId' and key ~= 'quoteId' then
            return Err('invalid_input', 'Order requests accept only requestId and quoteId.')
        end
    end
    local session = exports['feather-core']:GetSessionContext(source)
    if type(session) ~= 'table' or not session.ok then
        return Err('session_expired', 'Active buyer session required.')
    end
    local function Current()
        return exports['feather-core']:IsSessionCurrent(source,
            session.value.sessionId, session.value.characterId) == true
    end
    local existing = Find(resource, request.requestId)
    if not Current() then return Err('session_expired', 'Buyer session changed.') end
    -- Replay is a receipt lookup, not permission to pay/fulfill a stale quote.
    if existing then return Replay(existing, request, session.value) end
    local validated = ShopQuotes.Validate(request.quoteId, source)
    if not validated.ok then return validated end
    local quote = validated.value
    local orderId = DB.value('SELECT UUID()')
    if not ShopService.Uuid(orderId) then return Err('internal_error', 'Could not allocate order identity.') end
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        if not Current() or quote.sessionId ~= session.value.sessionId
            or quote.expiresAt <= os.time() then
            result = Err('session_expired', 'Quote or buyer session expired.')
            return false
        end
        tx.exec([[INSERT IGNORE INTO `shop_orders`
            (`order_id`,`source_resource`,`request_id`,`quote_id`,`buyer_account_id`,
             `buyer_character_id`,`buyer_session_id`,`shop_id`,`offer_id`,`item_name`,
             `definition_id`,`quantity`,`currency_code`,`unit_price`,`total_amount`,`catalog_revision`)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)]],
            orderId, resource, request.requestId, quote.id, quote.accountId, quote.characterId,
                quote.sessionId, quote.shopId, quote.offerId, quote.itemName, quote.definitionId,
                quote.quantity, quote.currency, quote.unitPrice, quote.total, quote.catalogRevision)
        local rows = tx.query([[SELECT * FROM `shop_orders` WHERE `source_resource`=?
            AND `request_id`=? FOR UPDATE]], resource, request.requestId) or {}
        local row = rows[1]
        if not row then result = Err('internal_error', 'Order could not be reserved.'); return false end
        if not Current() then result = Err('session_expired', 'Buyer session changed.'); return false end
        result = Replay(row, request, session.value)
        if result.ok then
            -- Another concurrent prepare may have inserted this same receipt.
            result.value.replayed = row.order_id ~= orderId
        end
        return result.ok
    end)
    if not called or committed ~= true then
        if type(result) == 'table' and result.ok == false then return result end
        return Err('internal_error', 'Order transaction did not confirm commit.')
    end
    return result
end
exports('PrepareOrder', function(request, source)
    return Prepare(request, source, GetInvokingResource())
end)
ShopOrders.Prepare = Prepare

ShopService.RegisterDevCommand('ShopOrderContractSmokeTest', function(source)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopOrderContractSmokeTest] FAIL service not ready'); return end
    local unauthorized = Prepare({}, 1, 'untrusted-test-resource')
    local invalid = Prepare({}, 1, 'feather-shops')
    local invalidStates = tonumber(DB.value(
        "SELECT COUNT(*) FROM `shop_orders` WHERE `status` <> 'prepared'"))
    local invalidTotals = tonumber(DB.value(
        'SELECT COUNT(*) FROM `shop_orders` WHERE `total_amount` <> `unit_price` * `quantity`'))
    local tests = {
        { 'untrusted caller rejected', not unauthorized.ok and unauthorized.code == 'authorization_denied' },
        { 'incomplete request rejected', not invalid.ok and invalid.code == 'invalid_input' },
        { 'stable request id required', not RequestId('') },
        { 'oversized id rejected', not RequestId(string.rep('a', 129)) },
        { 'malformed id rejected', not RequestId('bad request') },
        { 'order states valid', invalidStates == 0 },
        { 'order totals valid', invalidTotals == 0 }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ShopOrderContractSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ShopOrderContractSmokeTest] done %d/%d passed (no funds moved)'):format(passed, #tests))
end, true)
ShopService.RegisterDevCommand('ShopOrderPersistenceTest', function(source, args)
    if source ~= 0 then return end
    local target, requestId, operation = tonumber(args[1]), args[2], args[3]
    if not target or not RequestId(requestId) or (operation ~= 'prepare' and operation ~= 'retry') then
        print('[ShopOrderPersistenceTest] usage: ShopOrderPersistenceTest <source> <requestId> prepare|retry'); return
    end
    if not ShopService.IsReady() then print('[ShopOrderPersistenceTest] FAIL service not ready'); return end
    local row = Find('feather-shops', requestId)
    if operation == 'prepare' and row then
        print('[ShopOrderPersistenceTest] FAIL fresh request ID required'); return
    end
    if operation == 'retry' and not row then
        print('[ShopOrderPersistenceTest] FAIL prepared order missing'); return
    end
    local quoteId = row and row.quote_id
    if not quoteId then
        local shop = Config.Shops[1]
        local quoted = ShopQuotes.Create({ shopId = shop.id,
            offerId = shop.offers[1].id, quantity = 2 }, target)
        if not quoted.ok then
            print('[ShopOrderPersistenceTest] FAIL quote code=' .. quoted.code); return
        end
        quoteId = quoted.value.id
    end
    local request = { requestId = requestId, quoteId = quoteId }
    local first = Prepare(request, target, 'feather-shops')
    local replayed = first.ok and Prepare(request, target, 'feather-shops') or first
    local mismatch = Prepare({ requestId = requestId,
        quoteId = 'ffffffff-ffff-4fff-8fff-ffffffffffff' }, target, 'feather-shops')
    local count = tonumber(DB.value([[SELECT COUNT(*) FROM `shop_orders`
        WHERE `source_resource`='feather-shops' AND `request_id`=?]], requestId))
    local passed = first.ok and replayed.ok and replayed.value.replayed
        and replayed.value.id == first.value.id and first.value.status == 'prepared'
        and not mismatch.ok and mismatch.code == 'idempotency_conflict' and count == 1
    print(('[ShopOrderPersistenceTest] %s order=%s status=%s replayed=%s mismatchRejected=%s count=%s (no funds moved)'):format(
        passed and 'PASS' or 'FAIL', tostring(first.ok and first.value.id),
        tostring(first.ok and first.value.status), tostring(replayed.ok and replayed.value.replayed),
        tostring(not mismatch.ok and mismatch.code == 'idempotency_conflict'), tostring(count)))
end, true)
