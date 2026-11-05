local sweeping = false

-- Ends tenancies whose valid_until has passed (see PropertyInterests.SweepExpired).
local function StartSweep()
    if sweeping then
        return
    end
    sweeping = true
    CreateThread(function()
        while sweeping do
            Wait(Config.Limits.expirySweepMs)
            if sweeping and Property.IsReady() then
                local called, result = pcall(PropertyInterests.SweepExpired)
                if not called then
                    print('[feather-property] event=expiry.error ' .. tostring(result))
                elseif result > 0 then
                    print(('[feather-property] event=expiry.ended count=%d'):format(result))
                end
            end
        end
    end)
end

CreateThread(function()
    local called, result = xpcall(function()
        local valid = Property.ValidateConfig()
        if not valid.ok then
            return valid
        end

        Property.SetState('waiting', 'waiting_for_core')
        local ready = exports['feather-core']:AwaitReady(Config.ReadinessTimeoutMs)
        if type(ready) ~= 'table' or not ready.ok then
            return Property.Err('dependency_unavailable', 'Core did not become ready.')
        end
        local capabilities = exports['feather-core']:GetCapabilities()
        if type(capabilities) ~= 'table' or not capabilities.ok or type(capabilities.value) ~= 'table'
            or capabilities.value.contract ~= Config.RequiredCoreContract then
            return Property.Err('dependency_unavailable', 'Core Contract 1 is required.')
        end

        Property.SetState('waiting', 'waiting_for_database')
        if DB.awaitReady(Config.ReadinessTimeoutMs) ~= true then
            return Property.Err('dependency_unavailable', 'Database did not become ready.')
        end

        Property.SetState('migrating', 'database_migrations')
        local migrated = PropertyMigrations.Run()
        if not migrated.ok then
            return migrated
        end

        Property.SetState('starting', 'registering_contracts')
        local events = PropertyEvents.Start()
        if not events.ok then
            return events
        end
        local routes = PropertyRoutes.Register()
        if not routes.ok then
            return routes
        end

        Property.SetState('ready', 'ready')
        StartSweep()
        print(('[feather-property] event=startup.ready migrationsApplied=%d routes=%d'):format(
            migrated.value.applied, routes.value))
        return Property.Ok(true)
    end, debug.traceback)
    if not called then
        print('[feather-property] startup traceback: ' .. tostring(result))
        Property.Fail(Property.Err('startup_failed', 'Property startup raised an exception.'))
    elseif not result.ok then
        Property.Fail(result)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' or resource == 'feather-mysql' then
        PropertyEvents.Stop()
        sweeping = false
        Property.Fail(Property.Err('dependency_unavailable', 'A required dependency stopped. Restart Property after it is ready.'))
    elseif resource == GetCurrentResourceName() then
        PropertyEvents.Stop()
        sweeping = false
        Property.SetState('stopped', 'resource_stopped')
    end
end)

-- Read-only release gate; safe on production.
RegisterCommand('PropertyReleaseContractSmokeTest', function(source)
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
            if route.route == 'property.held.list.v1' and route.owner == GetCurrentResourceName() then
                routeFound = true
            end
        end
        local health = Property.GetHealth()
        local capabilities = Property.GetCapabilities()
        local events = PropertyEvents.State()
        local migrations = tonumber(DB.value('SELECT COUNT(*) FROM `feather_property_schema_migrations`'))
        local denied = PropertyRecords.Get({ propertyId = '00000000-0000-0000-0000-000000000000' }, 'untrusted-smoke-caller')
        local tests = {
            { 'service ready', health.ok and health.value.state == 'ready' },
            { 'server development disabled', Config.DevMode == false },
            { 'development commands absent', not registered.PropertyLifecycleSmokeTest
                and not registered.PropertyLinkSmokeTest },
            { 'authorization enabled', Config.Authorization.enabled == true },
            { 'publisher running', events.ok and events.value.running == true },
            { 'migration ledger', migrations == PropertyMigrations.Count },
            { 'owned route registered', routeFound },
            { 'untrusted reader denied', not denied.ok and denied.code == 'authorization_denied' },
            { 'contract capabilities', capabilities.ok and capabilities.value.contract == 1
                and capabilities.value.features.ownership == 1
                and capabilities.value.features.tenancy == 1 },
            { 'expiry sweep running', sweeping }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then
                passed = passed + 1
            end
            print(('[PropertyReleaseContractSmokeTest] %-29s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[PropertyReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
    end, debug.traceback)
    if not called then
        print('[PropertyReleaseContractSmokeTest] FAIL ' .. tostring(reason))
    end
end, true)
