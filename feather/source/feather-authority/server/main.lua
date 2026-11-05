CreateThread(function()
    local called, result = xpcall(function()
        local valid = Authority.ValidateConfig()
        if not valid.ok then return valid end
        Authority.SetState('waiting', 'waiting_for_dependencies')
        if not DB.awaitReady(Config.ReadinessTimeoutMs) then
            return Authority.Err('dependency_unavailable', 'Database did not become ready.')
        end
        local core = exports['feather-core']:AwaitReady(Config.ReadinessTimeoutMs)
        if type(core) ~= 'table' or not core.ok then
            return Authority.Err('dependency_unavailable', 'Core did not become ready.')
        end
        local coreCapabilities = exports['feather-core']:GetCapabilities()
        if type(coreCapabilities) ~= 'table' or not coreCapabilities.ok
            or type(coreCapabilities.value) ~= 'table'
            or coreCapabilities.value.contract ~= Config.RequiredCoreContract then
            return Authority.Err('dependency_unavailable', 'Core Contract 1 is required.')
        end
        local organizations = exports['feather-organizations']:AwaitReady(Config.ReadinessTimeoutMs)
        if type(organizations) ~= 'table' or not organizations.ok then
            return Authority.Err('dependency_unavailable', 'Organizations did not become ready.')
        end
        local organizationCapabilities = exports['feather-organizations']:GetCapabilities()
        if type(organizationCapabilities) ~= 'table' or not organizationCapabilities.ok
            or type(organizationCapabilities.value) ~= 'table'
            or organizationCapabilities.value.contract ~= Config.RequiredOrganizationsContract then
            return Authority.Err('dependency_unavailable', 'Organizations Contract 1 is required.')
        end
        Authority.SetState('migrating', 'database_migrations')
        local migrated = AuthorityMigrations.Run()
        if not migrated.ok then return migrated end
        Authority.SetState('starting', 'loading_capabilities')
        local loaded = AuthorityCapabilities.Load()
        if not loaded.ok then return loaded end
        Authority.SetState('ready', 'ready')
        local provider = AuthorityPolicy.Install()
        if not provider.ok then return provider end
        print(('[feather-authority] event=startup.ready migrationsApplied=%d capabilities=%d'):format(
            migrated.value.applied, loaded.value.capabilities))
        return Authority.Ok(true)
    end, debug.traceback)
    if not called then
        print('[feather-authority] startup traceback: ' .. tostring(result))
        Authority.Fail(Authority.Err('startup_failed', 'Authority startup raised an exception.'))
    elseif not result.ok then Authority.Fail(result) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' or resource == 'feather-organizations' or resource == 'feather-mysql' then
        Authority.Fail(Authority.Err('dependency_unavailable',
            'A required dependency stopped. Restart Authority after it is ready.'))
    elseif resource == GetCurrentResourceName() then
        Authority.SetState('stopped', 'resource_stopped')
    end
end)

