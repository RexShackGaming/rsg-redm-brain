JobAssignments = {}
local Ok, Err = Jobs.Ok, Jobs.Err

local selectAssignment = [[
    SELECT a.`assignment_id`,a.`character_id`,a.`job_id`,a.`grade_id`,a.`employer_type`,a.`employer_id`,
        a.`status`,a.`duty_state`,a.`owner_resource`,a.`provenance_type`,a.`provenance_id`,a.`revision`,
        FLOOR(UNIX_TIMESTAMP(a.`assigned_at`))*1000 AS assigned_at_ms,
        FLOOR(UNIX_TIMESTAMP(a.`ended_at`))*1000 AS ended_at_ms,
        d.`job_key`,d.`label` AS job_label,d.`status` AS job_status,
        g.`grade_key`,g.`label` AS grade_label,g.`ordinal`
    FROM `feather_job_assignments` a
    JOIN `feather_job_definitions` d ON d.`job_id`=a.`job_id`
    JOIN `feather_job_grades` g ON g.`grade_id`=a.`grade_id`]]

-- Snapshots and shared helpers -----------------------------------------------

function JobAssignments.Snapshot(row)
    if not row then return Err('assignment_not_found', 'Assignment not found.') end
    if not Jobs.Uuid(row.assignment_id) or not Jobs.Uuid(row.character_id) or not Jobs.Uuid(row.job_id)
        or not Jobs.Uuid(row.grade_id) or (row.status ~= 'active' and row.status ~= 'ended')
        or not Jobs.DutyStates[row.duty_state]
        or not Jobs.Integer(tonumber(row.revision), 1, Jobs.MaxRevision + 1) then
        return Err('invalid_persistence', 'Persisted assignment is invalid.')
    end
    return Ok({
        assignmentId = row.assignment_id,
        characterId = row.character_id,
        jobId = row.job_id,
        jobKey = row.job_key,
        jobLabel = row.job_label,
        jobStatus = row.job_status,
        gradeId = row.grade_id,
        gradeKey = row.grade_key,
        gradeLabel = row.grade_label,
        gradeOrdinal = tonumber(row.ordinal),
        employerType = row.employer_type,
        employerId = row.employer_id,
        status = row.status,
        dutyState = row.duty_state,
        ownerResource = row.owner_resource,
        provenanceType = row.provenance_type,
        provenanceId = row.provenance_id,
        revision = tonumber(row.revision),
        assignedAt = tonumber(row.assigned_at_ms),
        endedAt = row.ended_at_ms and tonumber(row.ended_at_ms) or nil
    })
end

function JobAssignments.Read(tx, assignmentId)
    local row = (tx.query(selectAssignment .. ' WHERE a.`assignment_id`=?', assignmentId) or {})[1]
    return JobAssignments.Snapshot(row)
end

function JobAssignments.CanMutate(ownerResource, resource)
    return ownerResource == resource or Config.Access.privilegedAssigners[resource] == true
end

-- Locks (creating if needed) the per-character state row. Lock order across all
-- assignment mutations is: receipt -> character state -> assignment.
function JobAssignments.LockCharacter(tx, characterId)
    tx.exec('INSERT IGNORE INTO `feather_job_character_state` (`character_id`) VALUES (?)', characterId)
    local row = (tx.query([[
        SELECT `character_id`,`active_assignment_id`,`revision` FROM `feather_job_character_state`
        WHERE `character_id`=? FOR UPDATE]], characterId) or {})[1]
    if not row then error('Character job state could not be locked.') end
    return { activeAssignmentId = row.active_assignment_id, revision = tonumber(row.revision) }
end

local function OpenSlot(characterId, jobId, employerType, employerId)
    return table.concat({ characterId, jobId, employerType or '-', employerId or '-' }, '|')
end

JobAssignments.Allowed = Jobs.Allowed

-- Shared prologue: trusted assigner and field/shape validation.
function JobAssignments.Begin(request, resource, allowedFields)
    local allowed = Jobs.CheckAccess('trustedAssigners', resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, allowedFields)
    if not fields.ok then return fields end
    return Jobs.ValidateCommon(request)
