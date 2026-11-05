if not Config.DevMode then return end

RegisterCommand('EconomyTreasurySettlementContractSmokeTest', function(source)
    if source ~= 0 then return end
    local passed,total=0,0
    local function Check(label,condition)
        total=total+1
        if condition then passed=passed+1 end
        print(('[EconomyTreasurySettlementContractSmokeTest] %s %s'):format(label,condition and 'PASS' or 'FAIL'))
    end
    local wallet={account_type='wallet',owner_type='character'}
    local treasury={account_type='treasury',owner_type='organization'}
    local sink={account_type='system_sink',owner_type='system'}
    local sourceAccount={account_type='system_source',owner_type='system'}
    local terms={reasonCode='shop.purchase',referenceType='shop_order',referenceId=Config.SystemOwnerId}
    local allowed=EconomyJournal.AccountTypesAllowed
    Check('shop treasury credit allowed',allowed('transfer',wallet,treasury,terms)==true)
    Check('generic treasury credit rejected',not allowed('transfer',wallet,treasury,{}))
    Check('treasury withdrawal rejected',not allowed('transfer',treasury,wallet,terms))
    Check('treasury supply rejected',not allowed('issue',sourceAccount,treasury,terms))
    Check('treasury destruction rejected',not allowed('destroy',treasury,sink,terms))
    Check('payment reversal type allowed',allowed('reversal',treasury,wallet,terms)==true)
    Check('historical sink reversal allowed',allowed('reversal',sink,wallet,terms)==true)
    Check('wrong treasury owner rejected',not allowed('transfer',wallet,{account_type='treasury',owner_type='character'},terms))
    print(('[EconomyTreasurySettlementContractSmokeTest] done %d/%d passed (isolated account-type gate; no funds moved)'):format(passed,total))
end,true)

RegisterCommand('EconomyTreasuryContractSmokeTest', function(source)
    if source ~= 0 then return end
    local passed, total = 0, 0
    local function Check(label, condition)
        total = total + 1
        if condition then passed = passed + 1 end
        print(('[EconomyTreasuryContractSmokeTest] %s %s'):format(label, condition and 'PASS' or 'FAIL'))
    end
    Check('treasury capability', EconomyAPI.GetCapabilities().value.features.organizationTreasuries == 1)
    local denied = EconomyAPI.EnsureOrganizationTreasuries({}, 'untrusted-resource')
    Check('untrusted provision rejected', not denied.ok and denied.code == 'authorization_denied')
    local invalid = EconomyAPI.EnsureOrganizationTreasuries({}, 'feather-economy')
    Check('missing identity rejected', not invalid.ok and invalid.code == 'invalid_input')
    invalid = EconomyAPI.EnsureOrganizationTreasuries({ organizationId = 'bad' }, 'feather-economy')
    Check('malformed UUID rejected', not invalid.ok and invalid.code == 'invalid_input')
    invalid = EconomyAPI.EnsureOrganizationTreasuries({ organizationId = Config.SystemOwnerId, balance = 100 }, 'feather-economy')
    Check('balance injection rejected', not invalid.ok and invalid.code == 'invalid_input')
    local rows = DB.query([[SELECT `account_id` FROM `economy_accounts`
        WHERE (`owner_type`='organization' AND `account_type`<>'treasury')
           OR (`account_type`='treasury' AND `owner_type`<>'organization')]]) or {}
    Check('owner type integrity', #rows == 0)
    print(('[EconomyTreasuryContractSmokeTest] done %d/%d passed (no accounts created or funds moved)'):format(passed, total))
end, true)

RegisterCommand('EconomyTreasuryProvisionTest', function(source, args)
    if source ~= 0 then return end
    local called, failure = xpcall(function()
        if type(args[1]) == 'string' then args[1] = args[1]:lower() end
        local first = EconomyAPI.EnsureOrganizationTreasuries({ organizationId = args[1] }, 'feather-economy')
        assert(first.ok, tostring(first.code) .. ': ' .. tostring(first.message))
        local second = EconomyAPI.EnsureOrganizationTreasuries({ organizationId = args[1] }, 'feather-economy')
        assert(second.ok and #first.value == #second.value and #first.value > 0, 'Treasury replay failed')
        for index, account in ipairs(first.value) do
            local replay = second.value[index]
            assert(account.ownerType == 'organization' and account.ownerId == args[1]
                and account.accountType == 'treasury' and account.status == 'open'
                and account.accountId == replay.accountId and account.balance == replay.balance,
                'Treasury identity or balance changed on replay')
        end
        print(('[EconomyTreasuryProvisionTest] PASS organization=%s treasuries=%d stableIdentity=true balancesUnchanged=true (no funds moved)'):format(args[1], #first.value))
    end, debug.traceback)
    if not called then print('[EconomyTreasuryProvisionTest] FAIL ' .. tostring(failure)) end
end, true)
