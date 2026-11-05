ContractsAPI = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local logger = ContractsLogging.Create('api')

-- Exceptions are programming faults: log them and return a safe envelope.
local function Boundary(label, operation, ...)
    local arguments = table.pack(...)
    local called, result = xpcall(function()
        return operation(table.unpack(arguments, 1, arguments.n))
    end, debug.traceback)
    if not called then
        logger.Error('operation.crashed', { operation = label, reason = tostring(result) })
        return Err('internal_error', 'Contracts operation failed.')
    end
    if not ContractsResults.Is(result) then
        logger.Error('operation.invalid_result', { operation = label })
        return Err('internal_error', 'Contracts operation returned an invalid result.')
    end
    return result
end

-- Debtor actions: a character debtor is named by context.actorSource; an
-- organization debtor acts as the calling resource (its treasury operator).
local function DebtorContext(context, resource)
    return ContractsObligations.ServerContext(resource, context)
end

function ContractsAPI.GetCapabilities() return ContractsFoundation.GetCapabilities() end
function ContractsAPI.GetHealth() return Ok(ContractsFoundation.GetHealth()) end
function ContractsAPI.AwaitReady(timeoutMs) return ContractsFoundation.AwaitReady(timeoutMs) end

function ContractsAPI.RegisterObligationType(definition, resource)
    return ContractsTypes.Register(definition, resource)
end

function ContractsAPI.GetObligationType(request)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    return ContractsTypes.Get(request)
end

function ContractsAPI.AcceptObligation(request, context, resource)
    local built = DebtorContext(context, resource)
    if not built.ok then return built end
    return ContractsObligations.AcceptObligation(request, built.value, resource, false)
end

function ContractsAPI.DisputeObligation(request, context, resource)
    local built = DebtorContext(context, resource)
    if not built.ok then return built end
    return ContractsObligations.DisputeObligation(request, built.value, resource, false)
end

function ContractsAPI.SettleObligation(request, context, resource)
    local built = ContractsObligations.ServerContext(resource, context)
    if not built.ok then return built end
    return ContractsSettlement.SettleObligation(request, built.value, resource, false)
end

exports('GetCapabilities', function()
    return Boundary('GetCapabilities', ContractsAPI.GetCapabilities)
end)
exports('GetHealth', function()
    return Boundary('GetHealth', ContractsAPI.GetHealth)
end)
exports('AwaitReady', function(timeoutMs)
    return Boundary('AwaitReady', ContractsAPI.AwaitReady, timeoutMs)
end)
exports('RegisterObligationType', function(definition)
    return Boundary('RegisterObligationType', ContractsAPI.RegisterObligationType, definition, GetInvokingResource())
end)
exports('GetObligationType', function(request)
    return Boundary('GetObligationType', ContractsAPI.GetObligationType, request)
end)
exports('CreateDraft', function(request, context)
    return Boundary('CreateDraft', ContractsObligations.CreateDraft, request, context, GetInvokingResource())
end)
exports('IssueObligation', function(request, context)
    return Boundary('IssueObligation', ContractsObligations.IssueObligation, request, context, GetInvokingResource())
end)
exports('AcceptObligation', function(request, context)
    return Boundary('AcceptObligation', ContractsAPI.AcceptObligation, request, context, GetInvokingResource())
end)
exports('GetObligation', function(request)
    return Boundary('GetObligation', ContractsObligations.GetObligation, request, GetInvokingResource())
end)
exports('ListPartyObligations', function(request)
    return Boundary('ListPartyObligations', ContractsObligations.ListPartyObligations, request, GetInvokingResource())
end)
exports('SettleObligation', function(request, context)
    return Boundary('SettleObligation', ContractsAPI.SettleObligation, request, context, GetInvokingResource())
end)
exports('CancelObligation', function(request, context)
    return Boundary('CancelObligation', ContractsObligations.CancelObligation, request, context, GetInvokingResource())
end)
exports('DisputeObligation', function(request, context)
    return Boundary('DisputeObligation', ContractsAPI.DisputeObligation, request, context, GetInvokingResource())
end)
exports('ResolveDispute', function(request, context)
    return Boundary('ResolveDispute', ContractsObligations.ResolveDispute, request, context, GetInvokingResource())
end)
exports('MarkDefaulted', function(request, context)
    return Boundary('MarkDefaulted', ContractsObligations.MarkDefaulted, request, context, GetInvokingResource())
end)
exports('ReconcileSettlements', function()
    return Boundary('ReconcileSettlements', ContractsSettlement.Reconcile, GetInvokingResource())
end)
