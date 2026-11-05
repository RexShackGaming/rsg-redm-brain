JobDefinitions = {}
local Ok, Err = Jobs.Ok, Jobs.Err

local selectDefinition = [[
    SELECT `job_id`,`job_key`,`label`,`owner_resource`,`status`,`metadata_version`,`revision`
    FROM `feather_job_definitions`]]
local selectGrade = [[
    SELECT `grade_id`,`job_id`,`grade_key`,`label`,`ordinal`,`status`,`metadata_version`,`revision`
    FROM `feather_job_grades`]]

-- Snapshots ------------------------------------------------------------------

function JobDefinitions.Snapshot(row)
    if not row then return Err('job_not_found', 'Job definition not found.') end
    if not Jobs.Uuid(row.job_id) or not Jobs.Key(row.job_key, 48)
        or (row.status ~= 'active' and row.status ~= 'retired')
        or not Jobs.Integer(tonumber(row.revision), 1, Jobs.MaxRevision + 1) then
        return Err('invalid_persistence', 'Persisted job definition is invalid.')
    end
    return Ok({
        jobId = row.job_id,
        jobKey = row.job_key,
        label = row.label,
        ownerResource = row.owner_resource,
        status = row.status,
        metadataVersion = tonumber(row.metadata_version),
        revision = tonumber(row.revision)
    })
end

function JobDefinitions.GradeSnapshot(row)
    if not row then return Err('grade_not_found', 'Job grade not found.') end
    if not Jobs.Uuid(row.grade_id) or not Jobs.Uuid(row.job_id) or not Jobs.Key(row.grade_key, 48)
        or (row.status ~= 'active' and row.status ~= 'retired')
        or not Jobs.Integer(tonumber(row.revision), 1, Jobs.MaxRevision + 1) then
        return Err('invalid_persistence', 'Persisted job grade is invalid.')
    end
    return Ok({
        gradeId = row.grade_id,
        jobId = row.job_id,
        gradeKey = row.grade_key,
        label = row.label,
        ordinal = tonumber(row.ordinal),
        status = row.status,
        metadataVersion = tonumber(row.metadata_version),
        revision = tonumber(row.revision)
    })
end

local function OwnsDefinition(definition, resource)
    return definition.owner_resource == resource or Config.Access.privilegedRegistrars[resource] == true
end

local function NewUuid(tx)
    local row = (tx.query('SELECT UUID() AS id') or {})[1]
    return row and Jobs.Uuid(row.id) and row.id or nil
end

local Allowed = Jobs.Allowed

-- Shared prologue: trusted registrar and field/shape validation.
local function Begin(request, resource, allowedFields)
    local allowed = Jobs.CheckAccess('trustedRegistrars', resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, allowedFields)
    if not fields.ok then return fields end
    return Jobs.ValidateCommon(request)
end

-- Service policy, then the server-derived actor recorded on audit facts.
local function Policy(request, resource, subject)
    local policy = Jobs.Authorize(Config.Authorization.definitionAction, resource, request.requestId, subject)
    if not policy.ok then return policy end
    return Jobs.Actor(request)
end

-- RegisterJobDefinition ------------------------------------------------------
-- The caller becomes the definition owner. Consumers re-register on every start
-- with the same stable request ID, which replays the stored result.

local registerFields = Allowed({ 'jobKey', 'label', 'metadataVersion' })

