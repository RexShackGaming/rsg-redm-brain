local Menu = exports['feather-menu-v2']
local shops, menuId, pageId, promptId = {}, nil, nil, nil
local opened, busy, generation, elementSequence = false, false, 0, 0
local groupId = joaat('feather-shops:interact')
local pendingKey = 'shops:ui:pending-purchase'
local pending
local currentShop
local function T(key) return ShopText(0,key) end
local function Amount(value,precision)
    precision=tonumber(precision) or 2
    if precision%1~=0 or precision<0 or precision>6 then precision=2 end
    return string.format('%.'..precision..'f',value/(10^precision))
end
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
        if not called then Message(T(type(pending)=='table' and 'error_checkout_pending' or 'error_generic')) end
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
    Add(page, 'textdisplay', { value = #lines > 0 and (T('wallet')..'\n' .. table.concat(lines, '\n'))
        or T('wallet_unavailable'), slot = 'content' })
end
local Catalog
local function ApplyOutcome(result,shop)
    local terminal=type(result)=='table' and ((result.ok==true and type(result.value)=='table' and result.value.state=='fulfilled')
        or (result.ok==false and type(result.details)=='table' and result.details.safeToClear==true
            and (result.details.purchaseState=='rejected' or result.details.purchaseState=='not_accepted')))
    if terminal then
        pending=nil;DeleteResourceKvp(pendingKey)
        local message=result.ok and T('fulfilled') or result.message
        Message(message)
        if opened and shop then Catalog(shop,message) end
        return
    end
    if not opened then return end
    local page=Page(T('checking'))
    AddBalances(page)
    Add(page,'textdisplay',{value=(type(result)=='table' and result.message or T('error_checkout_pending'))
        ..'\n'..T('saved'),slot='content'})
    Show(page)
end
local function CheckStatus(shop)
    if type(pending)~='table' then return end
    local result=Call('shops.purchase.status.v1',pending)
    ApplyOutcome(result,shop)
end
local function Purchase(shop)
    Async(function()
        if type(pending)~='table' then return end
        local result=Call('shops.purchase.v1',pending)
        ApplyOutcome(result,shop)
    end)
end
CreateThread(function()
    while true do
        Wait(5000)
        if type(pending)=='table' and not busy and GlobalState['feather-shops:ready']==true then
            Async(function() CheckStatus(currentShop) end)
        end
    end
end)
Catalog = function(shop, notice)
    currentShop=shop
    local page = Page(shop.label)
    AddBalances(page)
    if notice then Add(page, 'textdisplay', { value = notice, slot = 'content' }) end
    if pending ~= nil then
        Add(page, 'textdisplay', { value = T('earlier'), slot = 'content' })
        if type(pending) == 'table' then
            Add(page, 'button', { label = T('check_status'), slot = 'content' }, function() Async(function() CheckStatus(shop) end) end)
        end
    else
        for _, offer in ipairs(shop.offers) do
            Add(page, 'button', { label = offer.label .. ' — ' .. offer.currency .. ' ' .. Amount(offer.unitPrice,offer.currencyPrecision), slot = 'content' }, function()
                if busy then return end
                local detail = Page(offer.label)
                local quantity = 1
                Add(detail, 'number', { label = T('quantity'), value = 1, min = 1, max = offer.maximumQuantity, step = 1, slot = 'content' }, function(event)
                    quantity = tonumber(event.value) or 1
                end)
                Add(detail, 'button', { label = T('review'), slot = 'content' }, function()
                    Async(function()
                        local result = Call('shops.quote.v1', { shopId = shop.id, offerId = offer.id, quantity = quantity })
                        if not opened then return end
                        if type(result) ~= 'table' or not result.ok then
                            Catalog(shop, type(result) == 'table' and result.message or T('quote_unavailable')); return
                        end
                        local quote = result.value
                        local review = Page(T('confirm'))
                        AddBalances(review)
                        Add(review, 'textdisplay', { value = offer.label .. ' × ' .. quote.quantity .. '\n'..T('total')
                            .. quote.currency .. ' ' .. Amount(quote.total,quote.currencyPrecision) .. '\n'..T('expires'), slot = 'content' })
                        Add(review, 'button', { label = T('pay'), slot = 'content' }, function()
                            if busy or pending ~= nil then return end
                            pending = { quoteId = quote.id, requestId = 'ui:' .. quote.id }
                            SetResourceKvp(pendingKey, json.encode(pending))
                            Purchase(shop)
                        end)
                        Add(review, 'button', { label = T('cancel'), slot = 'footer' }, function() Async(function() Catalog(shop) end) end)
                        Show(review)
                    end)
                end)
                Add(detail, 'button', { label = T('back'), slot = 'footer' }, function() Async(function() Catalog(shop) end) end)
                Show(detail)
            end)
        end
    end
    Add(page, 'button', { label = T('close'), slot = 'footer' }, function() Menu:CloseMenu(menuId) end)
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
    if type(ready) ~= 'table' or not ready.ok then Message(T('core_unavailable')); return end
    local deadline, snapshot = GetGameTimer() + 30000
    repeat
        if GlobalState['feather-shops:ready']==true then snapshot = Call('shops.catalog.v1', {}) end
        if type(snapshot) == 'table' and snapshot.ok then break end
        Wait(1000)
    until GetGameTimer() >= deadline
    if type(snapshot) ~= 'table' or not snapshot.ok then Message(T('catalog_unavailable')); return end
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

AddEventHandler('feather-core:locale:changed',function()
    -- Visible labels are rebuilt in the selected language on the next open;
    -- saved purchase identity and automatic readback are retained.
    if opened and menuId then Menu:CloseMenu(menuId);opened=false end
end)
