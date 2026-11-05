JobEffective = {}
local Ok, Err = Jobs.Ok, Jobs.Err

-- SetDutyState ---------------------------------------------------------------
-- Duty is a per-assignment enum; it never touches job or grade identifiers.
local dutyFields = JobAssignments.Allowed({ 'assignmentId', 'expectedRevision', 'dutyState' })
function JobEffective.SetDuty(request, resource)
    local begun = JobAssignments.Begin(request, resource, dutyFields)
    if not begun.ok then return begun end
    if not Jobs.Uuid(request.assignmentId) or not Jobs.Integer(request.expectedRevision, 1, Jobs.MaxRevision)
        or not Jobs.DutyStates[request.dutyState] then
        return Err('invalid_input', 'Assignment UUID, expected revision, and duty state required.')
    end
    request = Jobs.Copy(request)
    request.assignmentId = request.assignmentId:lower()
    local actor = JobAssignments.Policy(request, resource, {
        assignmentId = request.assignmentId,
        dutyState = request.dutyState
    })
    if not actor.ok then return actor end
    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'assignment.duty',
        fingerprint = Jobs.Fingerprint('assignment.duty', request,
            { 'assignmentId', 'expectedRevision', 'dutyState', 'reasonCode' }),
        body = function(tx)
            local row = (tx.query([[SELECT a.`character_id`,a.`job_id`,a.`status`,a.`duty_state`,a.`owner_resource`,
                a.`revision`,d.`job_key` FROM `feather_job_assignments` a
                JOIN `feather_job_definitions` d ON d.`job_id`=a.`job_id`
                WHERE a.`assignment_id`=? FOR UPDATE]], request.assignmentId) or {})[1]
            if not row then return Err('assignment_not_found', 'Assignment not found.') end
            if not JobAssignments.CanMutate(row.owner_resource, resource) then
                return Err('authorization_denied', 'Caller does not own this assignment.')
            end
            if row.status ~= 'active' then return Err('assignment_ended', 'Assignment has ended.') end
            local revision = tonumber(row.revision)
            if revision ~= request.expectedRevision then
                return Err('revision_conflict', 'Assignment revision changed.', { revision = revision })
            end
            if row.duty_state == request.dutyState then
                return Err('no_change', 'Assignment is already in that duty state.')
            end
            tx.exec([[UPDATE `feather_job_assignments` SET `duty_state`=?,`revision`=`revision`+1
                WHERE `assignment_id`=? AND `revision`=?]], request.dutyState, request.assignmentId, revision)
            JobEvents.Record(tx, 'assignment.duty_changed', {
                aggregateType = 'assignment',
                aggregateId = request.assignmentId,
                assignmentId = request.assignmentId,
                characterId = row.character_id,
                jobId = row.job_id,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = { jobKey = row.job_key, dutyState = request.dutyState, previousDutyState = row.duty_state }
            })
            return JobAssignments.Read(tx, request.assignmentId)
        end
    })
end

-- SetActiveAssignment --------------------------------------------------------
-- expectedRevision is the character state revision (0 before any selection).
-- assignmentId = false clears the selection.
local activeFields = JobAssignments.Allowed({ 'characterId', 'assignmentId', 'expectedRevision' })
function JobEffective.SetActive(request, resource)
    if not Config.ActiveAssignment.enabled then
        return Err('feature_disabled', 'Active assignment selection is disabled.')
    end
    local begun = JobAssignments.Begin(request, resource, activeFields)
    if not begun.ok then return begun end
    if not Jobs.Uuid(request.characterId)
        or (request.assignmentId ~= false and not Jobs.Uuid(request.assignmentId))
        or not Jobs.Integer(request.expectedRevision, 0, Jobs.MaxRevision) then
        return Err('invalid_input', 'Character UUID, assignment UUID or false, and expected state revision required.')
    end
    request = Jobs.Copy(request)
    request.characterId = request.characterId:lower()
    if request.assignmentId then request.assignmentId = request.assignmentId:lower() end
    local actor = JobAssignments.Policy(request, resource, {
        characterId = request.characterId,
        assignmentId = request.assignmentId or nil
    })
    if not actor.ok then return actor end
    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'assignment.activate',
        fingerprint = Jobs.Fingerprint('assignment.activate', request,
            { 'characterId', 'assignmentId', 'expectedRevision', 'reasonCode' }),
        body = function(tx)
            local state = JobAssignments.LockCharacter(tx, request.characterId)
            if state.revision ~= request.expectedRevision then
                return Err('revision_conflict', 'Character job state revision changed.', { revision = state.revision })
            end
            if (state.activeAssignmentId or false) == request.assignmentId then
                return Err('no_change', 'That assignment is already the active selection.')
            end
            -- Callers may select their own assignments; clearing or replacing another
            -- resource's active selection requires the privileged group.
            local privileged = Config.Access.privilegedAssigners[resource] == true
            if state.activeAssignmentId and not privileged then
                local current = (tx.query(
                    'SELECT `owner_resource` FROM `feather_job_assignments` WHERE `assignment_id`=?',
                    state.activeAssignmentId) or {})[1]
                if current and current.owner_resource ~= resource then
                    return Err('authorization_denied', 'Active selection belongs to another resource.')
                end
            end
            local jobId, jobKey
            if request.assignmentId then
                local row = (tx.query([[SELECT a.`character_id`,a.`job_id`,a.`status`,a.`owner_resource`,d.`job_key`
                    FROM `feather_job_assignments` a JOIN `feather_job_definitions` d ON d.`job_id`=a.`job_id`
                    WHERE a.`assignment_id`=? LOCK IN SHARE MODE]], request.assignmentId) or {})[1]
                if not row or row.character_id ~= request.characterId then
                    return Err('assignment_not_found', 'Assignment does not belong to this character.')
                end
                if row.status ~= 'active' then return Err('assignment_ended', 'Assignment has ended.') end
                if not JobAssignments.CanMutate(row.owner_resource, resource) then
                    return Err('authorization_denied', 'Caller does not own this assignment.')
                end
                jobId, jobKey = row.job_id, row.job_key
            end
            tx.exec([[UPDATE `feather_job_character_state` SET `active_assignment_id`=?,`revision`=`revision`+1
                WHERE `character_id`=? AND `revision`=?]],
                request.assignmentId or nil, request.characterId, state.revision)
            JobEvents.Record(tx, 'assignment.activated', {
                aggregateType = 'character',
                aggregateId = request.characterId,
                characterId = request.characterId,
                assignmentId = request.assignmentId or nil,
                jobId = jobId,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = state.revision + 1,
                actor = actor.value,
                details = {
                    jobKey = jobKey,
                    activeAssignmentId = request.assignmentId or nil,
                    previousActiveAssignmentId = state.activeAssignmentId,
                    activeCleared = request.assignmentId == false or nil
                }
            })
            return Ok({
                characterId = request.characterId,
                activeAssignmentId = request.assignmentId or nil,
                previousActiveAssignmentId = state.activeAssignmentId,
                revision = state.revision + 1
            })
        end
    })