end

-- Service policy, then the server-derived actor recorded on audit facts.
function JobAssignments.Policy(request, resource, subject)
    local policy = Jobs.Authorize(Config.Authorization.assignmentAction, resource, request.requestId, subject)
    if not policy.ok then return policy end
    return Jobs.Actor(request)
end

-- CreateAssignment -----------------------------------------------------------
-- Works for offline characters. Society-style consumers pass their membership
-- as provenance and store the returned assignmentId on their own record.

local createFields = JobAssignments.Allowed({ 'characterId', 'jobId', 'jobKey', 'gradeId', 'gradeKey',
    'employerType', 'employerId', 'provenanceType', 'provenanceId', 'dutyState' })

function JobAssignments.Create(request, resource)
    local begun = JobAssignments.Begin(request, resource, createFields)
    if not begun.ok then return begun end
    if not Jobs.Uuid(request.characterId)
        or (request.jobId == nil) == (request.jobKey == nil)
        or (request.jobId ~= nil and not Jobs.Uuid(request.jobId))
        or (request.jobKey ~= nil and not Jobs.Key(request.jobKey, 48))
        or (request.gradeId == nil) == (request.gradeKey == nil)
        or (request.gradeId ~= nil and not Jobs.Uuid(request.gradeId))
        or (request.gradeKey ~= nil and not Jobs.Key(request.gradeKey, 48))
        or (request.employerType == nil) ~= (request.employerId == nil)
        or not Jobs.Key(request.provenanceType, 48) or not Jobs.Token(request.provenanceId, 128)
        or (request.dutyState ~= nil and not Jobs.DutyStates[request.dutyState]) then
        return Err('invalid_input',
            'Character UUID, one job and one grade reference, provenance, and optional employer/duty required.')
    end
    request = Jobs.Copy(request)
    request.characterId = request.characterId:lower()
    if request.jobId then request.jobId = request.jobId:lower() end
    if request.gradeId then request.gradeId = request.gradeId:lower() end
    if request.employerId then request.employerId = request.employerId:lower() end
    local actor = JobAssignments.Policy(request, resource, {
        characterId = request.characterId,
        jobId = request.jobId,
        jobKey = request.jobKey
    })
    if not actor.ok then return actor end

    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'assignment.create',
        fingerprint = Jobs.Fingerprint('assignment.create', request, { 'characterId', 'jobId', 'jobKey',
            'gradeId', 'gradeKey', 'employerType', 'employerId', 'provenanceType', 'provenanceId',
            'dutyState', 'reasonCode' }),
        precheck = function()
            local character = Jobs.ResolveCharacter(request.characterId)
            if not character.ok then return character end
            local employer = Jobs.ValidateEmployer(request.employerType, request.employerId)
            if not employer.ok then return employer end
            return Ok({})
        end,
        body = function(tx)
            -- (perf) Job and grade in one locked read (was two).
            local row = (tx.query([[
                SELECT d.`job_id`,d.`job_key`,d.`label` AS job_label,d.`owner_resource`,d.`status`,
                    g.`grade_id`,g.`grade_key`,g.`label` AS grade_label,g.`ordinal`,g.`status` AS grade_status
                FROM `feather_job_definitions` d
                LEFT JOIN `feather_job_grades` g ON g.`job_id`=d.`job_id` AND ]]
                .. (request.gradeId and 'g.`grade_id`=?' or 'g.`grade_key`=?') .. [[
                WHERE ]] .. (request.jobId and 'd.`job_id`=?' or 'd.`job_key`=?') .. ' LOCK IN SHARE MODE',
                request.gradeId or request.gradeKey, request.jobId or request.jobKey) or {})[1]
            if not row then return Err('job_not_found', 'Job definition not found.') end
            if row.status ~= 'active' then return Err('job_inactive', 'Job definition is retired.') end
            if not Config.Assignments.allowForeignJobs and row.owner_resource ~= resource
                and Config.Access.privilegedAssigners[resource] ~= true then
                return Err('authorization_denied', 'Caller may only assign jobs it owns.')
            end
            if not row.grade_id then return Err('grade_not_found', 'Grade does not belong to this job.') end
            if row.grade_status ~= 'active' then return Err('grade_inactive', 'Grade is retired.') end

            -- (perf) Lock the character state and read the open slot and the
            -- open count in the same statement (was three reads after the lock).
            -- The subqueries stay plain reads, exactly as the separate queries were.
            local slot = OpenSlot(request.characterId, row.job_id, request.employerType, request.employerId)
            tx.exec('INSERT IGNORE INTO `feather_job_character_state` (`character_id`) VALUES (?)', request.characterId)
            local state = (tx.query([[
                SELECT s.`active_assignment_id`, s.`revision`,
                    (SELECT `assignment_id` FROM `feather_job_assignments` WHERE `open_slot`=?) AS existing_id,
                    (SELECT COUNT(*) FROM `feather_job_assignments`
                        WHERE `character_id`=? AND `status`='active') AS open_count
                FROM `feather_job_character_state` s WHERE s.`character_id`=? FOR UPDATE]],
                slot, request.characterId, request.characterId) or {})[1]
            if not state then error('Character job state could not be locked.') end
            if state.existing_id then
                return Err('assignment_exists', 'Character already holds this job for this employer.', {
                    assignmentId = state.existing_id
                })
            end
            if (tonumber(state.open_count) or 0) >= Config.Assignments.maxOpenPerCharacter then
                return Err('assignment_limit', 'Character holds the maximum number of open assignments.')
            end
            local stateRevision = tonumber(state.revision)
            local activate = Config.ActiveAssignment.enabled and Config.ActiveAssignment.autoSelectFirst
                and not state.active_assignment_id

            -- (perf) Assignment ID, event IDs and the timestamp in one round trip.
            -- The row's assigned_at uses that same timestamp, so the snapshot
            -- below matches what a later read returns.
            local ids, nowSeconds = Jobs.NewIds(tx, activate and 3 or 2, true)
            local assignmentId = ids[1]
            local dutyState = request.dutyState or 'off_duty'
            tx.exec([[
                INSERT INTO `feather_job_assignments`
                    (`assignment_id`,`character_id`,`job_id`,`grade_id`,`employer_type`,`employer_id`,
                     `duty_state`,`owner_resource`,`provenance_type`,`provenance_id`,`open_slot`,`assigned_at`)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,FROM_UNIXTIME(?))]],
                assignmentId, request.characterId, row.job_id, row.grade_id,
                request.employerType, request.employerId, dutyState, resource,
                request.provenanceType, request.provenanceId, slot, nowSeconds)

            local events = { {
                eventType = 'assignment.created',
                eventId = ids[2],
                spec = {
                    aggregateType = 'assignment',
                    aggregateId = assignmentId,
                    assignmentId = assignmentId,
                    characterId = request.characterId,
                    jobId = row.job_id,
                    resource = resource,
                    requestId = request.requestId,
                    reasonCode = request.reasonCode,
                    referenceType = request.referenceType,
                    referenceId = request.referenceId,
                    revision = 1,
                    actor = actor.value,
                    details = {
                        jobKey = row.job_key,
                        gradeId = row.grade_id,
                        gradeKey = row.grade_key,
                        dutyState = dutyState,
                        employerType = request.employerType,
                        employerId = request.employerId,
                        provenanceType = request.provenanceType,
                        provenanceId = request.provenanceId,
                        ownerResource = resource
                    }
                }
            } }

            if activate then
                tx.exec([[
                    UPDATE `feather_job_character_state`
                    SET `active_assignment_id`=?,`revision`=`revision`+1
                    WHERE `character_id`=?]], assignmentId, request.characterId)
                events[2] = {
                    eventType = 'assignment.activated',
                    eventId = ids[3],
                    spec = {
                        aggregateType = 'character',
                        aggregateId = request.characterId,
                        assignmentId = assignmentId,
                        characterId = request.characterId,
                        jobId = row.job_id,
                        resource = resource,
                        requestId = request.requestId,
                        reasonCode = request.reasonCode,
                        referenceType = request.referenceType,
                        referenceId = request.referenceId,
                        revision = stateRevision + 1,
                        actor = actor.value,
                        details = { jobKey = row.job_key, activeAssignmentId = assignmentId }
                    }
                }
            end
            -- (perf) Both events in one multi-row INSERT each for events and outbox.
            JobEvents.RecordMany(tx, events)

            -- (perf) Built from known values instead of reading the row back;
            -- same shape and values as JobAssignments.Snapshot.
            return Ok({
                assignmentId = assignmentId,
                characterId = request.characterId,
                jobId = row.job_id,
                jobKey = row.job_key,
                jobLabel = row.job_label,
                jobStatus = row.status,
                gradeId = row.grade_id,
                gradeKey = row.grade_key,
                gradeLabel = row.grade_label,
                gradeOrdinal = tonumber(row.ordinal),
                employerType = request.employerType,
                employerId = request.employerId,
                status = 'active',
                dutyState = dutyState,
                ownerResource = resource,
                provenanceType = request.provenanceType,
                provenanceId = request.provenanceId,
                revision = 1,
                assignedAt = nowSeconds * 1000,
                active = activate or nil
            })
        end
    })
