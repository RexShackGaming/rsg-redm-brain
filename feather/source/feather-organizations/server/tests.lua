local function Request(id)
    return { requestId = id, organizationType = 'business', organizationKey = 'org_creation_test',
        legalName = 'Organization Creation Test Company', displayName = 'Organization Creation Test',
        reasonCode = 'development.creation_test' }
end
local function Run(name, callback)
    local called, result = xpcall(callback, debug.traceback)
    if not called then print((' [%s] FAIL %s'):format(name, tostring(result))) end
end
Organizations.RegisterDevCommand('OrganizationsCreationContractSmokeTest', function(source)
    if source ~= 0 then return end
    Run('OrganizationsCreationContractSmokeTest', function()
        if not Organizations.AwaitReady(0).ok then
            print('[OrganizationsCreationContractSmokeTest] FAIL service not ready'); return
        end
        local owner, valid = GetCurrentResourceName(), Request('contract-valid')
        local tests = {}
        local function Check(label, result) tests[#tests + 1] = { label, result } end
        Check('creation capability', Organizations.GetCapabilities().value.features.durableCreation == 1)
        Check('valid payload', OrganizationIdentity.Validate(valid).ok)
        local denied = OrganizationIdentity.Create(valid, 'untrusted-smoke-caller')
        Check('untrusted create rejected', not denied.ok and denied.code == 'authorization_denied')
        local deniedRead = OrganizationIdentity.Find({ organizationKey = valid.organizationKey }, 'untrusted-smoke-caller')
        Check('untrusted read rejected', not deniedRead.ok and deniedRead.code == 'authorization_denied')
        for _, test in ipairs({
            { 'missing ID rejected', nil },
            { 'oversized ID rejected', string.rep('x',129) },
            { 'malformed ID rejected', 'bad key' }
        }) do
            local request = Organizations.Copy(valid); request.requestId = test[2]
            local invalid = OrganizationIdentity.Validate(request)
            Check(test[1], not invalid.ok and invalid.code == 'invalid_input')
        end
        local injected = Organizations.Copy(valid); injected.sourceResource = owner
        Check('identity injection rejected', not OrganizationIdentity.Validate(injected).ok)
        local status = Organizations.Copy(valid); status.status = 'active'
        Check('initial status rejected', not OrganizationIdentity.Validate(status).ok)
        local badName = Organizations.Copy(valid); badName.displayName = '\ninvalid'
        Check('control name rejected', not OrganizationIdentity.Validate(badName).ok)
        Check('malformed UUID rejected', not OrganizationIdentity.Get({ organizationId = 'not-a-uuid' }, owner).ok)
        local changed = Organizations.Copy(valid); changed.displayName = 'Another Display Name'
        Check('payload binding', OrganizationIdentity.Validate(valid).value ~= OrganizationIdentity.Validate(changed).value)
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[OrganizationsCreationContractSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsCreationContractSmokeTest] done %d/%d passed (no organizations created)'):format(passed,#tests))
    end)
end, true)

Organizations.RegisterDevCommand('OrganizationsCreationLiveTest', function(source,args)
    if source ~= 0 or not Config.DevMode then return end
    Run('OrganizationsCreationLiveTest', function()
        if #args ~= 1 then print('[OrganizationsCreationLiveTest] FAIL use <stable requestId>'); return end
        local owner, request = GetCurrentResourceName(), Request(args[1])
        -- A fixed dev organization key deliberately limits this test to one entity.
        -- Reuse the original request ID, including after resource restart.
        local first = OrganizationIdentity.Create(request, owner)
        if not first.ok then
            print(('[OrganizationsCreationLiveTest] FAIL code=%s message=%s'):format(first.code,first.message)); return
        end
        local replay = OrganizationIdentity.Create(request, owner)
        local changed = Organizations.Copy(request); changed.displayName = 'Tampered Name'
        local mismatch = OrganizationIdentity.Create(changed, owner)
        local duplicate = Organizations.Copy(request)
        -- Change exactly one valid character: distinct even at the length limit.
        duplicate.requestId = args[1]:sub(1,-2) .. (args[1]:sub(-1) == 'x' and 'y' or 'x')
        local conflict = OrganizationIdentity.Create(duplicate, owner)
        local found = OrganizationIdentity.Find({ organizationKey = request.organizationKey },owner)
        local read = OrganizationIdentity.Get({ organizationId = first.value.organizationId },owner)
        local counts = DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organizations` WHERE `organization_key`=?) AS entities,
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id`=?) AS events,
            (SELECT COUNT(*) FROM `feather_organization_creation_receipts`
                WHERE `source_resource`=? AND `request_id`=?) AS receipts,
            (SELECT COUNT(*) FROM `feather_organization_creation_receipts`
                WHERE `source_resource`=? AND `request_id`=?) AS duplicate_receipts]], request.organizationKey, first.value.organizationId,owner,args[1],owner,duplicate.requestId)
        local good = replay.ok and replay.value.replayed == true
            and replay.value.organizationId == first.value.organizationId
            and not mismatch.ok and mismatch.code == 'idempotency_conflict'
            and not conflict.ok and conflict.code == 'organization_key_conflict'
            and found.ok and found.value.organizationId == first.value.organizationId
            and read.ok and read.value.status == 'pending' and read.value.revision == 1
            and counts and tonumber(counts.entities) == 1 and tonumber(counts.events) == 1
            and tonumber(counts.receipts) == 1 and tonumber(counts.duplicate_receipts) == 0
        print(('[OrganizationsCreationLiveTest] %s id=%s state=%s firstReplayed=%s replayed=%s mismatchRejected=%s keyConflict=%s singleEntityAudit=%s'):format(
            good and 'PASS' or 'FAIL', first.value.organizationId,first.value.status,
            tostring(first.value.replayed),tostring(replay.ok and replay.value.replayed),
            tostring(not mismatch.ok and mismatch.code == 'idempotency_conflict'),
            tostring(not conflict.ok and conflict.code == 'organization_key_conflict'),
            tostring(counts and tonumber(counts.entities)==1 and tonumber(counts.events)==1)))
    end)
end, true)
