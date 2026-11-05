local Ok, Err = ShopService.Ok, ShopService.Err
ShopPlayerRoutes = {}
local function Payload(request, fields)
    if type(request) ~= 'table' then return false end
    for key in pairs(request) do if not fields[key] then return false end end
    return true
end
local function QuotePayload(request)
    return Payload(request, { shopId = true, offerId = true, quantity = true })
        and ShopService.Uuid(request.shopId) and ShopService.Uuid(request.offerId)
        and ShopService.Integer(request.quantity, 1, 100)
end
local function PurchasePayload(request)
    return Payload(request, { quoteId = true, requestId = true })
        and ShopService.Uuid(request.quoteId) and type(request.requestId) == 'string'
        and #request.requestId <= 128
        and request.requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end
-- Explicit projection: never serialize server quotes, order snapshots, dependency
-- details, buyer identifiers, ledger accounts, or transaction IDs to clients.
local function PublicQuote(quote)
    return { id = quote.id, shopId = quote.shopId, offerId = quote.offerId,
        itemName = quote.itemName, quantity = quote.quantity, currency = quote.currency,
        unitPrice = quote.unitPrice, total = quote.total,
        catalogRevision = quote.catalogRevision, expiresAt = quote.expiresAt }
end
local function PublicError(result)
    return Err(type(result) == 'table' and result.code or 'dependency_unavailable',
        type(result) == 'table' and result.message or 'Shop service unavailable.')
end
local function Quote(request, source)
    if not QuotePayload(request) then return Err('invalid_input', 'Shop, offer, and integer quantity only.') end
    local result = ShopQuotes.Create(request, source)
    if not result.ok then return PublicError(result) end
    return Ok(PublicQuote(result.value))
end
local function UnpaidRejection(execution)
    return type(execution) == 'table' and execution.state == 'rejected'
        and execution.payment_transaction_id == nil and execution.fulfillment_json == nil
end
local function StaleQuote(result)
    return type(result) == 'table' and (result.code == 'quote_expired' or result.code == 'quote_not_found')
end
local function PurchaseInner(request, source)
    if not PurchasePayload(request) then return Err('invalid_input', 'Quote UUID and stable request ID only.') end
    local prepared = ShopOrders.Prepare(request, source, 'feather-shops')
    if not prepared.ok then
        local failure = PublicError(prepared)
        if StaleQuote(prepared) then
            -- Prepare replays existing receipts before inspecting ephemeral quotes.
            -- A stale-quote failure here means this key was not accepted.
            failure.message = 'Quote expired or was replaced. No payment was taken. Review a new price.'
            failure.details = { purchaseState = 'not_accepted', safeToClear = true }
        end
        return failure
    end
    local result = ShopPurchases.Purchase(prepared.value.id, source)
    if not result.ok then
        local failure = PublicError(result)
        -- A code/timeout/missing row alone cannot authorize dropping a retry.
        local execution = DB.one('SELECT `state`,`payment_transaction_id`,`fulfillment_json` FROM `shop_order_executions` WHERE `order_id`=?',
            prepared.value.id)
        if UnpaidRejection(execution) then
            failure.message = 'Purchase rejected. No payment was taken.'
            failure.details = { purchaseState = 'rejected', safeToClear = true }
        elseif execution == nil and StaleQuote(result) then
            failure.message = 'Quote expired or was replaced. No payment was taken. Review a new price.'
            failure.details = { purchaseState = 'not_accepted', safeToClear = true }
        end
        return failure
    end
    return Ok({ orderId = result.value.orderId, state = result.value.state,
        quantity = prepared.value.quantity, currency = prepared.value.currency,
        total = prepared.value.total, replayed = result.value.replayed })
end
local requestsRunning = {}
local function Purchase(request, source)
    if not PurchasePayload(request) then return Err('invalid_input', 'Quote UUID and stable request ID only.') end
    if requestsRunning[request.requestId] then return Err('transaction_conflict', 'This purchase request is already running.') end
    requestsRunning[request.requestId] = true
    local called, result = xpcall(function() return PurchaseInner(request, source) end, debug.traceback)
    requestsRunning[request.requestId] = nil
    if not called then
        print('[feather-shops] event=player.purchase_uncertain ' .. tostring(result))
        return Err('purchase_pending', 'Response uncertain. Retry the original purchase request.')
    end
    return result
