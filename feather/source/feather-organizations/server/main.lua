CreateThread(function()
    local called, result = xpcall(function()
        local valid = Organizations.ValidateConfig()
        if not valid.ok then return valid end
        Organizations.SetState('waiting', 'waiting_for_core')
        local ready = exports['feather-core']:AwaitReady(Config.ReadinessTimeoutMs)
        if type(ready) ~= 'table' or not ready.ok then
            return Organizations.Err('dependency_unavailable', 'Core did not become ready.')
        end
        local capabilities = exports['feather-core']:GetCapabilities()
        if type(capabilities) ~= 'table' or not capabilities.ok
            or type(capabilities.value) ~= 'table' or capabilities.value.contract ~= Config.RequiredCoreContract then
            return Organizations.Err('dependency_unavailable', 'Core Contract 1 is required.')
        end
        Organizations.SetState('waiting', 'waiting_for_database')
        if DB.awaitReady(Config.ReadinessTimeoutMs) ~= true then
            return Organizations.Err('dependency_unavailable', 'Database did not become ready.')
        end
        Organizations.SetState('migrating', 'database_migrations')
        local migrated = OrganizationMigrations.Run()
        if not migrated.ok then return migrated end
        Organizations.SetState('starting', 'loading_types')
        local loaded = OrganizationTypes.Load()
        if not loaded.ok then return loaded end
        local hierarchy = OrganizationHierarchy.CheckStartup()
        if not hierarchy.ok then return hierarchy end
        local events = OrganizationEvents.Start()
        if not events.ok then return events end
        Organizations.SetState('ready', 'ready')
        print(('[feather-organizations] event=startup.ready migrationsApplied=%d types=%d'):format(migrated.value.applied, loaded.value.types))
        return Organizations.Ok(true)
    end, debug.traceback)
    if not called then
        print('[feather-organizations] startup traceback: ' .. tostring(result))
        Organizations.Fail(Organizations.Err('startup_failed', 'Organizations startup raised an exception.'))
    elseif not result.ok then Organizations.Fail(result) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' or resource == 'feather-mysql' then
        OrganizationEvents.Stop()
        Organizations.Fail(Organizations.Err('dependency_unavailable', 'A required dependency stopped. Restart Organizations after it is ready.'))
    elseif resource == GetCurrentResourceName() then
        OrganizationEvents.Stop()
        Organizations.SetState('stopped', 'resource_stopped')
    end
end)

Organizations.RegisterDevCommand('OrganizationsFoundationSmokeTest', function(source)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local owner = GetCurrentResourceName()
        local caps, health, listed = Organizations.GetCapabilities(), Organizations.GetHealth(), OrganizationTypes.List(owner)
        local business = OrganizationTypes.Get('business', owner)
        local government = OrganizationTypes.Get('government', owner)
        local agency = OrganizationTypes.Get('government_agency', owner)
        local function Valid(result, key)
            return result.ok and result.value.key == key and Organizations.Uuid(result.value.organizationTypeId)
                and result.value.status == 'active' and result.value.revision >= 1
        end
        local snapshot = business.ok and business.value or {}
        snapshot.label = 'mutated'
        local fresh = OrganizationTypes.Get('business', owner)
        local denied = OrganizationTypes.List('untrusted-smoke-caller')
        local unknown = OrganizationTypes.Get('unknown_smoke_type', owner)
        local invalid = OrganizationTypes.Get({}, owner)
        local persisted = DB.one('SELECT `organization_type_id` FROM `feather_organization_types` WHERE `type_key`=?', 'business')
        local migrations = DB.value('SELECT COUNT(*) FROM `feather_organization_schema_migrations`')
        local tests = {
            { 'capabilities', caps.ok and caps.value.contract == 1 and caps.value.features.organizations == 1 },
            { 'health ready', health.ok and health.value.state == 'ready' },
            { 'bounded type catalog', listed.ok and #listed.value >= 3 and #listed.value <= 32 },
            { 'business identity', Valid(business, 'business') },
            { 'government identity', Valid(government, 'government') },
            { 'agency identity', Valid(agency, 'government_agency') },
            { 'snapshot isolated', fresh.ok and fresh.value.label ~= 'mutated' },
            { 'untrusted rejected', not denied.ok and denied.code == 'authorization_denied' },
            { 'unknown rejected', not unknown.ok and unknown.code == 'type_not_found' },
            { 'invalid rejected', not invalid.ok and invalid.code == 'invalid_input' },
            { 'await ready', Organizations.AwaitReady(0).ok },
            { 'persisted identity', business.ok and persisted and persisted.organization_type_id == business.value.organizationTypeId },
            { 'migration ledger', tonumber(migrations) == 7 }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[OrganizationsFoundationSmokeTest] %-24s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsFoundationSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
    end, debug.traceback)
    if not called then print('[OrganizationsFoundationSmokeTest] FAIL ' .. tostring(reason)) end
end, true)

RegisterCommand('OrganizationsReleaseContractSmokeTest',function(source)
    if source~=0 then return end
    local registered,callable={},type(GetRegisteredCommands)=='function'
    if callable then
        for _,command in ipairs(GetRegisteredCommands() or {}) do
            local name=type(command)=='table' and command.name or nil
            if type(name)=='string' then registered[name]=true end
        end
    end
    local developmentAbsent=callable
    if callable then
        for name in pairs(registered) do
            if name~='OrganizationsReleaseContractSmokeTest' and name:sub(1,13)=='Organizations' then
                developmentAbsent=false;break
            end
        end
    end
    local health=Organizations.GetHealth()
    local capabilities=Organizations.GetCapabilities()
    local events=OrganizationEvents.State()
    local business=OrganizationIdentity.Find({organizationKey='valentine_general_store'},GetCurrentResourceName())
    local fixture='feather-organizations-tests'
    local fixtureAbsent=Config.Access.trustedReaders[fixture]~=true
        and Config.Access.trustedCreators[fixture]~=true
        and Config.Access.trustedMutators[fixture]~=true
        and Config.Access.trustedAuditors[fixture]~=true
    local tests={
        {'service ready',health.ok and health.value.state=='ready'},
        {'server development disabled',Config.DevMode==false},
        {'authorization enabled',Config.Authorization.enabled==true},
        {'development commands absent',developmentAbsent},
        {'fixture trust absent',fixtureAbsent},
        {'publisher running',events.ok and events.value.running==true},
        {'canonical business active',business.ok and business.value.status=='active'
            and business.value.organizationType=='business'},
        {'contract capabilities',capabilities.ok and capabilities.value.contract==1
            and capabilities.value.features.controllingInterests==1}
    }
    local passed=0
    for _,test in ipairs(tests) do
        if test[2] then passed=passed+1 end
        print(('[OrganizationsReleaseContractSmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
    end
    print(('[OrganizationsReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
end,true)
