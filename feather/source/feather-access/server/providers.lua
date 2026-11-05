Access.Providers = {}
local targets, memberships, jobs = {}, {}, {}
local generation, inFlight = 0, 0
local MAX_EPOCH = 9007199254740991

local function Callable(value)
    local kind = type(value)
    if kind == 'function' or kind == 'userdata' then return true end
    if kind ~= 'table' then return false end
    if type(rawget(value, '__cfx_functionReference')) == 'string' then return true end
    local mt = getmetatable(value)
    return type(mt) == 'table' and type(mt.__call) == 'function'
end

local function Resource(value)
    return type(value) == 'string' and #value > 0 and #value <= 100
        and value:match('^[%w_-]+$') ~= nil
end

local function Keys(value, maximum, roles)
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return nil end
    local found, count = {}, 0
    for key, item in pairs(value) do
        count = count + 1
        local valid = Access.Key(item) or (roles and Access.Uuid(item) and item == item:lower())
        if count > maximum or not Access.Integer(key, 1, maximum) or not valid or found[item] then
            return nil
        end
        found[item] = true
    end
    if count == 0 then return nil end
    local ordered = {}
    for index = 1, count do
        if value[index] == nil then return nil end
        ordered[index] = value[index]
    end
    table.sort(ordered)
    return ordered, found
end

function Access.Providers.ValidateConfig()
    local cfg = Config.Providers
    if type(cfg) ~= 'table' or not Access.Integer(cfg.TimeoutMs, 10, 10000)
        or not Access.Integer(cfg.MaxInFlight, 1, 128)
        or type(cfg.Targets) ~= 'table' or type(cfg.Memberships) ~= 'table'
        or type(cfg.TrustedReaders) ~= 'table' then
        return Access.Err('invalid_config', 'Provider limits and trust maps are required.')
    end
    local count = 0
    for targetType, definition in pairs(cfg.Targets) do
        count = count + 1
        if count > 64 or not Access.Key(targetType)
            or not Access.OnlyFields(definition, { resource = true, capabilities = true })
            or not Resource(definition.resource) or not Keys(definition.capabilities, 32) then
            return Access.Err('invalid_config', 'Invalid target-provider configuration.')
        end
    end
    count = 0
    for organizationId, owner in pairs(cfg.Memberships) do
        count = count + 1
        if count > 1024 or not Access.Uuid(organizationId) or organizationId ~= organizationId:lower()
            or not Resource(owner) then
            return Access.Err('invalid_config', 'Membership scopes require lowercase organization UUIDs and resource names.')
        end
    end
    for owner, enabled in pairs(cfg.TrustedReaders) do
        if not Resource(owner) or type(enabled) ~= 'boolean' then
            return Access.Err('invalid_config', 'Invalid trusted provider reader.')
        end
    end
    return Access.Ok(true)
end

local function Public(entry)
    return { key = entry.key, resource = entry.resource, contract = 1, generation = entry.generation }
end

local function Register(bucket, key, resolver, caller, owner, extra)
    local ready = Access.Ready()
    if not ready.ok then return ready end
    if not Resource(caller) or caller ~= owner then
        return Access.Err('authorization_denied', 'Caller does not own this configured provider scope.')
    end
    if GetResourceState(caller) ~= 'started' then
        return Access.Err('provider_unavailable', 'Provider resource must be started.')
    end
    if not Callable(resolver) then return Access.Err('invalid_input', 'A callable resolver is required.') end
    if bucket[key] then return Access.Err('provider_conflict', 'Scope already registered; unregister before replacing.') end
    generation = generation + 1
    local entry = { key = key, resource = caller, generation = generation, resolve = resolver, extra = extra }
    bucket[key] = entry
    return Access.Ok(Public(entry))
end

