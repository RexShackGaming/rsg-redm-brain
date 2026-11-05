local resourceName = GetCurrentResourceName()
local menus = {}
local activeMenuId = nil
local uiReady = false
local startedAt = GetGameTimer()
local pausedMenuId = nil

local limits = { menus = 64, pages = 64, elements = 512, patchOperations = 256 }

local function Owner()
    local owner = GetInvokingResource()
    if type(owner) ~= 'string' or owner == '' then return nil end
    return owner
end

local function Count(values)
    local count = 0
    for _ in pairs(values) do count = count + 1 end
    return count
end

local function Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        if type(child) ~= 'function' then result[Copy(key, seen)] = Copy(child, seen) end
    end
    seen[value] = nil
    return result
end

local Merge = MenuValidation.Merge

-- Cfx marshals callbacks crossing a resource boundary as callable function-reference
-- objects. They are tables in some runtime builds rather than plain Lua functions.
local function IsCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' and type(value) ~= 'userdata' then return false end
    local metatable = getmetatable(value)
    return type(metatable) == 'table' and type(metatable.__call) == 'function'
end

local function Call(callback, payload)
    return pcall(function() callback(payload) end)
end

local function MenuFor(owner, menuId)
    local menu = menus[menuId]
    if not menu then return nil, MenuResults.Err('not_found', 'Menu was not found.') end
    if menu.owner ~= owner then return nil, MenuResults.Err('forbidden', 'Menu belongs to another resource.') end
    return menu, nil
end

local function PageFor(menu, pageId)
    local page = menu.pages[pageId]
    if not page then return nil, MenuResults.Err('not_found', 'Page was not found.') end
    return page, nil
end

