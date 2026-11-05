-- Read-only checks for GetTransaction. Stays available in the production profile.

RegisterCommand('EconomyTransactionReadSmokeTest', function(source)
    if source ~= 0 then return end
    local passed, total = 0, 0
    local function Check(label, condition)
        total = total + 1
        if condition then passed = passed + 1 end
        print(('[EconomyTransactionReadSmokeTest] %s %s'):format(label, condition and 'PASS' or 'FAIL'))
    end
    local features = EconomyAPI.GetCapabilities().value.features
    Check('capability advertised', features.transactionRead == 1)
    local untrusted = EconomyAPI.GetTransaction({ transactionId = Config.SystemOwnerId }, 'untrusted-resource')
    Check('untrusted reader rejected', not untrusted.ok and untrusted.code == 'authorization_denied')
    local malformed = EconomyAPI.GetTransaction({ transactionId = 'bad' }, 'feather-economy')
    Check('malformed id rejected', not malformed.ok and malformed.code == 'invalid_input')
    local extra = EconomyAPI.GetTransaction({ transactionId = Config.SystemOwnerId, accountId = 'x' }, 'feather-economy')
    Check('unknown field rejected', not extra.ok and extra.code == 'invalid_input')
    local missing = EconomyAPI.GetTransaction({ transactionId = Config.SystemOwnerId }, 'feather-economy')
    Check('unknown transaction not found', not missing.ok and missing.code == 'transaction_not_found')

    -- A recent transaction whose poster may read (it must be a trusted reader).
    local row
    for _, candidate in ipairs(DB.query([[SELECT `transaction_id`,`source_resource` FROM `economy_transactions`
        WHERE `status`='committed' AND `source_resource`<>'feather-hud' ORDER BY `posted_at` DESC LIMIT 50]]) or {}) do
        if Config.Access.trustedReaders[candidate.source_resource] == true then
            row = candidate
            break
        end
    end
    if not row then
        print('[EconomyTransactionReadSmokeTest] no committed transaction yet; ownership checks skipped')
    else
        local own = EconomyAPI.GetTransaction({ transactionId = row.transaction_id }, row.source_resource)
        local balanced = own.ok and #own.value.entries >= 2
        if balanced then
            local sum = 0
            for _, entry in ipairs(own.value.entries) do sum = sum + entry.amount end
            balanced = sum == 0 and own.value.amount > 0
        end
        Check('poster reads its transaction', own.ok and own.value.transactionId == row.transaction_id
            and own.value.status == 'committed')
        Check('entries balance', balanced)
        local foreign = EconomyAPI.GetTransaction({ transactionId = row.transaction_id }, 'feather-hud')
        Check('foreign transaction hidden', not foreign.ok and foreign.code == 'transaction_not_found')
        local privileged = EconomyAPI.GetTransaction({ transactionId = row.transaction_id }, 'feather-admin')
        Check('privileged reader allowed', privileged.ok)
    end
    print(('[EconomyTransactionReadSmokeTest] done %d/%d passed (read-only)'):format(passed, total))
end, true)