function Access.Providers.RegisterTarget(request, caller)
    if not Access.OnlyFields(request, { targetType = true, contract = true, resolve = true, authorize = true, transfer = true })
        or not Access.Key(request.targetType) or request.contract ~= 1 then
        return Access.Err('invalid_input', 'Target type, Contract 1 and resolver are required.')
    end
    if request.authorize ~= nil and not Callable(request.authorize) then
        return Access.Err('invalid_input', 'Target authorization callback must be callable.')
    end
    if request.transfer ~= nil and not Callable(request.transfer) then return Access.Err('invalid_input','Transfer proof callback must be callable.') end
    local definition = Config.Providers.Targets[request.targetType]
    local result=Register(targets, request.targetType, request.resolve, caller, definition and definition.resource, request.authorize)
    if result.ok then targets[request.targetType].transfer=request.transfer end
    return result
end

function Access.Providers.RegisterMembership(request, caller)
    if not Access.OnlyFields(request, { organizationId = true, contract = true, resolve = true, catalog = true })
        or not Access.Uuid(request.organizationId) or request.contract ~= 1 then
        return Access.Err('invalid_input', 'Organization UUID, Contract 1 and resolver are required.')
    end
    if request.catalog ~= nil and not Callable(request.catalog) then
        return Access.Err('invalid_input', 'Membership catalog callback must be callable.')
    end
    local id = request.organizationId:lower()
    return Register(memberships, id, request.resolve, caller, Config.Providers.Memberships[id], request.catalog)
end

local function Unregister(bucket, key, caller)
    local entry = bucket[key]
    if not entry then return Access.Err('provider_unavailable', 'Scope is not registered.') end
    if caller ~= entry.resource then return Access.Err('authorization_denied', 'Only the provider owner may unregister.') end
    bucket[key] = nil
    return Access.Ok(true)
end

function Access.Providers.UnregisterTarget(request, caller)
    if not Access.OnlyFields(request, { targetType = true }) or not Access.Key(request.targetType) then
        return Access.Err('invalid_input', 'Target type is required.')
    end
    return Unregister(targets, request.targetType, caller)
end

function Access.Providers.UnregisterMembership(request, caller)
    if not Access.OnlyFields(request, { organizationId = true }) or not Access.Uuid(request.organizationId) then
        return Access.Err('invalid_input', 'Organization UUID is required.')
    end
    return Unregister(memberships, request.organizationId:lower(), caller)
end

local function Invoke(bucket, entry, request, callback)
    if inFlight >= Config.Providers.MaxInFlight then
        return Access.Err('provider_busy', 'Provider call limit reached.')
    end
    local pending, started = promise.new(), GetGameTimer()
    local job = { entry = entry, settled = false, released = false }
    jobs[job], inFlight = true, inFlight + 1
    local function Settle(result)
        if not job.settled then job.settled = true; pending:resolve(result) end
    end
    job.settle = Settle
    SetTimeout(Config.Providers.TimeoutMs, function()
        Settle(Access.Err('provider_timeout', 'Provider did not reply within its deadline.'))
    end)
    CreateThread(function()
        local called, result = pcall(function() return (callback or entry.resolve)(request) end)
        if not job.released then
            job.released = true
            jobs[job], inFlight = nil, inFlight - 1
        end
        if not called then
            Settle(Access.Err('provider_failed', 'Provider callback raised an exception.'))
        elseif GetGameTimer() - started >= Config.Providers.TimeoutMs then
            Settle(Access.Err('provider_timeout', 'Provider reply arrived after its deadline.'))
        elseif bucket[entry.key] ~= entry or GetResourceState(entry.resource) ~= 'started' then
            Settle(Access.Err('provider_changed', 'Provider changed while resolving context.'))
        else
            Settle({ ok = true, value = result })
        end
    end)
    -- Timeouts abandon the result, not the running callback. Its slot remains
    -- occupied until completion/owner stop, bounding hung callback accumulation.
    local result = Citizen.Await(pending)
    if result.ok and (bucket[entry.key] ~= entry or GetResourceState(entry.resource) ~= 'started') then
        return Access.Err('provider_changed', 'Provider changed while resolving context.')
    end
    local ready = Access.Ready()
    if not ready.ok then return ready end
    return result
end

