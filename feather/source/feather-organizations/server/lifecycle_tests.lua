local function Run(name, callback)
    local called, result = xpcall(callback, debug.traceback)
    if not called then print((' [%s] FAIL %s'):format(name, tostring(result))) end
end
Organizations.RegisterDevCommand('OrganizationsLifecycleContractSmokeTest', function(source)
    if source ~= 0 then return end
    Run('OrganizationsLifecycleContractSmokeTest', function()
        if not Organizations.AwaitReady(0).ok then print('[OrganizationsLifecycleContractSmokeTest] FAIL not ready'); return end
        local request = { organizationId = '00000000-0000-4000-8000-000000000001',
            expectedRevision = 1, status = 'active', requestId = 'lifecycle-contract', reasonCode = 'development.lifecycle' }
        local tests = {
            { 'lifecycle capability', Organizations.GetCapabilities().value.features.organizationLifecycle == 1 },
            { 'valid request', OrganizationLifecycle.Validate(request).ok },
            { 'pending activation', OrganizationLifecycle.CanTransition('pending','active') },
            { 'active suspension', OrganizationLifecycle.CanTransition('active','suspended') },
            { 'suspended resume', OrganizationLifecycle.CanTransition('suspended','active') },
            { 'staged dissolution', OrganizationLifecycle.CanTransition('active','dissolving')
                and OrganizationLifecycle.CanTransition('dissolving','dissolved') },
            { 'skip dissolution rejected', not OrganizationLifecycle.CanTransition('active','dissolved') },
            { 'terminal state', not OrganizationLifecycle.CanTransition('dissolved','active') },
            { 'same status rejected', not OrganizationLifecycle.CanTransition('active','active') }
        }
        local denied = OrganizationLifecycle.Change(request,'untrusted-smoke-caller')
        tests[#tests+1] = { 'untrusted rejected', not denied.ok and denied.code == 'authorization_denied' }
        for _, test in ipairs({ { 'fractional revision', 'expectedRevision', 1.5 },
            { 'zero revision', 'expectedRevision', 0 }, { 'missing request ID','requestId',nil },
            { 'unknown status','status','unknown' }, { 'identity injection','sourceResource','injected' } }) do
            local changed = Organizations.Copy(request); changed[test[2]] = test[3]
            tests[#tests+1] = { test[1] .. ' rejected', not OrganizationLifecycle.Validate(changed).ok }
        end
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[OrganizationsLifecycleContractSmokeTest] %-30s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsLifecycleContractSmokeTest] done %d/%d passed (no status changes)'):format(passed,#tests))
    end)
end,true)

Organizations.RegisterDevCommand('OrganizationsLifecycleLiveTest',function(source,args)
    if source ~= 0 or not Config.DevMode then return end
    Run('OrganizationsLifecycleLiveTest',function()
        local base = args[1]
        if #args ~= 1 or type(base) ~= 'string' or #base > 100
            or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
            print('[OrganizationsLifecycleLiveTest] FAIL use <stable requestId up to 100 characters>'); return
        end
        local owner = GetCurrentResourceName()
        local created = OrganizationIdentity.Create({ requestId = base .. ':create', organizationType = 'business',
            organizationKey = 'org_lifecycle_test', legalName = 'Organization Lifecycle Test Company',
            displayName = 'Organization Lifecycle Test', reasonCode = 'development.lifecycle_test' },owner)
        if not created.ok then print('[OrganizationsLifecycleLiveTest] FAIL create code=' .. created.code); return end
        local id, allReplayed = created.value.organizationId, true
        for revision,status in ipairs({ 'active','suspended','active','dissolving','dissolved' }) do
            local request = { organizationId = id, expectedRevision = revision, status = status,
                requestId = base .. ':step:' .. revision, reasonCode = 'development.lifecycle_test' }
            local result = OrganizationLifecycle.Change(request,owner)
            if not result.ok then
                print(('[OrganizationsLifecycleLiveTest] FAIL step=%d code=%s'):format(revision,result.code)); return
            end
            allReplayed = allReplayed and result.value.replayed == true
            local replay = OrganizationLifecycle.Change(request,owner)
            local changed = Organizations.Copy(request); changed.reasonCode = 'development.tampered'
            local mismatch = OrganizationLifecycle.Change(changed,owner)
            if not replay.ok or replay.value.replayed ~= true or replay.value.revision ~= revision+1
                or replay.value.organizationId ~= id or mismatch.ok or mismatch.code ~= 'idempotency_conflict' then
                print('[OrganizationsLifecycleLiveTest] FAIL replay/mismatch step=' .. revision); return
            end
        end
        local stale = OrganizationLifecycle.Change({ organizationId=id,expectedRevision=1,status='active',
            requestId=base .. ':stale',reasonCode='development.lifecycle_test' },owner)
        local terminal = OrganizationLifecycle.Change({ organizationId=id,expectedRevision=6,status='active',
            requestId=base .. ':terminal',reasonCode='development.lifecycle_test' },owner)
        local current = OrganizationIdentity.Get({organizationId=id},owner)
        local counts = DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id`=?) AS events,
            (SELECT COUNT(*) FROM `feather_organization_lifecycle_receipts`
                WHERE `source_resource`=? AND `request_id` IN (?,?)) AS rejected_receipts]], id,owner,base .. ':stale',base .. ':terminal')
        local good = not stale.ok and stale.code=='revision_conflict' and not terminal.ok
            and terminal.code=='invalid_transition' and current.ok and current.value.status=='dissolved'
            and current.value.revision==6 and counts and tonumber(counts.events)==6
            and tonumber(counts.rejected_receipts)==0
        print(('[OrganizationsLifecycleLiveTest] %s id=%s state=%s revision=%s allReplayed=%s staleRejected=%s terminalBlocked=%s events=%s rolledBack=%s'):format(
            good and 'PASS' or 'FAIL',id,current.ok and current.value.status or 'unknown',
            tostring(current.ok and current.value.revision),tostring(allReplayed),
            tostring(not stale.ok and stale.code=='revision_conflict'),
            tostring(not terminal.ok and terminal.code=='invalid_transition'),
            tostring(counts and counts.events),tostring(counts and tonumber(counts.rejected_receipts)==0)))
    end)
end,true)