end

-- ChangeAssignmentGrade ------------------------------------------------------

local gradeFields = JobAssignments.Allowed({ 'assignmentId', 'expectedRevision', 'gradeId', 'gradeKey' })

function JobAssignments.ChangeGrade(request, resource)
    local begun = JobAssignments.Begin(request, resource, gradeFields)
    if not begun.ok then return begun end
    if not Jobs.Uuid(request.assignmentId) or not Jobs.Integer(request.expectedRevision, 1, Jobs.MaxRevision)
        or (request.gradeId == nil) == (request.gradeKey == nil)
        or (request.gradeId ~= nil and not Jobs.Uuid(request.gradeId))
        or (request.gradeKey ~= nil and not Jobs.Key(request.gradeKey, 48)) then
        return Err('invalid_input', 'Assignment UUID, expected revision, and one grade reference required.')
    end
    request = Jobs.Copy(request)
    request.assignmentId = request.assignmentId:lower()
    if request.gradeId then request.gradeId = request.gradeId:lower() end
    local actor = JobAssignments.Policy(request, resource, { assignmentId = request.assignmentId })
    if not actor.ok then return actor end

    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'assignment.grade',
        fingerprint = Jobs.Fingerprint('assignment.grade', request,
            { 'assignmentId', 'expectedRevision', 'gradeId', 'gradeKey', 'reasonCode' }),
        body = function(tx)
            local row = (tx.query([[
                SELECT `assignment_id`,`character_id`,`job_id`,`grade_id`,`status`,`owner_resource`,`revision`
                FROM `feather_job_assignments` WHERE `assignment_id`=? FOR UPDATE]], request.assignmentId) or {})[1]
            if not row then return Err('assignment_not_found', 'Assignment not found.') end
            if not JobAssignments.CanMutate(row.owner_resource, resource) then
                return Err('authorization_denied', 'Caller does not own this assignment.')
            end
            if row.status ~= 'active' then return Err('assignment_ended', 'Assignment has ended.') end
            local revision = tonumber(row.revision)
            if revision ~= request.expectedRevision then
                return Err('revision_conflict', 'Assignment revision changed.', { revision = revision })
            end

            local grade = (tx.query([[
                SELECT g.`grade_id`,g.`grade_key`,g.`status`,d.`job_key`
                FROM `feather_job_grades` g
                JOIN `feather_job_definitions` d ON d.`job_id`=g.`job_id`
                WHERE g.`job_id`=? AND ]] .. (request.gradeId and 'g.`grade_id`=?' or 'g.`grade_key`=?')
                .. ' LOCK IN SHARE MODE', row.job_id, request.gradeId or request.gradeKey) or {})[1]
            if not grade then return Err('grade_not_found', 'Grade does not belong to this job.') end
            if grade.status ~= 'active' then return Err('grade_inactive', 'Grade is retired.') end
            if grade.grade_id == row.grade_id then return Err('no_change', 'Assignment already holds that grade.') end

            local previous = (tx.query('SELECT `grade_key` FROM `feather_job_grades` WHERE `grade_id`=?',
                row.grade_id) or {})[1]
            tx.exec([[
                UPDATE `feather_job_assignments` SET `grade_id`=?,`revision`=`revision`+1
                WHERE `assignment_id`=? AND `revision`=?]], grade.grade_id, request.assignmentId, revision)

            JobEvents.Record(tx, 'assignment.grade_changed', {
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
                details = {
                    jobKey = grade.job_key,
                    gradeId = grade.grade_id,
                    gradeKey = grade.grade_key,
                    previousGradeId = row.grade_id,
                    previousGradeKey = previous and previous.grade_key
                }
            })
            return JobAssignments.Read(tx, request.assignmentId)
        end
    })