RegisterCommand('AuthorityReleaseContractSmokeTest', function(source)
    if source ~= 0 then return end
    local registered, callable = {}, type(GetRegisteredCommands) == 'function'
    if callable then
        for _, command in ipairs(GetRegisteredCommands() or {}) do
            local name = type(command) == 'table' and command.name or nil
            if type(name) == 'string' then registered[name] = true end
        end
    end
    local developmentAbsent = callable
    if callable then
        for name in pairs(registered) do
            if name ~= 'AuthorityReleaseContractSmokeTest' and name:sub(1, 9) == 'Authority' then
                developmentAbsent = false
                break
            end
        end
    end
    local health = Authority.GetHealth()
    local capabilities = Authority.GetCapabilities()
    local provider = exports['feather-core']:GetProvider('policy', 'feather-authority', 1)
    local access = Config.Access or {}
    local adminTrusted = access.trustedReaders and access.trustedReaders['feather-admin'] == true
        and access.trustedCapabilityRegistrars
            and access.trustedCapabilityRegistrars['feather-admin'] == true
        and access.trustedRoleCreators and access.trustedRoleCreators['feather-admin'] == true
        and access.trustedGrantors and access.trustedGrantors['feather-admin'] == true
        and access.trustedAssigners and access.trustedAssigners['feather-admin'] == true
    local fixture = 'feather-authority-tests'
    local fixtureAbsent = access.trustedReaders[fixture] ~= true
        and access.trustedCapabilityRegistrars[fixture] ~= true
        and access.trustedRoleCreators[fixture] ~= true
        and access.trustedGrantors[fixture] ~= true
        and access.trustedAssigners[fixture] ~= true
    local migrations = tonumber(DB.value(
        'SELECT COUNT(*) FROM `feather_authority_schema_migrations`'))
    local tests = {
        { 'service ready', health.ok and health.value.state == 'ready' },
        { 'server development disabled', Config.DevMode == false },
        { 'development commands absent', developmentAbsent },
        { 'fixture trust absent', fixtureAbsent },
        { 'Admin trust complete', adminTrusted },
        { 'named provider available', provider.ok and provider.value.provider.owner == 'feather-authority' },
        { 'production capabilities', capabilities.ok and capabilities.value.contract == 1
            and capabilities.value.features.assignmentReplacement == 1
            and capabilities.value.features.assignmentReads == 1
            and capabilities.value.features.characterAssignments == 1
            and capabilities.value.features.effectiveCapabilityReads == 1 },
        { 'migration ledger complete', migrations == 9 }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AuthorityReleaseContractSmokeTest] %-29s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AuthorityReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(
        passed, #tests))
end, true)

Authority.RegisterDevCommand('AuthorityFoundationSmokeTest', function(source)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local owner = GetCurrentResourceName()
        local capabilities = Authority.GetCapabilities()
        local health = Authority.GetHealth()
        local listed = AuthorityCapabilities.List(owner)
        local staff = AuthorityCapabilities.Get('staff.authority.manage', owner)
        local roleplay = AuthorityCapabilities.Get('rp.organization.treasury.approve', owner)
        local snapshot = staff.ok and staff.value or {}
        snapshot.description = 'mutated'
        local fresh = AuthorityCapabilities.Get('staff.authority.manage', owner)
        local denied = AuthorityCapabilities.List('untrusted-smoke-caller')
        local unknown = AuthorityCapabilities.Get('staff.unknown.test', owner)
        local invalid = AuthorityCapabilities.Get({}, owner)
        local persisted = DB.one([[SELECT `capability_id` FROM
            `feather_authority_capabilities` WHERE `capability_key`=?]], 'staff.authority.manage')
        local migrations = DB.value('SELECT COUNT(*) FROM `feather_authority_schema_migrations`')
        local function Valid(result, key, namespace)
            return result.ok and result.value.key == key and Authority.Uuid(result.value.capabilityId)
                and result.value.status == 'active' and result.value.revision >= 1
                and result.value.key:sub(1, #namespace + 1) == namespace .. '.'
        end
        local tests = {
            { 'capabilities', capabilities.ok and capabilities.value.contract == 1
                and capabilities.value.features.capabilityRegistry == 1
                and capabilities.value.features.assignments == 1 },
            { 'health ready', health.ok and health.value.state == 'ready' },
            { 'bounded catalog', listed.ok and #listed.value >= #Config.Capabilities and #listed.value <= 128 },
            { 'staff namespace', Valid(staff, 'staff.authority.manage', 'staff') },
            { 'roleplay namespace', Valid(roleplay, 'rp.organization.treasury.approve', 'rp') },
            { 'snapshot isolated', fresh.ok and fresh.value.description ~= 'mutated' },
            { 'untrusted rejected', not denied.ok and denied.code == 'authorization_denied' },
            { 'unknown rejected', not unknown.ok and unknown.code == 'capability_not_found' },
            { 'invalid rejected', not invalid.ok and invalid.code == 'invalid_input' },
            { 'await ready', Authority.AwaitReady(0).ok },
            { 'persisted identity', staff.ok and persisted
                and persisted.capability_id == staff.value.capabilityId },
            { 'migration ledger', tonumber(migrations) == 9 }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[AuthorityFoundationSmokeTest] %-21s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AuthorityFoundationSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
    end, debug.traceback)
    if not called then print('[AuthorityFoundationSmokeTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityCapabilityRegistrationContractSmokeTest', function(source)
    if source ~= 0 then return end
    local valid = { requestId = 'authority-capability-contract-001', capabilities = {
        { key = 'staff.admin.contract_test', description = 'Contract-only capability.', riskClass = 'moderate' }
    } }
    local first = AuthorityCapabilities.ValidateRegistration(valid)
    local same = AuthorityCapabilities.ValidateRegistration(Authority.Copy(valid))
    local changed = Authority.Copy(valid); changed.capabilities[1].riskClass = 'high'
    local changedResult = AuthorityCapabilities.ValidateRegistration(changed)
    local function Rejected(mutator)
        local request = Authority.Copy(valid); mutator(request)
        return not AuthorityCapabilities.ValidateRegistration(request).ok
    end
    local tests = {
        { 'registration contract', Authority.GetCapabilities().value.features.capabilityRegistrationContracts == 1
            and Authority.GetCapabilities().value.features.capabilityRegistration == 1 },
        { 'valid definition', first.ok },
        { 'untrusted rejected', (function()
            local result = AuthorityCapabilities.Register(valid, 'untrusted-smoke-caller')
            return not result.ok and result.code == 'authorization_denied'
        end)() },
        { 'stable fingerprint', same.ok and same.value == first.value },
        { 'payload binding', changedResult.ok and changedResult.value ~= first.value },
        { 'empty catalog rejected', Rejected(function(r) r.capabilities = {} end) },
        { 'duplicate key rejected', Rejected(function(r)
            r.capabilities[2] = Authority.Copy(r.capabilities[1]) end) },
        { 'bad key rejected', Rejected(function(r) r.capabilities[1].key = 'staff..bad' end) },
        { 'control text rejected', Rejected(function(r) r.capabilities[1].description = 'Bad\ntext' end) },
        { 'unknown risk rejected', Rejected(function(r) r.capabilities[1].riskClass = 'extreme' end) },
        { 'identity injection rejected', Rejected(function(r)
            r.capabilities[1].capabilityId = '00000000-0000-4000-8000-000000000001' end) },
        { 'status injection rejected', Rejected(function(r) r.capabilities[1].status = 'active' end) },
        { 'oversized request rejected', Rejected(function(r) r.requestId = string.rep('a', 129) end) }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AuthorityCapabilityRegistrationContractSmokeTest] %-27s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AuthorityCapabilityRegistrationContractSmokeTest] done %d/%d passed (no capabilities registered)'):format(
        passed, #tests))
end, true)

Authority.RegisterDevCommand('AuthorityPolicyProviderContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 1 and tonumber(args[1]),
            'Use <connected player source>')
        local playerSource = tonumber(args[1])
        local account = exports['feather-core']:GetAccountContext(playerSource)
        local session = exports['feather-core']:GetSessionContext(playerSource)
        assert(account.ok and session.ok and Authority.Uuid(session.value.characterId),
            'Active Core character session required')
        local named = exports['feather-core']:GetProvider('policy', 'feather-authority', 1)
        local default = exports['feather-core']:GetProvider('policy', nil, 1)
        local function IsCallable(value)
            return type(value) == 'function' or (type(value) == 'table'
                and type(rawget(value, '__cfx_functionReference')) == 'string')
        end
        assert(named.ok and IsCallable(named.value.implementation.Evaluate),
            'Named Authority policy provider is unavailable')
        local allow = named.value.implementation.Evaluate('staff.players.view', {
            source = playerSource, accountId = account.value.accountId,
            characterId = session.value.characterId, caller = 'authority-contract-smoke', subject = {}
        })
        local deny = named.value.implementation.Evaluate('staff.economy.adjust', {
            source = playerSource, accountId = account.value.accountId,
            characterId = session.value.characterId, caller = 'authority-contract-smoke', subject = {}
        })
        local system = named.value.implementation.Evaluate('staff.players.view', {
            source = 0, system = true, caller = 'authority-contract-smoke', subject = {}
        })
        local tests = {
            { 'named provider installed', AuthorityPolicy.IsInstalled() and named.ok
                and named.value.provider.owner == 'feather-authority' },
            { 'provider capabilities', named.ok
                and named.value.provider.capabilities.characterSubjects == 1 },
            { 'Admin remains default', default.ok and default.value.provider.owner == 'feather-admin' },
            { 'character decision envelope', allow.ok and type(allow.value.allowed) == 'boolean'
                and allow.value.code == 'forbidden' and allow.value.policyVersion ~= nil },
            { 'character deny envelope', deny.ok and deny.value.allowed == false
                and deny.value.code == 'forbidden' },
            { 'system fails closed', system.ok and system.value.allowed == false
                and system.value.code == 'unsupported_subject' }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[AuthorityPolicyProviderContractSmokeTest] %-24s %s'):format(
                test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AuthorityPolicyProviderContractSmokeTest] done %d/%d passed (Admin default unchanged)'):format(
            passed, #tests))
    end, debug.traceback)
    if not called then print('[AuthorityPolicyProviderContractSmokeTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityPolicyProviderLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 3 and tonumber(args[1])
            and Authority.Uuid(args[2]) and type(args[3]) == 'string',
            'Use <connected player source> <role UUID> <stable requestId>')
        local playerSource = tonumber(args[1])
        local account = exports['feather-core']:GetAccountContext(playerSource)
        local session = exports['feather-core']:GetSessionContext(playerSource)
        assert(account.ok and session.ok and Authority.Uuid(session.value.characterId),
            'Active Core character session required')
        local role = AuthorityRoles.Get({ roleId = args[2] }, GetCurrentResourceName())
        assert(role.ok, tostring(role.code) .. ': ' .. tostring(role.message))
        local issued = AuthorityAssignments.Issue({ requestId = args[3], subjectType = 'character',
            subjectId = session.value.characterId, roleId = args[2], expectedRoleRevision = role.value.revision,
            scopeType = 'server', reason = 'Authority provider live acceptance',
            reasonCode = 'development.provider_test' }, GetCurrentResourceName())
        assert(issued.ok, tostring(issued.code) .. ': ' .. tostring(issued.message))
        local named = exports['feather-core']:GetProvider('policy', 'feather-authority', 1)
        local default = exports['feather-core']:GetProvider('policy', nil, 1)
        assert(named.ok and default.ok and default.value.provider.owner == 'feather-admin',
            'Provider registry ownership changed')
        local context = { source = playerSource, accountId = account.value.accountId,
            characterId = session.value.characterId, caller = 'authority-live-test', subject = {} }
        local allow = named.value.implementation.Evaluate('staff.players.view', context)
        local deny = named.value.implementation.Evaluate('staff.economy.adjust', context)
        assert(allow.ok and allow.value.allowed and allow.value.code == 'allowed'
            and allow.value.assignmentId == issued.value.assignmentId
            and Authority.Uuid(allow.value.roleId) and Authority.Uuid(allow.value.grantId),
            'Named provider did not return attributed allow')
        assert(deny.ok and not deny.value.allowed and deny.value.code == 'forbidden',
            'Named provider did not deny ungranted capability')
        assert(allow.value.policyVersion == deny.value.policyVersion,
            'Provider decisions observed inconsistent policy versions')
        print(('[AuthorityPolicyProviderLiveTest] PASS assignment=%s character=%s allowed=true denied=true attribution=true policyVersion=%d firstReplayed=%s AdminDefaultUnchanged=true activeCharacterRequired=true'):format(
            issued.value.assignmentId, session.value.characterId, allow.value.policyVersion,
            tostring(issued.value.replayed)))
    end, debug.traceback)
    if not called then print('[AuthorityPolicyProviderLiveTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityAssignmentContractSmokeTest', function(source)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local valid = { requestId = 'authority-assignment-contract-001', subjectType = 'character',
            subjectId = '00000000-0000-4000-8000-000000000001',
            roleId = '00000000-0000-4000-8000-000000000002', expectedRoleRevision = 2,
            scopeType = 'server', validUntil = 1893456000, reason = 'Contract acceptance',
            reasonCode = 'development.contract' }
        local first = AuthorityAssignments.ValidateIssue(valid)
        local same = AuthorityAssignments.ValidateIssue(Authority.Copy(valid))
        local changed = Authority.Copy(valid); changed.reason = 'Changed reason'
        local changedResult = AuthorityAssignments.ValidateIssue(changed)
        local function Rejected(field, value)
            local request = Authority.Copy(valid); request[field] = value
            return not AuthorityAssignments.ValidateIssue(request).ok
        end
        local injected = Authority.Copy(valid); injected.assignmentId = valid.subjectId
        local untrusted = AuthorityAssignments.Issue(valid, 'untrusted-smoke-caller')
        local tests = {
            { 'assignment contract', Authority.GetCapabilities().value.features.assignmentContracts == 1
                and Authority.GetCapabilities().value.features.assignments == 1 },
            { 'valid character assignment', first.ok },
            { 'untrusted rejected', not untrusted.ok and untrusted.code == 'authorization_denied' },
            { 'stable fingerprint', same.ok and same.value == first.value },
            { 'payload binding', changedResult.ok and changedResult.value ~= first.value },
            { 'account subject accepted', (function()
                local request = Authority.Copy(valid); request.subjectType = 'account'
                return AuthorityAssignments.ValidateIssue(request).ok
            end)() },
            { 'unknown subject rejected', Rejected('subjectType', 'player') },
            { 'bad subject rejected', Rejected('subjectId', 'not-a-uuid') },
            { 'bad role rejected', Rejected('roleId', 'not-a-uuid') },
            { 'zero revision rejected', Rejected('expectedRoleRevision', 0) },
            { 'unknown scope rejected', Rejected('scopeType', 'organization') },
            { 'fractional expiry rejected', Rejected('validUntil', 1.5) },
            { 'blank reason rejected', Rejected('reason', '   ') },
            { 'identity injection rejected', not AuthorityAssignments.ValidateIssue(injected).ok }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[AuthorityAssignmentContractSmokeTest] %-27s %s'):format(
                test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AuthorityAssignmentContractSmokeTest] done %d/%d passed (no assignments created)'):format(
            passed, #tests))
    end, debug.traceback)
    if not called then print('[AuthorityAssignmentContractSmokeTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityAssignmentReplacementContractSmokeTest', function(source)
    if source ~= 0 then return end
    local valid = { requestId = 'authority-replacement-contract-001', subjectType = 'character',
        subjectId = '00000000-0000-4000-8000-000000000001',
        roleId = '00000000-0000-4000-8000-000000000002', expectedRoleRevision = 1,
        scopeType = 'server', reason = 'Contract validation only.',
        reasonCode = 'development.contract_test' }
    local function Rejected(field, value)
        local request = Authority.Copy(valid)
        request[field] = value
        return AuthorityAssignments.ValidateReplacement(request).ok == false
    end
    local injected = Authority.Copy(valid); injected.sourceResource = 'feather-admin'
    local changed = Authority.Copy(valid); changed.reason = 'Changed reason.'
    local tests = {
        { 'replacement capability', Authority.GetCapabilities().value.features.assignmentReplacement == 1 },
        { 'valid request', AuthorityAssignments.ValidateReplacement(valid).ok },
        { 'account subject accepted', (function()
            local request = Authority.Copy(valid); request.subjectType = 'account'
            return AuthorityAssignments.ValidateReplacement(request).ok
        end)() },
        { 'valid clear request', (function()
            local clear = Authority.Copy(valid); clear.roleId = nil; clear.expectedRoleRevision = nil
            return AuthorityAssignments.ValidateReplacement(clear).ok
        end)() },
        { 'untrusted rejected', AuthorityAssignments.ReplaceOwned(valid, 'untrusted-resource').code == 'authorization_denied' },
        { 'missing request rejected', Rejected('requestId', nil) },
        { 'oversized request rejected', Rejected('requestId', string.rep('a', 81)) },
        { 'bad subject rejected', Rejected('subjectId', 'not-a-uuid') },
        { 'bad role rejected', Rejected('roleId', 'not-a-uuid') },
        { 'zero revision rejected', Rejected('expectedRoleRevision', 0) },
        { 'unknown scope rejected', Rejected('scopeType', 'organization') },
        { 'identity injection rejected', AuthorityAssignments.ValidateReplacement(injected).ok == false },
        { 'payload binding', AuthorityAssignments.ValidateReplacement(valid).value
            ~= AuthorityAssignments.ValidateReplacement(changed).value }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AuthorityAssignmentReplacementContractSmokeTest] %-28s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AuthorityAssignmentReplacementContractSmokeTest] done %d/%d passed (no assignments changed)'):format(
        passed, #tests))
end)

