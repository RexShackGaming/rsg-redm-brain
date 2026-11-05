-- Access-owned adapter. Domain facts remain in Jobs/Organizations; no cross-domain SQL.
Access.Employment = {}
local E, scopes, generation = Access.Employment, {}, 0
local function Array(value, maximum)
    if type(value) ~= 'table' or getmetatable(value) ~= nil or #value > maximum then return false end
    local count = 0
    for key in pairs(value) do
        if not Access.Integer(key, 1, #value) then return false end
        count = count + 1
    end
    return count == #value
end
local function Definition(value)
    if not Access.OnlyFields(value, {jobIds = true, dutyState = true})
        or not Array(value.jobIds, 8) or #value.jobIds == 0
        or (value.dutyState ~= 'any' and value.dutyState ~= 'on_duty') then return false end
    local found = {}
    for _, id in ipairs(value.jobIds) do
        if not Access.Uuid(id) or id ~= id:lower() or found[id] then return false end
        found[id] = true
    end
    return true
end
function E.ValidateConfig()
    if not Access.OnlyFields(Config.Employment, {Scopes = true})
        or type(Config.Employment.Scopes) ~= 'table' or getmetatable(Config.Employment.Scopes) then
        return Access.Err('invalid_config', 'Employment scopes are required.')
    end
    local count = 0
    for id, scope in pairs(Config.Employment.Scopes) do
        count = count + 1
        if count > 128 or not Access.Uuid(id) or id ~= id:lower() or not Definition(scope)
            or Config.Providers.Memberships[id] ~= nil then
            return Access.Err('invalid_config', 'Invalid or conflicting employment scope.')
        end
    end
    return Access.Ok(true)
end
local function Current(stamp)
    return stamp == generation and GetResourceState('feather-jobs') == 'started'
        and GetResourceState('feather-organizations') == 'started'
end
local function Call(resource, operation, request, stamp)
    if not Current(stamp) then return Access.Err('provider_unavailable', 'Employment domains are unavailable.') end
    local called, result = pcall(function() return exports[resource][operation](nil, request) end)
    if not Current(stamp) or not called or type(result) ~= 'table' or result.ok ~= true
        or type(result.value) ~= 'table' then
        return Access.Err('provider_unavailable', 'Employment domain lookup failed.')
    end
    return result
end
local function Facts(id, scope, stamp)
    local organization = Call('feather-organizations', 'GetOrganization', {organizationId = id}, stamp)
    if not organization.ok then return organization end
    local state = organization.value
    if state.organizationId ~= id or (state.status ~= 'active' and state.status ~= 'pending'
        and state.status ~= 'suspended' and state.status ~= 'dissolving' and state.status ~= 'dissolved') then
        return Access.Err('provider_invalid', 'Invalid organization eligibility facts.')
    end
    local roles, jobs, known = {}, {}, {}
    if state.status == 'active' then
        for _, jobId in ipairs(scope.jobIds) do
            local result = Call('feather-jobs', 'GetJobDefinition', {jobId = jobId}, stamp)
            if not result.ok then return result end
            local job = result.value
            if job.jobId ~= jobId or (job.status ~= 'active' and job.status ~= 'retired')
                or not Array(job.grades, 32) then return Access.Err('provider_invalid', 'Invalid job catalog.') end
            jobs[jobId] = {}
            for _, grade in ipairs(job.grades) do
                if type(grade) ~= 'table' or not Access.Uuid(grade.gradeId) or grade.gradeId ~= grade.gradeId:lower()
                    or grade.jobId ~= jobId or known[grade.gradeId]
                    or (grade.status ~= 'active' and grade.status ~= 'retired') then
                    return Access.Err('provider_invalid', 'Invalid grade catalog.')
                end
                known[grade.gradeId] = true
                if job.status == 'active' and grade.status == 'active' then
                    jobs[jobId][grade.gradeId] = true
                    roles[#roles + 1] = 'grade.' .. grade.gradeId
                    if #roles > 32 then return Access.Err('limit_exceeded', 'Employment scope exceeds 32 active grades.') end
                end
            end
        end
    end
    return Access.Ok({organizationId = id, status = state.status == 'active' and 'active' or 'inactive',
        roleIds = roles, jobs = jobs})
end
function E.Catalog(id, scope)
    local result = Facts(id, scope, generation)
    if not result.ok then return result end
    result.value.jobs = nil
    return result
end
function E.Resolve(id, scope, request)
    local stamp = generation
    local result = Facts(id, scope, stamp)
    if not result.ok then return result end
    local value, roles, found = result.value, {}, {}
    if value.status == 'active' then
        local snapshot = Call('feather-jobs', 'GetEffectiveJobSnapshot', {characterId = request.characterId}, stamp)
        if not snapshot.ok then return snapshot end
        if snapshot.value.characterId ~= request.characterId or not Array(snapshot.value.assignments, 8) then
            return Access.Err('provider_invalid', 'Invalid employment snapshot.')
        end
        for _, assignment in ipairs(snapshot.value.assignments) do
            if type(assignment) ~= 'table' or assignment.characterId ~= request.characterId
                or not Access.Uuid(assignment.jobId) or not Access.Uuid(assignment.gradeId)
                or assignment.status ~= 'active' or (assignment.dutyState ~= 'on_duty'
                    and assignment.dutyState ~= 'off_duty' and assignment.dutyState ~= 'suspended') then
                return Access.Err('provider_invalid', 'Invalid assignment facts.')
            end
            if assignment.employerType == 'organization' and assignment.employerId == id
                and value.jobs[assignment.jobId] and value.jobs[assignment.jobId][assignment.gradeId]
                and assignment.dutyState ~= 'suspended'
                and (scope.dutyState == 'any' or assignment.dutyState == 'on_duty') then
                local role = 'grade.' .. assignment.gradeId
                if not found[role] then found[role] = true; roles[#roles + 1] = role end
            end
        end
    end
    -- Recheck organization eligibility after the potentially yielding Jobs lookup.
    local organization = Call('feather-organizations', 'GetOrganization', {organizationId = id}, stamp)
    if not organization.ok then return organization end
    if organization.value.organizationId ~= id then return Access.Err('provider_invalid', 'Organization identity changed.') end
    local active = value.status == 'active' and organization.value.status == 'active' and #roles > 0
    return Access.Ok({organizationId = id, characterId = request.characterId,
        status = active and 'active' or 'inactive', roleIds = active and roles or {}})
end
local function Register(id, definition, owner)
    if scopes[id] or Config.Providers.Memberships[id] then return Access.Err('provider_conflict', 'Membership scope already configured.') end
    local scope = Access.Copy(definition)
    Config.Providers.Memberships[id] = GetCurrentResourceName()
    local result = Access.Providers.RegisterMembership({organizationId = id, contract = 1,
        resolve = function(request) return E.Resolve(id, scope, request) end,
        catalog = function() return E.Catalog(id, scope) end}, GetCurrentResourceName())
    if not result.ok then Config.Providers.Memberships[id] = nil; return result end
    scopes[id] = {owner = owner, definition = scope}
    return result
end
function E.Start()
    for id, scope in pairs(Config.Employment.Scopes) do
        local result = Register(id, scope)
        if not result.ok then return result end
    end
    return Access.Ok(true)
end
function E.Fixture(request, caller)
    if not Config.DevMode or caller ~= 'feather-jobs-tests' then return Access.Err('authorization_denied', 'Development fixture only.') end
    if not Access.OnlyFields(request, {organizationId = true, jobIds = true, dutyState = true})
        or not Access.Uuid(request.organizationId) or request.organizationId ~= request.organizationId:lower()
        or not Definition({jobIds = request.jobIds, dutyState = request.dutyState}) then
        return Access.Err('invalid_input', 'Exact organization, jobs and duty mode required.')
    end
    local existing = scopes[request.organizationId]
    if existing then
        if existing.owner ~= caller then return Access.Err('provider_conflict', 'Scope belongs to configuration.') end
        local scope = existing.definition
        if scope.dutyState ~= request.dutyState or #scope.jobIds ~= #request.jobIds then
            return Access.Err('provider_conflict', 'Fixture scope changed.')
        end
        for i, id in ipairs(scope.jobIds) do
            if id ~= request.jobIds[i] then return Access.Err('provider_conflict', 'Fixture jobs changed.') end
        end
        return Access.Ok(true)
    end
    local count = 0; for _ in pairs(scopes) do count = count + 1 end
    if count >= 128 then return Access.Err('limit_exceeded', 'Too many employment scopes.') end
    return Register(request.organizationId, {jobIds = request.jobIds, dutyState = request.dutyState}, caller)
end
function E.Stopped(resource)
    if resource == 'feather-jobs' or resource == 'feather-organizations' then generation = generation + 1 end
    for id, scope in pairs(scopes) do
        if scope.owner == resource then
            Access.Providers.UnregisterMembership({organizationId = id}, GetCurrentResourceName())
            Config.Providers.Memberships[id], scopes[id] = nil, nil
        end
    end
end
