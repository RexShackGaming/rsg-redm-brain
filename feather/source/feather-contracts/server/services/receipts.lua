ContractsReceipts = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err

-- Reserves (resource, operation, requestId) inside the caller's transaction.
-- Returns Ok({ replay = storedValue }) for a completed identical request,
-- Ok({ fresh = true }) for a new one, or idempotency_conflict when the key is
-- bound to a different payload.
function ContractsReceipts.Reserve(tx, resource, operation, requestId, fingerprint)
    tx.exec([[INSERT IGNORE INTO `contract_receipts`
        (`source_resource`,`operation`,`request_id`,`request_fingerprint`) VALUES (?,?,?,?)]],
        resource, operation, requestId, fingerprint)
    local receipt = tx.one([[SELECT `request_fingerprint`,`result_json` FROM `contract_receipts`
        WHERE `source_resource`=? AND `operation`=? AND `request_id`=? FOR UPDATE]],
        resource, operation, requestId)
    if not receipt then return Err('internal_error', 'Request receipt could not be reserved.') end
    if receipt.request_fingerprint ~= fingerprint then
        return Err('idempotency_conflict', 'Request ID was already used for a different request.')
    end
    if receipt.result_json then
        local decoded, value = pcall(json.decode, receipt.result_json)
        if not decoded or type(value) ~= 'table' then
            return Err('invalid_persistence', 'Stored request receipt is invalid.')
        end
        value.replayed = true
        return Ok({ replay = value })
    end
    return Ok({ fresh = true })
end

function ContractsReceipts.Complete(tx, resource, operation, requestId, value)
    tx.exec([[UPDATE `contract_receipts` SET `result_json`=?
        WHERE `source_resource`=? AND `operation`=? AND `request_id`=?]],
        json.encode(value), resource, operation, requestId)
end
