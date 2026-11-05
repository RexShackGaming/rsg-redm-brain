-- Case access, identities and search auditing (master plan: Invariants and
-- security, Query rules, Privacy). Shared by every domain module.
local J, Repo = Justice, Justice.Repo
local A = {}
J.Access = A

function A.Gate(owner)
    if not J.Ready() then return J.Err('not_ready', 'Justice is not ready.') end
    if not J.Trusted(owner) then return J.Err('authorization_denied', 'Caller is not trusted.') end
    return J.Ok(true)
end

-- Eligibility for one case row. Sealed cases need justice.case.view_sealed and are
-- read-only (Seal/Unseal/Expunge set visibilityWrite). Role labels never grant
-- policy; they only make an already-authorized actor eligible for this case.
function J.CaseAllowed(query, case, actor, write)
    if not case then return false end
    if actor.system then return true end
    if case.status == 'sealed' and not actor.visibilityWrite and (write or not actor.viewSealed) then return false end
    if actor.manageAll or (not write and actor.viewAll) then return true end
    if case.opened_by_character_id == actor.characterId then return true end
    local memo = J.TxMemo[query]
    local key = case.case_id .. (write and ':w' or ':r')
    if memo and memo.access[key] ~= nil then return memo.access[key] end
    local allowed = Repo.MemberRole(query, case.case_id, actor.characterId, write) ~= nil
    if memo then memo.access[key] = allowed end
    return allowed
end

-- Principal for an operation on an existing case (read outside the transaction
-- only to scope policy; the transaction re-reads and locks it).
function A.CasePrincipal(request, owner, action, caseId, attributes, write)
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local case = J.Uuid(caseId) and Repo.Get(DB.one, 'case', caseId, owner) or nil
    local actor = J.Principal(owner, action, request, case and case.jurisdiction_id or nil, false, attributes)
    if not actor.ok then return actor end
    if not case or not J.CaseAllowed(DB.one, case, actor.value, write) then return J.Err('not_found', 'Case unavailable.') end
    return J.Ok({ actor = actor.value, case = case })
end
-- Locks the parent case inside a transaction and re-checks eligibility.
function A.LockCase(tx, caseId, owner, actor, write)
    local case = Repo.Get(tx.one, 'case', caseId, owner, true)
    if not case or not J.CaseAllowed(tx.one, case, actor, write) then return nil end
    return case
end
local editable = { open = true, filed = true, pending_hearing = true }
function A.Editable(case) return editable[case.status] == true end
function A.Closed(case) return case.status == 'closed' or case.status == 'dismissed' or case.status == 'sealed' end

-- Character identity through Core's character-profile provider (offline subjects allowed).
function A.Character(characterId)
    if not J.Uuid(characterId) then return J.Err('invalid_input', 'Character UUID required.') end
    local provider = J.Call('feather-core', 'GetProvider', 'character-profile', nil, 1)
    local implementation = provider.ok and type(provider.value) == 'table' and provider.value.implementation
    if type(implementation) ~= 'table' then return J.Err('character_unavailable', 'Character identity provider is unavailable.') end
    local called, identity = pcall(implementation.GetIdentity, characterId)
    if not called or type(identity) ~= 'table' or type(identity.ok) ~= 'boolean' then
        return J.Err('character_unavailable', 'Character identity provider returned no valid result.')
    end
    if not identity.ok then
        if identity.code == 'not_found' then return J.Err('subject_not_found', 'Character does not exist.') end
        return J.Err('character_unavailable', 'Character identity could not be verified.')
    end
    if type(identity.value) ~= 'table' or not J.Uuid(identity.value.characterId)
        or identity.value.characterId:lower() ~= characterId:lower() then
        return J.Err('character_unavailable', 'Character identity does not match.')
    end
    if identity.value.status ~= 'active' then return J.Err('subject_inactive', 'An active character is required.') end
    return J.Ok(true)
end
-- Organization identity through feather-organizations (master plan: Case parties).
function A.Organization(organizationId)
    if not J.Uuid(organizationId) then return J.Err('invalid_input', 'Organization UUID required.') end
    local result = J.Call('feather-organizations', 'GetOrganization', { organizationId = organizationId })
    if not result.ok then
        if result.code == 'organization_not_found' then return J.Err('organization_not_found', 'Organization does not exist.') end
        return J.Err('organization_unavailable', 'Organization identity could not be verified.')
    end
    if type(result.value) ~= 'table' or result.value.organizationId ~= organizationId:lower() then
        return J.Err('organization_unavailable', 'Organization identity does not match.')
    end
    if result.value.status ~= 'active' then return J.Err('organization_inactive', 'An active organization is required.') end
    return J.Ok(true)
end

-- Master plan, Query rules: search by character UUID is privileged and audited.
-- Officer searches are always recorded. Automated service-mode reads (e.g. a jail
-- placement check every few seconds) are recorded once per AccessAudit window.
local lastServiceAudit, trackedServiceAudits = {}, 0
function A.AuditSearch(owner, actor, action, subjectId)
    local window = ((JusticeConfig.AccessAudit or {}).ServiceRepeatSeconds or 3600) * 1000
    local key, now = nil, GetGameTimer()
    if actor.system and window > 0 then
        key = (owner or '') .. '|' .. action .. '|' .. subjectId
        if lastServiceAudit[key] and now - lastServiceAudit[key] < window then return true end
    end
    local ok = pcall(Repo.AccessAudit, { source = owner, actorId = actor.characterId, action = action, subjectId = subjectId })
    if ok and key then
        if trackedServiceAudits >= 5000 then lastServiceAudit, trackedServiceAudits = {}, 0 end
        if not lastServiceAudit[key] then trackedServiceAudits = trackedServiceAudits + 1 end
        lastServiceAudit[key] = now
    end
    return ok
end

-- Shared bounded page shape.
function A.Page(kind, items, more, extra)
    local list = {}
    for index, row in ipairs(items) do list[index] = J.Mutation.Snapshot(kind, row, extra and extra(row) or nil) end
    return J.Ok({ items = list, nextCursor = more and items[#items][Repo.Specs[kind].id] or nil })
end
function A.PageArgs(request)
    if request.limit ~= nil and not J.Integer(request.limit, 1, JusticeConfig.MaxPageSize) then return nil end
    if request.cursor ~= nil and not J.Uuid(request.cursor) then return nil end
    return { limit = request.limit or JusticeConfig.MaxPageSize, cursor = request.cursor }
end
