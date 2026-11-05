-- Development-only acceptance test. MUTATES DATA: it registers a uniquely keyed
-- smoke_* license definition, issues it to two characters, lets one expire,
-- renews, suspends, reinstates and revokes, issues again and retires the
-- definition. With an organization UUID it also issues a business license held
-- and issued by that organization. Nobody needs to be online. Never enable
-- DevMode in production.
--   Usage (server console):
--   LicensesLifecycleSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid> [organizationUuid]

local function Target(argument)
    if Licenses.Uuid(argument) then
        return argument:lower()
    end
    local source = tonumber(argument)
    if not source then
        return nil
    end
    local session = exports['feather-core']:GetSessionContext(source)
    return type(session) == 'table' and session.ok and session.value.characterId:lower() or nil
end

-- Runs both requests at once; the current-slot key must let exactly one win.
local function Race(first, second)
    local results, done = {}, 0
    for index, request in ipairs({ first, second }) do
        CreateThread(function()
            results[index] = LicenseRecords.Issue(request, GetCurrentResourceName())
            done = done + 1
        end)
    end
    while done < 2 do
        Wait(0)
    end
    return results[1], results[2]
end

Licenses.RegisterDevCommand('LicensesLifecycleSmokeTest', function(source, args)
    if source ~= 0 then
        return
    end
    CreateThread(function()
        local called, reason = xpcall(function()
            local holderA, holderB = Target(args[1]), Target(args[2])
            local organizationId = args[3] and Licenses.Uuid(args[3]) and args[3]:lower() or nil
            if not holderA or not holderB or holderA == holderB or (args[3] and not organizationId) then
                print('[LicensesLifecycleSmokeTest] usage: LicensesLifecycleSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid> [organizationUuid]')
                return
            end
            local owner, untrusted = GetCurrentResourceName(), 'untrusted-smoke-caller'
            local run = ('%d%04d'):format(os.time(), math.random(0, 9999))
            local key = 'smoke_' .. run
            local reasonCode = 'licenses.smoke_test'
            local function Id(step)
                return ('smoke:%s:%s'):format(run, step)
            end
            local function Define(requestId, label, resource)
                return LicenseDefinitions.Register({
                    requestId = requestId,
                    licenseKey = key,
                    label = label,
                    holderTypes = { 'character' },
                    defaultDurationSeconds = 86400,
                    maxDurationSeconds = 30 * 86400,
                    reasonCode = reasonCode
                }, resource)
            end
            local function Issue(step, holderId, extra, resource)
                local request = {
                    requestId = Id(step),
                    licenseKey = key,
                    holderType = 'character',
                    holderId = holderId,
                    reasonCode = reasonCode
                }
                for field, value in pairs(extra or {}) do
                    request[field] = value
                end
                return LicenseRecords.Issue(request, resource or owner)
            end
            local function Check(holderId)
                return LicenseRecords.Check({ holderType = 'character', holderId = holderId, licenseKey = key }, owner)
            end
            local function Step(fn, step, licenseId, revision, extra, resource)
                local request = { requestId = Id(step), licenseId = licenseId, expectedRevision = revision,
                    reasonCode = reasonCode }
                for field, value in pairs(extra or {}) do
                    request[field] = value
                end
                return fn(request, resource or owner)
            end

            local defined = Define(Id('define'), 'Smoke Licence', owner)
            local defineReplay = Define(Id('define'), 'Smoke Licence', owner)
            local defineConflict = Define(Id('define'), 'Other Label', owner)
            local defineTaken = Define(Id('define-again'), 'Smoke Licence', owner)
            local defineDenied = Define(Id('define-denied'), 'Smoke Licence', untrusted)

            local issuedA = Issue('issue-a', holderA, { scope = { classes = { 'pistol' } } })
            local issueReplay = Issue('issue-a', holderA, { scope = { classes = { 'pistol' } } })
            local duplicate = Issue('issue-a-again', holderA)
            local issueDenied = Issue('issue-denied', holderA, nil, untrusted)
            local tooLong = Issue('issue-long', holderB, { durationSeconds = 31 * 86400 })
            local badScope = Issue('issue-scope', holderB, { scope = { a = { b = { c = { d = { e = 1 } } } } } })
            local noActor = Issue('issue-officer', holderB, { issuerType = 'character' })
            local issuedB = Issue('issue-b', holderB, { durationSeconds = 2 })
            local licenseA = issuedA.ok and issuedA.value.licenseId or '00000000-0000-0000-0000-000000000000'
            local licenseB = issuedB.ok and issuedB.value.licenseId or '00000000-0000-0000-0000-000000000000'

            local checkA = Check(holderA)
            local checkB = Check(holderB)
            Wait(3500)
            local checkBExpired = Check(holderB)
            LicenseExpiry.Sweep()
            local historyB = LicenseEvents.History({ aggregateType = 'license', aggregateId = licenseB }, owner)
            local expiredEvent = false
            for _, item in ipairs(historyB.ok and historyB.value.items or {}) do
                if item.eventType == 'license.expired' then
                    expiredEvent = true
                end
            end
            local renewedB = Step(LicenseRecords.Renew, 'renew-b', licenseB, 1, { durationSeconds = 3600 })
            local checkBRenewed = Check(holderB)

            local stale = Step(LicenseRecords.Suspend, 'suspend-stale', licenseA, 99)
            local suspended = Step(LicenseRecords.Suspend, 'suspend', licenseA, 1)
            local checkASuspended = Check(holderA)
            local renewSuspended = Step(LicenseRecords.Renew, 'renew-suspended', licenseA, 2)
            local reinstated = Step(LicenseRecords.Reinstate, 'reinstate', licenseA, 2)
            local foreign = Step(LicenseRecords.Revoke, 'revoke-foreign', licenseA, 3, nil, untrusted)
            local revoked = Step(LicenseRecords.Revoke, 'revoke', licenseA, 3)
            local revokedAgain = Step(LicenseRecords.Revoke, 'revoke-again', licenseA, 4)
            local checkARevoked = Check(holderA)
            local reissued = Issue('issue-a-new', holderA)
            local current = LicenseRecords.ListByHolder({ holderType = 'character', holderId = holderA,
                licenseKey = key }, owner)
            local all = LicenseRecords.ListByHolder({ holderType = 'character', holderId = holderA,
                licenseKey = key, includeRevoked = true }, owner)
            local lookup = Licenses.FindOperation({ requestId = Id('issue-a') }, owner)
            local historyA = LicenseEvents.History({ aggregateType = 'license', aggregateId = licenseA }, owner)
            local retired = LicenseDefinitions.Update({ requestId = Id('retire'), licenseKey = key,
                expectedRevision = 1, status = 'retired', reasonCode = reasonCode }, owner)
            local issueRetired = Issue('issue-retired', holderB)

            -- A second kind for businesses and characters: a race for one holder,
            -- then (with an organization) a license held and issued by it.
            local businessKey = key .. '_biz'
            local business = LicenseDefinitions.Register({ requestId = Id('define-business'), licenseKey = businessKey,
                label = 'Smoke Business Permit', holderTypes = { 'character', 'organization' },
                defaultDurationSeconds = 86400, reasonCode = reasonCode }, owner)
            local function BusinessIssue(step, holderType, holderId, extra)
                local request = { requestId = Id(step), licenseKey = businessKey, holderType = holderType,
                    holderId = holderId, reasonCode = reasonCode }
                for field, value in pairs(extra or {}) do
                    request[field] = value
                end
                return request
            end
            local raceA, raceB = Race(BusinessIssue('race-a', 'character', holderA),
                BusinessIssue('race-b', 'character', holderA))
            local winners = (raceA.ok and 1 or 0) + (raceB.ok and 1 or 0)
            local loser = raceA.ok and raceB or raceA
            local orgIssued, orgUnknownIssuer
            if organizationId then
                orgIssued = LicenseRecords.Issue(BusinessIssue('org-issue', 'organization', organizationId, {
                    issuerType = 'organization', issuerId = organizationId }), owner)
                orgUnknownIssuer = LicenseRecords.Issue(BusinessIssue('org-unknown', 'character', holderB, {
                    issuerType = 'organization', issuerId = '00000000-0000-4000-8000-000000000000' }), owner)
            end

            local tests = {
                { 'register definition', defined.ok and defined.value.licenseKey == key
                    and defined.value.replayed == false },
                { 'definition replay', defineReplay.ok and defineReplay.value.replayed == true },
                { 'idempotency conflict', not defineConflict.ok and defineConflict.code == 'idempotency_conflict' },
                { 'license key taken', not defineTaken.ok and defineTaken.code == 'license_key_conflict' },
                { 'untrusted registrar denied', not defineDenied.ok and defineDenied.code == 'authorization_denied' },
                { 'license issued', issuedA.ok and issuedA.value.valid == true and issuedA.value.revision == 1
                    and issuedA.value.expiresAt - issuedA.value.issuedAt == 86400000 },
                { 'issue replay', issueReplay.ok and issueReplay.value.replayed == true
                    and issueReplay.value.licenseId == licenseA },
                { 'one current license', not duplicate.ok and duplicate.code == 'license_exists'
                    and duplicate.details.licenseId == licenseA },
                { 'untrusted issuer denied', not issueDenied.ok and issueDenied.code == 'authorization_denied' },
                { 'duration limit enforced', not tooLong.ok and tooLong.code == 'invalid_duration' },
                { 'scope limits enforced', not badScope.ok and badScope.code == 'invalid_scope' },
                { 'officer needs actor', not noActor.ok and noActor.code == 'invalid_input' },
                { 'check returns scope', checkA.ok and checkA.value.matched == true
                    and checkA.value.scope.classes[1] == 'pistol' },
                { 'short license valid', checkB.ok and checkB.value.matched == true },
                { 'expiry without sweep', checkBExpired.ok and checkBExpired.value.matched == false
                    and checkBExpired.value.expired == true and checkBExpired.value.status == 'active' },
                { 'expired event published', expiredEvent },
                { 'renewal revives', renewedB.ok and renewedB.value.valid == true and renewedB.value.revision == 2 },
                { 'renewed check', checkBRenewed.ok and checkBRenewed.value.matched == true },
                { 'stale revision rejected', not stale.ok and stale.code == 'revision_conflict' },
                { 'license suspended', suspended.ok and suspended.value.status == 'suspended'
                    and suspended.value.valid == false },
                { 'suspension denies check', checkASuspended.ok and checkASuspended.value.matched == false
                    and checkASuspended.value.status == 'suspended' },
                { 'suspended not renewable', not renewSuspended.ok and renewSuspended.code == 'license_suspended' },
                { 'license reinstated', reinstated.ok and reinstated.value.valid == true },
                { 'foreign mutation denied', not foreign.ok and foreign.code == 'authorization_denied' },
                { 'license revoked', revoked.ok and revoked.value.status == 'revoked' and revoked.value.valid == false },
                { 'revoke is terminal', not revokedAgain.ok and revokedAgain.code == 'license_revoked' },
                { 'revoked check empty', checkARevoked.ok and checkARevoked.value.matched == false
                    and checkARevoked.value.licenseId == nil },
                { 'issued again', reissued.ok and reissued.value.licenseId ~= licenseA },
                { 'list hides revoked', current.ok and #current.value.items == 1 and all.ok and #all.value.items == 2 },
                { 'operation lookup', lookup.ok and lookup.value.found == true
                    and lookup.value.operation == 'license.issue' },
                { 'audit history', historyA.ok and #historyA.value.items == 4 },
                { 'retired definition', retired.ok and retired.value.status == 'retired'
                    and not issueRetired.ok and issueRetired.code == 'definition_inactive' },
                { 'concurrent issue one winner', business.ok and winners == 1 and loser.code == 'license_exists' }
            }
            if organizationId then
                tests[#tests + 1] = { 'organization holder and issuer', orgIssued.ok and orgIssued.value.valid == true
                    and orgIssued.value.holderType == 'organization' and orgIssued.value.issuer.type == 'organization'
                    and orgIssued.value.issuer.id == organizationId }
                tests[#tests + 1] = { 'unknown issuer rejected', not orgUnknownIssuer.ok
                    and orgUnknownIssuer.code == 'issuer_not_found' }
            else
                print('[LicensesLifecycleSmokeTest] organization checks skipped (no organizationUuid given)')
            end
            local passed = 0
            for _, test in ipairs(tests) do
                if test[2] then
                    passed = passed + 1
                end
                print(('[LicensesLifecycleSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
            end
            print(('[LicensesLifecycleSmokeTest] done %d/%d passed (MUTATING: license key %s)'):format(
                passed, #tests, key))

            local function Explain(step, result)
                if result.ok then
                    return
                end
                local details = type(result.details) == 'table' and result.details or {}
                print(('[LicensesLifecycleSmokeTest] %s failed code=%s policyCode=%s provider=%s reason=%s'):format(
                    step, tostring(result.code), tostring(details.policyCode), tostring(details.provider),
                    tostring(details.policyReason or result.message)))
            end
            Explain('define', defined)
            Explain('issue', issuedA)
            if orgIssued then
                Explain('organization issue', orgIssued)
            end
        end, debug.traceback)
        if not called then
            print('[LicensesLifecycleSmokeTest] FAIL ' .. tostring(reason))
        end
    end)
end, true)
