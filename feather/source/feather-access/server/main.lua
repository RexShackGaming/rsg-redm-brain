AddEventHandler('onResourceStop', function(resource)
    Access.InventoryFence.Stopped(resource)
    Access.Employment.Stopped(resource)
    Access.Providers.DropOwner(resource)
    if resource == GetCurrentResourceName() then
        Access.Audit.Stop()
        Access.SetState('stopped', 'resource_stopped')
    elseif resource == 'feather-core' or resource == 'feather-mysql' then
        Access.Audit.Stop()
        Access.Fail(Access.Err('dependency_unavailable',
            'A required dependency stopped. Restart Access after it is ready.', { resource = resource }))
    elseif resource == 'feather-audit' then Access.Audit.AuditStopped()
    elseif resource == 'feather-access-tests' then Access.Audit.FixtureStopped() end
end)

CreateThread(function()
    local called, result = xpcall(function()
        local valid = Access.ValidateConfig()
        if not valid.ok then return valid end
        local dependencies = Access.StartDependencies()
        if not dependencies.ok then return dependencies end
        Access.SetState('migrating', 'database_migrations')
        local migrated = Access.Migrations.Run()
        if not migrated.ok then return migrated end
        local currentDependencies = Access.CheckDependencies()
        if not currentDependencies.ok then return currentDependencies end
        -- A stop event during a yielding startup must not be overwritten by ready.
        if Access.GetHealth().value.state == 'failed' then
            return Access.Err('dependency_unavailable', 'A dependency stopped during startup; restart Access.')
        end
        local publisher = Access.Audit.Start()
        if not publisher.ok then return publisher end
        Access.SetState('ready', 'providers_ready')
        local employment = Access.Employment.Start()
        if not employment.ok then return employment end
        print(('[feather-access] event=migrations.verified applied=%d total=%d'):format(
            migrated.value.applied, migrated.value.total))
        return Access.Ok(true)
    end, debug.traceback)
    if not called then
        print('[feather-access] startup traceback: ' .. tostring(result))
        Access.Fail(Access.Err('startup_failed', 'Access startup raised an exception.'))
    elseif not result.ok then
        Access.Fail(result)
    end
end)
