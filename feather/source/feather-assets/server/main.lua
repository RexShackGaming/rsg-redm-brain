CreateThread(function()
    local called, result = xpcall(function()
        local valid = Assets.ValidateConfig()
        if not valid.ok then
            return valid
        end

        Assets.SetState('waiting', 'waiting_for_core')
        local ready = exports['feather-core']:AwaitReady(Config.ReadinessTimeoutMs)
        if type(ready) ~= 'table' or not ready.ok then
            return Assets.Err('dependency_unavailable', 'Core did not become ready.')
        end
        local capabilities = exports['feather-core']:GetCapabilities()
        if type(capabilities) ~= 'table' or not capabilities.ok or type(capabilities.value) ~= 'table'
            or capabilities.value.contract ~= Config.RequiredCoreContract then
            return Assets.Err('dependency_unavailable', 'Core Contract 1 is required.')
        end

        Assets.SetState('waiting', 'waiting_for_database')
        if DB.awaitReady(Config.ReadinessTimeoutMs) ~= true then
            return Assets.Err('dependency_unavailable', 'Database did not become ready.')
        end

        Assets.SetState('migrating', 'database_migrations')
        local migrated = AssetMigrations.Run()
        if not migrated.ok then
            return migrated
        end

        Assets.SetState('starting', 'registering_contracts')
        local events = AssetEvents.Start()
        if not events.ok then
            return events
        end
        local routes = AssetRoutes.Register()
        if not routes.ok then
            return routes
        end

        Assets.SetState('ready', 'ready')
        print(('[feather-assets] event=startup.ready migrationsApplied=%d routes=%d'):format(
            migrated.value.applied, routes.value))
        return Assets.Ok(true)
    end, debug.traceback)
    if not called then
        print('[feather-assets] startup traceback: ' .. tostring(result))
        Assets.Fail(Assets.Err('startup_failed', 'Assets startup raised an exception.'))
    elseif not result.ok then
        Assets.Fail(result)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' or resource == 'feather-mysql' then
        AssetEvents.Stop()
        Assets.Fail(Assets.Err('dependency_unavailable', 'A required dependency stopped. Restart Assets after it is ready.'))
    elseif resource == GetCurrentResourceName() then
        AssetEvents.Stop()
        Assets.SetState('stopped', 'resource_stopped')
    end
end)

-- Read-only release gate; safe on production.
RegisterCommand('AssetsReleaseContractSmokeTest', function(source)
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
            if route.route == 'assets.owned.list.v1' and route.owner == GetCurrentResourceName() then
                routeFound = true
            end
        end
        local health = Assets.GetHealth()
        local capabilities = Assets.GetCapabilities()
        local events = AssetEvents.State()
        local migrations = tonumber(DB.value('SELECT COUNT(*) FROM `feather_asset_schema_migrations`'))
        local denied = AssetRecords.Get({ assetId = '00000000-0000-0000-0000-000000000000' }, 'untrusted-smoke-caller')
        -- Integrity: every live asset has exactly one owner, a retired one none.
        local broken = tonumber(DB.value([[
            SELECT COUNT(*) FROM `feather_asset_records` r
            WHERE (r.`status`<>'retired') <> (
                SELECT COUNT(*) FROM `feather_asset_interests` i
                WHERE i.`asset_id`=r.`asset_id` AND i.`interest_type`='owner' AND i.`status`='active'
            )]]))
        local tests = {
            { 'service ready', health.ok and health.value.state == 'ready' },
            { 'server development disabled', Config.DevMode == false },
            { 'development commands absent', not registered.AssetsLifecycleSmokeTest },
            { 'authorization enabled', Config.Authorization.enabled == true },
            { 'publisher running', events.ok and events.value.running == true },
            { 'migration ledger', migrations == AssetMigrations.Count },
            { 'owned route registered', routeFound },
            { 'untrusted reader denied', not denied.ok and denied.code == 'authorization_denied' },
            { 'one owner per live asset', broken == 0 },
            { 'contract capabilities', capabilities.ok and capabilities.value.contract == 1
                and capabilities.value.features.ownership == 1
                and capabilities.value.features.delegationEpoch == 1 }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then
                passed = passed + 1
            end
            print(('[AssetsReleaseContractSmokeTest] %-29s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AssetsReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
    end, debug.traceback)
    if not called then
        print('[AssetsReleaseContractSmokeTest] FAIL ' .. tostring(reason))
    end
end, true)
