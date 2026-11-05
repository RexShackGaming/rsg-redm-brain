SettingsProviders = {
    choices = {},
    onChanged = nil,
    revision = 0,
}

local function IsCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' and type(value) ~= 'userdata' then return false end
    local metatable = getmetatable(value)
    return type(metatable) == 'table' and type(metatable.__call) == 'function'
end

local function Finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end
local function Order(n)
    return n == nil or (Finite(n) and n % 1 == 0 and n >= -1000 and n <= 1000)
end
local function Copy(spec)
    local result = {}
    for key, value in pairs(spec) do result[key] = value end
    if spec.group then
        result.group = { key = spec.group.key, label = spec.group.label, order = spec.group.order }
    end
    if spec.options then
        result.options = {}
        for i, option in ipairs(spec.options) do
            result.options[i] = { value = option.value, label = option.label, disabled = option.disabled }
        end
    end
    return result
end
function SettingsProviders.ValidValue(spec, value)
    if spec.disabled == true then return false end
    if spec.control == 'slider' then
        if not Finite(value) or value < spec.min or value > spec.max then return false end
        local steps = (value - spec.min) / spec.step
        return Finite(steps) and math.abs(steps - math.floor(steps + 0.5)) <= 0.000001
    end
    for _, option in ipairs(spec.options or {}) do
        if option.value == value then return option.disabled ~= true end
    end
    return false
