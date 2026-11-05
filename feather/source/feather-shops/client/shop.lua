local Menu = exports['feather-menu-v2']
local shops, menuId, pageId, promptId = {}, nil, nil, nil
local opened, busy, generation, elementSequence = false, false, 0, 0
local groupId = joaat('feather-shops:interact')
local pendingKey = 'shops:ui:pending-purchase'
local pending
local saved = GetResourceKvpString(pendingKey)
if saved then
    local decoded, value = pcall(json.decode, saved)
    if decoded and type(value) == 'table' and type(value.quoteId) == 'string'
        and type(value.requestId) == 'string' then pending = value
    else pending = false; print('[feather-shops] Invalid saved purchase; new purchases blocked.') end
end
local function Require(result)
    if type(result) ~= 'table' or not result.ok then error(type(result) == 'table' and result.message or 'Provider unavailable.') end
    return result.value
end
local function Message(text)
    print('[feather-shops] ' .. tostring(text))
end
local function Call(route, request)
    return exports['feather-core']:CallRPCAsync(route, request, nil, 15000)
end
local function Async(work)
    if busy then return end
    busy = true
    CreateThread(function()
        local called, failure = xpcall(work, debug.traceback)
        busy = false
        if not called then Message(failure) end
    end)
end
local function Page(title)
    generation = generation + 1
    local previous = pageId
    pageId = Require(Menu:CreatePage(menuId, { key = 'shop-' .. generation })).pageId
    if previous then Require(Menu:DestroyPage(menuId, previous, pageId)) end
    Require(Menu:AddElement(menuId, pageId, 'header', { key = 'title', value = title, slot = 'header' }))
    return pageId
end
local function Add(page, kind, settings, callback)
    elementSequence = elementSequence + 1
    settings.key = 'element-' .. elementSequence
    return Require(Menu:AddElement(menuId, page, kind, settings, callback))
end
local function Show(page)
    Require(Menu:OpenMenu(menuId, { pageId = page, replace = false }))
