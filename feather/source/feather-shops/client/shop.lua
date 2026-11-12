local Menu = exports['feather-menu-v2']
local shops, menuId, pageId, promptId = {}, nil, nil, nil
local opened, busy, generation, elementSequence = false, false, 0, 0
local groupId = joaat('feather-shops:interact')
local pendingKey = 'shops:ui:pending-purchase'
local pending
local currentShop
local promptLabels={}
local buttons={}
local function SetBusy(value)
    for _,button in ipairs(buttons) do
        pcall(function() Menu:UpdateElement(menuId,pageId,button,{busy=value}) end)
    end
end
local function T(key,...) return ShopText(0,key,...) end
local function Label(offer) return ShopCatalogText(0,'ui_shops_item_'..offer.itemName,offer.label) end
local function PromptLabel(shop)
    if not promptLabels[shop.id] then promptLabels[shop.id]=ShopCatalogText(0,'ui_shops_store_'..shop.id,shop.label) end
    return promptLabels[shop.id]
end
local function Amount(value,precision)
    precision=tonumber(precision) or 2
    if precision%1~=0 or precision<0 or precision>6 then precision=2 end
    return string.format('%.'..precision..'f',value/(10^precision))
end
local function Price(value,currency,precision)
    return (currency=='dollars' and '$' or (currency..' '))..Amount(value,precision)
end
local function AmmoGroup(offer)
    for _,family in ipairs({'revolver','pistol','repeater','rifle','shotgun','varmint','arrow'}) do
        if offer.itemName:match('^ammo_'..family) then return family end
    end
    return 'other_ammo'
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
    SetBusy(true)
    CreateThread(function()
        local called, failure = xpcall(work, debug.traceback)
        busy = false
        SetBusy(false)
        if not called then Message(T(type(pending)=='table' and 'error_checkout_pending' or 'error_generic')) end
    end)
end
local function Page(title)
    generation = generation + 1
    buttons={}
    local previous = pageId
    pageId = Require(Menu:CreatePage(menuId, { key = 'shop-' .. generation })).pageId
    if previous then Require(Menu:DestroyPage(menuId, previous, pageId)) end
    Require(Menu:AddElement(menuId, pageId, 'header', { key = 'title', value = title, slot = 'header' }))
    return pageId