end

-- Reads ----------------------------------------------------------------------
function JobEffective.Build(characterId)
    local state = DB.one([[SELECT `active_assignment_id`,`revision` FROM `feather_job_character_state`
        WHERE `character_id`=?]], characterId)
    local open = JobAssignments.ListOpen(characterId)
    if not open.ok then return open end
    local activeId = Config.ActiveAssignment.enabled and state and state.active_assignment_id or nil
    local active
    for _, assignment in ipairs(open.value) do
        if assignment.assignmentId == activeId then active = assignment end
    end
    return Ok({
        characterId = characterId,
        revision = state and tonumber(state.revision) or 0,
        activeAssignmentId = active and active.assignmentId or nil,
        active = active,
        assignments = open.value
    })
end

function JobEffective.GetSnapshot(request, resource)
    local allowed = Jobs.CheckRead(resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, { characterId = true })
    if not fields.ok then return fields end
    if not Jobs.Uuid(request.characterId) then return Err('invalid_input', 'Character UUID required.') end
    return JobEffective.Build(request.characterId:lower())
end

-- CheckAssignment returns facts only; the consumer owns the action rule.
local checkFields = {
    characterId = true, jobKey = true, gradeKey = true, minGradeOrdinal = true,
    employerType = true, employerId = true, dutyState = true, activeOnly = true
}
function JobEffective.Check(request, resource)
    local allowed = Jobs.CheckRead(resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, checkFields)
    if not fields.ok then return fields end
    if not Jobs.Uuid(request.characterId) or not Jobs.Key(request.jobKey, 48)
        or (request.gradeKey ~= nil and not Jobs.Key(request.gradeKey, 48))
        or (request.minGradeOrdinal ~= nil and not Jobs.Integer(request.minGradeOrdinal, 0, 1000))
        or (request.employerType ~= nil and not Jobs.Key(request.employerType, 32))
        or (request.employerId ~= nil and not Jobs.Uuid(request.employerId))
        or (request.dutyState ~= nil and not Jobs.DutyStates[request.dutyState])
        or (request.activeOnly ~= nil and type(request.activeOnly) ~= 'boolean') then
        return Err('invalid_input', 'Character UUID and job key required; filters must be valid.')
    end
    local snapshot = JobEffective.Build(request.characterId:lower())
    if not snapshot.ok then return snapshot end
    local employerId = request.employerId and request.employerId:lower()
    for _, assignment in ipairs(snapshot.value.assignments) do
        if assignment.jobKey == request.jobKey
            and (request.gradeKey == nil or assignment.gradeKey == request.gradeKey)
            and (request.minGradeOrdinal == nil or assignment.gradeOrdinal >= request.minGradeOrdinal)
            and (request.employerType == nil or assignment.employerType == request.employerType)
            and (employerId == nil or assignment.employerId == employerId)
            and (request.dutyState == nil or assignment.dutyState == request.dutyState)
            and (request.activeOnly ~= true or assignment.assignmentId == snapshot.value.activeAssignmentId) then
            return Ok({ matched = true, assignment = assignment })
        end
    end
    return Ok({ matched = false })
end

Jobs.Export('SetDutyState', JobEffective.SetDuty)
Jobs.Export('SetActiveAssignment', JobEffective.SetActive)
Jobs.Export('GetEffectiveJobSnapshot', JobEffective.GetSnapshot)
Jobs.Export('CheckAssignment', JobEffective.Check)