end
function ShopPlayerRoutes.Start()
    for _, route in ipairs({
        { name = 'shops.wallets.v1', calls = 4,
            validate = function(request) return type(request) == 'table' and next(request) == nil end,
            handler = function(_, source)
                if not ShopService.IsReady() then return Err('not_ready', 'Shops is not ready.') end
                local session = exports['feather-core']:GetSessionContext(source)
                if type(session) ~= 'table' or not session.ok then return Err('session_expired', 'Active character required.') end
                local found = exports['feather-economy']:FindAccountsByOwner({ ownerType = 'character', ownerId = session.value.characterId })
                if type(found) ~= 'table' or not found.ok then return PublicError(found) end
                local wallets = {}
                for _, account in ipairs(found.value) do
                    if account.accountType == 'wallet' and account.status == 'open' then
                        local currency = exports['feather-economy']:GetCurrency(account.currency)
                        if type(currency) ~= 'table' or not currency.ok then return PublicError(currency) end
                        wallets[#wallets + 1] = { currency = account.currency, balance = account.balance,
                            precision = currency.value.precision, label = currency.value.label }
                    end
                end
                if not exports['feather-core']:IsSessionCurrent(source, session.value.sessionId, session.value.characterId) then
                    return Err('session_expired', 'Character session changed.')
                end
                table.sort(wallets, function(a, b) return a.currency < b.currency end)
                return Ok(wallets)
            end },
        { name = 'shops.catalog.v1', calls = 2, requireCharacter = false,
            validate = function(request) return type(request) == 'table' and next(request) == nil end,
            handler = function()
                local listed = ShopService.ListShops()
                if not listed.ok then return PublicError(listed) end
                local shops = {}
                for _, location in ipairs(listed.value) do
                    local found = ShopService.GetCatalog(location.id)
                    if not found.ok then return PublicError(found) end
                    shops[#shops + 1] = found.value
                end
                return Ok(shops)
            end },
        { name = 'shops.quote.v1', handler = Quote, validate = QuotePayload, calls = 4 },
        { name = 'shops.purchase.v1', handler = Purchase, validate = PurchasePayload, calls = 2 }
    }) do
        local registered = exports['feather-core']:RegisterRpc(route.name, route.handler, {
            contract = 1, direction = 'client_to_server', requireCharacter = route.requireCharacter ~= false,
            windowMs = 1000, maxCalls = route.calls, maxPayloadBytes = 512,
            maxDepth = 2, maxNodes = 8,
            validatePayload = function(request)
                return route.validate(request), 'Unexpected fields or invalid shop request.'
            end
        })
        if type(registered) ~= 'table' or not registered.ok then
            return Err('startup_failed', 'Could not register player shop route.', { route = route.name })
        end
    end
    return Ok(true)
end
ShopService.RegisterDevCommand('ShopPlayerRouteContractSmokeTest', function(source)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopPlayerRouteContractSmokeTest] FAIL service not ready'); return end
    local listed = exports['feather-core']:GetRpcRoutes()
    local routes = {}
    for _, route in ipairs(listed.ok and listed.value or {}) do routes[route.route] = route end
    local function Registered(name, requireCharacter)
        local route = routes[name]
        return route and route.owner == 'feather-shops' and route.contract == 1
            and route.direction == 'client_to_server' and route.requireCharacter == requireCharacter
    end
    local uuid = Config.Shops[1].id
    local base = { quoteId = uuid, requestId = 'route-contract' }
    local tampered = ShopService.Copy(base); tampered.source = 1
    local price = { shopId = uuid, offerId = Config.Shops[1].offers[1].id, quantity = 2, total = 1 }
    local public = PublicQuote({ id = uuid, characterId = 'secret', accountId = 'secret',
        sessionId = 'secret', source = 1, definitionId = 1 })
    local hidden = PublicError(Err('internal_error', 'Unavailable.', { accountId = 'secret' }))
    local tests = {
        { 'catalog available pre-character', Registered('shops.catalog.v1', false) },
        { 'quote route source-bound', Registered('shops.quote.v1', true) },
        { 'purchase route source-bound', Registered('shops.purchase.v1', true) },
        { 'identity injection rejected', not PurchasePayload(tampered) },
        { 'price injection rejected', not QuotePayload(price) },
        { 'valid purchase payload', PurchasePayload(base) },
        { 'public quote isolated', public.characterId == nil and public.accountId == nil and public.sessionId == nil
            and public.source == nil and public.definitionId == nil },
        { 'error details isolated', hidden.details == nil },
        { 'refund route absent', routes['shops.refund.v1'] == nil }
    }
    tests[#tests + 1] = { 'unpaid rejection clearable', UnpaidRejection({ state = 'rejected' }) }
    tests[#tests + 1] = { 'uncertain payment retained', not UnpaidRejection({ state = 'payment_pending' })
        and not UnpaidRejection(nil) and not UnpaidRejection({ state = 'rejected', payment_transaction_id = 'committed' }) }
    tests[#tests + 1] = { 'stale quote distinguished', StaleQuote(Err('quote_expired', 'Expired.'))
        and StaleQuote(Err('quote_not_found', 'Replaced.')) and not StaleQuote(Err('purchase_pending', 'Uncertain.')) }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ShopPlayerRouteContractSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ShopPlayerRouteContractSmokeTest] done %d/%d passed (no funds moved)'):format(passed, #tests))
end, true)
