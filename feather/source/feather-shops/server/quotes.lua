local Ok, Err, Copy = ShopService.Ok, ShopService.Err, ShopService.Copy
local quotes = {}
local function IsCallable(value)
    return type(value) == 'function' or (type(value) == 'table'
        and type(rawget(value, '__cfx_functionReference')) == 'string')
end

-- Revision describes all material quote/catalog fields in a fixed order.
local function Revision(shop, offer)
    local material = table.concat({ shop.id, tostring(shop.organizationId), tostring(shop.position.x),
        tostring(shop.position.y), tostring(shop.position.z), offer.id,
        offer.itemName, offer.currency, tostring(offer.unitPrice),
        tostring(offer.maximumQuantity) }, '|')
    local hash = 2166136261
    for index = 1, #material do hash = ((hash ~ material:byte(index)) * 16777619) & 0xffffffff end
    return ('catalog:%08x'):format(hash)
end
local function Terms(request)
    if type(request) ~= 'table' or not ShopService.Uuid(request.shopId)
        or not ShopService.Uuid(request.offerId)
        or not ShopService.Integer(request.quantity, 1, 100) then
        return Err('invalid_input', 'Shop, offer, and whole-number quantity are required.')
    end
    for key in pairs(request) do
        if key ~= 'shopId' and key ~= 'offerId' and key ~= 'quantity' then
            return Err('invalid_input', 'Quote requests may not supply prices or buyer identity.')
        end
    end
    local found = ShopService.GetCatalog(request.shopId)
    if not found.ok then return found end
    local shop, offer = found.value
    for _, candidate in ipairs(shop.offers) do
        if candidate.id == request.offerId then offer = candidate; break end
    end
    if not offer then return Err('offer_not_found', 'Offer does not belong to this shop.') end
    if request.quantity > offer.maximumQuantity then
        return Err('invalid_quantity', 'Offer quantity limit exceeded.')
    end
    return Ok({ shop = shop, offer = offer, quantity = request.quantity,
        total = offer.unitPrice * request.quantity, revision = Revision(shop, offer) })
end

local function Definition(itemName)
    local called, listed = pcall(function()
        local api = exports['feather-inventory']:initiate()
        if type(api) ~= 'table' or type(api.Items) ~= 'table'
            or not IsCallable(api.Items.GetDefinitions) then return nil end
        return api.Items.GetDefinitions()
    end)
    if not called or type(listed) ~= 'table' or not listed.ok or type(listed.value) ~= 'table' then
        return Err('dependency_unavailable', 'Inventory definitions are unavailable.')
    end
    for _, definition in pairs(listed.value) do
        if definition.name == itemName then
            if definition.archived_at ~= nil or definition.type == 'weapon'
                or (definition.instanceMode or definition.instance_mode) ~= 'stack' then
                return Err('item_unavailable', 'This offer requires an active ordinary stack item.')
            end
            return Ok({ id = definition.id, name = definition.name })
        end
    end
    return Err('item_unavailable', 'Offer item is not in the active Inventory catalog.')
end
local function Near(source, shop)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return Err('player_unavailable', 'Player ped is unavailable.')
    end
    local position = GetEntityCoords(ped)
    local dx, dy, dz = position.x - shop.position.x,
        position.y - shop.position.y, position.z - shop.position.z
    if dx * dx + dy * dy + dz * dz > Config.Quotes.maximumDistance ^ 2 then
        return Err('out_of_range', 'Move closer to the shop.')
    end
    return Ok(true)
end
local function BindingCurrent(source, quote)
    return exports['feather-core']:IsSessionCurrent(source, quote.sessionId, quote.characterId) == true
end

