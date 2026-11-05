FeatherAuditRateLimit = {}

local buckets = {}

function FeatherAuditRateLimit.Allow(sourceResource, maximum, now)
    now = now or os.time()
    local minute = math.floor(now / 60)
    local bucket = buckets[sourceResource]
    if not bucket or bucket.minute ~= minute then
        bucket = { minute = minute, count = 0 }
        buckets[sourceResource] = bucket
    end
    if bucket.count >= maximum then return false end
    bucket.count = bucket.count + 1
    return true
end