Authority.RegisterDevCommand('AuthorityAssignmentLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 3 and tonumber(args[1])
            and Authority.Uuid(args[2]) and type(args[3]) == 'string',
            'Use <player source> <role UUID> <stable requestId>')
        local session = exports['feather-core']:GetSessionContext(tonumber(args[1]))
        assert(session.ok and Authority.Uuid(session.value.characterId),
            'Active Core character session required for the acceptance test')
        local role = AuthorityRoles.Get({ roleId = args[2] }, GetCurrentResourceName())
        assert(role.ok, tostring(role.code) .. ': ' .. tostring(role.message))
        local request = { requestId = args[3], subjectType = 'character',
            subjectId = session.value.characterId, roleId = role.value.roleId,
            expectedRoleRevision = role.value.revision, scopeType = 'server',
            reason = 'Authority assignment live acceptance', reasonCode = 'development.live_test' }
        local first = AuthorityAssignments.Issue(request, GetCurrentResourceName())
        assert(first.ok, tostring(first.code) .. ': ' .. tostring(first.message))
        local replay = AuthorityAssignments.Issue(request, GetCurrentResourceName())
        assert(replay.ok and replay.value.replayed and replay.value.assignmentId == first.value.assignmentId,
            'Exact assignment did not replay its identity')
        local mismatch = Authority.Copy(request); mismatch.reason = 'Changed reason'
        local mismatchResult = AuthorityAssignments.Issue(mismatch, GetCurrentResourceName())
        assert(not mismatchResult.ok and mismatchResult.code == 'idempotency_conflict',
            'Changed assignment payload did not conflict')
        local stale = Authority.Copy(request); stale.requestId = args[3] .. ':stale'
        stale.expectedRoleRevision = math.max(1, role.value.revision - 1)
        local staleResult = AuthorityAssignments.Issue(stale, GetCurrentResourceName())
        assert(not staleResult.ok and (role.value.revision == 1
            and staleResult.code == 'assignment_conflict' or staleResult.code == 'revision_conflict'),
            'Stale role revision was accepted')
        local read = AuthorityAssignments.Get({ assignmentId = first.value.assignmentId }, GetCurrentResourceName())
        assert(read.ok and read.value.subjectType == 'character'
            and read.value.subjectId == session.value.characterId
            and read.value.issuerId == GetCurrentResourceName(), 'Assignment attribution is invalid')
        local assignmentCount = tonumber(DB.value([[SELECT COUNT(*) FROM
            `feather_authority_assignments` WHERE `assignment_id`=?]], first.value.assignmentId))
        local eventCount = tonumber(DB.value([[SELECT COUNT(*) FROM
            `feather_authority_assignment_events` WHERE `assignment_id`=?]], first.value.assignmentId))
        assert(assignmentCount == 1 and eventCount == 1,
            'Assignment did not produce exactly one identity and audit event')
        print(('[AuthorityAssignmentLiveTest] PASS assignment=%s character=%s role=%s firstReplayed=%s replayed=true mismatchRejected=true staleRejected=true attribution=true singleAssignmentAudit=true'):format(
            first.value.assignmentId, session.value.characterId, role.value.roleId,
            tostring(first.value.replayed)))
    end, debug.traceback)
    if not called then print('[AuthorityAssignmentLiveTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityAssignmentOfflineReplayTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 3 and Authority.Uuid(args[1])
            and Authority.Uuid(args[2]) and type(args[3]) == 'string',
            'Use <account UUID> <role UUID> <original requestId>')
        local role = AuthorityRoles.Get({ roleId = args[2] }, GetCurrentResourceName())
        assert(role.ok, tostring(role.code) .. ': ' .. tostring(role.message))
        local request = { requestId = args[3], subjectType = 'account', subjectId = args[1],
            roleId = args[2], expectedRoleRevision = role.value.revision, scopeType = 'server',
            reason = 'Authority assignment live acceptance', reasonCode = 'development.live_test' }
        local replay = AuthorityAssignments.Issue(request, GetCurrentResourceName())
        assert(replay.ok and replay.value.replayed == true,
            tostring(replay.code) .. ': original assignment did not replay')
        local identity = exports['feather-core']:GetAccountIdentity(args[1])
        local read = AuthorityAssignments.Get({ assignmentId = replay.value.assignmentId },
            GetCurrentResourceName())
        local events = tonumber(DB.value([[SELECT COUNT(*) FROM
            `feather_authority_assignment_events` WHERE `assignment_id`=?]],
            replay.value.assignmentId))
        assert(identity.ok and read.ok and read.value.subjectId == identity.value.accountId
            and events == 1, 'Offline assignment identity or audit evidence changed')
        print(('[AuthorityAssignmentOfflineReplayTest] PASS assignment=%s account=%s role=%s replayed=true activeSessionNotRequired=true singleAssignmentAudit=true'):format(
            replay.value.assignmentId, identity.value.accountId, role.value.roleId))
    end, debug.traceback)
    if not called then print('[AuthorityAssignmentOfflineReplayTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityEvaluationContractSmokeTest', function(source)
    if source ~= 0 then return end
    local base = { subjectType = 'character', subjectId = '00000000-0000-4000-8000-000000000001',
        capabilityKey = 'staff.players.view', scopeType = 'server' }
    local function Rejected(field, value)
        local request = Authority.Copy(base); request[field] = value
        return not AuthorityEvaluation.Validate(request).ok
    end
    local injected = Authority.Copy(base); injected.source = 1
    local denied = AuthorityEvaluation.Evaluate(base, 'untrusted-smoke-caller')
    local unknown = Authority.Copy(base); unknown.capabilityKey = 'staff.unknown.contract'
    local unknownResult = AuthorityEvaluation.Evaluate(unknown, GetCurrentResourceName())
    local tests = {
        { 'evaluation capability', Authority.GetCapabilities().value.features.scopedEvaluation == 1 },
        { 'valid request', AuthorityEvaluation.Validate(base).ok },
        { 'untrusted rejected', not denied.ok and denied.code == 'authorization_denied' },
        { 'account subject accepted', (function()
            local request = Authority.Copy(base); request.subjectType = 'account'
            return AuthorityEvaluation.Validate(request).ok
        end)() },
        { 'unknown subject rejected', Rejected('subjectType', 'player') },
        { 'bad subject rejected', Rejected('subjectId', 'not-a-uuid') },
        { 'bad capability rejected', Rejected('capabilityKey', 'staff..view') },
        { 'unknown scope rejected', Rejected('scopeType', 'organization') },
        { 'identity injection rejected', not AuthorityEvaluation.Validate(injected).ok },
        { 'unknown capability denied', unknownResult.ok and not unknownResult.value.allowed
            and unknownResult.value.reason == 'capability_unavailable' },
        { 'policy version returned', unknownResult.ok
            and Authority.Integer(unknownResult.value.policyVersion, 1, 9007199254740991) }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AuthorityEvaluationContractSmokeTest] %-27s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AuthorityEvaluationContractSmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
end, true)