-- Internal service helpers; no arbitrary callback invocation is exported.
Access.Providers.RoleIds = function(value) return Keys(value, 32, true) end

function Access.Providers.TransferProof(context, actor, request, manifest)
    local entry=targets[context.targetType]
    if not entry or not entry.transfer or entry.generation~=context.provider.generation then
        return Access.Err('provider_unavailable','Current transfer-proof provider required.')
    end
    local invoked=Invoke(targets,entry,{target=Access.Copy(context),actor=Access.Copy(actor),
        manifestId=manifest.manifest_id,sourceEpoch=tonumber(manifest.source_epoch),
        transferResource=request.transferResource,transferRequestId=request.transferRequestId},entry.transfer)
    if not invoked.ok then return invoked end
    local result=invoked.value
    if type(result)~='table' or result.ok~=true or type(result.value)~='table' or result.value.allowed~=true then
        return Access.Err('authorization_denied','New owner or committed transfer proof did not match.')
    end
    return Access.Ok(true)
end

function Access.Providers.Authorize(context, actor, action, capability)
    local entry = targets[context.targetType]
    if not entry or entry.generation ~= context.provider.generation or not entry.extra then
        return Access.Err('provider_unavailable', 'A current target-authority callback is required.')
    end
    local invoked = Invoke(targets, entry, { target = Access.Copy(context), actor = Access.Copy(actor),
        action = action, capability = capability }, entry.extra)
    if not invoked.ok then return invoked end
    local result = invoked.value
    if type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table'
        or result.value.allowed ~= true then
        return Access.Err('authorization_denied', 'Target provider denied management authority.')
    end
    return Access.Ok(true)
end

