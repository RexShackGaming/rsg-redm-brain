CreateThread(function()
    local called, result = xpcall(function()
        local valid = Licenses.ValidateConfig()
        if not valid.ok then
            return valid
        end

        Licenses.SetState('waiting', 'waiting_for_core')
        local ready = exports['feather-core']:AwaitReady(Config.ReadinessTimeoutMs)
        if type(ready) ~= 'table' or not ready.ok then
            return Licenses.Err('dependency_unavailable', 'Core did not become ready.')
        end
        local capabilities = exports['feather-core']:GetCapabilities()
        if type(capabilities) ~= 'table' or not capabilities.ok or type(capabilities.value) ~= 'table'
            or capabilities.value.contract ~= Config.RequiredCoreContract then
            return Licenses.Err('dependency_unavailable', 'Core Contract 1 is required.')
        end

        Licenses.SetState('waiting', 'waiting_for_database')
        if DB.awaitReady(Config.ReadinessTimeoutMs) ~= true then
            return Licenses.Err('dependency_unavailable', 'Database did not become ready.')
        end

        Licenses.SetState('migrating', 'database_migrations')
        local migrated = LicenseMigrations.Run()
        if not migrated.ok then
            return migrated
        end

        Licenses.SetState('starting', 'registering_contracts')
        local events = LicenseEvents.Start()
        if not events.ok then
            return events
        end
        local routes = LicenseRoutes.Register()
        if not routes.ok then
            return routes
        end
        LicenseExpiry.Start()

        Licenses.SetState('ready', 'ready')
        print(('[feather-licenses] event=startup.ready migrationsApplied=%d routes=%d'):format(
            migrated.value.applied, routes.value))
        return Licenses.Ok(true)
    end, debug.traceback)
    if not called then
        print('[feather-licenses] startup traceback: ' .. tostring(result))
        Licenses.Fail(Licenses.Err('startup_failed', 'Licenses startup raised an exception.'))
    elseif not result.ok then
        Licenses.Fail(result)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' or resource == 'feather-mysql' then
        LicenseEvents.Stop()
        LicenseExpiry.Stop()
        Licenses.Fail(Licenses.Err('dependency_unavailable', 'A required dependency stopped. Restart Licenses after it is ready.'))
    elseif resource == GetCurrentResourceName() then
        LicenseEvents.Stop()
        LicenseExpiry.Stop()
        Licenses.SetState('stopped', 'resource_stopped')
    end
end)

-- Read-only release gate; safe on production.
RegisterCommand('LicensesReleaseContractSmokeTest', function(source)
    if source ~= 0 then
        return
    end
    local called, reason = xpcall(function()
        local registered = {}
        for _, command in ipairs(GetRegisteredCommands() or {}) do
            registered[command.name] = true
        end
        local routeFound = false
        local routes = exports['feather-core']:GetRpcRoutes()
        for _, route in ipairs(type(routes) == 'table' and routes.ok and routes.value or {}) do
            if route.route == 'licenses.held.list.v1' and route.owner == GetCurrentResourceName() then
                routeFound = true
            end
        end
        local health = Licenses.GetHealth()
        local capabilities = Licenses.GetCapabilities()
        local events = LicenseEvents.State()
        local migrations = tonumber(DB.value('SELECT COUNT(*) FROM `feather_license_schema_migrations`'))
        local denied = LicenseRecords.Get({ licenseId = '00000000-0000-0000-0000-000000000000' }, 'untrusted-smoke-caller')
        -- Integrity: a current slot exactly on licenses that are not revoked.
        local broken = tonumber(DB.value([[
            SELECT COUNT(*) FROM `feather_licenses`
            WHERE (`status`<>'revoked') <> (`current_slot` IS NOT NULL)]]))
        local tests = {
            { 'service ready', health.ok and health.value.state == 'ready' },
            { 'server development disabled', Config.DevMode == false },
            { 'development commands absent', not registered.LicensesLifecycleSmokeTest },
            { 'authorization enabled', Config.Authorization.enabled == true },
            { 'publisher running', events.ok and events.value.running == true },
            { 'migration ledger', migrations == LicenseMigrations.Count },
            { 'held route registered', routeFound },
            { 'untrusted reader denied', not denied.ok and denied.code == 'authorization_denied' },
            { 'one current license per slot', broken == 0 },
            { 'contract capabilities', capabilities.ok and capabilities.value.contract == 1
                and capabilities.value.features.issuance == 1 }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then
                passed = passed + 1
            end
            print(('[LicensesReleaseContractSmokeTest] %-29s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[LicensesReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
    end, debug.traceback)
    if not called then
        print('[LicensesReleaseContractSmokeTest] FAIL ' .. tostring(reason))
    end
end, true)