end
local function Add(page, kind, settings, callback)
    elementSequence = elementSequence + 1
    settings.key = 'element-' .. elementSequence
    if kind=='button' then settings.busy=busy end
    local result=Require(Menu:AddElement(menuId, page, kind, settings, callback))
    if kind=='button' and result and result.elementId then buttons[#buttons+1]=result.elementId end
    return result
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
                lines[#lines + 1] = Price(wallet.balance,wallet.currency,precision)
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
Catalog = function(shop, notice, category, ammoGroup)
    currentShop=shop
    local page = Page(ShopCatalogText(0,'ui_shops_store_'..shop.id,shop.label))
    AddBalances(page)
    if notice then Add(page, 'textdisplay', { value = notice, slot = 'content' }) end
    if pending ~= nil then
        Add(page, 'textdisplay', { value = T('earlier'), slot = 'content' })
        if type(pending) == 'table' then
            Add(page, 'button', { label = T('check_status'), slot = 'content' }, function() Async(function() CheckStatus(shop) end) end)
        end
    else
        local grouped=false
        for _,offer in ipairs(shop.offers) do if offer.category then grouped=true;break end end
        if grouped and not category then
            for _,key in ipairs({'revolver','pistol','repeater','rifle','shotgun','ammunition','attachments','maintenance','goods'}) do
                local present=false
                for _,offer in ipairs(shop.offers) do if (offer.category or 'goods')==key then present=true;break end end
                if present then
                    local selected=key
                    Add(page,'button',{label=T('category_'..key),slot='content'},function() Async(function() Catalog(shop,nil,selected) end) end)
                end
            end
        elseif category=='ammunition' and not ammoGroup then
            for _,family in ipairs({'revolver','pistol','repeater','rifle','shotgun','varmint','arrow','other_ammo'}) do
                local present=false
                for _,offer in ipairs(shop.offers) do if offer.category=='ammunition' and AmmoGroup(offer)==family then present=true;break end end
                if present then
                    local selected=family
                    Add(page,'button',{label=T('ammo_'..family),slot='content'},function() Async(function() Catalog(shop,nil,category,selected) end) end)
                end
            end
        else
        for _, offer in ipairs(shop.offers) do
            if (not category or (offer.category or 'goods')==category) and (not ammoGroup or AmmoGroup(offer)==ammoGroup) then
            local label=Label(offer)
            local quantityLabel=T(offer.category=='ammunition' and 'round_count' or 'item_count',offer.packSize or 1)
            Add(page, 'button', {label=label,description=quantityLabel..' / '..Price(offer.unitPrice,offer.currency,offer.currencyPrecision),slot='content'}, function()
                if busy then return end
                local detail = Page(Label(offer))
                local quantity = 1
                if (offer.packSize or 1)>1 then Add(detail,'textdisplay',{value=T('contents',offer.packSize),slot='content'}) end
                Add(detail, 'number', { label = T((offer.packSize or 1)>1 and 'boxes' or 'quantity'), value = 1, min = 1, max = offer.maximumQuantity, step = 1, slot = 'content' }, function(event)
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
                        Add(review, 'textdisplay', { value = Label(offer) .. ' × ' .. quote.quantity .. '\n'..T('total')
                            .. Price(quote.total,quote.currency,quote.currencyPrecision) .. '\n'..T('expires'), slot = 'content' })
                        if (quote.packSize or 1)>1 then Add(review,'textdisplay',{value=T('delivered',quote.itemQuantity),slot='content'}) end
                        Add(review, 'button', { label = T('pay'), slot = 'content' }, function()
                            if busy or pending ~= nil then return end
                            pending = { quoteId = quote.id, requestId = 'ui:' .. quote.id }
                            SetResourceKvp(pendingKey, json.encode(pending))
                            Purchase(shop)
                        end)
                        Add(review, 'button', { label = T('cancel'), slot = 'footer' }, function() Async(function() Catalog(shop,nil,category,ammoGroup) end) end)
                        Show(review)
                    end)
                end)
                Add(detail, 'button', { label = T('back'), slot = 'footer' }, function() Async(function() Catalog(shop,nil,category,ammoGroup) end) end)
                Show(detail)
            end)
            end
        end
        end
        if category then Add(page,'button',{label=T('back'),slot='footer'},function() Async(function() Catalog(shop,nil,ammoGroup and category or nil) end) end) end
    end
    Add(page, 'button', { label = T('close'), slot = 'footer' }, function() Menu:CloseMenu(menuId) end)
    Show(page)
end
local function Open(shop)
    Async(function()
        -- Refresh translated labels and current prices on each open. Saved
        -- purchase identities remain untouched by a catalog/language refresh.
        local fresh=Call('shops.catalog.v1',{})
        if type(fresh)~='table' or not fresh.ok then Message(T('catalog_unavailable'));return end
        shops=fresh.value
        local current
        for _,candidate in ipairs(shops) do if candidate.id==shop.id then current=candidate;break end end
        if not current then Message(T('catalog_unavailable'));return end
        shop=current
        if not menuId then
            menuId = Require(Menu:CreateMenu({ key = 'shops', closable = true,
                position={x='3%',y='3%',anchor='top-left'}, draggable=false, persistPosition=false,
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
    promptId = Require(exports['feather-toolkit']:CreatePrompt({ control = control, label = T('browse'), groupId = groupId, mode = 'hold' })).id
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
                exports['feather-toolkit']:ShowPromptGroup(groupId, PromptLabel(nearest))
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
    promptLabels={}
    -- Visible labels are rebuilt in the selected language on the next open;
    -- saved purchase identity and automatic readback are retained.
    if opened and menuId then Menu:CloseMenu(menuId);opened=false end
    if promptId then
        exports['feather-toolkit']:RemovePrompt(promptId)
        local control=Require(exports['feather-toolkit']:ResolveControl('B'))
        promptId=Require(exports['feather-toolkit']:CreatePrompt({control=control,label=T('browse'),groupId=groupId,mode='hold'})).id
    end
end)