Authority.RegisterDevCommand('AuthorityEvaluationLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 1 and Authority.Uuid(args[1]),
            'Use <account UUID>')
        local allow = AuthorityEvaluation.Evaluate({ subjectType = 'account', subjectId = args[1],
            capabilityKey = 'staff.players.view', scopeType = 'server' }, GetCurrentResourceName())
        local deny = AuthorityEvaluation.Evaluate({ subjectType = 'account', subjectId = args[1],
            capabilityKey = 'staff.economy.adjust', scopeType = 'server' }, GetCurrentResourceName())
        assert(allow.ok and allow.value.allowed and allow.value.reason == 'explicit_role_grant'
            and Authority.Uuid(allow.value.assignmentId) and Authority.Uuid(allow.value.roleId)
            and Authority.Uuid(allow.value.grantId), 'Expected explicit role grant allow')
        assert(deny.ok and not deny.value.allowed and deny.value.reason == 'no_active_assignment',
            'Ungrantable capability did not deny')
        assert(allow.value.policyVersion == deny.value.policyVersion,
            'Read-only decisions observed inconsistent policy versions')
        print(('[AuthorityEvaluationLiveTest] PASS account=%s allowed=true reason=%s denied=true denyReason=%s policyVersion=%d attribution=true activeSessionNotRequired=true'):format(
            args[1], allow.value.reason, deny.value.reason, allow.value.policyVersion))
    end, debug.traceback)
    if not called then print('[AuthorityEvaluationLiveTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityAssignmentLifecycleContractSmokeTest', function(source)
    if source ~= 0 then return end
    local valid = { requestId = 'authority-lifecycle-contract-001',
        assignmentId = '00000000-0000-4000-8000-000000000001', expectedRevision = 1,
        status = 'suspended', reasonCode = 'development.contract' }
    local first = AuthorityAssignments.ValidateLifecycle(valid)
    local same = AuthorityAssignments.ValidateLifecycle(Authority.Copy(valid))
    local changed = Authority.Copy(valid); changed.status = 'revoked'
    local changedResult = AuthorityAssignments.ValidateLifecycle(changed)
    local function Rejected(field, value)
        local request = Authority.Copy(valid); request[field] = value
        return not AuthorityAssignments.ValidateLifecycle(request).ok
    end
    local injected = Authority.Copy(valid); injected.subjectId = valid.assignmentId
    local denied = AuthorityAssignments.ChangeStatus(valid, 'untrusted-smoke-caller')
    local tests = {
        { 'lifecycle capability', Authority.GetCapabilities().value.features.assignmentLifecycle == 1 },
        { 'valid suspend', first.ok },
        { 'stable fingerprint', same.ok and same.value == first.value },
        { 'payload binding', changedResult.ok and changedResult.value ~= first.value },
        { 'untrusted rejected', not denied.ok and denied.code == 'authorization_denied' },
        { 'bad assignment rejected', Rejected('assignmentId', 'not-a-uuid') },
        { 'zero revision rejected', Rejected('expectedRevision', 0) },
        { 'fractional revision rejected', Rejected('expectedRevision', 1.5) },
        { 'unknown status rejected', Rejected('status', 'expired') },
        { 'missing request rejected', Rejected('requestId', nil) },
        { 'bad reason rejected', Rejected('reasonCode', 'Bad Reason') },
        { 'identity injection rejected', not AuthorityAssignments.ValidateLifecycle(injected).ok }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AuthorityAssignmentLifecycleContractSmokeTest] %-28s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AuthorityAssignmentLifecycleContractSmokeTest] done %d/%d passed (no status changes)'):format(
        passed, #tests))
