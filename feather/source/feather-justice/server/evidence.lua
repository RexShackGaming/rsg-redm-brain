-- Evidence references (master plan: Evidence references; Evidence operations;
-- workflow "Evidence collection"). Inventory owns item instances and lockers.
local J, Repo, M, A = Justice, Justice.Repo, Justice.Mutation, Justice.Access
local maximumRevision = 9007199254740989
local types = { inventory_item = true, external = true }
local relationships = { collected = true, submitted = true, examined = true, exhibit = true }
local dispositions = { returned = true, destroyed = true, forfeited = true }

local function RefValid(kind, ref)
    if kind == 'inventory_item' then return type(ref) == 'string' and #ref <= 20 and ref:match('^[1-9]%d*$') ~= nil end
    return J.Uuid(ref)
end
local function Snapshot(row, case) return M.Snapshot('evidence', row, case and { jurisdictionId = case.jurisdiction_id } or nil) end

-- Synchronous in-memory index for the Inventory guard (guards must not query or yield).
local linked, guardActive, guardName = {}, false, 'feather-justice:evidence'
function J.EvidenceGuardActive() return guardActive end
function J.ReloadEvidenceIndex() linked = Repo.ActiveInventoryEvidence() end
local function Inventory()
    if GetResourceState('feather-inventory') ~= 'started' then return nil end
    local ok, api = pcall(function() return exports['feather-inventory']:initiate() end)
    return ok and type(api) == 'table' and api or nil
end
-- "Deleting or consuming a linked evidence item must be guarded or produce an
-- explicit immutable disposition record." Moves stay allowed (Inventory custody).
function J.InstallEvidenceGuard()
    if guardActive or not JusticeConfig.Evidence.InventoryGuard then return guardActive end
    local api = Inventory()
    if not api or type(api.Guards) ~= 'table' then return false end
    local ok, result = pcall(api.Guards.RegisterDestroyGuard, guardName, function(instance)
        local id = type(instance) == 'table' and tonumber(instance.id)
        if id and linked[tostring(math.floor(id))] then
            return false, 'This item is linked case evidence; remove the link with a disposition in Justice first.'
        end
        return true
    end)
    guardActive = ok and type(result) == 'table' and result.ok == true
    return guardActive
end
function J.RemoveEvidenceGuard()
    if not guardActive then return end
    guardActive = false
    local api = Inventory()
    if api and type(api.Guards) == 'table' then pcall(api.Guards.UnregisterDestroyGuard, guardName) end
end
function J.EvidenceGuardLost() guardActive = false end
local function ReadInstance(ref)
    local api = Inventory()
    if not api or type(api.Instances) ~= 'table' then return J.Err('inventory_unavailable', 'Inventory is unavailable.') end
    local ok, result = pcall(api.Instances.GetInstance, tonumber(ref))
    if not ok or type(result) ~= 'table' then return J.Err('inventory_unavailable', 'Inventory returned no valid result.') end
    if result.ok == true and type(result.value) == 'table' and tonumber(result.value.id) == tonumber(ref) then
        local name = type(result.value.definition) == 'table' and result.value.definition.name or nil
        return J.Ok({ itemName = J.Token(name, 64) and name or nil })
    end
    local code = type(result.error) == 'table' and result.error.code or result.code
    if code == 'NOT_FOUND' or code == 'not_found' then return J.Err('evidence_not_found', 'The item instance does not exist.') end
    return J.Err('inventory_unavailable', 'The item instance could not be verified.')
end
J.ReadEvidenceInstance = ReadInstance

