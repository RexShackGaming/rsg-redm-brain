-----------------------------------------------------------------------------------------------
-- custom leather & gold NUI: context menus + input dialogs
-----------------------------------------------------------------------------------------------
local registeredContexts = {}
local contextStack = {}
local pendingModalCallback = nil

local function UiLabels()
    return {
        select  = locale('ui_select'),
        cancel  = locale('ui_cancel'),
        confirm = locale('ui_confirm'),
        close   = locale('ui_close'),
        back    = locale('ui_back'),
    }
end

-----------------------------------------------------------------------------------------------
-- context menus
-- def = { id, title, subtitle?, menu?, onBack?, options = { { title, description?, icon?,
--         event?, args?, arrow?, disabled?, progress?, colorScheme?, badge? } } }
-----------------------------------------------------------------------------------------------
function OpenContext(def)
    if def and def.id then registeredContexts[def.id] = def end
end

local function renderContext(id)
    local def = registeredContexts[id]
    if not def then return end

    -- strip functions/args before sending to NUI
    local options = {}
    for i, o in ipairs(def.options or {}) do
        options[i] = {
            title = o.title, description = o.description, icon = o.icon, arrow = o.arrow,
            disabled = o.disabled, progress = o.progress, colorScheme = o.colorScheme,
            badge = o.badge, selectable = o.event ~= nil,
        }
    end

    SendNUIMessage({
        action    = 'openContext',
        title     = def.title,
        subtitle  = def.subtitle,
        canGoBack = #contextStack > 1,
        options   = options,
        labels    = UiLabels(),
    })
end

function ShowContext(id)
    if not registeredContexts[id] then return end
    if registeredContexts[id].menu and #contextStack > 0 then
        contextStack[#contextStack + 1] = id
    else
        contextStack = { id }
    end
    renderContext(id)
    SetNuiFocus(true, true)
end

function HideContext()
    contextStack = {}
    SendNUIMessage({ action = 'closeContext' })
    SetNuiFocus(false, false)
end

RegisterNUICallback('contextSelect', function(data, cb)
    cb({})
    local id = contextStack[#contextStack]
    local def = id and registeredContexts[id]
    local option = def and def.options and def.options[(tonumber(data.index) or -1) + 1]
    if not option or not option.event or option.disabled then return end

    -- close first (unless it opens a sub-menu) so the panel isn't left under a modal
    if not option.arrow then HideContext() end
    TriggerEvent(option.event, option.args)
end)

RegisterNUICallback('contextBack', function(_, cb)
    cb({})
    if #contextStack > 1 then
        local closing = registeredContexts[table.remove(contextStack)]
        if closing and closing.onBack then closing.onBack() end
        renderContext(contextStack[#contextStack])
    else
        HideContext()
    end
end)

RegisterNUICallback('contextClose', function(_, cb)
    cb({})
    HideContext()
end)

-----------------------------------------------------------------------------------------------
-- input dialog (callback based)
-- fields = { { label, description?, type = 'input'|'number'|'select', options?, required?,
--             default?, min?, max?, maxLength? } }
-- callback(values | nil)
-----------------------------------------------------------------------------------------------
function OpenInputDialog(title, fields, callback)
    -- cancel any dialog that is still open so its callback never leaks
    if pendingModalCallback then pendingModalCallback(nil) end
    pendingModalCallback = callback

    SendNUIMessage({ action = 'openModal', title = title, fields = fields, labels = UiLabels() })
    SetNuiFocus(true, true)
end

local function resolveModal(values)
    SetNuiFocus(false, false)
    local callback = pendingModalCallback
    pendingModalCallback = nil
    if callback then callback(values) end
end

RegisterNUICallback('modalSubmit', function(data, cb)
    cb({})
    resolveModal(type(data.values) == 'table' and data.values or nil)
end)

RegisterNUICallback('modalCancel', function(_, cb)
    cb({})
    resolveModal(nil)
end)
