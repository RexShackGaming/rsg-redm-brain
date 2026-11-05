MenuValidation = {}

local allowedElementTypes = {
    header = true, subheader = true, line = true, bottomline = true,
    button = true, input = true, textarea = true, slider = true,
    arrows = true, toggle = true, checkbox = true, dropdown = true,
    gridslider = true, imagebox = true, imageboxcontainer = true,
    pagearrows = true, textdisplay = true, radio = true, number = true,
    progress = true, spacer = true, colorpicker = true, accordion = true,
}

local optionTypes = { arrows = true, dropdown = true, radio = true, colorpicker = true }
local stringValueTypes = { header = true, subheader = true, textdisplay = true, input = true, textarea = true }
local numericValueTypes = { slider = true, number = true, progress = true }
local booleanValueTypes = { toggle = true, checkbox = true, accordion = true }
local slots = { header = true, content = true, footer = true }
local spacerSizes = { small = true, medium = true, large = true }
local imageObjectFits = { cover = true, contain = true, fill = true, none = true, ['scale-down'] = true }

local function Err(path, message, details)
    details = details or {}
    details.path = path
    return MenuResults.Err('invalid_input', path .. ' ' .. message, details)
end

local function Count(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
    seen[value] = nil
    return result
end

local function Merge(target, changes)
    for key, value in pairs(changes) do
        if type(value) == 'table' and type(target[key]) == 'table' and key ~= 'options' and key ~= 'items' and key ~= 'pages' then Merge(target[key], value)
        else target[key] = Copy(value) end
    end
end

MenuValidation.Merge = Merge
MenuValidation.Copy = Copy

function MenuValidation.Id(value, path)
    if type(value) ~= 'string' or value == '' or #value > 128 or not value:match('^[%w%._:%-/]+$') then
        return Err(path or 'key', 'must be 1-128 safe characters.')
    end
    return nil
end

function MenuValidation.ElementType(value)
    if type(value) ~= 'string' or not allowedElementTypes[value] then
        return MenuResults.Err('unsupported_element', 'Unsupported element type.', { elementType = value })
    end
    return nil
end

function MenuValidation.Handle(value, path)
    if type(value) ~= 'string' or #value == 0 or #value > 1024 or not value:match('^[%w%._:%-/]+$') then
        return Err(path, 'must be a returned menu/page handle.')
    end
end

function MenuValidation.Table(value, path)
    if type(value) ~= 'table' then return Err(path or 'value', 'must be a table.') end
    return nil
end

function MenuValidation.Finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function MenuValidation.Payload(value, path, limits)
    limits = limits or {}
    local maxDepth = limits.maxDepth or 6
    local maxEntries = limits.maxEntries or 4096
    local maxString = limits.maxString or 4096
    local entries, seen = 0, {}
    local function Visit(child, childPath, depth)
        local kind = type(child)
        if kind == 'string' then
            if #child > maxString then return Err(childPath, ('exceeds %d characters.'):format(maxString)) end
            return nil
        end
        if kind == 'number' then
            if not MenuValidation.Finite(child) then return Err(childPath, 'must be a finite number.') end
            return nil
        end
        if kind == 'nil' or kind == 'boolean' then return nil end
        if kind ~= 'table' then return Err(childPath, 'contains an unsupported value type.', { valueType = kind }) end
        if seen[child] then return Err(childPath, 'must not contain cycles.') end
        if depth > maxDepth then return Err(childPath, ('exceeds maximum depth %d.'):format(maxDepth)) end
        seen[child] = true
        for key, nested in pairs(child) do
            entries = entries + 1
            if entries > maxEntries then return Err(path, ('exceeds %d total fields.'):format(maxEntries)) end
            if type(key) ~= 'string' and type(key) ~= 'number' then return Err(childPath, 'contains an unsupported key type.') end
            if type(key) == 'string' and #key > 128 then return Err(childPath, 'contains an oversized field name.') end
            if type(key) == 'number' and (not MenuValidation.Finite(key) or key < 1 or key % 1 ~= 0) then return Err(childPath, 'array keys must be positive integers.') end
            if key == '__proto__' or key == 'prototype' or key == 'constructor' then return Err(childPath .. '.' .. key, 'is reserved.') end
            local problem = Visit(nested, childPath .. '.' .. tostring(key), depth + 1)
            if problem then return problem end
        end
        seen[child] = nil
        return nil
    end
    return Visit(value, path or 'value', 0)
end

local function OptionalString(spec, key, path, maxLength)
    local value = spec[key]
    if value == nil then return nil end
    if type(value) ~= 'string' or #value > maxLength then return Err(path .. '.' .. key, ('must be a string up to %d characters.'):format(maxLength)) end
end

local function OptionalBoolean(spec, key, path)
    if spec[key] ~= nil and type(spec[key]) ~= 'boolean' then return Err(path .. '.' .. key, 'must be boolean.') end
end

local function OptionalFinite(spec, key, path)
    if spec[key] ~= nil and not MenuValidation.Finite(spec[key]) then return Err(path .. '.' .. key, 'must be a finite number.') end
end

local function ValidateOptions(spec, path)
    if type(spec.options) ~= 'table' then return Err(path .. '.options', 'must be an array.') end
    if #spec.options == 0 or #spec.options > 500 or Count(spec.options) ~= #spec.options then
        return Err(path .. '.options', 'must contain 1-500 sequential entries.')
    end
    local values = { string = {}, number = {}, boolean = {} }
    for index, option in ipairs(spec.options) do
        local optionPath = path .. '.options.' .. index
        local value = option
        if type(option) == 'table' then
            value = option.value
            local problem = OptionalString(option, 'label', optionPath, 256)
                or OptionalString(option, 'text', optionPath, 256)
                or OptionalBoolean(option, 'disabled', optionPath)
            if problem then return problem end
        end
        local valueType = type(value)
        if valueType ~= 'string' and valueType ~= 'number' and valueType ~= 'boolean' then
            return Err(optionPath .. '.value', 'must be a string, finite number, or boolean.')
        end
        if valueType == 'number' and not MenuValidation.Finite(value) then return Err(optionPath .. '.value', 'must be finite.') end
        if valueType == 'string' and #value > 256 then return Err(optionPath .. '.value', 'exceeds 256 characters.') end
        if values[valueType][value] then return Err(optionPath .. '.value', 'must be unique.') end
        values[valueType][value] = true
    end
end

function MenuValidation.Menu(spec, path, requireKey)
    path = path or 'spec'
    local problem = MenuValidation.Table(spec, path) or MenuValidation.Payload(spec, path)
    if problem then return problem end
    if requireKey then problem = MenuValidation.Id(spec.key, path .. '.key'); if problem then return problem end end
    for _, key in ipairs({ 'draggable', 'resizable', 'closable', 'persistPosition', 'persistSize' }) do
        problem = OptionalBoolean(spec, key, path); if problem then return problem end
    end
    if spec.position ~= nil and type(spec.position) ~= 'table' then return Err(path .. '.position', 'must be a table.') end
    if spec.size ~= nil and type(spec.size) ~= 'table' then return Err(path .. '.size', 'must be a table.') end
    if spec.theme ~= nil and type(spec.theme) ~= 'table' then return Err(path .. '.theme', 'must be a table.') end
    return nil
end

function MenuValidation.Page(spec, path, requireKey)
    path = path or 'spec'
    local problem = MenuValidation.Table(spec, path) or MenuValidation.Payload(spec, path)
    if problem then return problem end
    if requireKey then return MenuValidation.Id(spec.key, path .. '.key') end
    return nil
end

function MenuValidation.Element(elementType, spec, path)
    path = path or 'spec'
    local problem = MenuValidation.ElementType(elementType) or MenuValidation.Table(spec, path)
        or MenuValidation.Payload(spec, path) or MenuValidation.Id(spec.key, path .. '.key')
    if problem then return problem end
    problem = OptionalString(spec, 'label', path, 256) or OptionalString(spec, 'placeholder', path, 256)
        or OptionalString(spec, 'onLabel', path, 64) or OptionalString(spec, 'offLabel', path, 64)
        or OptionalBoolean(spec, 'disabled', path) or OptionalBoolean(spec, 'persist', path)
    if problem then return problem end
    if spec.slot ~= nil and not slots[spec.slot] then return Err(path .. '.slot', 'must be header, content, or footer.') end
    if spec.row ~= nil then
        problem = MenuValidation.Id(spec.row, path .. '.row')
        if problem then return problem end
    end

    if stringValueTypes[elementType] and spec.value ~= nil then
        local maximum = (elementType == 'textarea' or elementType == 'textdisplay') and 4096 or 512
        if type(spec.value) ~= 'string' or #spec.value > maximum then return Err(path .. '.value', ('must be a string up to %d characters.'):format(maximum)) end
    end
    if booleanValueTypes[elementType] and spec.value ~= nil and type(spec.value) ~= 'boolean' then return Err(path .. '.value', 'must be boolean.') end
    if numericValueTypes[elementType] then
        for _, key in ipairs({ 'value', 'min', 'max', 'step' }) do problem = OptionalFinite(spec, key, path); if problem then return problem end end
        local minimum, maximum = spec.min or 0, spec.max or 100
        if minimum > maximum then return Err(path .. '.min', 'must not exceed max.') end
        if spec.step ~= nil and spec.step <= 0 then return Err(path .. '.step', 'must be greater than zero.') end
        if spec.value ~= nil and (spec.value < minimum or spec.value > maximum) then return Err(path .. '.value', 'must be within min and max.') end
    end
    if optionTypes[elementType] then
        problem = ValidateOptions(spec, path); if problem then return problem end
        if spec.value == nil then return Err(path .. '.value', 'is required for this choice element.') end
        local selected = false
        for _, option in ipairs(spec.options) do
            local optionValue = option
            if type(option) == 'table' then optionValue = option.value end
            if type(optionValue) == type(spec.value) and optionValue == spec.value then selected = true; break end
        end
        if not selected then return Err(path .. '.value', 'must match one of the option values.') end
        if elementType == 'dropdown' and spec.maxVisibleOptions ~= nil then
            if not MenuValidation.Finite(spec.maxVisibleOptions) or spec.maxVisibleOptions % 1 ~= 0
                or spec.maxVisibleOptions < 3 or spec.maxVisibleOptions > 10 then
                return Err(path .. '.maxVisibleOptions', 'must be an integer from 3 through 10.')
            end
        end
    end
    if elementType == 'gridslider' then
        if type(spec.value) ~= 'table' then return Err(path .. '.value', 'must contain x and y.') end
        local maxx, maxy = spec.maxx or 1, spec.maxy or 1
        if not MenuValidation.Finite(maxx) or maxx <= 0 or not MenuValidation.Finite(maxy) or maxy <= 0 then return Err(path, 'grid bounds must be positive finite numbers.') end
        if not MenuValidation.Finite(spec.value.x) or not MenuValidation.Finite(spec.value.y)
            or spec.value.x < 0 or spec.value.x > maxx or spec.value.y < 0 or spec.value.y > maxy then
            return Err(path .. '.value', 'x and y must be finite and within grid bounds.')
        end
        for _, key in ipairs({ 'step', 'stepx', 'stepy' }) do
            if spec[key] ~= nil and (not MenuValidation.Finite(spec[key]) or spec[key] <= 0) then
                return Err(path .. '.' .. key, 'must be a positive finite number.')
            end
        end
    end
    if elementType == 'pagearrows' then
        if not MenuValidation.Finite(spec.current) or not MenuValidation.Finite(spec.total)
            or spec.current % 1 ~= 0 or spec.total % 1 ~= 0 or spec.total < 1 or spec.current < 1 or spec.current > spec.total then
            return Err(path, 'page arrows require integer current/total with 1 <= current <= total.')
        end
    end
    if elementType == 'imageboxcontainer' then
        if type(spec.items) ~= 'table' or #spec.items == 0 or #spec.items > 100 or Count(spec.items) ~= #spec.items then
            return Err(path .. '.items', 'must contain 1-100 sequential entries.')
        end
        for index, item in ipairs(spec.items) do
            if type(item) ~= 'table' then return Err(path .. '.items.' .. index, 'must be a table.') end
            problem = OptionalString(item, 'label', path .. '.items.' .. index, 256)
                or OptionalString(item, 'image', path .. '.items.' .. index, 2048)
                or OptionalString(item, 'img', path .. '.items.' .. index, 2048)
                or OptionalBoolean(item, 'disabled', path .. '.items.' .. index)
            if problem then return problem end
        end
    end
    if elementType == 'spacer' and spec.size ~= nil and not spacerSizes[spec.size] then return Err(path .. '.size', 'must be small, medium, or large.') end
    return nil
end

function MenuValidation.ElementChanges(elementType, current, changes, path)
    local problem = MenuValidation.Table(changes, path or 'changes') or MenuValidation.Payload(changes, path or 'changes')
    if problem then return problem end
    local candidate = Copy(current)
    Merge(candidate, changes)
    return MenuValidation.Element(elementType, candidate, path or 'changes')
end

function MenuValidation.Navigation(spec, path)
    path = path or 'spec'
    local problem = MenuValidation.Table(spec, path) or MenuValidation.Payload(spec, path)
    if problem then return problem end
    if spec.type ~= 'tabs' and spec.type ~= 'stepper' then return Err(path .. '.type', 'must be tabs or stepper.') end
    if type(spec.pages) ~= 'table' or #spec.pages == 0 or #spec.pages > 64 or Count(spec.pages) ~= #spec.pages then
        return Err(path .. '.pages', 'must contain 1-64 sequential entries.')
    end
    local ids = {}
    for index, page in ipairs(spec.pages) do
        if type(page) ~= 'table' then return Err(path .. '.pages.' .. index, 'must be a table.') end
        problem = MenuValidation.Handle(page.pageId, path .. '.pages.' .. index .. '.pageId')
            or OptionalString(page, 'label', path .. '.pages.' .. index, 128)
            or OptionalBoolean(page, 'disabled', path .. '.pages.' .. index)
            or OptionalBoolean(page, 'hidden', path .. '.pages.' .. index)
        if problem then return problem end
        if ids[page.pageId] then return Err(path .. '.pages.' .. index .. '.pageId', 'must be unique.') end
        ids[page.pageId] = true
    end
    return nil
end

-- Contract field allowlists: a typo is an error, rather than an ignored setting.
local function Fields(spec, names, path)
    if type(spec) ~= 'table' then return Err(path, 'must be a table.') end
    local allowed = {}
    for name in names:gmatch('%S+') do allowed[name] = true end
    for name in pairs(spec) do
        if not allowed[name] then return Err(path .. '.' .. tostring(name), 'is not a supported field.') end
    end
end
MenuValidation.Fields = Fields

function MenuValidation.Bytes(value, path, maximum)
    local problem = MenuValidation.Payload(value, path)
    if problem then return problem end
    if json and json.encode then
        local ok, encoded = pcall(json.encode, value)
        if not ok then return Err(path, 'cannot be encoded as JSON.') end
        if #encoded > (maximum or 65536) then return Err(path, 'exceeds the encoded byte budget.') end
    end
end

local function Length(value, path, allowAuto)
    if allowAuto and value == 'auto' then return nil end
    if type(value) ~= 'string' then return Err(path, 'must be a CSS length string.') end
    local amount, unit = value:match('^(%d+%.?%d*)([%a%%]+)$')
    amount = tonumber(amount)
    local bounds = { px = 8192, rem = 512, ['%'] = 100, vw = 100, vh = 100 }
    if not amount or not bounds[unit] or amount > bounds[unit] then
        return Err(path, 'must be a non-negative bounded px, rem, %, vw, or vh length.')
    end
end

local function Color(value, path)
    if type(value) ~= 'string' or #value > 64 then return Err(path, 'must be a bounded color string.') end
    if value == 'transparent' or value == 'black' or value == 'white' then return nil end
    if value:match('^#%x+$') and (#value == 4 or #value == 5 or #value == 7 or #value == 9) then return nil end
    local r, g, b = value:match('^rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)$')
    local alpha
    if not r then r, g, b, alpha = value:match('^rgba%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*([%d%.]+)%s*%)$') end
    if r and tonumber(r) <= 255 and tonumber(g) <= 255 and tonumber(b) <= 255
        and (not alpha or (tonumber(alpha) and tonumber(alpha) >= 0 and tonumber(alpha) <= 1)) then return nil end
    return Err(path, 'must be hex, rgb(), rgba(), transparent, black, or white.')
end

function MenuValidation.Sound(spec, path)
    local problem = Fields(spec, 'action soundset', path)
    if problem then return problem end
    for _, key in ipairs({ 'action', 'soundset' }) do
        if type(spec[key]) ~= 'string' or #spec[key] == 0 or #spec[key] > 128 or not spec[key]:match('^[%w_%-]+$') then
            return Err(path .. '.' .. key, 'must be a 1-128 character frontend sound identifier.')
        end
    end
end

local function Asset(value, path)
    if type(value) ~= 'string' or #value == 0 or #value > 2048 then return Err(path, 'must be an asset path.') end
    if value:find('..', 1, true) or value:find('[%s\\<>"\'()]') then return Err(path, 'contains unsafe path characters.') end
    if value:match('^https://cfx%-nui%-[%w_%-]+/[%w_%.%/%-]+$') then return nil end
    if value:match('^[%w_][%w_%.%/%-]*$') then return nil end
    return Err(path, 'must be a relative path or https://cfx-nui-RESOURCE/path; remote and data URLs are excluded.')
end

local baseMenu, basePage, baseElement, baseNavigation = MenuValidation.Menu, MenuValidation.Page, MenuValidation.Element, MenuValidation.Navigation

function MenuValidation.Menu(spec, path, requireKey)
    path = path or 'spec'
    local problem = baseMenu(spec, path, requireKey)
        or Fields(spec, 'key draggable resizable closable persistPosition persistSize position size theme focus controller', path)
    if problem then return problem end
    problem = OptionalBoolean(spec, 'controller', path)
    if problem then return problem end
    if spec.focus ~= nil then
        problem = Fields(spec.focus, 'keyboard cursor', path .. '.focus')
            or OptionalBoolean(spec.focus, 'keyboard', path .. '.focus') or OptionalBoolean(spec.focus, 'cursor', path .. '.focus')
        if problem then return problem end
    end
    if spec.position then
        problem = Fields(spec.position, 'x y anchor', path .. '.position'); if problem then return problem end
        for key, value in pairs(spec.position) do
            if key == 'anchor' then
                if value ~= 'center' and value ~= 'top-left' then return Err(path .. '.position.anchor', 'must be center or top-left.') end
            else problem = Length(value, path .. '.position.' .. key); if problem then return problem end end
        end
    end
    if spec.size then
        problem = Fields(spec.size, 'width height minWidth maxWidth minHeight maxHeight breakpoints', path .. '.size'); if problem then return problem end
        for key, value in pairs(spec.size) do
            if key == 'breakpoints' then
                problem = Fields(value, '720 1080 1440 2160', path .. '.size.breakpoints'); if problem then return problem end
                for breakpoint, width in pairs(value) do problem = Length(width, path .. '.size.breakpoints.' .. breakpoint); if problem then return problem end end
            else problem = Length(value, path .. '.size.' .. key, key == 'height' or key == 'minHeight'); if problem then return problem end end
        end
    end
    if spec.theme then
        problem = Fields(spec.theme, 'preset accent background panel text muted radius fontFamily', path .. '.theme'); if problem then return problem end
        for key, value in pairs(spec.theme) do
            if key == 'preset' then
                if value ~= 'redemption' then return Err(path .. '.theme.preset', 'must be redemption.') end
            elseif key == 'radius' then problem = Length(value, path .. '.theme.radius')
            elseif key == 'fontFamily' then
                local fonts={['Georgia, serif']=true,['Arial, sans-serif']=true,monospace=true,
                    rdr=true,RDRLino=true,RDRGothica=true,RDRCatalogueBold=true,HapnaSlabSerif=true,
                    Redemption=true,WWI=true,Cherolina=true,AncientAd=true}
                if not fonts[value] then return Err(path .. '.theme.fontFamily', 'must be a documented bundled font or local font stack.') end
            else problem = Color(value, path .. '.theme.' .. key) end
            if problem then return problem end
        end
    end
    return MenuValidation.Bytes(spec, path)
end

function MenuValidation.Page(spec, path, requireKey)
    return basePage(spec, path, requireKey) or Fields(spec, 'key', path or 'spec')
end

local elementFields = {
    header = 'value', subheader = 'value', textdisplay = 'value', line = '', bottomline = '',
    button = 'value sound busy busyLabel confirm', input = 'value placeholder maxLength error', textarea = 'value placeholder maxLength rows error',
    number = 'value min max step placeholder error', slider = 'value min max step', progress = 'value min max step text',
    toggle = 'value onLabel offLabel sound', checkbox = 'value onLabel offLabel sound',
    arrows = 'value options sound', dropdown = 'value options placeholder emptyText maxVisibleOptions sound',
    radio = 'value options sound', colorpicker = 'value options sound',
    gridslider = 'value maxx maxy step stepx stepy sound', pagearrows = 'current total sound',
    imagebox = 'value image img alt width height aspectRatio objectFit sound', imageboxcontainer = 'items sound', spacer = 'size', accordion = 'value labelAlign notify selected',
}

local function ImageSizing(spec, path)
    local problem
    for _, key in ipairs({ 'width', 'height' }) do
        if spec[key] ~= nil then
            problem = Length(spec[key], path .. '.' .. key, true)
            if problem then return problem end
        end
    end
    if spec.objectFit ~= nil and not imageObjectFits[spec.objectFit] then
        return Err(path .. '.objectFit', 'must be cover, contain, fill, none, or scale-down.')
    end
    if spec.aspectRatio ~= nil then
        if type(spec.aspectRatio) ~= 'string' then return Err(path .. '.aspectRatio', 'must be a ratio such as 16/9.') end
        local width, height = spec.aspectRatio:match('^(%d+%.?%d*)/(%d+%.?%d*)$')
        width, height = tonumber(width), tonumber(height)
        if not width or not height or width <= 0 or height <= 0 or width > 100 or height > 100 then
            return Err(path .. '.aspectRatio', 'must contain positive values no greater than 100, such as 16/9.')
        end
    end
end

function MenuValidation.Element(elementType, spec, path)
    path = path or 'spec'
    local problem = baseElement(elementType, spec, path)
    if problem then return problem end
    problem = Fields(spec, 'key slot row label disabled persist section ' .. elementFields[elementType], path)
    if problem then return problem end
    if spec.section ~= nil then
        problem = MenuValidation.Id(spec.section, path .. '.section')
        if problem then return problem end
        if elementType == 'accordion' or spec.slot == 'header' or spec.slot == 'footer' then
            return Err(path .. '.section', 'is only allowed on content elements outside an accordion header.')
        end
    end
    if elementType == 'accordion' then
        if spec.labelAlign ~= nil and spec.labelAlign ~= 'left' and spec.labelAlign ~= 'center' then return Err(path .. '.labelAlign', 'must be left or center.') end
        problem = OptionalBoolean(spec, 'notify', path) or OptionalBoolean(spec, 'selected', path); if problem then return problem end
        if not spec.label or spec.label == '' then return Err(path .. '.label', 'is required.') end
        if spec.slot == 'header' or spec.slot == 'footer' or spec.row ~= nil then
            return Err(path, 'accordion must be an ungrouped content element.')
        end
    end
    if elementType == 'button' then
        problem = OptionalBoolean(spec, 'busy', path) or OptionalString(spec, 'busyLabel', path, 256)
        if problem then return problem end
        if spec.confirm ~= nil then
            problem = Fields(spec.confirm, 'title message confirmLabel cancelLabel', path .. '.confirm'); if problem then return problem end
            for _, key in ipairs({'title', 'message', 'confirmLabel', 'cancelLabel'}) do
                if type(spec.confirm[key]) ~= 'string' or #spec.confirm[key] == 0 or #spec.confirm[key] > 512 then return Err(path .. '.confirm.' .. key, 'requires 1-512 bytes of localized text.') end
            end
        end
    end
    problem = OptionalString(spec, 'error', path, 512); if problem then return problem end
    if spec.sound ~= nil then problem = MenuValidation.Sound(spec.sound, path .. '.sound'); if problem then return problem end end
    for _, key in ipairs({ 'alt', 'text', 'emptyText' }) do problem = OptionalString(spec, key, path, 256); if problem then return problem end end
    if spec.maxLength ~= nil then
        local maximum = elementType == 'textarea' and 4096 or 512
        if not MenuValidation.Finite(spec.maxLength) or spec.maxLength % 1 ~= 0 or spec.maxLength < 1 or spec.maxLength > maximum then return Err(path .. '.maxLength', 'is outside the text length limit.') end
        if spec.value and #spec.value > spec.maxLength then return Err(path .. '.value', 'exceeds maxLength.') end
    end
    if spec.rows ~= nil and (not MenuValidation.Finite(spec.rows) or spec.rows % 1 ~= 0 or spec.rows < 1 or spec.rows > 20) then return Err(path .. '.rows', 'must be an integer from 1 through 20.') end
    for _, key in ipairs({ 'image', 'img' }) do if spec[key] ~= nil then problem = Asset(spec[key], path .. '.' .. key); if problem then return problem end end end
    if elementType == 'imagebox' and not spec.image and not spec.img then return Err(path .. '.image', 'is required.') end
    if elementType == 'imagebox' then problem = ImageSizing(spec, path); if problem then return problem end end
    if elementType == 'gridslider' then problem = Fields(spec.value, 'x y', path .. '.value'); if problem then return problem end end
    if optionTypes[elementType] then
        for index, option in ipairs(spec.options) do
            if type(option) == 'table' then
                problem = Fields(option, 'value label text disabled' .. (elementType == 'colorpicker' and ' color' or ''), path .. '.options.' .. index)
                if problem then return problem end
            end
            if elementType == 'colorpicker' then
                local color = type(option) == 'table' and (option.color or option.value) or option
                problem = Color(color, path .. '.options.' .. index); if problem then return problem end
            end
        end
    end
    if elementType == 'imageboxcontainer' then
        local identities = { string = {}, number = {}, boolean = {} }
        for index, item in ipairs(spec.items) do
            local itemPath = path .. '.items.' .. index
            problem = Fields(item, 'key value label image img alt disabled width height aspectRatio objectFit', itemPath)
                or OptionalString(item, 'alt', itemPath, 256)
            if problem then return problem end
            if item.key ~= nil then problem = MenuValidation.Id(item.key, itemPath .. '.key'); if problem then return problem end end
            local kind = type(item.value)
            if kind ~= 'string' and kind ~= 'number' and kind ~= 'boolean' then return Err(itemPath .. '.value', 'must be a scalar value.') end
            if identities[kind][item.value] then return Err(itemPath .. '.value', 'must be unique.') end
            identities[kind][item.value] = true
            if not item.image and not item.img then return Err(itemPath .. '.image', 'is required.') end
            for _, key in ipairs({ 'image', 'img' }) do if item[key] then problem = Asset(item[key], itemPath .. '.' .. key); if problem then return problem end end end
            problem = ImageSizing(item, itemPath); if problem then return problem end
        end
    end
    return MenuValidation.Bytes(spec, path)
end

function MenuValidation.Navigation(spec, path)
    path = path or 'spec'
    local problem = baseNavigation(spec, path) or Fields(spec, 'type pages controlled allowDirectStep backLabel nextLabel finishLabel', path)
    if problem then return problem end
    for _, key in ipairs({ 'controlled', 'allowDirectStep' }) do problem = OptionalBoolean(spec, key, path); if problem then return problem end end
    for _, key in ipairs({ 'backLabel', 'nextLabel', 'finishLabel' }) do problem = OptionalString(spec, key, path, 128); if problem then return problem end end
    for index, page in ipairs(spec.pages) do
        local pagePath = path .. '.pages.' .. index
        problem = Fields(page, 'pageId label hidden disabled complete invalid', pagePath)
            or OptionalBoolean(page, 'complete', pagePath) or OptionalBoolean(page, 'invalid', pagePath)
        if problem then return problem end
    end
    return MenuValidation.Bytes(spec, path)
end

function MenuValidation.OpenOptions(spec, closeOnly)
    local problem = Fields(spec, closeOnly and 'sound' or 'pageId keyboard cursor replace sound', 'options')
    if problem then return problem end
    if spec.pageId ~= nil then problem = MenuValidation.Handle(spec.pageId, 'options.pageId'); if problem then return problem end end
    for _, key in ipairs({ 'keyboard', 'cursor', 'replace' }) do problem = OptionalBoolean(spec, key, 'options'); if problem then return problem end end
    if spec.sound ~= nil then return MenuValidation.Sound(spec.sound, 'options.sound') end
end

function MenuValidation.FocusOptions(spec)
    local problem = Fields(spec, 'keyboard cursor', 'options')
    if problem then return problem end
    for _, key in ipairs({ 'keyboard', 'cursor' }) do
        problem = OptionalBoolean(spec, key, 'options')
        if problem then return problem end
    end
end

function MenuValidation.ElementAction(element, event)
    local spec, kind = element.data, element.type
    local problem = Fields(event, 'menuId pageId elementId event value meta revision', 'event') or MenuValidation.Bytes(event, 'event')
    if problem then return problem end
    local action = event.event
    if kind == 'button' or kind == 'imagebox' then
        if action ~= 'activate' then return Err('event.event', 'must be activate.') end
    elseif kind == 'imageboxcontainer' then
        if action ~= 'child' then return Err('event.event', 'must be child.') end
        for _, item in ipairs(spec.items) do
            if item.value == event.value and not item.disabled then return nil end
        end
        return Err('event.value', 'must identify an enabled child.')
    elseif kind == 'pagearrows' then
        if action == 'previous' and event.value == -1 and spec.current > 1 then return nil end
        if action == 'next' and event.value == 1 and spec.current < spec.total then return nil end
        return Err('event.event', 'is outside the page boundaries.')
    elseif stringValueTypes[kind] and kind ~= 'input' and kind ~= 'textarea' or kind == 'progress' or kind == 'spacer' or kind == 'line' or kind == 'bottomline' then
        return Err('event.event', 'is not supported by a display element.')
    else
        if action ~= 'change' or event.value == nil then return Err('event.event', 'requires change and a value.') end
        problem = MenuValidation.ElementChanges(kind, spec, { value = event.value }, 'event')
        if problem then return problem end
        if optionTypes[kind] then
            for _, option in ipairs(spec.options) do
                if type(option) == 'table' and option.value == event.value and option.disabled then return Err('event.value', 'is disabled.') end
            end
        end
    end
end