J.Export('LinkEvidence', function(p, owner)
    if not M.Fields(p, { 'caseId', 'expectedCaseRevision', 'evidenceType', 'evidenceId', 'relationship', 'description', 'subjectCharacterId' }, true)
        or not J.Uuid(p.caseId) or not J.Integer(p.expectedCaseRevision, 1, maximumRevision) or not types[p.evidenceType or '']
        or not RefValid(p.evidenceType, p.evidenceId) or not relationships[p.relationship or '']
        or (p.description ~= nil and not J.Text(p.description, 1000))
        or (p.subjectCharacterId ~= nil and not J.Uuid(p.subjectCharacterId)) then
        return J.Err('invalid_input', 'Case revision, evidence type and id, relationship and bounded description required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.evidence.link', p.caseId:lower(), { evidenceType = p.evidenceType }, true)
    if not access.ok then return access end
    local actor = access.value.actor
    local evidenceId = p.evidenceType == 'external' and p.evidenceId:lower() or p.evidenceId
    -- External reads happen before Justice locks are taken.
    local instance = p.evidenceType == 'inventory_item' and ReadInstance(evidenceId) or J.Ok({})
    local subject = p.subjectCharacterId and A.Character(p.subjectCharacterId:lower()) or J.Ok(true)
    local result = M.Run('evidence.linked', p, owner, actor, function(tx, context)
        if not instance.ok then return instance end
        if not subject.ok then return subject end
        local case = A.LockCase(tx, p.caseId:lower(), owner, actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if A.Closed(case) then return J.Err('case_closed', 'Evidence needs a case that is not closed.') end
        if case.revision ~= p.expectedCaseRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        if Repo.ActiveEvidence(tx.one, case.case_id, p.evidenceType, evidenceId) then
            return J.Err('evidence_exists', 'This evidence is already linked to the case.')
        end
        local row = { evidence_link_id = J.NewUuid(), case_id = case.case_id, evidence_type = p.evidenceType, evidence_id = evidenceId,
            relationship = p.relationship, linked_by_character_id = actor.characterId, linked_at = context.now, status = 'active',
            subject_character_id = p.subjectCharacterId and p.subjectCharacterId:lower() or nil, description = p.description,
            item_name = instance.value.itemName, revision = 1 }
        Repo.Insert(tx, 'evidence', row)
        return J.Ok(Snapshot(row, case))
    end)
    if result.ok and p.evidenceType == 'inventory_item' then linked[evidenceId] = true end
    return result
end)

J.Export('RemoveEvidenceLink', function(p, owner)
    if type(p) ~= 'table' or (p.disposition ~= nil and not dispositions[p.disposition]) then
        return J.Err('invalid_input', 'Optional disposition must be returned, destroyed or forfeited.')
    end
    local reference
    local result = J.ChangeRecord('evidence', 'evidenceLinkId', p, owner, 'justice.evidence.link', 'evidence.removed',
        function(row) return { disposition = p.disposition, evidenceType = row.evidence_type } end, function(_, row, _, context)
            if row.status ~= 'active' then return J.Err('invalid_transition', 'Only an active link can be removed.') end
            reference = row.evidence_type == 'inventory_item' and row.evidence_id or nil
            return { status = 'removed', removed_at = context.now, removed_by_character_id = context.actor.characterId,
                disposition = p.disposition }
        end, { 'disposition' })
    -- Another case may still hold the same item; the reload settles the guard cache.
    if result.ok and reference then pcall(J.ReloadEvidenceIndex) end
    return result
end)

J.Export('ListCaseEvidence', function(p, owner)
    local page = M.Fields(p, { 'caseId', 'includeRemoved', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or not J.Uuid(p.caseId) or (p.includeRemoved ~= nil and type(p.includeRemoved) ~= 'boolean') then
        return J.Err('invalid_input', 'Case UUID and bounded page required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.evidence.view', p.caseId:lower(), nil, false)
    if not access.ok then return access end
    page.filters = { case_id = access.value.case.case_id }
    page.statuses = not p.includeRemoved and { 'active' } or nil
    local items, more = Repo.Page(DB.query, 'evidence', owner, page)
    if not J.Current(access.value.actor) then return J.Err('session_expired', 'Actor changed.') end
    return A.Page('evidence', items, more, function() return { jurisdictionId = access.value.case.jurisdiction_id } end)
end)

-- Operator reconciliation: an Inventory item deleted outside the guard is recorded
-- as 'missing' instead of silently pointing at nothing.
function J.ReconcileEvidence(limit)
    if not J.Ready() then return J.Err('not_ready', 'Justice is not ready.') end
    local generation = J.Generation()
    local checked, missing, unavailable = 0, 0, 0
    for _, link in ipairs(Repo.ActiveInventoryLinks(limit or 100)) do
        checked = checked + 1
        local instance = ReadInstance(link.evidence_id)
        if not instance.ok and instance.code == 'evidence_not_found' then
            local owner = link.owner_resource
            local request = { requestId = 'justice:evidence:missing:' .. link.evidence_link_id, reasonCode = 'justice.evidence.missing',
                evidenceLinkId = link.evidence_link_id }
            local marked = M.Run('evidence.missing', request, 'feather-justice', { generation = generation, system = true }, function(tx, context)
                Repo.Get(tx.one, 'case', link.case_id, owner, true)
                local row = Repo.Get(tx.one, 'evidence', link.evidence_link_id, owner, true)
                if not row or row.status ~= 'active' then return J.Err('invalid_transition', 'Already removed.') end
                local changes = { status = 'missing', removed_at = context.now, revision = row.revision + 1 }
                Repo.Update(tx, 'evidence', row.evidence_link_id, changes)
                for key, value in pairs(changes) do row[key] = value end
                return J.Ok(Snapshot(row))
            end)
            if marked.ok then missing = missing + 1 end
        elseif not instance.ok then unavailable = unavailable + 1 end
    end
    pcall(J.ReloadEvidenceIndex)
    return J.Ok({ checked = checked, missing = missing, unavailable = unavailable })
end
