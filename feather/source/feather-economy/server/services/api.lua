EconomyAPI = {}

function EconomyAPI.GetCapabilities()
    return EconomyFoundation.GetCapabilities()
end

function EconomyAPI.GetHealth()
    return EconomyResults.Ok(EconomyFoundation.GetHealth())
end

function EconomyAPI.AwaitReady(timeoutMs)
    return EconomyFoundation.AwaitReady(timeoutMs)
end

function EconomyAPI.GetCurrency(code)
    return EconomyCurrencies.Get(code)
end

function EconomyAPI.ListCurrencies()
    return EconomyCurrencies.List()
end

local function Authorize(resource, group)
    if type(resource) ~= 'string' or resource == ''
        or type(Config.Access[group]) ~= 'table'
        or Config.Access[group][resource] ~= true then
        return EconomyResults.Err('authorization_denied',
            'Calling resource is not authorized for this Economy operation.')
    end
    return EconomyResults.Ok(true)
end

function EconomyAPI.GetAccount(request, resource)
    local allowed = Authorize(resource, 'trustedReaders')
    if not allowed.ok then return allowed end
    request = type(request) == 'table' and request or {}
    return EconomyAccounts.Get(request.accountId)
end

function EconomyAPI.FindAccountsByOwner(request, resource)
    local allowed = Authorize(resource, 'trustedReaders')
    if not allowed.ok then return allowed end
    request = type(request) == 'table' and request or {}
    return EconomyAccounts.FindByOwner(request.ownerType, request.ownerId)
end

function EconomyAPI.EnsureCharacterWallets(request, resource)
    local allowed = Authorize(resource, 'trustedProvisioners')
    if not allowed.ok then return allowed end
    request = type(request) == 'table' and request or {}
    return EconomyAccounts.EnsureCharacterWallets(request.characterId)
end

-- Provisions one bank account per currency for a character under a stable
-- accountRef, so a character can hold several (for example one per branch).
-- Like the treasury export it accepts only identity fields: no balances,
-- account types or labels can be supplied by the caller.
function EconomyAPI.EnsureCharacterBankAccounts(request, resource)
    local allowed = Authorize(resource, 'trustedBankProvisioners')
    if not allowed.ok then return allowed end
    if EconomyFoundation.GetHealth().state ~= 'ready' then
        return EconomyResults.Err('not_ready', 'Economy is not ready.')
    end
    if type(request) ~= 'table' then
        return EconomyResults.Err('invalid_input', 'Character UUID required.')
    end
    for key in pairs(request) do
        if key ~= 'characterId' and key ~= 'accountRef' then
            return EconomyResults.Err('invalid_input', 'Unexpected bank provisioning field.')
        end
    end
    local id = request.characterId
    if type(id) ~= 'string' or not id:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') then
        return EconomyResults.Err('invalid_input', 'Character UUID required.')
    end
    return EconomyAccounts.EnsureCharacterBankAccounts(id:lower(), request.accountRef)
end

-- Account history is private owner history. Besides the privileged readers, a
-- caller sees only accounts it serves: bank transactors read bank accounts, and
-- an operator reads the treasury bound to it. Unknown and foreign accounts return
-- the same denial so the answer does not reveal whether an account exists.
local function CanReadHistory(accountId, resource)
    local account = EconomyAccounts.Get(accountId)
    if not account.ok then return false end
    local value = account.value
    if value.accountType == 'bank' then
        local bankers = Config.Access.trustedBankTransactors
        return type(bankers) == 'table' and bankers[resource] == true
    end
    if value.accountType == 'treasury' and value.ownerType == 'organization' and type(value.ownerId) == 'string' then
        return DB.value('SELECT `operator_resource` FROM `economy_treasury_operators` WHERE `organization_id`=?',
            value.ownerId:lower()) == resource
    end
    return false
end

function EconomyAPI.ListAccountEntries(request, resource)
    local allowed = Authorize(resource, 'trustedReaders')
    if not allowed.ok then return allowed end
    request = type(request) == 'table' and request or {}
    local privileged = Config.Access.privilegedHistoryReaders
    if not (type(privileged) == 'table' and privileged[resource] == true) then
        local id = request.accountId
        if type(id) ~= 'string' or not id:match(
            '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') then
            return EconomyResults.Err('invalid_input', 'accountId must be a UUID.')
        end
        if not CanReadHistory(id, resource) then
            return EconomyResults.Err('authorization_denied', 'Calling resource may not read this account history.')
        end
    end
    return EconomyAccounts.ListEntries(request.accountId, request.limit, request.offset, request.before)
