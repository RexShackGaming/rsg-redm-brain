-- Read-only check of the obligation settlement rule (journal.lua). It uses
-- in-memory accounts and a test settler; no account is created and no funds move.

RegisterCommand('EconomySettlementGateSmokeTest', function(source)
    if source ~= 0 then return end
    local Check, Result = EconomyTests.Counter('EconomySettlementGateSmokeTest')
    local SETTLER, OPERATOR, OTHER = 'economy-gate-settler', 'economy-gate-operator', 'economy-gate-other'
    local settlers = Config.Access.trustedSettlers
    Config.Access.trustedSettlers = { [SETTLER] = true }
    local called, failure = xpcall(function()
        local org, otherOrg = '00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a2'
        local bindings = { [org] = OPERATOR }
        local database = { value = function(_, organizationId) return bindings[organizationId] end }
        local wallet = { account_type = 'wallet', owner_type = 'character', owner_id = '00000000-0000-4000-8000-0000000000c1' }
        local treasury = { account_type = 'treasury', owner_type = 'organization', owner_id = org }
        local unbound = { account_type = 'treasury', owner_type = 'organization', owner_id = otherOrg }
        local sink = { account_type = 'system_sink', owner_type = 'system', owner_id = Config.SystemOwnerId }
        local function Request(overrides)
            local request = { reasonCode = Config.Settlement.reasonCode, referenceType = Config.Settlement.referenceType,
                referenceId = '00000000-0000-4000-8000-0000000000b1' }
            for key, value in pairs(overrides or {}) do request[key] = value end
            return request
        end
        local function Allowed(from, to, request, resource, context, operation)
            return EconomyJournal.AccountTypesAllowed(operation or 'transfer', from, to, request, resource,
                context or {}, database) == true
        end

        Check('capability advertised', EconomyAPI.GetCapabilities().value.features.organizationSettlement == 1)
        Check('wallet pays organization treasury', Allowed(wallet, treasury, Request(), SETTLER))
        Check('non-settler refused', not Allowed(wallet, treasury, Request(), OTHER))
        Check('other reason refused', not Allowed(wallet, treasury, Request({ reasonCode = 'other.reason' }), SETTLER))
        Check('other reference type refused', not Allowed(wallet, treasury, Request({ referenceType = 'order' }), SETTLER))
        Check('reference must be a UUID', not Allowed(wallet, treasury, Request({ referenceId = 'x' }), SETTLER))
        Check('only transfers', not Allowed(wallet, treasury, Request(), SETTLER, nil, 'issue'))
        Check('treasury pays for its operator', Allowed(treasury, wallet, Request(), SETTLER, { onBehalfOf = OPERATOR }))
        Check('treasury pays the system sink', Allowed(treasury, sink, Request(), SETTLER, { onBehalfOf = OPERATOR }))
        Check('treasury pays another treasury', Allowed(treasury, unbound, Request(), SETTLER, { onBehalfOf = OPERATOR }))
        Check('treasury refused without operator', not Allowed(treasury, wallet, Request(), SETTLER))
        Check('treasury refused for another resource', not Allowed(treasury, wallet, Request(), SETTLER, { onBehalfOf = OTHER }))
        Check('unbound treasury refused', not Allowed(unbound, wallet, Request(), SETTLER, { onBehalfOf = OPERATOR }))
    end, debug.traceback)
    Config.Access.trustedSettlers = settlers
    if not called then print('[EconomySettlementGateSmokeTest] FAIL ' .. tostring(failure)) end
    local passed, total = Result()
    print(('[EconomySettlementGateSmokeTest] done %d/%d passed (in-memory accounts; no funds moved)'):format(passed, total))
end, true)
