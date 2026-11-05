-- Recovery consumes stored acceptance, not a player source or an expired quote.
-- No new orders, payment intents, or compensation requests are created here.
local running, attempted, completed, failed = false, 0, 0, 0
local testPaused=false
local config = Config.Reconciliation
local valid = type(config) == 'table' and type(config.enabled) == 'boolean'
    and ShopService.Integer(config.pollIntervalMs, 1000, 60000)
    and ShopService.Integer(config.retryDelaySeconds, 5, 3600)
    and ShopService.Integer(config.batchSize, 1, 50)
CreateThread(function()
    if not valid then print('[feather-shops] event=reconciliation.invalid_config'); return end
    if not config.enabled then return end
    running = true
    while true do
        Wait(config.pollIntervalMs)
        if ShopService.IsReady() and not testPaused then
            local called, errorText = xpcall(function()
                local rows = DB.query([[SELECT e.`order_id`,c.`state` AS compensation_state
                    FROM `shop_order_executions` e
                    LEFT JOIN `shop_order_compensations` c ON c.`order_id`=e.`order_id`
                    WHERE (c.`state` IN ('cancellation_pending','refund_pending')
                        OR (e.`state` IN ('payment_pending','paid') AND
                            (c.`state` IS NULL OR c.`state`='delivery_committed')))
                    AND COALESCE(c.`updated_at`,e.`updated_at`) <= TIMESTAMPADD(SECOND, -?, CURRENT_TIMESTAMP)
                    ORDER BY COALESCE(c.`updated_at`,e.`updated_at`),e.`order_id` LIMIT ?]],
                    config.retryDelaySeconds, config.batchSize) or {}
                for _, row in ipairs(rows) do
                    if testPaused then break end
                    local refund = row.compensation_state == 'cancellation_pending' or row.compensation_state == 'refund_pending'
                    -- Advance attempt time even if the dependency returns the same
                    -- error again, keeping persistent failures from starving others.
                    DB.exec(row.compensation_state ~= nil
                        and 'UPDATE `shop_order_compensations` SET `updated_at`=CURRENT_TIMESTAMP WHERE `order_id`=?'
                        or 'UPDATE `shop_order_executions` SET `updated_at`=CURRENT_TIMESTAMP WHERE `order_id`=?', row.order_id)
                    attempted = attempted + 1
                    local result = refund and ShopPurchases.RecoverCompensation(row.order_id)
                        or ShopPurchases.RecoverPurchase(row.order_id)
                    if result.ok then completed = completed + 1 else failed = failed + 1 end
                    print(('[feather-shops] event=reconciliation.attempt order=%s workflow=%s ok=%s code=%s'):format(
                        row.order_id, refund and 'refund' or 'purchase', tostring(result.ok), tostring(result.code)))
                end
            end, debug.traceback)
            if not called then print('[feather-shops] event=reconciliation.failed ' .. tostring(errorText)) end
        end
    end
end)
ShopService.RegisterDevCommand('ShopReconciliationTestControl',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if #args~=1 or (args[1]~='pause' and args[1]~='resume') then
        print('[ShopReconciliationTestControl] FAIL use pause|resume');return
    end
    testPaused=args[1]=='pause'
    print(('[ShopReconciliationTestControl] PASS paused=%s; resume or restart feather-shops after testing'):format(tostring(testPaused)))
end,true)
RegisterCommand('ShopReconciliationState', function(source)
    if source ~= 0 then return end
    print('[ShopReconciliationState] ' .. json.encode({ enabled = valid and config.enabled or false,
        running = running, paused = testPaused, ready = ShopService.IsReady(), attempted = attempted, completed = completed, failed = failed }))
end, true)
