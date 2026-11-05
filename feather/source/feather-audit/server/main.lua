exports('GetHealth', function()
    return FeatherAudit.GetHealth()
end)

exports('GetCapabilities', function()
    return FeatherAudit.GetCapabilities()
end)

exports('Ingest', function(event)
    local sourceResource = GetInvokingResource()
    return FeatherAuditIngestion.Ingest(event, sourceResource)
end)

local function protectedRead(request, actorSource, operation)
    local caller = GetInvokingResource()
    local called, result = pcall(FeatherAuditAuthorization.Search, request, actorSource, caller, operation)
    if not called then
        return { ok = false, code = 'forbidden', message = 'Audit read is not permitted.' }
    end
    return result
end

exports('Search', function(request, actorSource)
    return protectedRead(request, actorSource, 'audit.search.v1')
end)
exports('GetEvent', function(request, actorSource)
    return protectedRead(request, actorSource, 'audit.event.get.v1')
end)
exports('GetCorrelation', function(request, actorSource)
    return protectedRead(request, actorSource, 'audit.correlation.get.v1')
end)

exports('GetVisibilitySmokeFixture', function()
    if GetInvokingResource() ~= 'feather-admin' or not Config.Development.smokeCommands
        or not FeatherAuditVisibilityFixture then return nil end
    local copy = {}
    for key, value in pairs(FeatherAuditVisibilityFixture) do copy[key] = value end
    return copy
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    FeatherAudit.SetState(FeatherAuditConstants.lifecycle.starting, false, 'database_starting')
    if Config.Development.startupMessage then
        print('[feather-audit] Starting migrations and ingestion foundation.')
    end
end)

CreateThread(function()
    DB.awaitReady()
    local configOk, configProblem = FeatherAuditConfig.Validate()
    if not configOk then
        FeatherAudit.SetDatabaseState(false, 0, configProblem)
        FeatherAudit.SetState(FeatherAuditConstants.lifecycle.unavailable, false, 'configuration_invalid')
        print(('[feather-audit] Configuration invalid: %s'):format(tostring(configProblem)))
        return
    end
    local ok, migrationOk, detail = pcall(FeatherAuditMigrations.Run)
    if not ok or not migrationOk then
        local reason = ok and detail or tostring(migrationOk)
        FeatherAudit.SetDatabaseState(false, 0, reason)
        FeatherAudit.SetState(FeatherAuditConstants.lifecycle.unavailable, false, 'migration_failed')
        print(('[feather-audit] Database migration failed: %s'):format(tostring(reason)))
        return
    end

    FeatherAudit.SetDatabaseState(true, detail)
    FeatherAudit.SetState(FeatherAuditConstants.lifecycle.ready, true, nil)
    print(('[feather-audit] Ready with %d migration(s); ingestion v1 enabled.'):format(detail))
end)