end
local function AddBalances(page)
    local result = Call('shops.wallets.v1', {})
    local lines = {}
    if type(result) == 'table' and result.ok and type(result.value) == 'table' then
        for _, wallet in ipairs(result.value) do
            local precision = tonumber(wallet.precision)
            if type(wallet.balance) == 'number' and precision and precision % 1 == 0 and precision >= 0 and precision <= 6 then
                lines[#lines + 1] = (wallet.label or wallet.currency) .. ': '
                    .. string.format('%.' .. precision .. 'f', wallet.balance / (10 ^ precision))
            end
        end
    end
    Add(page, 'textdisplay', { value = #lines > 0 and ('Wallet\n' .. table.concat(lines, '\n'))
        or 'Wallet balance unavailable — not assumed to be zero.', slot = 'content' })
end
local Catalog
local function Purchase(shop)
    Async(function()
        if type(pending) ~= 'table' then Message('No valid saved purchase.'); return end
        local result = Call('shops.purchase.v1', { quoteId = pending.quoteId, requestId = pending.requestId })
        if type(result) ~= 'table' or not result.ok then
            if type(result) == 'table' and result.ok == false and type(result.details) == 'table'
                and result.details.safeToClear == true
                and (result.details.purchaseState == 'rejected' or result.details.purchaseState == 'not_accepted') then
                pending = nil; DeleteResourceKvp(pendingKey)
                Message(result.message)
                if opened then Catalog(shop, result.message) end
                return
            end
            local page = Page('Purchase needs attention')
            AddBalances(page)
            Add(page, 'textdisplay', { value = (type(result) == 'table' and result.message or 'Response unavailable.')
                .. '\nThe original request is saved. Retry does not create another purchase.', slot = 'content' })
            Add(page, 'button', { label = 'Retry original purchase', slot = 'content' }, function() Purchase(shop) end)
            if opened then Show(page) end
            return
        end
        pending = nil; DeleteResourceKvp(pendingKey)
        Message('Purchase fulfilled.')
        if opened then Catalog(shop, 'Purchase fulfilled. Items delivered.') end
    end)
end
Catalog = function(shop, notice)
    local page = Page(shop.label)
    AddBalances(page)
    if notice then Add(page, 'textdisplay', { value = notice, slot = 'content' }) end
    if pending ~= nil then
        Add(page, 'textdisplay', { value = 'An earlier purchase needs resolution before a new purchase.', slot = 'content' })
        if type(pending) == 'table' then
            Add(page, 'button', { label = 'Retry saved purchase', slot = 'content' }, function() Purchase(shop) end)
        end
    else
        for _, offer in ipairs(shop.offers) do
            Add(page, 'button', { label = offer.label .. ' — ' .. offer.currency .. ' ' .. string.format('%.2f', offer.unitPrice / 100), slot = 'content' }, function()
                if busy then return end
                local detail = Page(offer.label)
                local quantity = 1
                Add(detail, 'number', { label = 'Quantity', value = 1, min = 1, max = offer.maximumQuantity, step = 1, slot = 'content' }, function(event)
                    quantity = tonumber(event.value) or 1
                end)
                Add(detail, 'button', { label = 'Review price', slot = 'content' }, function()
                    Async(function()
                        local result = Call('shops.quote.v1', { shopId = shop.id, offerId = offer.id, quantity = quantity })
                        if not opened then return end
                        if type(result) ~= 'table' or not result.ok then
                            Catalog(shop, type(result) == 'table' and result.message or 'Quote unavailable.'); return
                        end
                        local quote = result.value
                        local review = Page('Confirm purchase')
                        AddBalances(review)
                        Add(review, 'textdisplay', { value = offer.label .. ' × ' .. quote.quantity .. '\nTotal: '
                            .. quote.currency .. ' ' .. string.format('%.2f', quote.total / 100) .. '\nQuote expires shortly.', slot = 'content' })
                        Add(review, 'button', { label = 'Confirm and pay', slot = 'content' }, function()
                            if busy or pending ~= nil then return end
                            pending = { quoteId = quote.id, requestId = 'ui:' .. quote.id }
                            SetResourceKvp(pendingKey, json.encode(pending))
                            Purchase(shop)
                        end)
                        Add(review, 'button', { label = 'Cancel', slot = 'footer' }, function() Async(function() Catalog(shop) end) end)
                        Show(review)
                    end)
                end)
                Add(detail, 'button', { label = 'Back', slot = 'footer' }, function() Async(function() Catalog(shop) end) end)
                Show(detail)
            end)
        end
    end
    Add(page, 'button', { label = 'Close', slot = 'footer' }, function() Menu:CloseMenu(menuId) end)
    Show(page)
end
local function Open(shop)
    Async(function()
        if not menuId then
            menuId = Require(Menu:CreateMenu({ key = 'shops', closable = true,
                theme = { preset = 'redemption' }, focus = { keyboard = true, cursor = true } })).menuId
            Require(Menu:RegisterMenuLifecycle(menuId, function(event)
                if event.event == 'closed' then opened = false
                elseif event.event == 'opened' or event.event == 'resumed' then opened = true end
            end))
        end
        Catalog(shop)
    end)
end
CreateThread(function()
    local ready = exports['feather-core']:AwaitReady(30000)
    if type(ready) ~= 'table' or not ready.ok then Message('Core not ready.'); return end
    local deadline, snapshot = GetGameTimer() + 30000
    repeat
        if GlobalState['feather-shops:ready']==true then snapshot = Call('shops.catalog.v1', {}) end
        if type(snapshot) == 'table' and snapshot.ok then break end
        Wait(1000)
    until GetGameTimer() >= deadline
    if type(snapshot) ~= 'table' or not snapshot.ok then Message('Shop catalog unavailable.'); return end
    shops = snapshot.value
    local control = Require(exports['feather-toolkit']:ResolveControl('B'))
    promptId = Require(exports['feather-toolkit']:CreatePrompt({ control = control, label = 'Browse shop', groupId = groupId, mode = 'hold' })).id
    while true do
        local delay = 750
        if not opened and not busy and not IsEntityDead(PlayerPedId()) then
            local position, nearest, distance = GetEntityCoords(PlayerPedId())
            for _, shop in ipairs(shops) do
                local current = #(position - vector3(shop.position.x, shop.position.y, shop.position.z))
                if current <= 3.0 and (not distance or current < distance) then nearest, distance = shop, current end
            end
            if nearest then
                delay = 0
                exports['feather-toolkit']:ShowPromptGroup(groupId, nearest.label)
                local result = exports['feather-toolkit']:IsPromptCompleted(promptId)
                if result.ok and result.value.completed then Open(nearest) end
            end
        end
        Wait(delay)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if menuId then pcall(function() Menu:DestroyMenu(menuId) end) end
    if promptId then pcall(function() exports['feather-toolkit']:RemovePrompt(promptId) end) end
end)
