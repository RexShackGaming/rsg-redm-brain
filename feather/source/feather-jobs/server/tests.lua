-- Development-only acceptance test. MUTATES DATA: it registers a uniquely keyed
-- smoke_* job, assigns it to the given character twice (two employers), switches
-- the active job, walks the lifecycle, ends both assignments, and retires the
-- job. The character may be offline but must not have an active job owned by
-- another resource. Never enable DevMode in production.
--   Usage (server console): JobsLifecycleSmokeTest <serverId|characterUuid>

local function Target(argument)
    if Jobs.Uuid(argument) then return argument:lower() end
    local source = tonumber(argument)
    if not source then return nil end
    local session = exports['feather-core']:GetSessionContext(source)
    return type(session) == 'table' and session.ok and session.value.characterId or nil
end

Jobs.RegisterDevCommand('JobsLifecycleSmokeTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local characterId = Target(args[1])
        if not characterId then
            print('[JobsLifecycleSmokeTest] usage: JobsLifecycleSmokeTest <serverId|characterUuid>')
            return
        end
        local owner, untrusted = GetCurrentResourceName(), 'untrusted-smoke-caller'
        local before = JobEffective.Build(characterId)
        if not before.ok then
            print('[JobsLifecycleSmokeTest] snapshot failed: ' .. tostring(before.code))
            return
        end
        if before.value.active and before.value.active.ownerResource ~= owner then
            print(('[JobsLifecycleSmokeTest] the active job of this character belongs to %s; use a character without a job')
                :format(tostring(before.value.active.ownerResource)))
            return
        end
        local run = ('%d%04d'):format(os.time(), math.random(0, 9999))
        local jobKey = 'smoke_' .. run
        local function Id(step) return ('smoke:%s:%s'):format(run, step) end

        local registered = JobDefinitions.Register({ requestId = Id('register'), jobKey = jobKey,
            label = 'Smoke Job', reasonCode = 'jobs.smoke_test' }, owner)
        local replayed = JobDefinitions.Register({ requestId = Id('register'), jobKey = jobKey,
            label = 'Smoke Job', reasonCode = 'jobs.smoke_test' }, owner)
        local conflicted = JobDefinitions.Register({ requestId = Id('register'), jobKey = jobKey,
            label = 'Different Label', reasonCode = 'jobs.smoke_test' }, owner)
        local denied = JobDefinitions.Register({ requestId = Id('denied'), jobKey = jobKey .. '_x',
            label = 'Denied', reasonCode = 'jobs.smoke_test' }, untrusted)
        local jobId = registered.ok and registered.value.jobId or '00000000-0000-0000-0000-000000000000'

        local recruit = JobDefinitions.DefineGrade({ requestId = Id('grade-recruit'), jobId = jobId,
            gradeKey = 'recruit', label = 'Recruit', ordinal = 0, reasonCode = 'jobs.smoke_test' }, owner)
        local senior = JobDefinitions.DefineGrade({ requestId = Id('grade-senior'), jobId = jobId,
            gradeKey = 'senior', label = 'Senior', ordinal = 10, reasonCode = 'jobs.smoke_test' }, owner)
        local ordinalClash = JobDefinitions.DefineGrade({ requestId = Id('grade-clash'), jobId = jobId,
            gradeKey = 'clash', label = 'Clash', ordinal = 10, reasonCode = 'jobs.smoke_test' }, owner)
        local definition = JobDefinitions.Get({ jobId = jobId }, owner)

        local created = JobAssignments.Create({ requestId = Id('assign'), characterId = characterId,
            jobKey = jobKey, gradeKey = 'recruit', provenanceType = 'smoke_test', provenanceId = run,
            reasonCode = 'jobs.smoke_test' }, owner)
        local duplicate = JobAssignments.Create({ requestId = Id('assign-again'), characterId = characterId,
            jobKey = jobKey, gradeKey = 'recruit', provenanceType = 'smoke_test', provenanceId = run,
            reasonCode = 'jobs.smoke_test' }, owner)
        local assignmentId = created.ok and created.value.assignmentId or '00000000-0000-0000-0000-000000000000'

        local stale = JobAssignments.ChangeGrade({ requestId = Id('promote-stale'), assignmentId = assignmentId,
            expectedRevision = 99, gradeKey = 'senior', reasonCode = 'jobs.smoke_test' }, owner)
        local promoted = JobAssignments.ChangeGrade({ requestId = Id('promote'), assignmentId = assignmentId,
            expectedRevision = 1, gradeKey = 'senior', reasonCode = 'jobs.smoke_test' }, owner)
        local onDuty = JobEffective.SetDuty({ requestId = Id('duty'), assignmentId = assignmentId,
            expectedRevision = 2, dutyState = 'on_duty', reasonCode = 'jobs.smoke_test' }, owner)
        local checked = JobEffective.Check({ characterId = characterId, jobKey = jobKey,
            minGradeOrdinal = 10, dutyState = 'on_duty' }, owner)

        -- Same job for a second employer: a separate assignment, never an overwrite.
        local employerId = DB.value('SELECT UUID()')
        local second = JobAssignments.Create({ requestId = Id('assign-second'), characterId = characterId,
            jobKey = jobKey, gradeKey = 'recruit', employerType = 'society', employerId = employerId,
            provenanceType = 'smoke_test', provenanceId = run .. ':second', referenceType = 'smoke_run',
            referenceId = run, reasonCode = 'jobs.smoke_test' }, owner)
        local secondId = second.ok and second.value.assignmentId or '00000000-0000-0000-0000-000000000000'
        -- A door that requires duty (bcc-doorlocks) must not open for the off-duty assignment.
        local offDuty = JobEffective.Check({ characterId = characterId, jobKey = jobKey,
            employerType = 'society', employerId = employerId, dutyState = 'on_duty' }, owner)
        local both = JobEffective.Build(characterId)
        local function Holds(snapshot, assignmentId)
            for _, assignment in ipairs(snapshot.ok and snapshot.value.assignments or {}) do
                if assignment.assignmentId == assignmentId then return true end
            end
            return false
        end
        local activated = JobEffective.SetActive({ requestId = Id('activate'), characterId = characterId,
            assignmentId = secondId, expectedRevision = both.ok and both.value.revision or 0,
            reasonCode = 'jobs.smoke_test' }, owner)
        local activeCheck = JobEffective.Check({ characterId = characterId, jobKey = jobKey, activeOnly = true }, owner)
        local endedSecond = JobAssignments.End({ requestId = Id('end-second'), assignmentId = secondId,
            expectedRevision = 1, reasonCode = 'jobs.smoke_test' }, owner)
        local afterSecond = JobEffective.Build(characterId)
        local secondHistory = JobEvents.History({ aggregateType = 'assignment', aggregateId = secondId }, owner)
        local referenced = false
        for _, item in ipairs(secondHistory.ok and secondHistory.value.items or {}) do
            if item.eventType == 'assignment.created' and item.referenceType == 'smoke_run'
                and item.referenceId == run then referenced = true end
        end
        local foreignEnd = JobAssignments.End({ requestId = Id('end-foreign'), assignmentId = assignmentId,
            expectedRevision = 3, reasonCode = 'jobs.smoke_test' }, untrusted)
        local ended = JobAssignments.End({ requestId = Id('end'), assignmentId = assignmentId,
            expectedRevision = 3, reasonCode = 'jobs.smoke_test' }, owner)
        local endedAgain = JobAssignments.End({ requestId = Id('end-again'), assignmentId = assignmentId,
            expectedRevision = 4, reasonCode = 'jobs.smoke_test' }, owner)
        local after = JobEffective.Build(characterId)
        local lookup = Jobs.FindOperation({ requestId = Id('assign') }, owner)
        local history = JobEvents.History({ aggregateType = 'assignment', aggregateId = assignmentId }, owner)
        local retired = JobDefinitions.Update({ requestId = Id('retire'), jobId = jobId, expectedRevision = 1,
            status = 'retired', reasonCode = 'jobs.smoke_test' }, owner)

        local stillHeld = Holds(after, assignmentId) or Holds(after, secondId)
        local tests = {
            { 'register definition', registered.ok and registered.value.jobKey == jobKey
                and registered.value.replayed == false },
            { 'idempotent replay', replayed.ok and replayed.value.replayed == true and replayed.value.jobId == jobId },
            { 'idempotency conflict', not conflicted.ok and conflicted.code == 'idempotency_conflict' },
            { 'untrusted registrar denied', not denied.ok and denied.code == 'authorization_denied' },
            { 'grades defined', recruit.ok and senior.ok and senior.value.ordinal == 10 },
            { 'ordinal conflict', not ordinalClash.ok and ordinalClash.code == 'grade_ordinal_conflict' },
            { 'grades ordered', definition.ok and #definition.value.grades == 2
                and definition.value.grades[1].gradeKey == 'recruit' },
            { 'assignment created', created.ok and created.value.revision == 1
                and created.value.dutyState == 'off_duty' },
            { 'open slot enforced', not duplicate.ok and duplicate.code == 'assignment_exists' },
            { 'stale revision rejected', not stale.ok and stale.code == 'revision_conflict' },
            { 'grade changed', promoted.ok and promoted.value.gradeKey == 'senior' and promoted.value.revision == 2 },
            { 'duty keeps identifiers', onDuty.ok and onDuty.value.dutyState == 'on_duty'
                and onDuty.value.jobId == jobId and onDuty.value.gradeKey == 'senior' },
            { 'check returns facts', checked.ok and checked.value.matched == true },
            { 'second employer kept apart', second.ok and Holds(both, assignmentId) and Holds(both, secondId) },
            { 'duty filter excludes off', offDuty.ok and offDuty.value.matched == false },
            { 'active selection switched', activated.ok and activated.value.activeAssignmentId == secondId },
            { 'active-only check', activeCheck.ok and activeCheck.value.matched == true
                and activeCheck.value.assignment.assignmentId == secondId },
            { 'ending one keeps other', endedSecond.ok and Holds(afterSecond, assignmentId)
                and not Holds(afterSecond, secondId) and afterSecond.value.activeAssignmentId == nil },
            { 'reference recorded', referenced },
            { 'foreign mutation denied', not foreignEnd.ok and foreignEnd.code == 'authorization_denied' },
            { 'assignment ended', ended.ok and ended.value.status == 'ended' and ended.value.dutyState == 'off_duty' },
            { 'end is terminal', not endedAgain.ok and endedAgain.code == 'assignment_ended' },
            { 'snapshot excludes ended', after.ok and not stillHeld },
            { 'operation lookup', lookup.ok and lookup.value.found == true
                and lookup.value.operation == 'assignment.create' },
            { 'audit history', history.ok and #history.value.items >= 4 },
            { 'smoke job retired', retired.ok and retired.value.status == 'retired' }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[JobsLifecycleSmokeTest] %-26s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[JobsLifecycleSmokeTest] done %d/%d passed (MUTATING: job %s)'):format(passed, #tests, jobKey))
        local function Explain(step, result)
            if result.ok then return end
            local details = type(result.details) == 'table' and result.details or {}
            print(('[JobsLifecycleSmokeTest] %s failed code=%s policyCode=%s provider=%s reason=%s'):format(
                step, tostring(result.code), tostring(details.policyCode), tostring(details.provider),
                tostring(details.policyReason or result.message)))
        end
        Explain('register', registered)
        Explain('assign', created)
        Explain('assign-second', second)
        Explain('activate', activated)
    end, debug.traceback)
    if not called then print('[JobsLifecycleSmokeTest] FAIL ' .. tostring(reason)) end
end, true)