end
function SettingsProviders.Groups(visible)
    local ids, groups, byKey = {}, {}, {}

    for id in pairs(SettingsProviders.choices) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local provider = SettingsProviders.choices[id]
        if not visible or visible(provider) then
            local metadata = provider.spec.group
            local key = provider.owner .. '/' .. (metadata and metadata.key or '')
            local label = metadata and metadata.label or provider.owner
            local order = metadata and metadata.order or 0
            order = order or 0
            local group = byKey[key]
            if not group then
                group = { key = key, label = label, order = order, choices = {} }
                byKey[key], groups[#groups + 1] = group, group
            elseif (group.label ~= label or group.order ~= order) and SettingsProviders.diagnosticRevision ~= SettingsProviders.revision then
                SettingsProviders.diagnosticRevision = SettingsProviders.revision
                print('[feather-settings] conflicting group metadata: ' .. key)
            end
            group.choices[#group.choices + 1] = { id = id, provider = provider }
        end
    end
    table.sort(groups, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
    for _, group in ipairs(groups) do
        table.sort(group.choices, function(a, b)
            local ao, bo = a.provider.spec.order or 0, b.provider.spec.order or 0
            if ao ~= bo then return ao < bo end
            return a.id < b.id
        end)
    end
    return groups
end
local function IsChoiceSpecValid(spec)
    if type(spec) ~= 'table' or type(spec.id) ~= 'string' or spec.id == '' then return false, 'invalid id' end
    if #spec.id > 100 or not spec.id:match('^[%w%._:%-]+$') then return false, 'invalid id' end
    if type(spec.label) ~= 'string' or spec.label == '' then return false, 'invalid label' end
    if #spec.label > 100 then return false, 'invalid label' end
    if not Order(spec.order) then return false, 'invalid order' end
    if spec.disabled ~= nil and type(spec.disabled) ~= 'boolean' then return false, 'invalid disabled' end
    if spec.maxVisibleOptions ~= nil and (not Finite(spec.maxVisibleOptions) or spec.maxVisibleOptions % 1 ~= 0) then return false, 'invalid visible options' end
    if spec.group ~= nil then
        local g = spec.group
        if type(g) ~= 'table' or type(g.key) ~= 'string' or #g.key < 1 or #g.key > 64
            or not g.key:match('^[%w%._:%-]+$') or type(g.label) ~= 'string'
            or #g.label < 1 or #g.label > 100 or not Order(g.order) then return false, 'invalid group' end
    end
    local control = spec.control or 'dropdown'
    if control ~= 'dropdown' and control ~= 'arrows' and control ~= 'slider' then
        return false, 'invalid control'
    end
    if control == 'slider' then
        if not Finite(spec.min) or not Finite(spec.max) or spec.min >= spec.max
            or not Finite(spec.step) or spec.step <= 0 then return false, 'invalid slider bounds' end
    elseif type(spec.options) ~= 'table' or #spec.options < 2 or #spec.options > 20 then
        return false, 'invalid options'
    end
    local callbackPair = IsCallable(spec.getValue) and IsCallable(spec.setValue)
    local exportPair = type(spec.getExport) == 'string' and spec.getExport ~= ''
        and type(spec.setExport) == 'string' and spec.setExport ~= ''
    local eventPair = spec.initialValue ~= nil and type(spec.setEvent) == 'string'
        and spec.setEvent ~= '' and #spec.setEvent <= 150
    if not callbackPair and not exportPair and not eventPair then
        return false, ('invalid accessors get=%s set=%s getExport=%s setExport=%s setEvent=%s'):format(
            type(spec.getValue), type(spec.setValue), type(spec.getExport), type(spec.setExport), type(spec.setEvent))
    end
    if spec.isVisible ~= nil and not IsCallable(spec.isVisible) then return false, 'invalid visibility callback' end

    if control == 'slider' and not Finite((spec.max - spec.min) / spec.step) then return false, 'invalid slider span' end
    if spec.initialValue ~= nil then
        if control == 'slider' then
            if not Finite(spec.initialValue) or spec.initialValue < spec.min or spec.initialValue > spec.max then
                return false, 'invalid initial slider value'
            end
        elseif type(spec.initialValue) ~= 'string' or #spec.initialValue > 100 then
            return false, 'invalid initial option value'
        end
    end
    local values = {}
    for _, option in ipairs(spec.options or {}) do
        if type(option) ~= 'table' or type(option.value) ~= 'string'
            or type(option.label) ~= 'string' then return false, 'invalid option entry' end
        if option.value == '' or #option.value > 100 or option.label == '' or #option.label > 100 then
            return false, 'invalid option entry'
        end
        if option.disabled ~= nil and type(option.disabled) ~= 'boolean' then return false, 'invalid disabled option' end
        if values[option.value] then return false, 'duplicate option value' end
        values[option.value] = true
    end
    return true, nil
end

local function RemoveChoice(id, invokingResource)
    local registered = SettingsProviders.choices[id]
    if not registered then return false end
    if invokingResource and registered.owner ~= invokingResource then return false end

    SettingsProviders.revision = SettingsProviders.revision + 1
    SettingsProviders.choices[id] = nil
    if SettingsProviders.onChanged then SettingsProviders.onChanged(id) end
    return true
end

exports('RegisterChoice', function(spec)
    local invokingResource = GetInvokingResource()
    local declaredOwner = type(spec) == 'table' and spec.ownerResource or nil
    if invokingResource and declaredOwner and invokingResource ~= declaredOwner then
        return false, 'owner does not match invoking resource'
    end
    local owner = invokingResource or declaredOwner
    if type(owner) ~= 'string' or owner == '' then return false, 'owner unavailable' end
    local valid, reason = IsChoiceSpecValid(spec)
    if not valid then return false, reason end

    local existing = SettingsProviders.choices[spec.id]
    if existing and existing.owner ~= owner then return false, 'choice belongs to another resource' end

    SettingsProviders.revision = SettingsProviders.revision + 1
    SettingsProviders.choices[spec.id] = {
        owner = owner,
        spec = Copy(spec),
        value = spec.initialValue,
    }
    if SettingsProviders.onChanged then SettingsProviders.onChanged(spec.id) end
    return true, nil
end)

exports('UnregisterChoice', function(id, ownerResource)
    local invokingResource = GetInvokingResource()
    if invokingResource and ownerResource and invokingResource ~= ownerResource then return false end
    return RemoveChoice(id, invokingResource or ownerResource)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    local removed = {}
    for id, registered in pairs(SettingsProviders.choices) do
        if registered.owner == resourceName then removed[#removed + 1] = id end
    end
    for _, id in ipairs(removed) do RemoveChoice(id, resourceName) end
end)