end

-- EndAssignment --------------------------------------------------------------
-- Ending is terminal: duty resets to off_duty, the open slot is released, and an
-- active selection pointing at this assignment is cleared in the same commit.

local endFields = JobAssignments.Allowed({ 'assignmentId', 'expectedRevision' })

function JobAssignments.End(request, resource)
    local begun = JobAssignments.Begin(request, resource, endFields)
    if not begun.ok then return begun end
    if not Jobs.Uuid(request.assignmentId) or not Jobs.Integer(request.expectedRevision, 1, Jobs.MaxRevision) then
        return Err('invalid_input', 'Assignment UUID and expected revision required.')
    end
    request = Jobs.Copy(request)
    request.assignmentId = request.assignmentId:lower()
    local actor = JobAssignments.Policy(request, resource, { assignmentId = request.assignmentId })
    if not actor.ok then return actor end

    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'assignment.end',
        fingerprint = Jobs.Fingerprint('assignment.end', request, { 'assignmentId', 'expectedRevision', 'reasonCode' }),
        body = function(tx)
            -- Unlocked read only to learn the character; locks follow the shared order.
            local probe = (tx.query('SELECT `character_id` FROM `feather_job_assignments` WHERE `assignment_id`=?',
                request.assignmentId) or {})[1]
            if not probe then return Err('assignment_not_found', 'Assignment not found.') end
            local state = JobAssignments.LockCharacter(tx, probe.character_id)

            local row = (tx.query([[
                SELECT a.`character_id`,a.`job_id`,a.`status`,a.`duty_state`,a.`owner_resource`,a.`revision`,
                    d.`job_key`
                FROM `feather_job_assignments` a
                JOIN `feather_job_definitions` d ON d.`job_id`=a.`job_id`
                WHERE a.`assignment_id`=? FOR UPDATE]], request.assignmentId) or {})[1]
            if not row or row.character_id ~= probe.character_id then
                return Err('assignment_not_found', 'Assignment not found.')
            end
            if not JobAssignments.CanMutate(row.owner_resource, resource) then
                return Err('authorization_denied', 'Caller does not own this assignment.')
            end
            if row.status ~= 'active' then return Err('assignment_ended', 'Assignment has already ended.') end
            local revision = tonumber(row.revision)
            if revision ~= request.expectedRevision then
                return Err('revision_conflict', 'Assignment revision changed.', { revision = revision })
            end

            local activeCleared = state.activeAssignmentId == request.assignmentId
            if activeCleared then
                tx.exec([[
                    UPDATE `feather_job_character_state`
                    SET `active_assignment_id`=NULL,`revision`=`revision`+1
                    WHERE `character_id`=?]], row.character_id)
            end
            tx.exec([[
                UPDATE `feather_job_assignments`
                SET `status`='ended',`duty_state`='off_duty',`open_slot`=NULL,
                    `ended_at`=CURRENT_TIMESTAMP,`revision`=`revision`+1
                WHERE `assignment_id`=? AND `revision`=?]], request.assignmentId, revision)

            JobEvents.Record(tx, 'assignment.ended', {
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
                details = {
                    jobKey = row.job_key,
                    status = 'ended',
                    previousStatus = 'active',
                    previousDutyState = row.duty_state,
                    activeCleared = activeCleared or nil
                }
            })
            return JobAssignments.Read(tx, request.assignmentId)
        end
    })
