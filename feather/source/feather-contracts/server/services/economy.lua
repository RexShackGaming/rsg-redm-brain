ContractsEconomy = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local logger = ContractsLogging.Create('economy')

-- Economy codes that prove the transfer did not post and will not post on
-- replay. Anything else (timeouts, internal errors, an unavailable provider)
-- leaves the outcome unknown, and the settlement stays pending for replay.
local definitiveRejections = {
    insufficient_funds = true,
    account_not_found = true,
    account_closed = true,
    currency_mismatch = true,
    authorization_denied = true,
    invalid_input = true,
    idempotency_conflict = true,
    transaction_conflict = true
}

local function Call(method, ...)
    local arguments = table.pack(...)
    local called, result = pcall(function()
        return exports['feather-economy'][method](exports['feather-economy'], table.unpack(arguments, 1, arguments.n))
    end)
    if not called then
        logger.Warn('call.failed', { method = method, reason = tostring(result) })
        return Err('dependency_unavailable', 'Feather Economy is unavailable.', { method = method })
    end
    if not ContractsResults.Is(result) then
        return Err('dependency_unavailable', 'Feather Economy returned an invalid result.', { method = method })
    end
    return result
end

function ContractsEconomy.RequireCurrency(code)
    local currency = Call('GetCurrency', code)
    if not currency.ok then
        if currency.code == 'currency_not_found' or currency.code == 'invalid_input' then
            return Err('currency_not_found', 'Currency was not found.')
        end
        return currency
    end
    if type(currency.value) ~= 'table' or currency.value.enabled ~= true then
        return Err('currency_disabled', 'Currency is not enabled.')
    end
    return Ok(currency.value)
end

local function FindOwnerAccount(ownerType, ownerId, accountType, currency)
    local accounts = Call('FindAccountsByOwner', { ownerType = ownerType, ownerId = ownerId })
    if not accounts.ok then return accounts end
    for _, account in ipairs(type(accounts.value) == 'table' and accounts.value or {}) do
        if account.accountType == accountType and account.currency == currency then
            if account.status ~= 'open' then
                return Err('account_closed', 'The party account is closed.')
            end
            return Ok(account)
        end
    end
    return Err('account_not_found', 'The party has no account in that currency.')
end

-- Resolved once at issuance and frozen on the obligation.
function ContractsEconomy.ResolveCreditorAccount(creditorType, creditorId, currency)
    if creditorType == 'character' then
        return FindOwnerAccount('character', creditorId, 'wallet', currency)
    elseif creditorType == 'organization' then
        return FindOwnerAccount('organization', creditorId, 'treasury', currency)
    elseif creditorType == 'system' then
        local account = Call('GetSystemAccount', { currency = currency, accountType = 'system_sink' })
        if not account.ok then return account end
        if type(account.value) ~= 'table' or account.value.status ~= 'open' then
            return Err('account_closed', 'The system account is closed.')
        end
        return Ok(account.value)
    end
    return Err('invalid_input', 'Unsupported creditor type.')
end

-- The account a debtor pays from: a character's wallet or an organization's treasury.
function ContractsEconomy.ResolveDebtorAccount(debtor, currency)
    if debtor.type == 'organization' then
        return FindOwnerAccount('organization', debtor.id, 'treasury', currency)
    end
    return FindOwnerAccount('character', debtor.id, 'wallet', currency)
end

-- The resource an organization's treasury is bound to, or nil. Only that resource
-- may act for the organization as a debtor (accept, dispute, pay).
function ContractsEconomy.TreasuryOperator(organizationId, currency)
    local treasury = FindOwnerAccount('organization', organizationId, 'treasury', currency)
    return treasury.ok and treasury.value.operatorResource or nil
end

-- The resource an organization's treasuries are bound to (the binding is per
-- organization, not per currency), or nil.
function ContractsEconomy.OrganizationOperator(organizationId)
    local accounts = Call('FindAccountsByOwner', { ownerType = 'organization', ownerId = organizationId })
    for _, account in ipairs(accounts.ok and type(accounts.value) == 'table' and accounts.value or {}) do
        if account.accountType == 'treasury' and type(account.operatorResource) == 'string' then
            return account.operatorResource
        end
    end
    return nil
end

-- DevMode acceptance only: the next N transfers post in Economy but their reply
-- is dropped, as if Economy timed out after the money moved.
ContractsEconomy.simulatedLostReplies = 0

-- Returns Ok({ outcome = 'committed'|'rejected'|'unknown', transactionId, code }).
function ContractsEconomy.Settle(settlement)
    local result = Call('Transfer', {
        fromAccountId = settlement.payer_account_id,
        toAccountId = settlement.payee_account_id,
        currency = settlement.currency,
        amount = math.floor(tonumber(settlement.amount)),
        reasonCode = Config.Settlement.reasonCode,
        referenceType = Config.Settlement.referenceType,
        referenceId = settlement.obligation_id,
        idempotencyKey = settlement.economy_idempotency_key
    }, {
        actorAccountId = settlement.actor_account_id,
        actorCharacterId = settlement.actor_character_id,
        correlationId = settlement.correlation_id,
        -- Economy lets an organization treasury pay only for the resource operating it.
        onBehalfOf = settlement.source_resource
    })
    if Config.DevMode and ContractsEconomy.simulatedLostReplies > 0 then
        ContractsEconomy.simulatedLostReplies = ContractsEconomy.simulatedLostReplies - 1
        logger.Warn('settle.reply_dropped', { settlementId = settlement.settlement_id, posted = result.ok })
        return Ok({ outcome = 'unknown', code = 'simulated_timeout' })
    end
    if result.ok then
        local value = type(result.value) == 'table' and result.value or {}
        if not ContractsValidation.Uuid(value.transactionId)
            or tonumber(value.amount) ~= tonumber(settlement.amount)
            or value.fromAccountId ~= settlement.payer_account_id
            or value.toAccountId ~= settlement.payee_account_id then
            logger.Error('settle.receipt_mismatch', { settlementId = settlement.settlement_id })
            return Ok({ outcome = 'unknown', code = 'receipt_mismatch' })
        end
        return Ok({ outcome = 'committed', transactionId = value.transactionId:lower(),
            replayed = value.replayed == true })
    end
    if definitiveRejections[result.code] then
        return Ok({ outcome = 'rejected', code = result.code, details = result.details })
    end
    return Ok({ outcome = 'unknown', code = result.code })
end

-- True when Economy offers GetTransaction (capability feature transactionRead).
function ContractsEconomy.CanReadTransactions()
    local capabilities = Call('GetCapabilities')
    return capabilities.ok and type(capabilities.value) == 'table' and type(capabilities.value.features) == 'table'
        and (tonumber(capabilities.value.features.transactionRead) or 0) >= 1
end

-- Economy only returns transactions Contracts posted itself.
function ContractsEconomy.GetTransaction(transactionId)
    return Call('GetTransaction', { transactionId = transactionId })
end