function JobDefinitions.Register(request, resource)
    local begun = Begin(request, resource, registerFields)
    if not begun.ok then return begun end
    if not Jobs.Key(request.jobKey, 48) or not Jobs.Text(request.label, 100)
        or (request.metadataVersion ~= nil and not Jobs.Integer(request.metadataVersion, 1, 65535)) then
        return Err('invalid_input', 'Stable job key, label, and optional metadata version required.')
    end
    request = Jobs.Copy(request)
    local actor = Policy(request, resource, { jobKey = request.jobKey })
    if not actor.ok then return actor end

    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'definition.register',
        fingerprint = Jobs.Fingerprint('definition.register', request,
            { 'jobKey', 'label', 'metadataVersion', 'reasonCode' }),
        body = function(tx)
            local existing = (tx.query(selectDefinition .. ' WHERE `job_key`=? FOR UPDATE', request.jobKey) or {})[1]
            if existing then
                return Err('job_key_conflict', 'Job key is already registered.', {
                    jobId = existing.job_id,
                    ownerResource = existing.owner_resource
                })
            end
            local jobId = NewUuid(tx)
            if not jobId then return Err('internal_error', 'Could not generate job UUID.') end

            tx.exec([[
                INSERT INTO `feather_job_definitions`
                    (`job_id`,`job_key`,`label`,`owner_resource`,`metadata_version`)
                VALUES (?,?,?,?,?)]],
                jobId, request.jobKey, request.label, resource, request.metadataVersion or 1)
            local created = JobDefinitions.Snapshot((tx.query(selectDefinition .. ' WHERE `job_id`=?', jobId) or {})[1])
            if not created.ok then return created end

            JobEvents.Record(tx, 'definition.registered', {
                aggregateType = 'definition',
                aggregateId = jobId,
                jobId = jobId,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = 1,
                actor = actor.value,
                details = {
                    jobKey = request.jobKey,
                    label = request.label,
                    ownerResource = resource,
                    status = 'active'
                }
            })
            return created
        end
    })
end

-- UpdateJobDefinition --------------------------------------------------------

local updateFields = Allowed({ 'jobId', 'expectedRevision', 'label', 'status', 'metadataVersion' })

function JobDefinitions.Update(request, resource)
    local begun = Begin(request, resource, updateFields)
    if not begun.ok then return begun end
    if not Jobs.Uuid(request.jobId) or not Jobs.Integer(request.expectedRevision, 1, Jobs.MaxRevision)
        or (request.label ~= nil and not Jobs.Text(request.label, 100))
        or (request.status ~= nil and request.status ~= 'active' and request.status ~= 'retired')
        or (request.metadataVersion ~= nil and not Jobs.Integer(request.metadataVersion, 1, 65535))
        or (request.label == nil and request.status == nil and request.metadataVersion == nil) then
        return Err('invalid_input', 'Job UUID, expected revision, and at least one change required.')
    end
    request = Jobs.Copy(request)
    request.jobId = request.jobId:lower()
    local actor = Policy(request, resource, { jobId = request.jobId })
    if not actor.ok then return actor end

    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'definition.update',
        fingerprint = Jobs.Fingerprint('definition.update', request,
            { 'jobId', 'expectedRevision', 'label', 'status', 'metadataVersion', 'reasonCode' }),
        body = function(tx)
            local row = (tx.query(selectDefinition .. ' WHERE `job_id`=? FOR UPDATE', request.jobId) or {})[1]
            if not row then return Err('job_not_found', 'Job definition not found.') end
            if not OwnsDefinition(row, resource) then
                return Err('authorization_denied', 'Caller does not own this job definition.')
            end
            local revision = tonumber(row.revision)
            if revision ~= request.expectedRevision then
                return Err('revision_conflict', 'Job definition revision changed.', { revision = revision })
            end

            local label = request.label or row.label
            local status = request.status or row.status
            local metadataVersion = request.metadataVersion or tonumber(row.metadata_version)
            if label == row.label and status == row.status and metadataVersion == tonumber(row.metadata_version) then
                return Err('no_change', 'Job definition already matches the request.')
            end

            tx.exec([[
                UPDATE `feather_job_definitions`
                SET `label`=?,`status`=?,`metadata_version`=?,`revision`=`revision`+1
                WHERE `job_id`=? AND `revision`=?]],
                label, status, metadataVersion, request.jobId, revision)
            local updated = JobDefinitions.Snapshot(
                (tx.query(selectDefinition .. ' WHERE `job_id`=?', request.jobId) or {})[1])
            if not updated.ok then return updated end

            JobEvents.Record(tx, 'definition.updated', {
                aggregateType = 'definition',
                aggregateId = request.jobId,
                jobId = request.jobId,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = {
                    jobKey = row.job_key,
                    label = label,
                    status = status,
                    previousStatus = row.status,
                    metadataVersion = metadataVersion
                }
            })
            return updated
        end
    })
end

-- DefineGrade ----------------------------------------------------------------
-- Creates a grade, or updates an existing one when expectedRevision is given.
-- Ordinals are unique per job; move a grade to a free ordinal before swapping.

local gradeFields = Allowed({
    'jobId', 'gradeKey', 'label', 'ordinal', 'status', 'metadataVersion', 'expectedRevision'
})

