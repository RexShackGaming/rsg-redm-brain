LicenseExpiry = {}
local running = false

-- Publishes licenses.license.expired.v1 once per license and expiry time. It
-- changes no state that validity depends on: every read already compares
-- expiresAt with the database clock. A renewal clears expiry_notified_at, so a
-- renewed license that expires again is reported again.
function LicenseExpiry.Sweep()
    local rows = DB.query([[
        SELECT `license_id`,`license_key`,`holder_type`,`holder_id`,`status`,`expires_at_ms`,`revision`
        FROM `feather_licenses`
        WHERE `expiry_notified_at` IS NULL AND `status`<>'revoked'
            AND `expires_at_ms` IS NOT NULL AND `expires_at_ms`<=UNIX_TIMESTAMP()*1000
        ORDER BY `expires_at_ms` LIMIT ?]], Config.Expiry.batchSize) or {}
    local published = 0
    for _, row in ipairs(rows) do
        local expiresAt = math.floor(tonumber(row.expires_at_ms))
        local called, committed = pcall(DB.transaction, function(tx)
            -- Re-checked under the row lock: a renewal or revocation in between wins.
            local updated = tx.exec([[
                UPDATE `feather_licenses` SET `expiry_notified_at`=CURRENT_TIMESTAMP
                WHERE `license_id`=? AND `expiry_notified_at` IS NULL AND `status`<>'revoked'
                    AND `expires_at_ms`=?]], row.license_id, expiresAt)
            if tonumber(updated) ~= 1 then
                return false
            end
            LicenseEvents.Record(tx, 'license.expired', {
                aggregateType = 'license',
                aggregateId = row.license_id,
                licenseId = row.license_id,
                licenseKey = row.license_key,
                holderType = row.holder_type,
                holderId = row.holder_id,
                resource = GetCurrentResourceName(),
                requestId = ('expiry:%s:%d'):format(row.license_id, expiresAt),
                reasonCode = 'licenses.expired',
                revision = tonumber(row.revision),
                details = {
                    status = row.status,
                    expiresAt = expiresAt
                }
            })
            return true
        end)
        if called and committed == true then
            published = published + 1
        elseif not called then
            print(('[feather-licenses] event=expiry.failed id=%s reason=%s'):format(row.license_id, tostring(committed)))
        end
    end
    return published
end

function LicenseExpiry.Start()
    if running then
        return
    end
    running = true
    CreateThread(function()
        while running do
            Wait(Config.Expiry.sweepIntervalMs)
            if running and Licenses.IsReady() then
                local called, reason = pcall(LicenseExpiry.Sweep)
                if not called then
                    print('[feather-licenses] event=expiry.error ' .. tostring(reason))
                end
            end
        end
    end)
end

function LicenseExpiry.Stop()
    running = false
end
