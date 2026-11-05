-- Isolated Cfx environment. Production modules receive no real file/network/process APIs.
local Harness = {}
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}; for key, item in pairs(value) do result[key] = copy(item) end; return result
end
Harness.copy = copy

function Harness.new(codec)
    local h = { now = 1700000000, ms = 0, files = {}, timers = {}, requests = {}, logs = {},
        commands = {}, threads = {}, events = {}, writes = {}, writeFailures = {}, readFailures = {}, versions = {} }
    local env = { assert = assert, error = error, ipairs = ipairs, pairs = pairs, next = next,
        pcall = pcall, tonumber = tonumber, tostring = tostring, type = type, select = select,
        rawget = rawget, load = load, coroutine = coroutine,
        math = copy(math), string = copy(string), table = copy(table), os = {} }
    env._G = env
    env.os.time = function() return h.now end
    env.print = function(...) local values = {...}; for i, v in ipairs(values) do values[i] = tostring(v) end; h.logs[#h.logs + 1] = table.concat(values, '\t') end
    -- Deliberately mocked codec: opaque tokens represent decoded JSON fixtures.
    -- This tests malformed/oversized input handling and persistence semantics,
    -- not Cfx's JSON implementation. Each decode returns a fresh value.
    local objects, sequence = {}, 0
    env.json = {
        encode = function(value)
            if h.encodeFails then error('fixture encode failure') end
            sequence = sequence + 1
            local token = 'json-fixture-' .. sequence
            if h.encodeOversized then token = token .. string.rep('x', env.Config.MaxResponseBytes) end
            objects[token] = copy(value)
            return token
        end,
        decode = function(raw)
            if not objects[raw] then error('malformed JSON fixture') end
            return copy(objects[raw])
        end
    }
    if codec then env.json = codec end
    env.GetCurrentResourceName = function() return 'feather-versioner' end
    env.LoadResourceFile = function(resource, path)
        assert(resource == 'feather-versioner', 'cross-resource read')
        if h.readFailures[path] then error('fixture read failure') end
        return h.files[path]
    end
    env.SaveResourceFile = function(resource, path, raw, length)
        assert(resource == 'feather-versioner', 'cross-resource write')
        assert(path == env.Config.CacheFile or path == env.Config.CacheFile .. '.bak', 'non-cache write')
        assert(length == #raw)
        h.writes[#h.writes + 1] = path
        if h.writeFailures[path] == 'throw' then error('fixture write failure') end
        if h.writeFailures[path] then return false end
        h.files[path] = h.partialWrite and raw:sub(1, #raw - 1) or raw
        if h.numericWriteResult then return 1 end
        return true
    end
    env.SetTimeout = function(delay, callback) h.timers[#h.timers + 1] = { at = h.ms + delay, callback = callback } end
    env.GetGameTimer = function() return h.ms end
    env.PerformHttpRequest = function(url, callback, method, body, headers)
        assert(url:match('^https://api%.github%.com/repos/'), 'unexpected outbound host')
        assert(method == 'GET' and body == '')
        h.requests[#h.requests + 1] = { url = url, callback = callback, headers = headers }
    end
    env.GetResourceState = function(name) return h.versions[name] and 'started' or 'missing' end
    env.GetResourceMetadata = function(name) return h.versions[name] end
    env.GetNumResourceMetadata = function() return 0 end
    env.RegisterCommand = function(name, callback, restricted) assert(restricted == true); h.commands[name] = callback end
    env.AddEventHandler = function(name, callback) h.events[name] = callback end
    env.CreateThread = function(callback) h.threads[#h.threads + 1] = coroutine.create(callback) end
    env.Wait = function(delay) coroutine.yield(delay) end
    -- Unsupported Cfx APIs (including lifecycle mutation) are absent and fail if called.
    h.env = env
    function h:load(path) assert(loadfile(path, 't', env))() end
    if codec then
        -- Cfx acceptance must not depend on or rewrite operator policies.
        env.Config = {
            Enabled = true, CheckOnStart = true, StartupDelaySeconds = 15, IntervalMinutes = 720,
            ResponseDeadlineSeconds = 15, CacheTtlMinutes = 120, ManualRefreshCooldownSeconds = 60,
            MaxBackoffMinutes = 240, JitterPercent = 10, MaxConcurrentRequests = 2,
            MaxResponseBytes = 1048576, MaxReleases = 50, MaxReleaseTitleBytes = 160,
            ReportCurrent = false, ReportSummary = true, ConsoleColors = false,
            IncludeReleaseTitle = true, ReportNewerThanPin = false, AllowManifestDiscovery = false,
            AllowedOwners = { 'FeatherFramework' }, CacheFile = 'versioner-cache.json', Resources = {}
        }
    else
        h:load('config.lua')
    end
    for _, path in ipairs({ 'shared/results.lua', 'server/sanitize.lua', 'server/semver.lua', 'server/config.lua',
        'server/registry.lua', 'server/cache.lua', 'server/github.lua', 'server/reporter.lua', 'server/scheduler.lua', 'server/commands.lua' }) do h:load(path) end
    env.Config.Resources = { alpha = { repository = 'FeatherFramework/example' } }
    h.versions.alpha = '1.0.0'
    env.Config.ConsoleColors = false
    assert(env.VersionerConfig.Validate().ok)
    function h:advance(ms)
        local target = self.ms + ms
        while true do
            local selected, at
            for i, timer in ipairs(self.timers) do if timer.at <= target and (not at or timer.at < at) then selected, at = i, timer.at end end
            if not selected then break end
            local timer = table.remove(self.timers, selected)
            self.now = self.now + (at - self.ms) / 1000; self.ms = at
            timer.callback()
        end
        self.now = self.now + (target - self.ms) / 1000; self.ms = target
    end
    function h:respond(index, status, body, headers)
        self.requests[index].callback(status, body or '', headers or {}, 'fixture transport detail')
    end
    function h:release(version)
        return { tag = 'v' .. version, version = version, title = 'Release',
            url = 'https://github.com/FeatherFramework/example/releases/tag/v' .. version, prerelease = false }
    end
    function h:entry(version)
        return { repository = 'FeatherFramework/example', fetchedAt = self.now - 120, expiresAt = self.now - 60,
            etag = '"fixture"', releases = { self:release(version or '2.0.0') } }
    end
    function h:snapshot(entry)
        return { schema = 1, writtenAt = self.now, entries = { ['featherframework/example'] = entry or self:entry() } }
    end
    function h:body(version)
        local r = self:release(version or '2.0.0')
        return env.json.encode({ { tag_name = r.tag, html_url = r.url, name = r.title, prerelease = r.prerelease, draft = false } })
    end
    return h
end
return Harness
