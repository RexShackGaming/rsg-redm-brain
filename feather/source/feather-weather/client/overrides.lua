-- Pure bounded handle arbitration; ownership comes from the invoking resource.
WeatherOverrides = {}
local O, W = WeatherOverrides, Weather
O.__index = O
local function SamePresentation(left, right)
    for _, key in ipairs({'clock','weather','wind','snow','priority'}) do
        local a, b = left[key], right[key]
        if type(a) == 'table' and type(b) == 'table' then
            for field, value in pairs(a) do if b[field] ~= value then return false end end
            for field, value in pairs(b) do if a[field] ~= value then return false end end
        elseif a ~= b then return false end
    end
    return true
end
function O.New(config, epoch)
    return setmetatable({ config=config, epoch=epoch, handles={}, serial=0 }, O)
end
function O:Validate(owner, spec)
    local policy = self.config.overrideOwners[owner]
    if not policy then return W.Err('denied', 'Invoking client resource is not an allowed override owner.') end
    if not W.Fields(spec, { clock=true, weather=true, wind=true, snow=true, priority=true, ttlSeconds=true })
        or not W.Number(spec.priority, 0, policy.maxPriority, true)
        or not W.Number(spec.ttlSeconds, 1, self.config.maxOverrideSeconds)
        or (spec.clock == nil and spec.weather == nil and spec.wind == nil and spec.snow == nil) then
        return W.Err('invalid_input', 'Expected channels, priority, and bounded ttlSeconds.')
    end
    -- A scene clock is fixed seconds-of-week; weather contains name + transitionSeconds.
    if spec.clock ~= nil and (not W.Number(spec.clock, 0, W.WEEK) or spec.clock >= W.WEEK) then return W.Err('invalid_input', 'Invalid fixed scene clock.') end
    if spec.weather ~= nil and (not W.Fields(spec.weather, { name=true, transitionSeconds=true })
        or type(spec.weather.name) ~= 'string' or not W.types[spec.weather.name]
        or not W.Number(spec.weather.transitionSeconds, 0, 300)) then return W.Err('invalid_input', 'Invalid scene weather.') end
    if spec.wind ~= nil and not W.Wind(spec.wind) then return W.Err('invalid_input', 'Invalid scene wind.') end
    if spec.snow ~= nil and type(spec.snow) ~= 'boolean' then return W.Err('invalid_input', 'Invalid scene snow flag.') end
    return W.Ok(W.Copy(spec))
end
function O:Expire(now)
    for handle, item in pairs(self.handles) do
        if now >= item.expires then self.handles[handle] = nil end
    end
end
function O:Acquire(owner, spec, now)
    local validated = self:Validate(owner, spec)
    if not validated.ok then return validated end
    self:Expire(now)
    local count = 0
    for _ in pairs(self.handles) do count = count + 1 end
    if count >= self.config.maxOverrides then return W.Err('limit', 'Local override limit reached.') end
    self.serial = self.serial + 1
    local handle = self.epoch .. ':' .. self.serial
    self.handles[handle] = { owner=owner, spec=validated.value, order=self.serial,
        revision=1, expires=now + spec.ttlSeconds }
    return W.Ok({ handle=handle, ttlSeconds=spec.ttlSeconds })
end
function O:Update(owner, handle, spec, now)
    self:Expire(now)
    local item = type(handle) == 'string' and self.handles[handle]
    if not item then return W.Err('not_found', 'Override handle expired or is unknown.') end
    if item.owner ~= owner then return W.Err('denied', 'Override belongs to another resource.') end
    local validated = self:Validate(owner, spec)
    if not validated.ok then return validated end
    -- Renewing an unchanged scene must not restart its weather transition.
    if not SamePresentation(item.spec, validated.value) then item.revision = item.revision + 1 end
    item.spec, item.expires = validated.value, now + spec.ttlSeconds
    return W.Ok({ handle=handle, ttlSeconds=spec.ttlSeconds })
end
function O:Release(owner, handle)
    if type(handle) ~= 'string' or #handle > 200 then return W.Err('invalid_input', 'Expected override handle.') end
    local item = self.handles[handle]
    if item and item.owner ~= owner then return W.Err('denied', 'Override belongs to another resource.') end
    self.handles[handle] = nil
    return W.Ok({ released=item ~= nil })
end
function O:ReleaseOwner(owner)
    for handle, item in pairs(self.handles) do
        if item.owner == owner then self.handles[handle] = nil end
    end
end
function O:Resolve(now)
    self:Expire(now)
    local winners, count = {}, 0
    for handle, item in pairs(self.handles) do
        count = count + 1
        for _, channel in ipairs({ 'clock', 'weather', 'wind', 'snow' }) do
            if item.spec[channel] ~= nil then
                local current = winners[channel]
                if not current or item.spec.priority > current.priority
                    or (item.spec.priority == current.priority and item.order < current.order) then
                    winners[channel] = { value=W.Copy(item.spec[channel]), owner=item.owner, priority=item.spec.priority,
                        order=item.order, token=handle .. ':' .. item.revision }
                end
            end
        end
    end
    return winners, count
end