local function CreateQuote(request, source)
    if not ShopService.IsReady() then return Err('not_ready', 'Shops is not ready.') end
    if not ShopService.Integer(source, 1, 65535) then return Err('invalid_input', 'Active player source required.') end
    local terms = Terms(request)
    if not terms.ok then return terms end
    local commerce=ShopOrganizations.CheckCommerce(request.shopId)
    if not commerce.ok then return commerce end
    local session = exports['feather-core']:GetSessionContext(source)
    if type(session) ~= 'table' or not session.ok then
        return Err('session_expired', 'Active character session required.')
    end
    local definition = Definition(terms.value.offer.itemName)
    if not definition.ok then return definition end
    local currency = exports['feather-economy']:GetCurrency(terms.value.offer.currency)
    if type(currency) ~= 'table' or not currency.ok or not currency.value.enabled then
        return Err('currency_unavailable', 'Offer currency is unavailable.')
    end
    local quote = { id = DB.value('SELECT UUID()'), source = source,
        sessionId = session.value.sessionId, characterId = session.value.characterId,
        accountId = session.value.accountId, shopId = request.shopId, offerId = request.offerId,
        itemName = terms.value.offer.itemName, definitionId = definition.value.id,
        quantity = request.quantity, currency = terms.value.offer.currency,
        unitPrice = terms.value.offer.unitPrice, total = terms.value.total,
        catalogRevision = terms.value.revision, expiresAt = os.time() + Config.Quotes.lifetimeSeconds }
    -- Definition and UUID lookups may yield: re-check identity and position last.
    if not BindingCurrent(source, quote) then return Err('session_expired', 'Buyer session changed.') end
    local nearby = Near(source, terms.value.shop)
    if not nearby.ok then return nearby end
    if not ShopService.Uuid(quote.id) then return Err('internal_error', 'Could not allocate quote identity.') end
    commerce=ShopOrganizations.CheckCommerce(request.shopId)
    if not commerce.ok then return commerce end
    if not BindingCurrent(source,quote) then return Err('session_expired','Buyer session changed.') end
    quotes[source] = quote -- one outstanding quote per source; replaces previous quote
    return Ok(Copy(quote))
end
local function ValidateQuote(quoteId, source)
    if not ShopService.IsReady() then return Err('not_ready', 'Shops is not ready.') end
    if not ShopService.Uuid(quoteId) or not ShopService.Integer(source, 1, 65535) then
        return Err('invalid_input', 'Quote UUID and active player source required.')
    end
    local quote = quotes[source]
    if not quote or quote.id ~= quoteId then return Err('quote_not_found', 'Quote is not current for this buyer.') end
    if quote.expiresAt <= os.time() then quotes[source] = nil; return Err('quote_expired', 'Quote expired.') end
    if not BindingCurrent(source, quote) then quotes[source] = nil; return Err('session_expired', 'Buyer session changed.') end
    local terms = Terms({ shopId = quote.shopId, offerId = quote.offerId, quantity = quote.quantity })
    if not terms.ok or terms.value.revision ~= quote.catalogRevision then
        quotes[source] = nil
        return Err('catalog_changed', 'Quoted offer has changed.')
    end
    local definition = Definition(quote.itemName)
    if not definition.ok then return definition end
    if definition.value.id ~= quote.definitionId then return Err('catalog_changed', 'Item definition changed.') end
    local currency = exports['feather-economy']:GetCurrency(quote.currency)
    if type(currency) ~= 'table' or not currency.ok or not currency.value.enabled then
        return Err('currency_unavailable', 'Quoted currency is unavailable.')
    end
    if not BindingCurrent(source, quote) then return Err('session_expired', 'Buyer session changed.') end
    if quotes[source] ~= quote then return Err('quote_not_found', 'Quote was replaced while validating.') end
    local nearby = Near(source, terms.value.shop)
    if not nearby.ok then return nearby end
    if quote.expiresAt <= os.time() then return Err('quote_expired', 'Quote expired.') end
    local commerce=ShopOrganizations.CheckCommerce(quote.shopId)
    if not commerce.ok then return commerce end
    if not BindingCurrent(source,quote) then return Err('session_expired','Buyer session changed.') end
    if quotes[source]~=quote then return Err('quote_not_found','Quote was replaced while validating.') end
    return Ok(Copy(quote))