end

-- Reads ----------------------------------------------------------------------

function JobAssignments.Get(request, resource)
    local allowed = Jobs.CheckRead(resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, { assignmentId = true })
    if not fields.ok then return fields end
    if not Jobs.Uuid(request.assignmentId) then return Err('invalid_input', 'Assignment UUID required.') end
    local row = DB.one(selectAssignment .. ' WHERE a.`assignment_id`=?', request.assignmentId:lower())
    return JobAssignments.Snapshot(row)
end

-- Open assignments are bounded by maxOpenPerCharacter, so no pagination needed.
function JobAssignments.ListOpen(characterId)
    local rows = DB.query(selectAssignment .. [[
        WHERE a.`character_id`=? AND a.`status`='active'
        ORDER BY a.`assigned_at`,a.`assignment_id` LIMIT ?]],
        characterId, Config.Assignments.maxOpenPerCharacter) or {}
    local items = {}
    for _, row in ipairs(rows) do
        local snapshot = JobAssignments.Snapshot(row)
        if not snapshot.ok then return snapshot end
        items[#items + 1] = snapshot.value
    end
    return Ok(items)
end

function JobAssignments.List(request, resource)
    local allowed = Jobs.CheckRead(resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, { characterId = true, includeEnded = true, limit = true, cursor = true })
    if not fields.ok then return fields end
    local limit = request.limit == nil and 20 or request.limit
    if not Jobs.Uuid(request.characterId)
        or (request.includeEnded ~= nil and type(request.includeEnded) ~= 'boolean')
        or not Jobs.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.cursor ~= nil and not Jobs.Uuid(request.cursor)) then
        return Err('invalid_input', 'Character UUID, bounded limit, and optional assignment UUID cursor required.')
    end

    local characterId = request.characterId:lower()
    local sql = selectAssignment .. ' WHERE a.`character_id`=?'
    local params = { characterId }
    if request.includeEnded ~= true then sql = sql .. " AND a.`status`='active'" end
    if request.cursor then
        local cursorId = request.cursor:lower()
        local cursor = DB.one([[
            SELECT DATE_FORMAT(`assigned_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_job_assignments` WHERE `assignment_id`=? AND `character_id`=?]], cursorId, characterId)
        if not cursor then return Err('invalid_cursor', 'Cursor does not belong to this character.') end
        sql = sql .. ' AND (a.`assigned_at`<? OR (a.`assigned_at`=? AND a.`assignment_id`<?))'
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = cursorId
    end
    sql = sql .. ' ORDER BY a.`assigned_at` DESC,a.`assignment_id` DESC LIMIT ?'
    params[#params + 1] = limit + 1

    local rows = DB.query(sql, table.unpack(params)) or {}
    local items = {}
    for index = 1, math.min(#rows, limit) do
        local snapshot = JobAssignments.Snapshot(rows[index])
        if not snapshot.ok then return snapshot end
        items[#items + 1] = snapshot.value
    end
    return Ok({ items = items, nextCursor = #rows > limit and items[#items].assignmentId or nil })
end

Jobs.Export('CreateAssignment', JobAssignments.Create)
Jobs.Export('ChangeAssignmentGrade', JobAssignments.ChangeGrade)
Jobs.Export('EndAssignment', JobAssignments.End)
Jobs.Export('GetAssignment', JobAssignments.Get)
Jobs.Export('ListCharacterAssignments', JobAssignments.List)