end

-- A transaction is readable by the resource that posted it and by privileged
-- history readers. Unknown and foreign transactions return the same not-found
-- answer so the reply does not reveal whether a transaction exists.
function EconomyAPI.GetTransaction(request, resource)
    local allowed = Authorize(resource, 'trustedReaders')
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or type(request.transactionId) ~= 'string' or not request.transactionId:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') then
        return EconomyResults.Err('invalid_input', 'transactionId must be a UUID.')
    end
    for key in pairs(request) do
        if key ~= 'transactionId' then
            return EconomyResults.Err('invalid_input', 'Unexpected transaction lookup field.')
        end
    end
    local transaction = EconomyJournal.GetTransaction(request.transactionId)
    local privileged = Config.Access.privilegedHistoryReaders
    if not transaction or (transaction.sourceResource ~= resource
        and not (type(privileged) == 'table' and privileged[resource] == true)) then
        return EconomyResults.Err('transaction_not_found', 'Economy transaction was not found.')
    end
    return EconomyResults.Ok(transaction)
end

function EconomyAPI.GetSystemAccount(request, resource)
    local allowed = Authorize(resource, 'trustedReaders')
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or type(request.currency) ~= 'string'
        or (request.accountType ~= 'system_source' and request.accountType ~= 'system_sink') then
        return EconomyResults.Err('invalid_input', 'Currency and system account type required.')
    end
    local accounts = EconomyAccounts.FindByOwner('system', Config.SystemOwnerId)
    if not accounts.ok then return accounts end
    for _, account in ipairs(accounts.value) do
        if account.currency == request.currency and account.accountType == request.accountType then
            return EconomyResults.Ok(account)
        end
    end
    return EconomyResults.Err('account_not_found', 'System account was not found.')
end

function EconomyAPI.EnsureOrganizationTreasuries(request, resource)
    local allowed = Authorize(resource, 'trustedTreasuryProvisioners')
    if not allowed.ok then return allowed end
    if EconomyFoundation.GetHealth().state ~= 'ready' then
        return EconomyResults.Err('not_ready', 'Economy is not ready.')
    end
    if type(request) ~= 'table' then
        return EconomyResults.Err('invalid_input', 'Organization UUID required.')
    end
    for key in pairs(request) do
        if key ~= 'organizationId' then
            return EconomyResults.Err('invalid_input', 'Unexpected treasury provisioning field.')
        end
    end
    local id = request.organizationId
    if type(id) ~= 'string' or not id:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') then
        return EconomyResults.Err('invalid_input', 'Organization UUID required.')
    end
    -- Resolve through the owning service, never through its database tables.
    -- No hard startup dependency: Organizations may start after Economy.
    id = id:lower()
    local called, organization = pcall(function()
        return exports['feather-organizations']:GetOrganization({ organizationId = id })
    end)
    if not called or type(organization) ~= 'table' or organization.ok ~= true
        or type(organization.value) ~= 'table' or organization.value.organizationId ~= id then
        return EconomyResults.Err('dependency_unavailable', 'Organization identity could not be verified.')
    end
    if organization.value.status ~= 'active' then
        return EconomyResults.Err('organization_inactive', 'Active organization required for treasury provisioning.')
    end
    return EconomyAccounts.EnsureOrganizationTreasuries(id)
end