function Access.Providers.Catalog(organizationId)
    local entry = memberships[organizationId]
    if not entry or not entry.extra or GetResourceState(entry.resource) ~= 'started' then
        return Access.Err('provider_unavailable', 'An organization role catalog is required.')
    end
    local invoked = Invoke(memberships, entry, { organizationId = organizationId }, entry.extra)
    if not invoked.ok then return invoked end
    local result = invoked.value
    if type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table' then
        return Access.Err('provider_invalid', 'Invalid organization role catalog.')
    end
    local value = result.value
    local roles = type(value.roleIds) == 'table' and next(value.roleIds) == nil and {} or Keys(value.roleIds, 32, true)
    if not Access.OnlyFields(value, { organizationId = true, status = true, roleIds = true })
        or value.organizationId ~= organizationId or (value.status ~= 'active' and value.status ~= 'inactive')
        or not roles or (value.status == 'inactive' and #roles > 0) then
        return Access.Err('provider_invalid', 'Invalid organization role identity, state or roles.')
    end
    return Access.Ok({ organizationId = organizationId, status = value.status, roleIds = roles, provider = Public(entry) })
end

local function Lookup(bucket, key, caller)
    local ready = Access.Ready()
    if not ready.ok then return nil, ready end
    if not Resource(caller) or Config.Providers.TrustedReaders[caller] ~= true then
        return nil, Access.Err('authorization_denied', 'Caller is not a trusted context reader.')
    end
    local entry = bucket[key]
    if not entry or GetResourceState(entry.resource) ~= 'started' then
        return nil, Access.Err('provider_unavailable', 'No active provider for this scope.')
    end
    return entry
end

local function Envelope(result)
    return type(result) == 'table' and getmetatable(result) == nil and result.ok == true
        and type(result.value) == 'table'
end

function Access.Providers.ResolveTarget(request, caller)
    if not Access.OnlyFields(request, { targetType = true, targetId = true })
        or not Access.Key(request.targetType) or not Access.Uuid(request.targetId) then
        return Access.Err('invalid_input', 'Exact target type and UUID are required.')
    end
    local entry, denied = Lookup(targets, request.targetType, caller)
    if not entry then return denied end
    local id = request.targetId:lower()
    local invoked = Invoke(targets, entry, { targetType = entry.key, targetId = id })
    if not invoked.ok then return invoked end
    local result = invoked.value
    if not Envelope(result) then return Access.Err('provider_invalid', 'Target provider did not return a successful context.') end
    local value = result.value
    if not Access.OnlyFields(value, { targetType = true, targetId = true, epoch = true, status = true, capabilities = true })
        or value.targetType ~= entry.key or value.targetId ~= id
        or not Access.Integer(value.epoch, 1, MAX_EPOCH)
        or (value.status ~= 'active' and value.status ~= 'suspended' and value.status ~= 'retired'
            and value.status ~= 'unavailable') then
        return Access.Err('provider_invalid', 'Target context identity, epoch or state is invalid.')
    end
    local capabilities = Keys(value.capabilities, 32)
    local _, allowed = Keys(Config.Providers.Targets[entry.key].capabilities, 32)
    if not capabilities then return Access.Err('provider_invalid', 'Target capability vocabulary is invalid.') end
    for _, capability in ipairs(capabilities) do
        if not allowed[capability] then return Access.Err('provider_invalid', 'Target capability is outside configured vocabulary.') end
    end
    return Access.Ok({ targetType = entry.key, targetId = id, epoch = value.epoch,
        status = value.status, capabilities = capabilities, provider = Public(entry) })
end

function Access.Providers.ResolveMembership(request, caller)
    if not Access.OnlyFields(request, { organizationId = true, characterId = true })
        or not Access.Uuid(request.organizationId) or not Access.Uuid(request.characterId) then
        return Access.Err('invalid_input', 'Organization and character UUIDs are required.')
    end
    local id, characterId = request.organizationId:lower(), request.characterId:lower()
    local entry, denied = Lookup(memberships, id, caller)
    if not entry then return denied end
    local invoked = Invoke(memberships, entry, { organizationId = id, characterId = characterId })
    if not invoked.ok then return invoked end
    local result = invoked.value
    if not Envelope(result) then return Access.Err('provider_invalid', 'Membership provider did not return a successful context.') end
    local value = result.value
    if not Access.OnlyFields(value, { organizationId = true, characterId = true, status = true, roleIds = true })
        or value.organizationId ~= id or value.characterId ~= characterId
        or (value.status ~= 'active' and value.status ~= 'inactive') then
        return Access.Err('provider_invalid', 'Membership identity or status is invalid.')
    end
    -- Empty roles are a valid non-qualifying membership, never an implicit wildcard.
    local roles
    if type(value.roleIds) == 'table' and next(value.roleIds) == nil and getmetatable(value.roleIds) == nil then
        roles = {}
    else roles = Keys(value.roleIds, 32, true) end
    if not roles or (value.status == 'inactive' and #roles > 0) then
        return Access.Err('provider_invalid', 'Membership role IDs are invalid.')
    end
    return Access.Ok({ organizationId = id, characterId = characterId,
        status = value.status, roleIds = roles, provider = Public(entry) })
end

function Access.Providers.DropOwner(resource)
    for _, bucket in ipairs({ targets, memberships }) do
        for key, entry in pairs(bucket) do if entry.resource == resource then bucket[key] = nil end end
    end
    for job in pairs(jobs) do
        if job.entry.resource == resource then
            job.settle(Access.Err('provider_unavailable', 'Provider resource stopped.'))
            if not job.released then job.released = true; inFlight = inFlight - 1 end
            jobs[job] = nil
        end
    end
end

function Access.Providers.Counts()
    local counts = { targets = 0, memberships = 0, inFlight = inFlight }
    for _ in pairs(targets) do counts.targets = counts.targets + 1 end
    for _ in pairs(memberships) do counts.memberships = counts.memberships + 1 end
    return counts
end

-- Internal read-only release diagnostics; no target lookup or grant operation.
function Access.Providers.TargetStatus(targetType,resource)
    local entry=targets[targetType]
    local definition=Config.Providers.Targets[targetType]
    return definition~=nil and definition.resource==resource and entry~=nil
        and entry.resource==resource and GetResourceState(resource)=='started'
end