local function PublicMenu(menu)
    local pages = {}
    for _, pageId in ipairs(menu.pageOrder) do
        local page = menu.pages[pageId]
        local elements = {}
        for _, elementId in ipairs(page.elementOrder) do elements[#elements + 1] = Copy(page.elements[elementId].public) end
        pages[#pages + 1] = { pageId = page.id, key = page.key, config = Copy(page.config), elements = elements }
    end
    local keys = {}
    for key in pairs(menu.keyCallbacks or {}) do keys[key] = true end
    return {
        menuId = menu.id, key = menu.key, revision = menu.revision, config = Copy(menu.config),
        pages = pages, activePageId = menu.activePageId, open = menu.open,
        navigation = Copy(menu.navigation), keys = keys, focus = Copy(menu.focus),
    }
end

local function Budget(menu, incoming, outgoing)
    -- Reserve envelope/ID overhead. Individual definitions are limited separately.
    if not json or not json.encode then return nil end
    local size = #json.encode(PublicMenu(menu)) + #json.encode(incoming or {}) - #json.encode(outgoing or {}) + 2048
    if size > 1048576 then return MenuResults.Err('limit_exceeded', 'Menu snapshot exceeds the 1 MiB transport budget.') end
end

local function Send(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

local function Sync(menu)
    if uiReady then
        menu.sentAt = GetGameTimer()
        menu.ackRevision = nil
        Send('menu:sync', { menu = PublicMenu(menu) })
    end
end

local function Mutate(menu, operations)
    menu.revision = menu.revision + 1
    if not menu.sentAt then menu.sentAt = GetGameTimer() end
    if uiReady then Send('menu:patch', { menuId = menu.id, revision = menu.revision, operations = operations }) end
end

local function EmitLifecycle(menu, event, details)
    if not menu.lifecycleCallback then return end
    local payload = Copy(details or {})
    payload.event = event
    payload.menuId = menu.id
    payload.pageId = payload.pageId or menu.activePageId
    local ok, problem = Call(menu.lifecycleCallback, payload)
    if not ok then print(('[%s] lifecycle callback failed owner=%s menu=%s error=%s'):format(resourceName, menu.owner, menu.id, tostring(problem))) end
end

local function Capabilities()
    return MenuResults.Ok({
        resource = resourceName, contract = 1,
        version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        state = uiReady and 'ready' or 'starting',
        features = {
            menus = 1, pages = 1, elements = 1, focus = 1, dropdowns = 1,
            draggable = 1, resizable = 1, themes = 1, reactiveState = 1,
            tabs = 1, stepper = 1, ownerCleanup = 1, boundedValidation = 1, acknowledgements = 1,
            browserGamepad = 1, modalInputCapture = 1, focusHandoff = 1,
        },
    })
end

local function Health()
    local pending = 0
    for _, menu in pairs(menus) do if menu.open and menu.ackRevision ~= menu.revision then pending = pending + 1 end end
    return MenuResults.Ok({ state = uiReady and 'ready' or 'starting', uiReady = uiReady, menuCount = Count(menus), activeMenuId = activeMenuId, pendingAcknowledgements = pending })
end

exports('GetCapabilities', Capabilities)
exports('GetHealth', Health)
-- Public, owner-neutral input state. First-party hotkey providers can use this
-- to avoid opening another UI while a modal Menu v2 instance owns focus.
exports('IsInputCaptured', function()
    local menu = activeMenuId and menus[activeMenuId] or nil
    return (menu ~= nil and (menu.focus.keyboard or menu.focus.cursor)) == true
end)
exports('AwaitReady', function(timeoutMs)
    timeoutMs = tonumber(timeoutMs) or 0
    local deadline = GetGameTimer() + math.max(0, math.min(timeoutMs, 30000))
    repeat
        if uiReady then return Health() end
        if timeoutMs <= 0 then break end
        Wait(0)
    until GetGameTimer() >= deadline
    return MenuResults.Err(timeoutMs > 0 and 'timeout' or 'not_ready', 'Feather Menu UI is not ready.')
end)

print(('[%s] Contract 1 client exports registered; waiting for NUI readiness.'):format(resourceName))

exports('CreateMenu', function(spec)
    local owner = Owner()
    if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local invalid = MenuValidation.Menu(spec, 'spec', true)
    if invalid then return invalid end
    if Count(menus) >= limits.menus then return MenuResults.Err('limit_exceeded', 'Menu limit reached.') end
    local menuId = owner .. ':' .. spec.key
    if menus[menuId] then return MenuResults.Err('conflict', 'Menu key already exists for this resource.') end
    menus[menuId] = {
        id = menuId, key = spec.key, owner = owner, config = Copy(spec), pages = {}, pageOrder = {},
        revision = 0, open = false, activePageId = nil, navigation = nil, keyCallbacks = {}, lifecycleCallback = nil,
        focus = { keyboard = true, cursor = true },
    }
    return MenuResults.Ok({ menuId = menuId })
end)

exports('CreatePage', function(menuId, spec)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local invalid = MenuValidation.Page(spec, 'spec', true); if invalid then return invalid end
    if Count(menu.pages) >= limits.pages then return MenuResults.Err('limit_exceeded', 'Page limit reached.') end
    local pageId = menuId .. '/' .. spec.key
    if menu.pages[pageId] then return MenuResults.Err('conflict', 'Page key already exists in this menu.') end
    local overBudget = Budget(menu, spec); if overBudget then return overBudget end
    menu.pages[pageId] = { id = pageId, key = spec.key, config = Copy(spec), elements = {}, elementOrder = {} }
    menu.pageOrder[#menu.pageOrder + 1] = pageId
    Mutate(menu, { { op = 'page:add', page = { pageId = pageId, key = spec.key, config = Copy(spec), elements = {} } } })
    return MenuResults.Ok({ pageId = pageId })
end)

exports('UpdatePage', function(menuId, pageId, changes)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local page; page, failure = PageFor(menu, pageId); if failure then return failure end
    local invalid = MenuValidation.Page(changes, 'changes', false); if invalid then return invalid end
    if changes.key and changes.key ~= page.key then return MenuResults.Err('invalid_input', 'Page keys cannot be changed.') end
    Merge(page.config, changes); Mutate(menu, { { op = 'page:update', pageId = pageId, changes = Copy(changes) } })
    return MenuResults.Ok({ revision = menu.revision })
end)

exports('DestroyPage', function(menuId, pageId, fallbackPageId)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local _, pageFailure = PageFor(menu, pageId); if pageFailure then return pageFailure end
    if menu.activePageId == pageId then
        if not fallbackPageId or fallbackPageId == pageId or not menu.pages[fallbackPageId] then
            return MenuResults.Err('conflict', 'Destroying the active page requires a valid fallbackPageId.')
        end
        menu.activePageId = fallbackPageId
    end
    menu.pages[pageId] = nil
    for index, id in ipairs(menu.pageOrder) do if id == pageId then table.remove(menu.pageOrder, index); break end end
    local operations = { { op = 'page:remove', pageId = pageId, fallbackPageId = fallbackPageId } }
    if menu.navigation then
        local pages = {}
        for _, item in ipairs(menu.navigation.pages) do if item.pageId ~= pageId then pages[#pages + 1] = item end end
        if #pages == 0 then menu.navigation = nil; menu.navigationCallback = nil
        else menu.navigation.pages = pages end
        operations[#operations + 1] = { op = 'navigation:set', navigation = menu.navigation and Copy(menu.navigation) or false }
    end
    Mutate(menu, operations)
    return MenuResults.Ok({ destroyed = true, revision = menu.revision })
end)

exports('AddElement', function(menuId, pageId, elementType, spec, callback)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local page; page, failure = PageFor(menu, pageId); if failure then return failure end
    local invalid = MenuValidation.Element(elementType, spec, 'spec')
    if invalid then return invalid end
    if spec.section then
        local parent = page.elements[pageId .. '/' .. spec.section]
        if not parent or parent.public.type ~= 'accordion' then
            return MenuResults.Err('invalid_input', 'section must reference an existing accordion on this page.')
        end
    end
    if callback ~= nil and not IsCallable(callback) then return MenuResults.Err('invalid_input', 'callback must be callable.') end
    if Count(page.elements) >= limits.elements then return MenuResults.Err('limit_exceeded', 'Element limit reached.') end
    local elementId = pageId .. '/' .. spec.key
    if page.elements[elementId] then return MenuResults.Err('conflict', 'Element key already exists on this page.') end
    local public = { elementId = elementId, key = spec.key, type = elementType, data = Copy(spec) }
    local overBudget = Budget(menu, public); if overBudget then return overBudget end
    page.elements[elementId] = { public = public, callback = callback }
    page.elementOrder[#page.elementOrder + 1] = elementId
    Mutate(menu, { { op = 'element:add', pageId = pageId, element = Copy(public) } })
    return MenuResults.Ok({ elementId = elementId })
end)

local function UpdateElement(owner, menuId, pageId, elementId, changes)
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local page; page, failure = PageFor(menu, pageId); if failure then return failure end
    local element = page.elements[elementId]
    if not element then return MenuResults.Err('not_found', 'Element was not found.') end
    local invalid = MenuValidation.ElementChanges(element.public.type, element.public.data, changes, 'changes'); if invalid then return invalid end
    if changes.key and changes.key ~= element.public.key then return MenuResults.Err('invalid_input', 'Element keys cannot be changed.') end
    local candidate = Copy(element.public.data); Merge(candidate, changes)
    local overBudget = Budget(menu, candidate, element.public.data); if overBudget then return overBudget end
    Merge(element.public.data, changes)
    Mutate(menu, { { op = 'element:update', pageId = pageId, elementId = elementId, changes = Copy(changes) } })
    return MenuResults.Ok({ revision = menu.revision })
end

exports('UpdateElement', function(menuId, pageId, elementId, changes)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    return UpdateElement(owner, menuId, pageId, elementId, changes)
end)

exports('SetElementValue', function(menuId, pageId, elementId, value)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    return UpdateElement(owner, menuId, pageId, elementId, { value = value })
end)

exports('FocusElement', function(menuId, pageId, elementId)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local page; page, failure = PageFor(menu, pageId); if failure then return failure end
    if not page.elements[elementId] then return MenuResults.Err('not_found', 'Element was not found.') end
    if not menu.open or menu.activePageId ~= pageId then return MenuResults.Err('invalid_state', 'Element page is not active.') end
    Send('element:focus', { menuId = menuId, pageId = pageId, elementId = elementId })
    return MenuResults.Ok({ elementId = elementId })
end)

exports('RemoveElement', function(menuId, pageId, elementId)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local page; page, failure = PageFor(menu, pageId); if failure then return failure end
    if not page.elements[elementId] then return MenuResults.Ok({ removed = false }, { idempotent = true }) end
    page.elements[elementId] = nil
    for index, id in ipairs(page.elementOrder) do if id == elementId then table.remove(page.elementOrder, index); break end end
    Mutate(menu, { { op = 'element:remove', pageId = pageId, elementId = elementId } })
    return MenuResults.Ok({ removed = true })
end)

exports('UpdateMenu', function(menuId, changes)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local invalid = MenuValidation.Menu(changes, 'changes', false); if invalid then return invalid end
    if changes.key and changes.key ~= menu.key then return MenuResults.Err('invalid_input', 'Menu keys cannot be changed.') end
    local candidate = Copy(menu.config); Merge(candidate, changes)
    invalid = MenuValidation.Menu(candidate, 'changes', true); if invalid then return invalid end
    local overBudget = Budget(menu, candidate, menu.config); if overBudget then return overBudget end
    Merge(menu.config, changes); Mutate(menu, { { op = 'menu:update', changes = Copy(changes) } })
    return MenuResults.Ok({ revision = menu.revision })
end)

exports('ApplyPatch', function(menuId, operations)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local payloadError = MenuValidation.Bytes(operations, 'operations', 262144); if payloadError then return payloadError end
    if type(operations) ~= 'table' or #operations == 0 or #operations > limits.patchOperations or Count(operations) ~= #operations then
        return MenuResults.Err('invalid_input', 'operations must be a non-empty bounded array.')
    end
    local targets, incoming, outgoing = {}, {}, {}
    for index, operation in ipairs(operations) do
        if type(operation) ~= 'table' or operation.op ~= 'updateElement' or type(operation.changes) ~= 'table' then
            return MenuResults.Err('invalid_input', 'Contract 1 patches currently accept updateElement operations.', { index = index })
        end
        local page = menu.pages[operation.pageId]
        if not page or not page.elements[operation.elementId] then
            return MenuResults.Err('not_found', 'Patch references an unknown page or element.', { index = index })
        end
        local element = page.elements[operation.elementId]
        local fields = MenuValidation.Fields(operation, 'op pageId elementId changes', 'operations.' .. index)
        if fields then return fields end
        targets[operation.pageId] = targets[operation.pageId] or {}
        if targets[operation.pageId][operation.elementId] then return MenuResults.Err('conflict', 'Each element may appear only once in an atomic patch.') end
        targets[operation.pageId][operation.elementId] = true
        if operation.changes.key and operation.changes.key ~= element.public.key then return MenuResults.Err('invalid_input', 'Element keys cannot be changed.') end
        local invalid = MenuValidation.ElementChanges(element.public.type, element.public.data, operation.changes, 'operations.' .. index .. '.changes')
        if invalid then return invalid end
        local candidate = Copy(element.public.data); Merge(candidate, operation.changes)
        incoming[#incoming + 1] = candidate; outgoing[#outgoing + 1] = element.public.data
    end
    local overBudget = Budget(menu, incoming, outgoing); if overBudget then return overBudget end
    local publicOperations = {}
    for _, operation in ipairs(operations) do
        local element = menu.pages[operation.pageId].elements[operation.elementId]
        Merge(element.public.data, operation.changes)
        publicOperations[#publicOperations + 1] = {
            op = 'element:update', pageId = operation.pageId, elementId = operation.elementId,
            changes = Copy(operation.changes),
        }
    end
    Mutate(menu, publicOperations)
    return MenuResults.Ok({ revision = menu.revision, applied = #publicOperations })
end)

exports('ConfigureNavigation', function(menuId, spec, callback)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local invalid = MenuValidation.Navigation(spec, 'spec'); if invalid then return invalid end
    for _, item in ipairs(spec.pages) do if not menu.pages[item.pageId] then return MenuResults.Err('not_found', 'Navigation references an unknown page.') end end
    local overBudget = Budget(menu, spec, menu.navigation); if overBudget then return overBudget end
    if callback ~= nil and not IsCallable(callback) then return MenuResults.Err('invalid_input', 'callback must be callable.') end
    menu.navigation = Copy(spec); menu.navigationCallback = callback
    Mutate(menu, { { op = 'navigation:set', navigation = Copy(spec) } })
    return MenuResults.Ok({ revision = menu.revision })
end)

exports('RegisterKeyAction', function(menuId, key, callback)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    if type(key) ~= 'string' or key == '' or #key > 32 or not IsCallable(callback) then
        return MenuResults.Err('invalid_input', 'key and callback are required.')
    end
    menu.keyCallbacks[key] = callback
    Mutate(menu, { { op = 'key:set', key = key } })
    return MenuResults.Ok({ key = key })
end)

exports('RemoveKeyAction', function(menuId, key)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    if type(key) ~= 'string' or key == '' or #key > 32 then return MenuResults.Err('invalid_input', 'key must be a 1-32 character string.') end
    menu.keyCallbacks[key] = nil
    Mutate(menu, { { op = 'key:remove', key = key } })
    return MenuResults.Ok({ key = key })
end)

exports('RegisterMenuLifecycle', function(menuId, callback)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    if callback ~= nil and not IsCallable(callback) then return MenuResults.Err('invalid_input', 'callback must be callable or nil.') end
    menu.lifecycleCallback = callback
    return MenuResults.Ok({ registered = callback ~= nil })
end)

exports('UpdateNavigation', function(menuId, changes)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    if not menu.navigation then return MenuResults.Err('invalid_state', 'Navigation is not configured.') end
    local payloadError = MenuValidation.Bytes(changes, 'changes'); if payloadError then return payloadError end
    if type(changes) ~= 'table' then return MenuResults.Err('invalid_input', 'changes must be a table.') end
    local candidate = Copy(menu.navigation); Merge(candidate, changes)
    local invalid = MenuValidation.Navigation(candidate, 'changes'); if invalid then return invalid end
    for _, item in ipairs(candidate.pages) do if not menu.pages[item.pageId] then return MenuResults.Err('not_found', 'Navigation references an unknown page.') end end
    local overBudget = Budget(menu, candidate, menu.navigation); if overBudget then return overBudget end
    Merge(menu.navigation, changes); Mutate(menu, { { op = 'navigation:update', changes = Copy(changes) } })
    return MenuResults.Ok({ revision = menu.revision })
end)

exports('NavigateToPage', function(menuId, pageId)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local _, pageFailure = PageFor(menu, pageId); if pageFailure then return pageFailure end
    local fromPageId = menu.activePageId
    menu.activePageId = pageId; Mutate(menu, { { op = 'page:activate', pageId = pageId } })
    EmitLifecycle(menu, 'pageChanged', { fromPageId = fromPageId, pageId = pageId })
    return MenuResults.Ok({ pageId = pageId, revision = menu.revision })
end)

exports('OpenMenu', function(menuId, options)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    if not uiReady then return MenuResults.Err('not_ready', 'Feather Menu UI is not ready.') end
    options = options or {}
    local invalid = MenuValidation.OpenOptions(options); if invalid then return invalid end
    local pageId = options.pageId or menu.activePageId or menu.pageOrder[1]
    if not pageId or not menu.pages[pageId] then return MenuResults.Err('invalid_state', 'Menu has no valid startup page.') end
    if activeMenuId and activeMenuId ~= menuId then
        local active = menus[activeMenuId]
        if options.replace == false then return MenuResults.Err('focus_unavailable', 'Another menu is active.') end
        if active then
            active.open = false
            Send('menu:close', { menuId = active.id })
            EmitLifecycle(active, 'closed', { reason = 'replaced', replacedByMenuId = menuId })
        end
    end
    menu.activePageId = pageId; menu.open = true; activeMenuId = menuId; Sync(menu)
    Send('menu:open', { menuId = menuId, pageId = pageId })
    local defaults = menu.config.focus or {}
    menu.focus = { keyboard = options.keyboard == nil and defaults.keyboard ~= false or options.keyboard == true,
        cursor = options.cursor == nil and defaults.cursor ~= false or options.cursor == true }
    pausedMenuId = nil
    SetNuiFocus(menu.focus.keyboard, menu.focus.cursor)
    SetNuiFocusKeepInput(false)
    if type(options.sound) == 'table' and type(options.sound.action) == 'string' and type(options.sound.soundset) == 'string' then
        PlaySoundFrontend(options.sound.action, options.sound.soundset, true, 0)
    end
    EmitLifecycle(menu, 'opened', { pageId = pageId })
    return MenuResults.Ok({ menuId = menuId, pageId = pageId })
end)

-- Temporarily hand input back to the game without hiding or rebuilding the
-- active menu. The owning resource must explicitly restore focus afterward.
exports('SetMenuFocus', function(menuId, options)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    if not menu.open or activeMenuId ~= menu.id then
        return MenuResults.Err('invalid_state', 'Menu must be open and active to change focus.')
    end
    options = options or {}
    local invalid = MenuValidation.FocusOptions(options); if invalid then return invalid end
    menu.focus = {
        keyboard = options.keyboard == nil and menu.focus.keyboard or options.keyboard == true,
        cursor = options.cursor == nil and menu.focus.cursor or options.cursor == true,
    }
    SetNuiFocus(menu.focus.keyboard, menu.focus.cursor)
    SetNuiFocusKeepInput(false)
    return MenuResults.Ok(Copy(menu.focus))
end)

local function Close(menu, reason)
    if pausedMenuId == menu.id then pausedMenuId = nil end
    local wasOpen = menu.open
    menu.open = false
    if activeMenuId == menu.id then
        activeMenuId = nil
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
    if uiReady then Send('menu:close', { menuId = menu.id }) end
    if wasOpen then EmitLifecycle(menu, 'closed', { reason = reason or 'api' }) end
end

exports('CloseMenu', function(menuId, options)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    local invalid = MenuValidation.OpenOptions(options or {}, true); if invalid then return invalid end
    Close(menu, 'api')
    if type(options) == 'table' and type(options.sound) == 'table'
        and type(options.sound.action) == 'string' and type(options.sound.soundset) == 'string' then
        PlaySoundFrontend(options.sound.action, options.sound.soundset, true, 0)
    end
    return MenuResults.Ok({ menuId = menuId })
end)

exports('DestroyMenu', function(menuId)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    Close(menu); menus[menuId] = nil; Send('menu:destroy', { menuId = menuId })
    return MenuResults.Ok({ destroyed = true })
end)

exports('DestroyOwnedMenus', function()
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local removed = 0
    for menuId, menu in pairs(menus) do
        if menu.owner == owner then Close(menu); menus[menuId] = nil; Send('menu:destroy', { menuId = menuId }); removed = removed + 1 end
    end
    return MenuResults.Ok({ removed = removed })
end)

exports('GetMenuState', function(menuId)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    return MenuResults.Ok(PublicMenu(menu))
end)

exports('SyncMenu', function(menuId)
    local owner = Owner(); if not owner then return MenuResults.Err('unauthenticated', 'Calling resource is required.') end
    local menu, failure = MenuFor(owner, menuId); if failure then return failure end
    Sync(menu); return MenuResults.Ok({ revision = menu.revision })
end)

RegisterNUICallback('ready', function(_, cb)
    uiReady = true
    for _, menu in pairs(menus) do if menu.open then Sync(menu) end end
    cb({ ok = true })
end)

RegisterNUICallback('ack', function(data, cb)
    local menu = type(data) == 'table' and menus[data.menuId] or nil
    if not menu or not MenuValidation.Finite(data.revision) or data.revision % 1 ~= 0
        or data.revision < 0 or data.revision > menu.revision then cb({ ok = false, code = 'invalid_input' }); return end
    menu.ackRevision = math.max(menu.ackRevision or -1, data.revision)
    if menu.ackRevision == menu.revision then menu.sentAt = nil; menu.recoveryAttempts = 0 end
    cb({ ok = true })
end)

RegisterNUICallback('desync', function(data, cb)
    local menu = type(data) == 'table' and menus[data.menuId] or nil
    if menu then Sync(menu) end
    cb({ ok = menu ~= nil })
end)

RegisterNUICallback('close', function(data, cb)
    local menu = type(data) == 'table' and menus[data.menuId] or nil
    if menu and menu.open and menu.config.closable ~= false then Close(menu, 'user') end
    cb({ ok = true })
end)

RegisterNUICallback('elementAction', function(data, cb)
    local menu = type(data) == 'table' and menus[data.menuId] or nil
    local page = menu and menu.pages[data.pageId] or nil
    local element = page and page.elements[data.elementId] or nil
    if not menu or not menu.open or menu.activePageId ~= data.pageId or not element then cb({ ok = false }); return end
    if element.public.data.disabled == true or element.public.data.busy == true then cb({ ok = false }); return end
    local invalid = MenuValidation.ElementAction(element.public, data)
    if invalid then cb(invalid); return end
    if data.revision ~= nil and data.revision ~= menu.revision then Sync(menu); cb({ ok = false, code = 'conflict' }); return end
    if data.event == 'change' and element.public.data.persist ~= false then
        local candidate = Copy(element.public.data); candidate.value = Copy(data.value)
        local overBudget = Budget(menu, candidate, element.public.data); if overBudget then cb(overBudget); return end
        element.public.data.value = Copy(data.value)
        Mutate(menu, { {
            op = 'element:update', pageId = page.id, elementId = element.public.elementId,
            changes = { value = Copy(data.value) },
        } })
    end
    if element.callback then
        local value, meta = Copy(data.value), nil
        if element.public.type == 'button' or element.public.type == 'imagebox' then value = Copy(element.public.data.value) end
        if element.public.type == 'imageboxcontainer' then
            for _, item in ipairs(element.public.data.items) do if item.value == data.value then meta = { child = Copy(item) }; break end end
        end
        local ok, problem = Call(element.callback, {
            menuId = menu.id, pageId = page.id, elementId = element.public.elementId,
            action = data.event, value = value, meta = meta,
        })
        if not ok then
            print(('[%s] callback failed owner=%s element=%s error=%s'):format(resourceName, menu.owner, element.public.elementId, tostring(problem)))
            cb({ ok = false, code = 'callback_failed' }); return
        end
    end
    if element.public.data.sound then PlaySoundFrontend(element.public.data.sound.action, element.public.data.sound.soundset, true, 0) end
    local response = { ok = true }
    if data.event == 'change' then response.value = Copy(element.public.data.value) end
    cb(response)
end)

RegisterNUICallback('navigationIntent', function(data, cb)
    local menu = type(data) == 'table' and menus[data.menuId] or nil
    if not menu or not menu.open or not menu.navigation then cb({ ok = false, code = 'invalid_state' }); return end
    local invalid = MenuValidation.Fields(data, 'menuId mode fromPageId toPageId action index', 'intent') or MenuValidation.Bytes(data, 'intent')
    if invalid then cb(invalid); return end
    if data.mode ~= menu.navigation.type or data.fromPageId ~= menu.activePageId then cb({ ok = false, code = 'conflict' }); return end
    local visible, current, target = {}, nil, nil
    for _, item in ipairs(menu.navigation.pages) do
        if not item.hidden then
            visible[#visible + 1] = item
            if item.pageId == menu.activePageId then current = #visible end
            if item.pageId == data.toPageId then target = item end
        end
    end
    local allowed = target and not target.disabled
    if menu.navigation.type == 'tabs' then allowed = allowed and data.action == 'select'
    elseif data.action == 'finish' then allowed = current == #visible and current ~= nil and data.toPageId == nil
    elseif data.action == 'next' then allowed = allowed and current and visible[current + 1] == target
    elseif data.action == 'back' then allowed = allowed and current and visible[current - 1] == target
    elseif data.action == 'step' then allowed = allowed and menu.navigation.allowDirectStep ~= false
    else allowed = false end
    if not allowed then cb({ ok = false, code = 'invalid_input' }); return end
    if menu and menu.open and menu.navigation and menu.navigation.type == 'tabs' and menu.navigation.controlled ~= true
        and type(data.toPageId) == 'string' and menu.pages[data.toPageId] then
        local fromPageId = menu.activePageId
        menu.activePageId = data.toPageId
        Mutate(menu, { { op = 'page:activate', pageId = data.toPageId } })
        EmitLifecycle(menu, 'pageChanged', { fromPageId = fromPageId, pageId = data.toPageId })
    end
    if menu and menu.open and menu.navigationCallback then
        local ok, problem = Call(menu.navigationCallback, Copy(data))
        if not ok then print(('[%s] navigation callback failed: %s'):format(resourceName, tostring(problem))); cb({ ok = false, code = 'callback_failed' }); return end
    end
    cb({ ok = menu ~= nil })
end)

RegisterNUICallback('keyAction', function(data, cb)
    local menu = type(data) == 'table' and menus[data.menuId] or nil
    local callback = menu and menu.open and menu.keyCallbacks[data.key] or nil
    if callback then
        local ok, problem = Call(callback, { menuId = menu.id, key = data.key })
        if not ok then print(('[%s] key callback failed: %s'):format(resourceName, tostring(problem))) end
    end
    cb({ ok = callback ~= nil })
end)

AddEventHandler('onClientResourceStop', function(stopped)
    if stopped == resourceName then SetNuiFocusKeepInput(false); SetNuiFocus(false, false); return end
    for menuId, menu in pairs(menus) do
        if menu.owner == stopped then
            if activeMenuId == menuId then
                SetNuiFocusKeepInput(false)
                SetNuiFocus(false, false)
                activeMenuId = nil
            end
            menus[menuId] = nil
            if uiReady then Send('menu:destroy', { menuId = menuId }) end
        end
    end
end)

CreateThread(function()
    Wait(5000)
    if not uiReady then print(('[%s] NUI did not report ready after %dms. Verify compiled ui/index.html and ui/assets are present.'):format(resourceName, GetGameTimer() - startedAt)) end
end)

CreateThread(function()
    while true do
        Wait(0)
        if activeMenuId and IsPauseMenuActive() then
            local menu = menus[activeMenuId]
            if menu then
                pausedMenuId = menu.id
                menu.open = false
                activeMenuId = nil
                SetNuiFocusKeepInput(false)
                SetNuiFocus(false, false)
                Send('menu:close', { menuId = menu.id })
                EmitLifecycle(menu, 'suspended', { reason = 'pauseMenu' })
            end
        elseif pausedMenuId and not IsPauseMenuActive() then
            local menu = menus[pausedMenuId]
            pausedMenuId = nil
            if menu and not activeMenuId then
                menu.open = true
                activeMenuId = menu.id
                Sync(menu)
                Send('menu:open', { menuId = menu.id, pageId = menu.activePageId })
                SetNuiFocus(menu.focus.keyboard, menu.focus.cursor)
                SetNuiFocusKeepInput(false)
                EmitLifecycle(menu, 'resumed', { reason = 'pauseMenu' })
            end
        end
    end
end)

-- NUI focus alone does not consistently stop RedM controller actions. While a
-- Menu v2 window owns focus, suppress every gameplay control group each frame;
-- Chromium still receives its controller input for menu navigation.
CreateThread(function()
    while true do
        local menu = activeMenuId and menus[activeMenuId] or nil
        if menu and (menu.focus.keyboard or menu.focus.cursor) then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            Wait(0)
        else
            Wait(100)
        end
    end
end)

-- Recover lost NUI delivery without creating an unbounded resend loop.
CreateThread(function()
    while true do
        Wait(500)
        for _, menu in pairs(menus) do
            if menu.open and menu.sentAt and menu.ackRevision ~= menu.revision
                and GetGameTimer() - menu.sentAt >= 2000 and (menu.recoveryAttempts or 0) < 3 then
                menu.recoveryAttempts = (menu.recoveryAttempts or 0) + 1
                Sync(menu)
            end
        end
    end
end)