function JobDefinitions.DefineGrade(request, resource)
    local begun = Begin(request, resource, gradeFields)
    if not begun.ok then return begun end
    if not Jobs.Uuid(request.jobId) or not Jobs.Key(request.gradeKey, 48) or not Jobs.Text(request.label, 100)
        or not Jobs.Integer(request.ordinal, 0, 1000)
        or (request.status ~= nil and request.status ~= 'active' and request.status ~= 'retired')
        or (request.metadataVersion ~= nil and not Jobs.Integer(request.metadataVersion, 1, 65535))
        or (request.expectedRevision ~= nil and not Jobs.Integer(request.expectedRevision, 1, Jobs.MaxRevision)) then
        return Err('invalid_input',
            'Job UUID, grade key, label, ordinal 0-1000, and optional status/revision required.')
    end
    request = Jobs.Copy(request)
    request.jobId = request.jobId:lower()
    local actor = Policy(request, resource, { jobId = request.jobId, gradeKey = request.gradeKey })
    if not actor.ok then return actor end

    return Jobs.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'grade.define',
        fingerprint = Jobs.Fingerprint('grade.define', request, { 'jobId', 'gradeKey', 'label', 'ordinal',
            'status', 'metadataVersion', 'expectedRevision', 'reasonCode' }),
        body = function(tx)
            -- The definition row lock serializes grade changes per job.
            local job = (tx.query(selectDefinition .. ' WHERE `job_id`=? FOR UPDATE', request.jobId) or {})[1]
            if not job then return Err('job_not_found', 'Job definition not found.') end
            if not OwnsDefinition(job, resource) then
                return Err('authorization_denied', 'Caller does not own this job definition.')
            end

            local existing = (tx.query(selectGrade .. ' WHERE `job_id`=? AND `grade_key`=? FOR UPDATE',
                request.jobId, request.gradeKey) or {})[1]
            local occupied = (tx.query(selectGrade .. ' WHERE `job_id`=? AND `ordinal`=?',
                request.jobId, request.ordinal) or {})[1]
            if occupied and (not existing or occupied.grade_id ~= existing.grade_id) then
                return Err('grade_ordinal_conflict', 'Another grade already uses that ordinal.', {
                    gradeKey = occupied.grade_key
                })
            end

            local status = request.status or 'active'
            local gradeId, revision
            if not existing then
                if request.expectedRevision ~= nil then
                    return Err('grade_not_found', 'Grade does not exist yet; omit expectedRevision.')
                end
                local count = tonumber(tx.value('SELECT COUNT(*) FROM `feather_job_grades` WHERE `job_id`=?',
                    request.jobId)) or 0
                if count >= Config.Limits.maxGradesPerJob then return Err('grade_limit', 'Job grade limit reached.') end
                gradeId = NewUuid(tx)
                if not gradeId then return Err('internal_error', 'Could not generate grade UUID.') end
                tx.exec([[
                    INSERT INTO `feather_job_grades`
                        (`grade_id`,`job_id`,`grade_key`,`label`,`ordinal`,`status`,`metadata_version`)
                    VALUES (?,?,?,?,?,?,?)]],
                    gradeId, request.jobId, request.gradeKey, request.label, request.ordinal,
                    status, request.metadataVersion or 1)
                revision = 1
            else
                if request.expectedRevision == nil then
                    return Err('grade_exists', 'Grade already exists; pass expectedRevision to update it.', {
                        gradeId = existing.grade_id,
                        revision = tonumber(existing.revision)
                    })
                end
                if tonumber(existing.revision) ~= request.expectedRevision then
                    return Err('revision_conflict', 'Grade revision changed.', {
                        revision = tonumber(existing.revision)
                    })
                end
                gradeId, revision = existing.grade_id, tonumber(existing.revision) + 1
                tx.exec([[
                    UPDATE `feather_job_grades`
                    SET `label`=?,`ordinal`=?,`status`=?,`metadata_version`=?,`revision`=`revision`+1
                    WHERE `grade_id`=? AND `revision`=?]],
                    request.label, request.ordinal, status,
                    request.metadataVersion or tonumber(existing.metadata_version), gradeId, request.expectedRevision)
            end

            local gradeRow = (tx.query(selectGrade .. ' WHERE `grade_id`=?', gradeId) or {})[1]
            local grade = JobDefinitions.GradeSnapshot(gradeRow)
            if not grade.ok then return grade end

            JobEvents.Record(tx, 'grade.defined', {
                aggregateType = 'grade',
                aggregateId = gradeId,
                jobId = request.jobId,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision,
                actor = actor.value,
                details = {
                    jobKey = job.job_key,
                    gradeId = gradeId,
                    gradeKey = request.gradeKey,
                    label = request.label,
                    ordinal = request.ordinal,
                    status = status,
                    previousStatus = existing and existing.status or nil
                }
            })
            return grade
        end
    })