-- Binds an active organization's treasuries to the calling resource. The first
-- operator to bind an organization keeps it permanently; only that resource may
-- then move those treasuries, and only with reason codes it registered
-- (RegisterOperatedReasons). Binding one another resource operates is rejected.
function EconomyAPI.EnsureOperatedTreasury(request, resource)
    local allowed = Authorize(resource, 'trustedTreasuryOperators')
    if not allowed.ok then return allowed end
    if EconomyFoundation.GetHealth().state ~= 'ready' then
        return EconomyResults.Err('not_ready', 'Economy is not ready.')
    end
    if type(request) ~= 'table' then
        return EconomyResults.Err('invalid_input', 'Organization UUID required.')
    end
    for key in pairs(request) do
        if key ~= 'organizationId' then
            return EconomyResults.Err('invalid_input', 'Unexpected operated treasury field.')
        end
    end
    local id = request.organizationId
    if type(id) ~= 'string' or not id:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') then
        return EconomyResults.Err('invalid_input', 'Organization UUID required.')
    end
    id = id:lower()
    local called, organization = pcall(function()
        return exports['feather-organizations']:GetOrganization({ organizationId = id })
    end)
    if not called or type(organization) ~= 'table' or organization.ok ~= true
        or type(organization.value) ~= 'table' or organization.value.organizationId ~= id then
        return EconomyResults.Err('dependency_unavailable', 'Organization identity could not be verified.')
    end
    if organization.value.status ~= 'active' then
        return EconomyResults.Err('organization_inactive', 'Active organization required for an operated treasury.')
    end
    DB.exec('INSERT IGNORE INTO `economy_treasury_operators` (`organization_id`,`operator_resource`) VALUES (?,?)',
        id, resource)
    local operator = DB.value('SELECT `operator_resource` FROM `economy_treasury_operators` WHERE `organization_id`=?', id)
    if operator ~= resource then
        return EconomyResults.Err('operator_conflict', 'That organization treasury is operated by another resource.')
    end
    return EconomyAccounts.EnsureOrganizationTreasuries(id)
end

-- Registers the caller's reason codes and the movement shapes each may use,
-- replacing what it registered before. Operators call this on every start.
function EconomyAPI.RegisterOperatedReasons(request, resource)
    return EconomyOperators.Register(resource, request)
end

function EconomyAPI.Transfer(request, context, resource)
    context = type(context) == 'table' and context or {}
    context.resource = resource
    return EconomyJournal.Transfer(request, context)
end

function EconomyAPI.ReversePayment(request, context, resource)
    local allowed = Authorize(resource, 'trustedReversers')
    if not allowed.ok then return allowed end
    context = type(context) == 'table' and context or {}
    context.resource = resource
    return EconomyJournal.ReversePayment(request, context)
end

local function CoreAuthorize(action, request)
    return exports['feather-core']:Authorize(action, request)
end

-- Issue and Destroy need an explicit Core policy allow while
-- Config.Authorization.enabled is true. No provider, a denial, an invalid
-- decision, or an error raised by the call all deny. `authorize` defaults to
-- Core; EconomyReleaseGateSmokeTest passes stand-ins for each failure mode.
local function SupplyAuthorization(operation,request,context,resource,authorize)
    if Config.Authorization.enabled == true then
        local action = operation == 'issue' and Config.Authorization.issueAction
            or Config.Authorization.destroyAction
        local subject = type(request) == 'table' and request or {}
        local called, decision = pcall(authorize or CoreAuthorize, action, {
            source = context.actorSource,
            correlationId = context.correlationId,
            -- resource lets the policy provider match a service grant for the caller.
            subject = { resource = resource, operation = operation, accountId = subject.accountId,
                currency = subject.currency, amount = subject.amount }
        })
        if not called or type(decision) ~= 'table' or decision.ok ~= true
            or type(decision.value) ~= 'table' or decision.value.allowed ~= true then
            local policyCode = 'invalid_decision'
            if not called then
                policyCode = 'policy_error'
            elseif type(decision) == 'table' and decision.ok == false then
                policyCode = decision.code or 'policy_error'
            elseif type(decision) == 'table' and type(decision.value) == 'table'
                and decision.value.allowed == false then
                policyCode = decision.value.code or 'denied'
            end
            return EconomyResults.Err('authorization_denied',
                'Currency supply operation is not authorized.', {
                    action = action, policyCode = tostring(policyCode)
                })
        end
    end
    return EconomyResults.Ok(true)
end
function EconomyAPI.Supply(operation,request,context,resource,authorize)
    context=type(context)=='table' and context or {};context.resource=resource
    local allowed=SupplyAuthorization(operation,request,context,resource,authorize)
    if not allowed.ok then return allowed end
    return operation=='issue' and EconomyJournal.Issue(request,context) or EconomyJournal.Destroy(request,context)