end
local function Allowed()
    return Config.Quotes.trustedCallers[GetInvokingResource() or ''] == true
end
ShopQuotes = { Create = CreateQuote, Validate = ValidateQuote }
exports('CreateQuote', function(request, source)
    if not Allowed() then return Err('authorization_denied', 'Quote caller is not trusted.') end
    return CreateQuote(request, source)
end)
exports('ValidateQuote', function(quoteId, source)
    if not Allowed() then return Err('authorization_denied', 'Quote caller is not trusted.') end
    return ValidateQuote(quoteId, source)
end)
AddEventHandler('playerDropped', function() quotes[source] = nil end)
CreateThread(function()
    while true do
        Wait(30000)
        for source, quote in pairs(quotes) do
            if quote.expiresAt <= os.time() then quotes[source] = nil end
        end
    end
end)

ShopService.RegisterDevCommand('ShopQuoteContractSmokeTest', function(source)
    if source ~= 0 then return end
    if not ShopService.IsReady() then print('[ShopQuoteContractSmokeTest] FAIL service not ready'); return end
    local shop = Config.Shops[1]
    local offer = shop and shop.offers[1]
    if not offer then print('[ShopQuoteContractSmokeTest] FAIL test offer required'); return end
    local base = { shopId = shop.id, offerId = offer.id, quantity = 2 }
    local valid = Terms(base)
    local tests = { { 'authoritative total', valid.ok and valid.value.total == offer.unitPrice * 2 },
        { 'inventory definition valid', Definition(offer.itemName).ok } }
    for _, quantity in ipairs({ 0, -1, 1.5, '2', offer.maximumQuantity + 1 }) do
        local request = Copy(base); request.quantity = quantity
        local rejected = Terms(request)
        tests[#tests + 1] = { 'quantity rejected ' .. tostring(quantity), not rejected.ok }
    end
    local tampered = Copy(base); tampered.total = 1; tampered.unitPrice = 1
    local rejected = Terms(tampered)
    tests[#tests + 1] = { 'price tampering rejected', not rejected.ok and rejected.code == 'invalid_input' }
    local unknown = Copy(base); unknown.offerId = 'ffffffff-ffff-4fff-8fff-ffffffffffff'
    rejected = Terms(unknown)
    tests[#tests + 1] = { 'unknown offer rejected', not rejected.ok and rejected.code == 'offer_not_found' }
    local changed = Copy(offer); changed.unitPrice = changed.unitPrice + 1
    tests[#tests + 1] = { 'revision binds price', Revision(shop, offer) ~= Revision(shop, changed) }
    tests[#tests + 1] = { 'stale session rejected', not BindingCurrent(65535,
        { sessionId = 'invalid', characterId = 'invalid' }) }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ShopQuoteContractSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ShopQuoteContractSmokeTest] done %d/%d passed (no funds moved)'):format(passed, #tests))
end, true)
ShopService.RegisterDevCommand('ShopQuoteLiveTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args[1])
    local shop = Config.Shops[1]
    if not target or not shop or not shop.offers[1] then
        print('[ShopQuoteLiveTest] usage: ShopQuoteLiveTest <active source near test shop>'); return
    end
    local created = CreateQuote({ shopId = shop.id, offerId = shop.offers[1].id, quantity = 2 }, target)
    if not created.ok then
        print(('[ShopQuoteLiveTest] FAIL code=%s message=%s'):format(created.code, created.message)); return
    end
    local validated = ValidateQuote(created.value.id, target)
    created.value.total = 1
    local isolated = ValidateQuote(created.value.id, target)
    local passed = validated.ok and isolated.ok and isolated.value.total == shop.offers[1].unitPrice * 2
    print(('[ShopQuoteLiveTest] %s quantity=2 total=%s sessionBound=true snapshotIsolated=%s (no funds moved)'):format(
        passed and 'PASS' or 'FAIL', tostring(validated.ok and validated.value.total), tostring(passed)))
end, true)
