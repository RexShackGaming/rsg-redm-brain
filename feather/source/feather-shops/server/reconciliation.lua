-- Automatic receipt readback only. Never repeat a payment or item mutation.
local attempted,resolved,failed=0,0,0
CreateThread(function()
    while true do
        Wait(Config.Reconciliation.pollIntervalMs)
        if ShopService.IsReady() then
            local called=pcall(function()
                local rows=DB.query([[SELECT order_id FROM shop_checkout_attempts
                    WHERE state='pending' AND updated_at<=TIMESTAMPADD(SECOND,-?,CURRENT_TIMESTAMP)
                    ORDER BY updated_at,order_id LIMIT ?]],Config.Reconciliation.retryDelaySeconds,Config.Reconciliation.batchSize) or {}
                for _,row in ipairs(rows) do
                    if not ShopPurchases.IsActive(row.order_id) then
                        -- Advancing the polling index prevents one unavailable
                        -- receipt from starving the rest of this bounded queue.
                        DB.exec("UPDATE shop_checkout_attempts SET updated_at=CURRENT_TIMESTAMP WHERE order_id=? AND state='pending'",row.order_id)
                        attempted=attempted+1
                        local result=ShopPurchases.RecoverPurchase(row.order_id)
                        if result.ok or (result.details and result.details.safeToClear) then resolved=resolved+1 else failed=failed+1 end
                    end
                end
            end)
            if not called then failed=failed+1 end
        end
    end
end)
RegisterCommand('ShopReconciliationState',function(source)
    if source~=0 then return end
    local called,row=pcall(DB.one,[[SELECT COUNT(*) AS pending,
        COALESCE(MAX(TIMESTAMPDIFF(SECOND,created_at,CURRENT_TIMESTAMP)),0) AS oldest
        FROM shop_checkout_attempts WHERE state='pending']])
    local pending=called and row and tonumber(row.pending) or nil
    local healthy=pending==0
    print('[ShopReconciliationState] '..json.encode({state=healthy and 'healthy' or 'recovering',
        message=healthy and 'Checkout recovery is healthy. No action is needed.'
            or 'Checkout requests are awaiting automatic readback. Keep their receipts unchanged.',
        pending=pending,oldestSeconds=called and row and tonumber(row.oldest) or nil,
        automaticMutationRetries=0,attempted=attempted,resolved=resolved,failed=failed}))
end,true)