end, true)

Authority.RegisterDevCommand('AuthorityAssignmentLifecycleLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 2 and Authority.Uuid(args[1])
            and type(args[2]) == 'string', 'Use <assignment UUID> <stable requestId>')
        local assignment = AuthorityAssignments.Get({ assignmentId = args[1] }, GetCurrentResourceName())
        assert(assignment.ok, tostring(assignment.code) .. ': ' .. tostring(assignment.message))
        local historical = assignment.value.status == 'revoked'
        local accountId = assignment.value.subjectId
        local function Evaluate()
            return AuthorityEvaluation.Evaluate({ subjectType = 'account', subjectId = accountId,
                capabilityKey = 'staff.players.view', scopeType = 'server' }, GetCurrentResourceName())
        end
        local steps = {
            { suffix = ':suspend', revision = 1, status = 'suspended' },
            { suffix = ':resume', revision = 2, status = 'active' },
            { suffix = ':revoke', revision = 3, status = 'revoked' }
        }
        local replayed = true
        for index, step in ipairs(steps) do
            local result = AuthorityAssignments.ChangeStatus({ requestId = args[2] .. step.suffix,
                assignmentId = args[1], expectedRevision = step.revision, status = step.status,
                reasonCode = 'development.lifecycle_test' }, GetCurrentResourceName())
            assert(result.ok, tostring(result.code) .. ': ' .. tostring(result.message))
            replayed = replayed and result.value.replayed == true
            if not historical then
                local decision = Evaluate()
                local expectedAllow = index == 2
                assert(decision.ok and decision.value.allowed == expectedAllow,
                    'Evaluation did not reflect assignment status ' .. step.status)
            end
        end
        local terminal = AuthorityAssignments.ChangeStatus({ requestId = args[2] .. ':terminal',
            assignmentId = args[1], expectedRevision = 4, status = 'active',
            reasonCode = 'development.lifecycle_test' }, GetCurrentResourceName())
        assert(not terminal.ok and terminal.code == 'assignment_terminal', 'Revoked assignment was resumed')
        local final = AuthorityAssignments.Get({ assignmentId = args[1] }, GetCurrentResourceName())
        local finalDecision = Evaluate()
        local events = tonumber(DB.value([[SELECT COUNT(*) FROM
            `feather_authority_assignment_events` WHERE `assignment_id`=?]], args[1]))
        assert(final.ok and final.value.status == 'revoked' and final.value.revision == 4 and events == 4
            and finalDecision.ok and finalDecision.value.allowed == false,
            'Final assignment lifecycle evidence is inconsistent')
        print(('[AuthorityAssignmentLifecycleLiveTest] PASS assignment=%s state=revoked revision=4 allReplayed=%s suspendDenied=true resumeAllowed=true revokeDenied=true terminalBlocked=true events=4'):format(
            args[1], tostring(replayed)))
    end, debug.traceback)
    if not called then print('[AuthorityAssignmentLifecycleLiveTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityAssignmentExpiryTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 3 and Authority.Uuid(args[1])
            and Authority.Uuid(args[2]) and type(args[3]) == 'string',
            'Use <account UUID> <role UUID> <stable requestId>')
        local role = AuthorityRoles.Get({ roleId = args[2] }, GetCurrentResourceName())
        assert(role.ok, tostring(role.code) .. ': ' .. tostring(role.message))
        local receipt = DB.one([[SELECT `result_json` FROM `feather_authority_assignment_receipts`
            WHERE `source_resource`=? AND `request_id`=?]], GetCurrentResourceName(), args[3])
        local priorId
        if receipt and receipt.result_json then
            local decoded, value = pcall(json.decode, receipt.result_json)
            if decoded and type(value) == 'table' then priorId = value.assignmentId end
        end
        local validUntil = priorId and tonumber(DB.value([[SELECT UNIX_TIMESTAMP(`valid_until`)
            FROM `feather_authority_assignments` WHERE `assignment_id`=?]], priorId)) or os.time() + 3
        local request = { requestId = args[3], subjectType = 'account', subjectId = args[1],
            roleId = args[2], expectedRoleRevision = role.value.revision, scopeType = 'server',
            validUntil = validUntil, reason = 'Authority expiry acceptance',
            reasonCode = 'development.expiry_test' }
        local first = AuthorityAssignments.Issue(request, GetCurrentResourceName())
        assert(first.ok, tostring(first.code) .. ': ' .. tostring(first.message))
        if first.value.replayed ~= true then
            local before = AuthorityEvaluation.Evaluate({ subjectType = 'account', subjectId = args[1],
                capabilityKey = 'staff.players.view', scopeType = 'server' }, GetCurrentResourceName())
            assert(before.ok and before.value.allowed, 'Fresh assignment did not authorize before expiry')
            Wait(4000)
        end
        local after = AuthorityEvaluation.Evaluate({ subjectType = 'account', subjectId = args[1],
            capabilityKey = 'staff.players.view', scopeType = 'server' }, GetCurrentResourceName())
        local replay = AuthorityAssignments.Issue(request, GetCurrentResourceName())
        assert(after.ok and not after.value.allowed and after.value.reason == 'no_active_assignment',
            'Expired assignment continued authorizing')
        assert(replay.ok and replay.value.replayed and replay.value.assignmentId == first.value.assignmentId,
            'Expired assignment receipt did not replay')
        print(('[AuthorityAssignmentExpiryTest] PASS assignment=%s validUntil=%d firstReplayed=%s allowedBefore=true deniedAfter=true reason=%s replayed=true stableIdentity=true'):format(
            first.value.assignmentId, validUntil, tostring(first.value.replayed), after.value.reason))
    end, debug.traceback)
    if not called then print('[AuthorityAssignmentExpiryTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityAssignmentConcurrencyTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 3 and Authority.Uuid(args[1])
            and Authority.Uuid(args[2]) and type(args[3]) == 'string',
            'Use <account UUID> <role UUID> <stable requestId>')
        local role = AuthorityRoles.Get({ roleId = args[2] }, GetCurrentResourceName())
        assert(role.ok, tostring(role.code) .. ': ' .. tostring(role.message))
        local issued = AuthorityAssignments.Issue({ requestId = args[3] .. ':assignment',
            subjectType = 'account', subjectId = args[1], roleId = args[2],
            expectedRoleRevision = role.value.revision, scopeType = 'server',
            reason = 'Authority concurrency acceptance', reasonCode = 'development.concurrency_test' },
            GetCurrentResourceName())
        assert(issued.ok, tostring(issued.code) .. ': ' .. tostring(issued.message))
        local assignmentId = issued.value.assignmentId
        local prior = DB.query([[SELECT `request_id`,`event_type` FROM
            `feather_authority_assignment_events` WHERE `assignment_id`=?
                AND `request_id` IN (?,?)]],
            assignmentId, args[3] .. ':suspend', args[3] .. ':revoke') or {}
        local winner, loser
        if #prior == 0 then
            print('[AuthorityAssignmentConcurrencyTest] started assignment=' .. assignmentId)
            local results, completed = {}, 0
            for _, status in ipairs({ 'suspended', 'revoked' }) do
                CreateThread(function()
                    local result = AuthorityAssignments.ChangeStatus({ requestId = args[3] .. ':'
                        .. (status == 'suspended' and 'suspend' or 'revoke'), assignmentId = assignmentId,
                        expectedRevision = 1, status = status,
                        reasonCode = 'development.concurrency_test' }, GetCurrentResourceName())
                    results[status] = result
                    completed = completed + 1
                    print(('[AuthorityAssignmentConcurrencyTest] contender=%s ok=%s code=%s'):format(
                        status, tostring(result.ok), tostring(result.code)))
                end)
            end
            local deadline = GetGameTimer() + 15000
            while completed < 2 and GetGameTimer() < deadline do Wait(25) end
            assert(completed == 2, 'Concurrency contenders timed out')
            for status, result in pairs(results) do
                if result.ok then winner = status else
                    assert(result.code == 'revision_conflict', 'Losing contender was not stale')
                    loser = status
                end
            end
            assert(winner and loser, 'Exactly one lifecycle contender must commit')
        else
            assert(#prior == 1, 'More than one race event committed')
            winner = prior[1].request_id:sub(-7) == 'suspend' and 'suspended' or 'revoked'
            loser = winner == 'suspended' and 'revoked' or 'suspended'
        end
        local winnerRequest = args[3] .. ':' .. (winner == 'suspended' and 'suspend' or 'revoke')
        local winnerReplay = AuthorityAssignments.ChangeStatus({ requestId = winnerRequest,
            assignmentId = assignmentId, expectedRevision = 1, status = winner,
            reasonCode = 'development.concurrency_test' }, GetCurrentResourceName())
        assert(winnerReplay.ok and winnerReplay.value.replayed, 'Winner receipt did not replay')
        local current = AuthorityAssignments.Get({ assignmentId = assignmentId }, GetCurrentResourceName())
        if current.ok and current.value.status == 'suspended' then
            local cleanup = AuthorityAssignments.ChangeStatus({ requestId = args[3] .. ':cleanup',
                assignmentId = assignmentId, expectedRevision = current.value.revision, status = 'revoked',
                reasonCode = 'development.concurrency_cleanup' }, GetCurrentResourceName())
            assert(cleanup.ok, 'Suspended race winner could not be revoked')
        end
        local final = AuthorityAssignments.Get({ assignmentId = assignmentId }, GetCurrentResourceName())
        local decision = AuthorityEvaluation.Evaluate({ subjectType = 'account', subjectId = args[1],
            capabilityKey = 'staff.players.view', scopeType = 'server' }, GetCurrentResourceName())
        local raceEvents = tonumber(DB.value([[SELECT COUNT(*) FROM
            `feather_authority_assignment_events` WHERE `assignment_id`=? AND `request_id` IN (?,?)]],
            assignmentId, args[3] .. ':suspend', args[3] .. ':revoke'))
        assert(final.ok and final.value.status == 'revoked' and decision.ok
            and decision.value.allowed == false and raceEvents == 1,
            'Concurrent assignment outcome is inconsistent')
        print(('[AuthorityAssignmentConcurrencyTest] PASS assignment=%s committed=1 stale=1 winner=%s loser=%s final=revoked raceEvents=1 winnerReplayed=true failClosed=true firstReplayed=%s'):format(
            assignmentId, winner, loser, tostring(issued.value.replayed)))
    end, debug.traceback)
    if not called then print('[AuthorityAssignmentConcurrencyTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityRoleGrantContractSmokeTest', function(source)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local valid = {
            requestId = 'authority-grant-contract-001',
            roleId = '00000000-0000-4000-8000-000000000001',
            capabilityKey = 'staff.players.view',
            expectedRevision = 1,
            scopeType = 'server',
            reasonCode = 'development.contract'
        }
        local first = AuthorityGrants.ValidateIssue(valid)
        local same = AuthorityGrants.ValidateIssue(Authority.Copy(valid))
        local changed = Authority.Copy(valid)
        changed.scopeType = 'organization'
        local changedFingerprint = AuthorityGrants.ValidateIssue(changed)
        local function Rejected(field, value)
            local request = Authority.Copy(valid)
            request[field] = value
            return not AuthorityGrants.ValidateIssue(request).ok
        end
        local injected = Authority.Copy(valid)
        injected.effect = 'deny'
        local tests = {
            { 'grant contract capability', Authority.GetCapabilities().value.features.roleGrantContracts == 1
                and Authority.GetCapabilities().value.features.roleGrants == 1 },
            { 'valid request', first.ok },
            { 'stable fingerprint', same.ok and same.value == first.value },
            { 'payload binding', changedFingerprint.ok and changedFingerprint.value ~= first.value },
            { 'deny injection rejected', not AuthorityGrants.ValidateIssue(injected).ok },
            { 'untrusted rejected', (function()
                local result = AuthorityGrants.Issue(valid, 'untrusted-smoke-caller')
                return not result.ok and result.code == 'authorization_denied'
            end)() },
            { 'bad role rejected', Rejected('roleId', 'not-a-uuid') },
            { 'bad capability rejected', Rejected('capabilityKey', 'staff..view') },
            { 'zero revision rejected', Rejected('expectedRevision', 0) },
            { 'fractional revision rejected', Rejected('expectedRevision', 1.5) },
            { 'string revision rejected', Rejected('expectedRevision', '1') },
            { 'unknown scope rejected', Rejected('scopeType', 'global') },
            { 'identity injection rejected', (function()
                local request = Authority.Copy(valid)
                request.grantId = '00000000-0000-4000-8000-000000000002'
                return not AuthorityGrants.ValidateIssue(request).ok
            end)() }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[AuthorityRoleGrantContractSmokeTest] %-28s %s'):format(
                test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AuthorityRoleGrantContractSmokeTest] done %d/%d passed (no grants created)'):format(
            passed, #tests))
    end, debug.traceback)
    if not called then print('[AuthorityRoleGrantContractSmokeTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityRoleContractSmokeTest', function(source)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local valid = {
            requestId = 'authority-role-contract-001',
            roleKey = 'staff.server_operator',
            label = 'Server Operator',
            roleClass = 'staff',
            reasonCode = 'development.contract'
        }
        local first = AuthorityRoles.ValidateCreate(valid)
        local same = AuthorityRoles.ValidateCreate(Authority.Copy(valid))
        local changed = Authority.Copy(valid)
        changed.label = 'Changed Label'
        local changedFingerprint = AuthorityRoles.ValidateCreate(changed)
        local denied = AuthorityRoles.Create(valid, 'untrusted-smoke-caller')
        local tests = {
            { 'role capability', Authority.GetCapabilities().value.features.roles == 1 },
            { 'valid staff role', first.ok },
            { 'stable fingerprint', same.ok and same.value == first.value },
            { 'payload binding', changedFingerprint.ok and changedFingerprint.value ~= first.value },
            { 'untrusted rejected', not denied.ok and denied.code == 'authorization_denied' },
            { 'class mismatch rejected', not AuthorityRoles.ValidateCreate({
                requestId = valid.requestId, roleKey = 'rp.server_operator', label = valid.label,
                roleClass = 'staff', reasonCode = valid.reasonCode
            }).ok },
            { 'unknown class rejected', not AuthorityRoles.ValidateCreate({
                requestId = valid.requestId, roleKey = valid.roleKey, label = valid.label,
                roleClass = 'system', reasonCode = valid.reasonCode
            }).ok },
            { 'identity injection rejected', not AuthorityRoles.ValidateCreate({
                requestId = valid.requestId, roleKey = valid.roleKey, label = valid.label,
                roleClass = valid.roleClass, reasonCode = valid.reasonCode,
                roleId = '00000000-0000-4000-8000-000000000001'
            }).ok },
            { 'status injection rejected', not AuthorityRoles.ValidateCreate({
                requestId = valid.requestId, roleKey = valid.roleKey, label = valid.label,
                roleClass = valid.roleClass, reasonCode = valid.reasonCode, status = 'active'
            }).ok },
            { 'control label rejected', not AuthorityRoles.ValidateCreate({
                requestId = valid.requestId, roleKey = valid.roleKey, label = 'Bad\nLabel',
                roleClass = valid.roleClass, reasonCode = valid.reasonCode
            }).ok },
            { 'missing request rejected', not AuthorityRoles.ValidateCreate({
                roleKey = valid.roleKey, label = valid.label,
                roleClass = valid.roleClass, reasonCode = valid.reasonCode
            }).ok },
            { 'malformed key rejected', not AuthorityRoles.ValidateCreate({
                requestId = valid.requestId, roleKey = 'staff..operator', label = valid.label,
                roleClass = valid.roleClass, reasonCode = valid.reasonCode
            }).ok }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[AuthorityRoleContractSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AuthorityRoleContractSmokeTest] done %d/%d passed (no roles created)'):format(passed, #tests))
    end, debug.traceback)
    if not called then print('[AuthorityRoleContractSmokeTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityRoleLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 1 and type(args[1]) == 'string'
            and #args[1] >= 1 and #args[1] <= 80
            and args[1]:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$'),
            'Use <stable requestId>')
        local requestId = args[1]
        local slug = requestId:lower():gsub('[^a-z0-9_]', '_')
        assert(#slug <= 70, 'Request ID is too long for the acceptance role key')
        local roleKey = 'staff.acceptance_' .. slug
        local request = {
            requestId = requestId,
            roleKey = roleKey,
            label = 'Authority Acceptance Operator',
            roleClass = 'staff',
            reasonCode = 'development.live_test'
        }
        local first = AuthorityRoles.Create(request, GetCurrentResourceName())
        assert(first.ok, tostring(first.code) .. ': ' .. tostring(first.message))
        local replay = AuthorityRoles.Create(request, GetCurrentResourceName())
        assert(replay.ok and replay.value.replayed == true, 'Exact role creation did not replay')
        assert(replay.value.roleId == first.value.roleId, 'Replay changed role identity')
        local mismatch = Authority.Copy(request)
        mismatch.label = 'Tampered Acceptance Operator'
        local mismatchResult = AuthorityRoles.Create(mismatch, GetCurrentResourceName())
        assert(not mismatchResult.ok and mismatchResult.code == 'idempotency_conflict',
            'Changed payload did not conflict with the request receipt')
        local keyConflict = Authority.Copy(request)
        keyConflict.requestId = requestId .. ':key-conflict'
        local keyConflictResult = AuthorityRoles.Create(keyConflict, GetCurrentResourceName())
        assert(not keyConflictResult.ok and keyConflictResult.code == 'role_key_conflict',
            'Duplicate role key was not rejected')
        local byId = AuthorityRoles.Get({ roleId = first.value.roleId }, GetCurrentResourceName())
        local byKey = AuthorityRoles.Find({ roleKey = roleKey }, GetCurrentResourceName())
        assert(byId.ok and byKey.ok and byId.value.roleId == byKey.value.roleId,
            'Role identity reads are inconsistent')
        byId.value.label = 'mutated'
        local fresh = AuthorityRoles.Get({ roleId = first.value.roleId }, GetCurrentResourceName())
        assert(fresh.ok and fresh.value.label == request.label, 'Role snapshot was not isolated')
        local roleCount = tonumber(DB.value(
            'SELECT COUNT(*) FROM `feather_authority_roles` WHERE `role_key`=?', roleKey))
        local eventCount = tonumber(DB.value([[SELECT COUNT(*) FROM
            `feather_authority_role_events` WHERE `role_id`=? AND `event_type`='authority.role.created']],
            first.value.roleId))
        local receiptCount = tonumber(DB.value([[SELECT COUNT(*) FROM
            `feather_authority_role_creation_receipts` WHERE `source_resource`=? AND `request_id`=?]],
            GetCurrentResourceName(), requestId))
        assert(roleCount == 1 and eventCount == 1 and receiptCount == 1,
            'Role creation did not produce exactly one identity, event, and receipt')
        print(('[AuthorityRoleLiveTest] PASS id=%s key=%s firstReplayed=%s replayed=true mismatchRejected=true keyConflict=true singleRoleAudit=true'):format(
            first.value.roleId, roleKey, tostring(first.value.replayed)))
    end, debug.traceback)
    if not called then print('[AuthorityRoleLiveTest] FAIL ' .. tostring(reason)) end
end, true)

