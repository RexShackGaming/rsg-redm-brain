MedicalWorker = {}

-- Bounded scan includes offline characters. Advance uses the condition row lock.
function MedicalWorker.Tick(now, repository, newId)
    local failures, advanced = 0, 0
    local due = repository.Due(now) or {}
    for _, row in ipairs(due) do
        local ok = pcall(function()
            -- Generate once outside transaction retries. After uncertain commit,
            -- the next scan reads stored state instead of assuming rollback.
            local record = repository.Advance(row.character_id, now, newId())
            if record and record.lifeState == 'dead' then advanced = advanced + 1 end
        end)
        if not ok then failures = failures + 1 end
    end
    return {scanned = #due, advanced = advanced, failures = failures}
end
return MedicalWorker