end

-- Reads ----------------------------------------------------------------------

function JobDefinitions.Load(jobId, jobKey)
    local row = jobId and DB.one(selectDefinition .. ' WHERE `job_id`=?', jobId)
        or DB.one(selectDefinition .. ' WHERE `job_key`=?', jobKey)
    local definition = JobDefinitions.Snapshot(row)
    if not definition.ok then return definition end

    local grades = {}
    local rows = DB.query(selectGrade .. ' WHERE `job_id`=? ORDER BY `ordinal` LIMIT ?',
        definition.value.jobId, Config.Limits.maxGradesPerJob) or {}
    for _, gradeRow in ipairs(rows) do
        local grade = JobDefinitions.GradeSnapshot(gradeRow)
        if not grade.ok then return grade end
        grades[#grades + 1] = grade.value
    end
    definition.value.grades = grades
    return definition
end

function JobDefinitions.Get(request, resource)
    local allowed = Jobs.CheckRead(resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, { jobId = true, jobKey = true })
    if not fields.ok then return fields end
    if (request.jobId == nil) == (request.jobKey == nil)
        or (request.jobId ~= nil and not Jobs.Uuid(request.jobId))
        or (request.jobKey ~= nil and not Jobs.Key(request.jobKey, 48)) then
        return Err('invalid_input', 'Exactly one of job UUID or job key required.')
    end
    return JobDefinitions.Load(request.jobId and request.jobId:lower(), request.jobKey)
end

function JobDefinitions.List(request, resource)
    local allowed = Jobs.CheckRead(resource)
    if not allowed.ok then return allowed end
    request = request or {}
    local fields = Jobs.Fields(request, { ownerResource = true, status = true, limit = true, cursor = true })
    if not fields.ok then return fields end
    local limit = request.limit == nil and 20 or request.limit
    if not Jobs.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.ownerResource ~= nil
            and (type(request.ownerResource) ~= 'string' or #request.ownerResource > 100))
        or (request.status ~= nil and request.status ~= 'active' and request.status ~= 'retired')
        or (request.cursor ~= nil and not Jobs.Key(request.cursor, 48)) then
        return Err('invalid_input', 'Bounded limit, optional owner/status filters, and job key cursor required.')
    end

    local clauses, params = {}, {}
    local function Where(clause, value)
        clauses[#clauses + 1] = clause
        params[#params + 1] = value
    end
    if request.ownerResource then Where('`owner_resource`=?', request.ownerResource) end
    if request.status then Where('`status`=?', request.status) end
    if request.cursor then Where('`job_key`>?', request.cursor) end

    local sql = selectDefinition
    if #clauses > 0 then sql = sql .. ' WHERE ' .. table.concat(clauses, ' AND ') end
    sql = sql .. ' ORDER BY `job_key` LIMIT ?'
    params[#params + 1] = limit + 1

    local rows = DB.query(sql, table.unpack(params)) or {}
    local items = {}
    for index = 1, math.min(#rows, limit) do
        local definition = JobDefinitions.Snapshot(rows[index])
        if not definition.ok then return definition end
        items[#items + 1] = definition.value
    end
    return Ok({ items = items, nextCursor = #rows > limit and items[#items].jobKey or nil })
end

Jobs.Export('RegisterJobDefinition', JobDefinitions.Register)
Jobs.Export('UpdateJobDefinition', JobDefinitions.Update)
Jobs.Export('DefineGrade', JobDefinitions.DefineGrade)
Jobs.Export('GetJobDefinition', JobDefinitions.Get)
Jobs.Export('ListJobDefinitions', JobDefinitions.List)
