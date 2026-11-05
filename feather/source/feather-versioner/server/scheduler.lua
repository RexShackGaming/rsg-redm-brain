VersionerScheduler = { generation = 0, running = false, stopped = false, lastManualAt = 0, failures = {}, nextAllowedAt = {} }

local function repositoryHasInstalledResources(repository)
    for _, name in ipairs(repository.resources) do local entry = VersionerRegistry.Get(name); if entry and entry.installed then return true end end
    return false
end

local function applyRepository(repository, cache, stale)
    for _, name in ipairs(repository.resources) do
        local entry = VersionerRegistry.Get(name)
        if entry and entry.installed then VersionerReporter.Evaluate(entry, cache, stale) end
    end
end

local function failRepository(repository, failure)
    local stale = VersionerCache.Get(repository.key)
    for _, name in ipairs(repository.resources) do
        local entry = VersionerRegistry.Get(name)
        if entry and entry.installed then VersionerReporter.Error(entry, failure, stale) end
    end
end

function VersionerScheduler.Run(reason, callback)
    if Config.Enabled ~= true then return VersionerResults.Err('disabled', 'Versioner is disabled by operator configuration.') end
    if VersionerScheduler.stopped then return VersionerResults.Err('stopped', 'Versioner is stopping.') end
    if VersionerScheduler.running then return VersionerResults.Err('in_flight', 'A version check is already running.') end
    VersionerScheduler.running = true
    VersionerScheduler.generation = VersionerScheduler.generation + 1
    local generation, startedAt = VersionerScheduler.generation, GetGameTimer()
    local built = VersionerRegistry.Build()
    if not built.ok then VersionerScheduler.running = false; return built end
    local queue, pending, completed, finished = {}, 0, 0, false
    for _, repository in pairs(VersionerRegistry.repositories) do
        if repositoryHasInstalledResources(repository) then
            local cached = VersionerCache.Get(repository.key)
            if reason ~= 'manual' and VersionerCache.IsFresh(cached) then applyRepository(repository, cached, false)
            elseif (VersionerScheduler.nextAllowedAt[repository.key] or 0) > os.time() then failRepository(repository, VersionerResults.Err('backoff', 'Repository is waiting for its retry window.'))
            else queue[#queue + 1] = repository end
        end
    end
    local index = 1
    local function finishIfDone()
        if finished then return end
        if pending > 0 or index <= #queue then return end
        if generation ~= VersionerScheduler.generation then return end
        finished = true
        VersionerScheduler.running = false
        if VersionerCache.dirty then local saved = VersionerCache.Save(); if not saved.ok then print(('[feather-versioner] cache warning: %s'):format(saved.message)) end end
        print(('[feather-versioner] check cycle complete reason=%s repositories=%d durationMs=%d'):format(reason, completed, GetGameTimer() - startedAt))
        if callback then callback(VersionerResults.Ok({ generation = generation, entries = VersionerRegistry.entries })) end
    end
    local pump
    pump = function()
        if generation ~= VersionerScheduler.generation then return end
        while pending < Config.MaxConcurrentRequests and index <= #queue do
            local repository = queue[index]; index = index + 1; pending = pending + 1
            VersionerGithub.Fetch(repository, generation, function(result)
                if generation ~= VersionerScheduler.generation then return end
                pending, completed = pending - 1, completed + 1
                if result.ok then
                    VersionerScheduler.failures[repository.key], VersionerScheduler.nextAllowedAt[repository.key] = 0, 0
                    applyRepository(repository, result.value.cache, false)
                else
                    local failures = (VersionerScheduler.failures[repository.key] or 0) + 1
                    VersionerScheduler.failures[repository.key] = failures
                    local delay = math.min(Config.MaxBackoffMinutes * 60, 30 * (2 ^ math.min(failures - 1, 10)))
                    local reset = result.details and tonumber(result.details.reset)
                    if result.code == 'rate_limited' and reset and reset == reset and reset < math.huge then
                        delay = math.min(Config.MaxBackoffMinutes * 60, math.max(delay, reset - os.time()))
                    end
                    VersionerScheduler.nextAllowedAt[repository.key] = os.time() + math.max(1, delay)
                    failRepository(repository, result)
                end
                pump(); finishIfDone()
            end)
        end
        finishIfDone()
    end
    pump()
    return VersionerResults.Ok({ generation = generation, queued = #queue })
end

function VersionerScheduler.Manual(callback)
    if Config.Enabled ~= true then return VersionerResults.Err('disabled', 'Versioner is disabled by operator configuration.') end
    local now = os.time()
    if now - VersionerScheduler.lastManualAt < Config.ManualRefreshCooldownSeconds then
        return VersionerResults.Err('cooldown', 'Manual refresh is cooling down.', { remaining = Config.ManualRefreshCooldownSeconds - (now - VersionerScheduler.lastManualAt) })
    end
    local result = VersionerScheduler.Run('manual', callback)
    if result.ok then VersionerScheduler.lastManualAt = now end
    return result
end

function VersionerScheduler.Start()
    if not Config.Enabled then print('[feather-versioner] disabled by operator configuration'); return end
    if Config.CheckOnStart then SetTimeout(math.floor(Config.StartupDelaySeconds * 1000), function() if not VersionerScheduler.stopped then VersionerScheduler.Run('startup', function() VersionerReporter.Print(VersionerRegistry.entries) end) end end) end
    CreateThread(function()
        while not VersionerScheduler.stopped do
            local base = Config.IntervalMinutes * 60 * 1000
            local jitter = math.floor(base * (Config.JitterPercent / 100) * ((math.random() * 2) - 1))
            Wait(math.max(60000, base + jitter))
            if not VersionerScheduler.stopped and not VersionerScheduler.running then VersionerScheduler.Run('interval', function() VersionerReporter.Print(VersionerRegistry.entries) end) end
        end
    end)
end

function VersionerScheduler.Stop()
    VersionerScheduler.stopped = true
    VersionerScheduler.generation = VersionerScheduler.generation + 1
    VersionerScheduler.running = false
    if VersionerCache.dirty then
        local saved = VersionerCache.Save()
        if not saved.ok then print(('[feather-versioner] cache warning on stop: %s'):format(saved.message)) end
    end
end