Authority.RegisterDevCommand('AuthorityRoleGrantLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 2 and type(args[1]) == 'string'
            and Authority.Uuid(args[2]), 'Use <stable requestId> <role UUID>')
        local role = AuthorityRoles.Get({ roleId = args[2] }, GetCurrentResourceName())
        assert(role.ok, tostring(role.code) .. ': ' .. tostring(role.message))
        local prior = DB.one([[SELECT `revision` FROM `feather_authority_role_events`
            WHERE `role_id`=? AND `source_resource`=? AND `request_id`=?
                AND `event_type`='authority.role.grant_added']],
            role.value.roleId, GetCurrentResourceName(), args[1])
        local expectedRevision = prior and tonumber(prior.revision) - 1 or role.value.revision
        local request = { requestId = args[1], roleId = role.value.roleId,
            capabilityKey = 'staff.players.view', expectedRevision = expectedRevision,
            scopeType = 'server', reasonCode = 'development.live_test' }
        local first = AuthorityGrants.Issue(request, GetCurrentResourceName())
        assert(first.ok, tostring(first.code) .. ': ' .. tostring(first.message))
        local replay = AuthorityGrants.Issue(request, GetCurrentResourceName())
        assert(replay.ok and replay.value.replayed and replay.value.grantId == first.value.grantId,
            'Exact grant did not replay its identity')
        local mismatch = Authority.Copy(request); mismatch.scopeType = 'organization'
        local mismatchResult = AuthorityGrants.Issue(mismatch, GetCurrentResourceName())
        assert(not mismatchResult.ok and mismatchResult.code == 'idempotency_conflict',
            'Changed grant payload did not conflict')
        local stale = Authority.Copy(request); stale.requestId = args[1] .. ':stale'
        stale.capabilityKey = 'staff.economy.adjust'
        local staleResult = AuthorityGrants.Issue(stale, GetCurrentResourceName())
        assert(not staleResult.ok and staleResult.code == 'revision_conflict', 'Stale role revision was accepted')
        local classMismatch = Authority.Copy(request); classMismatch.requestId = args[1] .. ':class'
        classMismatch.capabilityKey = 'rp.organization.treasury.approve'
        classMismatch.expectedRevision = first.value.roleRevision
        local classResult = AuthorityGrants.Issue(classMismatch, GetCurrentResourceName())
        assert(not classResult.ok and classResult.code == 'class_mismatch', 'Cross-class grant was accepted')
        local grants = tonumber(DB.value([[SELECT COUNT(*) FROM `feather_authority_role_grants`
            WHERE `role_id`=? AND `status`='active']], role.value.roleId))
        local events = tonumber(DB.value([[SELECT COUNT(*) FROM `feather_authority_role_events`
            WHERE `role_id`=? AND `event_type`='authority.role.grant_added']], role.value.roleId))
        assert(grants == 1 and events == 1, 'Grant did not produce exactly one active grant and audit event')
        print(('[AuthorityRoleGrantLiveTest] PASS role=%s grant=%s revision=%d firstReplayed=%s replayed=true mismatchRejected=true staleRejected=true classMismatch=true singleGrantAudit=true'):format(
            role.value.roleId, first.value.grantId, first.value.roleRevision, tostring(first.value.replayed)))
    end, debug.traceback)
    if not called then print('[AuthorityRoleGrantLiveTest] FAIL ' .. tostring(reason)) end
end, true)
