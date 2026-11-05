CreateThread(function()
    local called, result = xpcall(function()
        local valid = Jobs.ValidateConfig()
        if not valid.ok then return valid end

        Jobs.SetState('waiting', 'waiting_for_core')
        local ready = exports['feather-core']:AwaitReady(Config.ReadinessTimeoutMs)
        if type(ready) ~= 'table' or not ready.ok then
            return Jobs.Err('dependency_unavailable', 'Core did not become ready.')
        end
        local capabilities = exports['feather-core']:GetCapabilities()
        if type(capabilities) ~= 'table' or not capabilities.ok or type(capabilities.value) ~= 'table'
            or capabilities.value.contract ~= Config.RequiredCoreContract then
            return Jobs.Err('dependency_unavailable', 'Core Contract 1 is required.')
        end

        Jobs.SetState('waiting', 'waiting_for_database')
        if DB.awaitReady(Config.ReadinessTimeoutMs) ~= true then
            return Jobs.Err('dependency_unavailable', 'Database did not become ready.')
        end

        Jobs.SetState('migrating', 'database_migrations')
        local migrated = JobMigrations.Run()
        if not migrated.ok then return migrated end

        Jobs.SetState('starting', 'registering_contracts')
        local events = JobEvents.Start()
        if not events.ok then return events end
        local routes = JobRoutes.Register()
        if not routes.ok then return routes end

        Jobs.SetState('ready', 'ready')
        print(('[feather-jobs] event=startup.ready migrationsApplied=%d routes=%d'):format(
            migrated.value.applied, routes.value))
        return Jobs.Ok(true)
    end, debug.traceback)
    if not called then
        print('[feather-jobs] startup traceback: ' .. tostring(result))
        Jobs.Fail(Jobs.Err('startup_failed', 'Jobs startup raised an exception.'))
    elseif not result.ok then
        Jobs.Fail(result)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' or resource == 'feather-mysql' then
        JobEvents.Stop()
        Jobs.Fail(Jobs.Err('dependency_unavailable', 'A required dependency stopped. Restart Jobs after it is ready.'))
    elseif resource == GetCurrentResourceName() then
        JobEvents.Stop()
        Jobs.SetState('stopped', 'resource_stopped')
    end
end)

-- Read-only release gate; safe on production.
-- Read-only native wiring check. Does not change providers, employer state or assignments.
RegisterCommand('JobsNativeIntegrationSmokeTest', function(source, args)
    if source ~= 0 then return end
    local expected = { active = 'allowed', inactive = 'employer_inactive', missing = 'employer_not_found' }
    if not Jobs.Uuid(args[1]) or not expected[args[2]] then
        print('[JobsNativeIntegrationSmokeTest] usage: JobsNativeIntegrationSmokeTest <organizationUUID> <active|inactive|missing>')
        return
    end
    CreateThread(function()
        local called, reason = xpcall(function()
            local function Policy(action, principal)
                return Jobs.Authorize(action, principal, 'jobs.native.readonly', {})
            end
            local definition = Policy(Config.Authorization.definitionAction, 'feather-jobs')
            local assignment = Policy(Config.Authorization.assignmentAction, 'feather-jobs')
            local foreignDefinition = Policy(Config.Authorization.definitionAction, 'jobs-untrusted-native-test')
            local foreignAssignment = Policy(Config.Authorization.assignmentAction, 'jobs-untrusted-native-test')
            local employer = Jobs.ValidateEmployer('organization', args[1])
            local tests = {
                { 'Jobs ready', Jobs.GetHealth().value.state == 'ready' },
                { 'policy enabled', Config.Authorization.enabled == true },
                { 'native definition policy', definition.ok == true },
                { 'native assignment policy', assignment.ok == true },
                { 'foreign definition denied', not foreignDefinition.ok and foreignDefinition.code == 'authorization_denied' },
                { 'foreign assignment denied', not foreignAssignment.ok and foreignAssignment.code == 'authorization_denied' },
                { 'organization employer ' .. args[2],
                    (args[2] == 'active' and employer.ok == true)
                    or (args[2] ~= 'active' and not employer.ok and employer.code == expected[args[2]]) },
            }
            local passed = 0
            for _, test in ipairs(tests) do
                if test[2] then passed = passed + 1 end
                print(('[JobsNativeIntegrationSmokeTest] %s %s'):format(test[2] and 'PASS' or 'FAIL', test[1]))
            end
            print(('[JobsNativeIntegrationSmokeTest] employerResult=%s done %d/%d passed (read-only)')
                :format(employer.ok and 'allowed' or tostring(employer.code), passed, #tests))
        end, debug.traceback)
        if not called then print('[JobsNativeIntegrationSmokeTest] FAIL ' .. tostring(reason)) end
    end)
end, true)

RegisterCommand('JobsReleaseContractSmokeTest', function(source)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local registered = {}
        for _, command in ipairs(GetRegisteredCommands() or {}) do registered[command.name] = true end
        local routeFound = false
        local routes = exports['feather-core']:GetRpcRoutes()
        for _, route in ipairs(type(routes) == 'table' and routes.ok and routes.value or {}) do
            if route.route == 'jobs.snapshot.get.v1' and route.owner == GetCurrentResourceName() then
                routeFound = true
            end
        end
        local health = Jobs.GetHealth()
        local capabilities = Jobs.GetCapabilities()
        local events = JobEvents.State()
        local migrations = tonumber(DB.value('SELECT COUNT(*) FROM `feather_job_schema_migrations`'))
        local denied = JobDefinitions.List({}, 'untrusted-smoke-caller')
        -- Integrity: an open slot exactly on open assignments, and every active
        -- selection points at an open assignment of the same character.
        local broken = tonumber(DB.value([[
            SELECT (SELECT COUNT(*) FROM `feather_job_assignments`
                    WHERE (`status`='active') <> (`open_slot` IS NOT NULL))
                + (SELECT COUNT(*) FROM `feather_job_character_state` s
                    LEFT JOIN `feather_job_assignments` a ON a.`assignment_id`=s.`active_assignment_id`
                    WHERE s.`active_assignment_id` IS NOT NULL
                        AND (a.`assignment_id` IS NULL OR a.`status`<>'active' OR a.`character_id`<>s.`character_id`))]]))
        local fixture = 'feather-jobs-tests'
        local fixtureAbsent = true
        for _, group in pairs(Config.Access) do
            if group[fixture] == true then fixtureAbsent = false end
        end
        local tests = {
            { 'service ready', health.ok and health.value.state == 'ready' },
            { 'server development disabled', Config.DevMode == false },
            { 'development commands absent', not registered.JobsLifecycleSmokeTest },
            { 'fixture trust absent', fixtureAbsent },
            { 'authorization enabled', Config.Authorization.enabled == true },
            { 'publisher running', events.ok and events.value.running == true },
            { 'migration ledger', migrations == JobMigrations.Count },
            { 'snapshot route owned', routeFound },
            { 'untrusted reader denied', not denied.ok and denied.code == 'authorization_denied' },
            { 'assignment integrity', broken == 0 },
            { 'contract capabilities', capabilities.ok and capabilities.value.contract == 1
                and capabilities.value.features.assignments == 1
                and capabilities.value.features.references == 1 }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[JobsReleaseContractSmokeTest] %-29s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[JobsReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
    end, debug.traceback)
    if not called then print('[JobsReleaseContractSmokeTest] FAIL ' .. tostring(reason)) end
end, true)
