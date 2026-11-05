ContractsValidation = {}

local Err = ContractsResults.Err

function ContractsValidation.Uuid(value)
    return type(value) == 'string' and #value == 36
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

function ContractsValidation.Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

function ContractsValidation.Key(value, maximum)
    return type(value) == 'string' and #value <= maximum
        and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

function ContractsValidation.Code(value, maximum)
    return type(value) == 'string' and #value <= maximum
        and value:match('^[a-z][a-z0-9._:%-]*$') ~= nil
end

function ContractsValidation.Text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and not value:find('%c') and value:find('%S') ~= nil
end

function ContractsValidation.RequestId(value, maximum)
    return type(value) == 'string' and #value <= maximum
        and value:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end

-- Rejects any field not named in `allowed`, so callers cannot smuggle state.
function ContractsValidation.Fields(request, allowed, label)
    if type(request) ~= 'table' then
        return Err('invalid_input', ('%s request required.'):format(label))
    end
    for field in pairs(request) do
        if type(field) ~= 'string' or not allowed[field] then
            return Err('invalid_input', ('Unexpected %s field.'):format(label), { field = tostring(field) })
        end
    end
    return ContractsResults.Ok(true)
end

-- Length-prefixed so free text containing delimiters cannot collide.
function ContractsValidation.Fingerprint(values)
    local parts = {}
    for index = 1, #values do
        local value = values[index]
        value = value == nil and '' or tostring(value)
        parts[#parts + 1] = tostring(#value) .. ':' .. value
    end
    return table.concat(parts, '|')
end

function ContractsValidation.Lower(value)
    return type(value) == 'string' and value:lower() or value
end

-- Runs body(tx) in one database transaction. The body returns a result
-- envelope; only an ok envelope commits. A commit that cannot be confirmed is
-- reported as transaction_failed so callers retry with the same request ID.
function ContractsValidation.Transaction(label, body)
    local result, failure
    local called, committed = pcall(DB.transaction, function(tx)
        -- DB.transaction re-runs this callback after a retryable deadlock.
        result, failure = nil, nil
        local executed, outcome = xpcall(body, debug.traceback, tx)
        if not executed then
            failure = tostring(outcome)
            return false
        end
        result = outcome
        return ContractsResults.Is(outcome) and outcome.ok == true
    end)
    if failure then
        print(('[feather-contracts] level=error component=transaction event=%s.failed reason=%s')
            :format(label, failure))
        return Err('internal_error', 'Contracts transaction failed.')
    end
    if not called then
        if ContractsResults.Is(result) and not result.ok then return result end
        return Err('transaction_failed', 'Contracts transaction did not commit. Retry the same request ID.',
            { reason = tostring(type(committed) == 'table' and committed.code or committed) })
    end
    if not ContractsResults.Is(result) then
        return Err('internal_error', 'Contracts transaction returned an invalid result.')
    end
    if result.ok and committed ~= true then
        return Err('transaction_failed', 'Contracts transaction did not confirm commit. Retry the same request ID.')
    end
    return result
end

function ContractsValidation.NewUuid(tx)
    local value = tx.value('SELECT UUID()')
    if not ContractsValidation.Uuid(value) then error('Could not generate a UUID.') end
    return value:lower()
end