end
-- Same policy and account checks as a payout, with no currency/receipt writes.
function EconomyAPI.CheckIssue(request,context,resource,authorize)
    context=type(context)=='table' and context or {};context.resource=resource
    if type(request)~='table' or not EconomyJournal.MayPost('issue',resource,request.reasonCode)
        or type(request.amount)~='number' or request.amount<1 or request.amount%1~=0
        or request.amount>Config.Limits.maximumTransferAmount then return EconomyResults.Err('authorization_denied','Issue scope is unavailable.') end
    local allowed=SupplyAuthorization('issue',request,context,resource,authorize)
    if not allowed.ok then return allowed end
    local account=EconomyAPI.GetAccount({accountId=request.accountId},resource)
    if not account.ok or account.value.accountType~='wallet' or account.value.status~='open'
        or account.value.currency~=request.currency or account.value.ownerType~='character'
        or account.value.ownerId~=context.actorCharacterId then return EconomyResults.Err('account_unavailable','Payout wallet is unavailable.') end
    local source=EconomyAPI.GetSystemAccount({currency=request.currency,accountType='system_source'},resource)
    if not source.ok or source.value.status~='open' then return EconomyResults.Err('account_unavailable','System payout account is unavailable.') end
    return EconomyResults.Ok({allowed=true,sourceAccountId=source.value.accountId})
end
exports('CheckIssue',function(request,context) return EconomyAPI.CheckIssue(request,context,GetInvokingResource()) end)

function EconomyAPI.Issue(request, context, resource)
    return EconomyAPI.Supply('issue', request, context, resource)
end

function EconomyAPI.Destroy(request, context, resource)
    return EconomyAPI.Supply('destroy', request, context, resource)
end

exports('GetCapabilities', EconomyAPI.GetCapabilities)
exports('GetHealth', EconomyAPI.GetHealth)
exports('AwaitReady', EconomyAPI.AwaitReady)
exports('GetCurrency', EconomyAPI.GetCurrency)
exports('ListCurrencies', EconomyAPI.ListCurrencies)
exports('GetAccount', function(request)
    return EconomyAPI.GetAccount(request, GetInvokingResource())
end)
exports('FindAccountsByOwner', function(request)
    return EconomyAPI.FindAccountsByOwner(request, GetInvokingResource())
end)
exports('EnsureCharacterWallets', function(request)
    return EconomyAPI.EnsureCharacterWallets(request, GetInvokingResource())
end)
exports('EnsureOrganizationTreasuries', function(request)
    return EconomyAPI.EnsureOrganizationTreasuries(request, GetInvokingResource())
end)
exports('RegisterOperatedReasons', function(request)
    return EconomyAPI.RegisterOperatedReasons(request, GetInvokingResource())
end)
exports('EnsureOperatedTreasury', function(request)
    return EconomyAPI.EnsureOperatedTreasury(request, GetInvokingResource())
end)
exports('EnsureCharacterBankAccounts', function(request)
    return EconomyAPI.EnsureCharacterBankAccounts(request, GetInvokingResource())
end)
exports('ListAccountEntries', function(request)
    return EconomyAPI.ListAccountEntries(request, GetInvokingResource())
end)
exports('GetTransaction', function(request)
    return EconomyAPI.GetTransaction(request, GetInvokingResource())
end)
exports('GetSystemAccount', function(request)
    return EconomyAPI.GetSystemAccount(request, GetInvokingResource())
end)
exports('Transfer', function(request, context)
    return EconomyAPI.Transfer(request, context, GetInvokingResource())
end)
exports('ReversePayment', function(request, context)
    return EconomyAPI.ReversePayment(request, context, GetInvokingResource())
end)
exports('Issue', function(request, context)
    return EconomyAPI.Issue(request, context, GetInvokingResource())
end)
exports('Destroy', function(request, context)
    return EconomyAPI.Destroy(request, context, GetInvokingResource())
end)

exports('initiate', function()
    return {
        GetCapabilities = EconomyAPI.GetCapabilities,
        GetHealth = EconomyAPI.GetHealth,
        AwaitReady = EconomyAPI.AwaitReady,
        Currencies = {
            Get = EconomyAPI.GetCurrency,
            List = EconomyAPI.ListCurrencies
        }
    }
end)
