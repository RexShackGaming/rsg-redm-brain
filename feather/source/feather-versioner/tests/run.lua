-- Run from feather-versioner: lua tests/run.lua (Lua 5.4).
local H = dofile('tests/harness.lua')
local tests, passed = {}, 0
local function test(name, callback) tests[#tests + 1] = { name, callback } end
local function eq(actual, expected) assert(actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual))) end
local key = 'featherframework/example'
local function configure(h, resources)
    h.env.Config.Resources = resources
    assert(h.env.VersionerConfig.Validate().ok)
end

test('SemVer precedence, normalization, large numbers, invalid identifiers', function()
    local s = H.new().env.VersionerSemver
    local chain = { '1.0.0-alpha', '1.0.0-alpha.1', '1.0.0-alpha.beta', '1.0.0-beta', '1.0.0-beta.2',
        '1.0.0-beta.11', '1.0.0-rc.1', '1.0.0', '1.9.0', '1.10.0', '2.0.0' }
    for i = 2, #chain do eq(s.Compare(chain[i-1], chain[i]).value, -1); eq(s.Compare(chain[i], chain[i-1]).value, 1) end
    eq(s.Compare('v1.2.3+local.1', '1.2.3+other').value, 0)
    eq(s.Compare('999999999999999999999.0.0', '999999999999999999998.0.0').value, 1)
    for _, v in ipairs({ '1.2', '01.2.3', '1.2.3-01', '1.2.3-', '1.2.3+', '1.2.3+a..b', '1.2.3+.a', '1.2.3+a.', string.rep('1', 129) }) do assert(not s.Parse(v).ok, v) end
end)

test('owner allowlist, repository/URL bounds, sanitizer and config types', function()
    local h, invalid = H.new(), { '../bad/repo', 'a/b/extra', 'https://github.com/a/b', 'a/..', string.rep('a', 101) .. '/b' }
    local e = h.env
    for _, value in ipairs(invalid) do assert(not e.VersionerSanitize.Repository(value).ok) end
    for _, url in ipairs({ 'https://evil.example/releases/tag/v1', 'https://github.com/FeatherFramework/other/releases/tag/v1',
        'https://github.com/FeatherFramework/example/releases/../x', 'https://github.com/FeatherFramework/example/releases/tag/v1?token=secret' }) do assert(not e.VersionerSanitize.ReleaseUrl(url, 'FeatherFramework/example')) end
    eq(e.VersionerSanitize.Text('\27[31m^1Hello\nWorld\27[0m', 100), 'Hello World')
    eq(#e.VersionerSanitize.Text(string.rep('a', 200), 10), 10)
    e.Config.Resources.alpha.repository = 'Other/example'; eq(e.VersionerConfig.Validate().code, 'owner_not_allowed')
    e.Config.Resources.alpha.repository = 'FeatherFramework/example'
    for _, value in ipairs({ 0/0, math.huge, -math.huge, 1.5 }) do e.Config.MaxConcurrentRequests = value; assert(not e.VersionerConfig.Validate().ok) end
    e.Config.MaxConcurrentRequests = 2
    e.Config.Enabled = 'false'; assert(not e.VersionerConfig.Validate().ok); e.Config.Enabled = true
    e.Config.Resources.alpha.enabled = 'false'; assert(not e.VersionerConfig.Validate().ok); e.Config.Resources.alpha.enabled = nil
    e.Config.AllowManifestDiscovery = true; eq(e.VersionerConfig.Validate().code, 'unsupported_config')
end)

for _, kind in ipairs({ 'missing', 'empty', 'oversized', 'malformed', 'schema', 'timestamp', 'read error' }) do
    test('backup fallback for ' .. kind .. ' primary', function()
        local h = H.new(); local e, path = h.env, h.env.Config.CacheFile
        h.files[path .. '.bak'] = e.json.encode(h:snapshot())
        if kind == 'empty' then h.files[path] = ''
        elseif kind == 'oversized' then h.files[path] = string.rep('x', e.Config.MaxResponseBytes + 1)
        elseif kind == 'malformed' then h.files[path] = '{broken'
        elseif kind == 'read error' then h.readFailures[path] = true
        elseif kind == 'schema' or kind == 'timestamp' then
            local snapshot = h:snapshot(); if kind == 'schema' then snapshot.schema = 99 else snapshot.writtenAt = math.huge end
            h.files[path] = e.json.encode(snapshot)
        end
        local loaded = e.VersionerCache.Load(); assert(loaded.ok and loaded.value.recovered); eq(loaded.value.loaded, 1)
        eq(e.VersionerCache.Get(key).releases[1].version, '2.0.0')
        assert(e.VersionerCache.dirty)
    end)
end

test('absent first-run, corrupt pair and unsupported backup degrade safely', function()
    local h = H.new(); local e, path = h.env, h.env.Config.CacheFile
    assert(e.VersionerCache.Load().ok)
    h.files[path] = ''; h.files[path .. '.bak'] = '{bad'; eq(e.VersionerCache.Load().code, 'cache_invalid'); eq(next(e.VersionerCache.entries), nil)
    local old = h:snapshot(); old.schema = 0; h.files[path .. '.bak'] = e.json.encode(old)
    eq(e.VersionerCache.Load().code, 'cache_invalid')
end)

local mutations = {
    identity = function(v) v.repository = 'Other/repo' end,
    fetchedNaN = function(v) v.fetchedAt = 0/0 end,
    expiresInf = function(v) v.expiresAt = math.huge end,
    negative = function(v) v.fetchedAt = -1 end,
    fractional = function(v) v.fetchedAt = 1.5 end,
    reversed = function(v) v.expiresAt = v.fetchedAt - 1 end,
    etag = function(v) v.etag = 'secret\nInjected' end,
    longEtag = function(v) v.etag = string.rep('x', 257) end,
    releaseType = function(v) v.releases[1] = 'bad' end,
    sparse = function(v) v.releases[3] = v.releases[1] end,
    tag = function(v) v.releases[1].tag = 'invalid' end,
    version = function(v) v.releases[1].version = 'invalid' end,
    mismatch = function(v) v.releases[1].version = '3.0.0' end,
    url = function(v) v.releases[1].url = 'https://evil.example' end,
    title = function(v) v.releases[1].title = string.rep('x', 161) end,
    prerelease = function(v) v.releases[1].prerelease = 'false' end,
    tooManyReleases = function(v) for i = 2, 51 do v.releases[i] = v.releases[1] end end
}
for name, mutate in pairs(mutations) do
    test('deep cache rejects ' .. name .. ' and keeps valid sibling', function()
        local h = H.new(); local e = h.env
        local snapshot = h:snapshot(); local bad = h:entry(); mutate(bad)
        snapshot.entries['bad/key'] = bad
        -- Use the correct key for the malformed entry so field validation is exercised.
        snapshot.entries[key] = bad
        local good = h:entry(); good.repository = 'FeatherFramework/good'; good.releases = {}
        snapshot.entries['featherframework/good'] = good; snapshot.entries['bad/key'] = nil
        h.files[e.Config.CacheFile] = e.json.encode(snapshot)
        local loaded = e.VersionerCache.Load(); assert(loaded.ok); eq(loaded.value.dropped, 1); eq(loaded.value.loaded, 1)
        eq(e.VersionerCache.Get(key), nil)
    end)
end

test('cache count bound and invalid-only primary recover backup', function()
    local h = H.new(); local e = h.env; local snapshot = h:snapshot()
    snapshot.entries[key].releases[1].url = 'https://evil.example'
    h.files[e.Config.CacheFile] = e.json.encode(snapshot)
    h.files[e.Config.CacheFile .. '.bak'] = e.json.encode(h:snapshot())
    assert(e.VersionerCache.Load().value.recovered)
    snapshot = h:snapshot(); for i = 1, 513 do snapshot.entries['invalid/' .. i] = {} end
    h.files[e.Config.CacheFile] = e.json.encode(snapshot)
    assert(e.VersionerCache.Load().value.recovered)
end)

test('save preserves validated backup despite corrupt primary, restart recovery', function()
    local h = H.new(); local e, path = h.env, h.env.Config.CacheFile
    h.files[path] = e.json.encode(h:snapshot()); assert(e.VersionerCache.Load().ok)
    h.files[path] = '{corrupted after load'
    e.VersionerCache.Put(key, h:entry('3.0.0')); assert(e.VersionerCache.Save().ok)
    eq(e.json.decode(h.files[path .. '.bak']).entries[key].releases[1].version, '2.0.0')
    assert(e.VersionerCache.Load().ok); eq(e.VersionerCache.Get(key).releases[1].version, '3.0.0')
    h.files[path] = '{broken'; assert(e.VersionerCache.Load().value.recovered)
    eq(e.VersionerCache.Get(key).releases[1].version, '2.0.0')
    assert(e.VersionerCache.Save().ok); assert(e.VersionerCache.Load().ok)
end)

for _, target in ipairs({ 'primary', 'backup' }) do
    for _, failure in ipairs({ true, 'throw' }) do
        test('dirty state and recovery on ' .. target .. ' write ' .. tostring(failure), function()
            local h = H.new(); local e, path = h.env, h.env.Config.CacheFile
            h.files[path] = e.json.encode(h:snapshot()); assert(e.VersionerCache.Load().ok)
            local previous = h.files[path]
            h.writeFailures[target == 'primary' and path or path .. '.bak'] = failure
            e.VersionerCache.Put(key, h:entry('3.0.0')); eq(e.VersionerCache.Save().code, 'cache_write_failed')
            assert(e.VersionerCache.dirty); eq(h.files[path], previous)
            if target == 'backup' then eq(#h.writes, 1) else assert(h.files[path .. '.bak']) end
            h.writeFailures = {}; assert(e.VersionerCache.Save().ok); assert(not e.VersionerCache.dirty)
            assert(e.VersionerCache.Load().ok); eq(e.VersionerCache.Get(key).releases[1].version, '3.0.0')
        end)
    end
end

test('first save seeds backup; invalid/encoding failures retain it', function()
    local h = H.new(); local e, path = h.env, h.env.Config.CacheFile
    assert(e.VersionerCache.Load().ok); e.VersionerCache.Put(key, h:entry()); assert(e.VersionerCache.Save().ok)
    local backup = h.files[path .. '.bak']
    e.VersionerCache.Put(key, {}); eq(e.VersionerCache.Save().code, 'cache_invalid'); eq(h.files[path .. '.bak'], backup)
    e.VersionerCache.Put(key, h:entry()); h.encodeFails = true
    eq(e.VersionerCache.Save().code, 'cache_too_large'); eq(h.files[path .. '.bak'], backup); assert(e.VersionerCache.dirty)
end)

test('stable/prerelease/draft/ignore selection and pin information', function()
    local h = H.new(); local e = h.env
    local body = e.json.encode({
        { tag_name = 'v2.0.0', html_url = h:release('2.0.0').url, name = '^1Stable\nTitle' },
        { tag_name = 'v3.0.0-rc.1', html_url = h:release('3.0.0-rc.1').url, prerelease = true },
        { tag_name = 'v9.0.0', html_url = h:release('9.0.0').url, draft = true },
        { tag_name = 'bad', html_url = 'https://evil.example' }
    })
    local decoded = e.VersionerGithub.DecodeFixture(body, 'FeatherFramework/example'); assert(decoded.ok); eq(#decoded.value, 2)
    eq(decoded.value[1].title, 'Stable Title')
    local cache = { releases = decoded.value }
    eq(e.VersionerGithub.Select(cache, { channel = 'stable', ignored = {} }).value.target.release.version, '2.0.0')
    eq(e.VersionerGithub.Select(cache, { channel = 'prerelease', ignored = {} }).value.target.release.version, '3.0.0-rc.1')
    eq(e.VersionerGithub.Select(cache, { channel = 'stable', ignored = { ['2.0.0'] = true } }).value.target, nil)
    configure(h, { alpha = { repository = 'FeatherFramework/example', pin = '1.0.0' } })
    e.VersionerRegistry.Build(); local entry = e.VersionerRegistry.Get('alpha')
    e.VersionerReporter.Evaluate(entry, cache, false); eq(entry.status, 'pinned')
    e.VersionerReporter.PrintOne(entry); assert(not table.concat(h.logs):find('Upstream information', 1, true))
    e.Config.ReportNewerThanPin = true; e.VersionerReporter.PrintOne(entry)
    assert(table.concat(h.logs):find('Upstream information: 2.0.0', 1, true)); eq(entry.status, 'pinned'); eq(entry.target.version, '1.0.0')
end)

test('stale failure remains actionable then clears on success', function()
    local h = H.new(); local e = h.env
    e.VersionerCache.Put(key, h:entry()); e.VersionerScheduler.Run('manual')
    h:respond(1, 404, 'secret raw body')
    local entry = e.VersionerRegistry.Get('alpha')
    eq(entry.status, 'outdated'); assert(entry.stale); eq(entry.warning.code, 'not_found')
    e.VersionerReporter.PrintOne(entry); local output = table.concat(h.logs, '\n')
    assert(output:find('Stale reason:', 1, true) and output:find('not_found', 1, true)); assert(not output:find('secret', 1, true))
    h:advance(30000); e.VersionerScheduler.Run('manual'); h:respond(2, 200, h:body())
    assert(not e.VersionerRegistry.Get('alpha').stale); eq(e.VersionerRegistry.Get('alpha').warning, nil)
end)

test('Enabled blocks all check paths, read-only commands remain console-only', function()
    local h = H.new(); local e = h.env; e.Config.Enabled = false
    e.VersionerScheduler.Start(); eq(#h.timers, 0); eq(#h.threads, 0)
    for _, reason in ipairs({ 'manual', 'startup', 'interval' }) do eq(e.VersionerScheduler.Run(reason).code, 'disabled') end
    e.VersionerScheduler.lastManualAt = h.now; eq(e.VersionerScheduler.Manual().code, 'disabled')
    h.commands.feather(1, { 'versions', 'check' }); eq(#h.logs, 1)
    h.commands.feather(0, { 'versions', 'check' }); assert(table.concat(h.logs):find('(disabled)', 1, true))
    h.commands.feather(0, { 'versions', 'help' }); h.commands.feather(0, { 'versions' }); eq(#h.requests, 0)
end)

test('startup delay, interval scheduling, fresh cache and manual cooldown', function()
    local h = H.new(); local e = h.env
    e.VersionerScheduler.Start(); h:advance(14000); eq(#h.requests, 0)
    h:advance(1000); eq(#h.requests, 1); h:respond(1, 200, h:body())
    assert(e.VersionerScheduler.Run('interval').ok); eq(#h.requests, 1)
    assert(e.VersionerScheduler.Manual().ok); eq(#h.requests, 2); h:respond(2, 304)
    eq(e.VersionerScheduler.Manual().code, 'cooldown')
    eq(h.requests[2].headers['If-None-Match'], nil) -- first 200 had no ETag
    local ok, delay = coroutine.resume(h.threads[1]); assert(ok); assert(delay >= 60000)
    e.Config.Enabled = false; h:advance(delay); assert(coroutine.resume(h.threads[1])); eq(#h.requests, 2)
end)

test('deduplicated upstreams, concurrency cap and in-flight rejection', function()
    local h = H.new(); local e = h.env
    configure(h, { alpha = { repository = 'FeatherFramework/example' }, beta = { repository = 'FeatherFramework/example' },
        gamma = { repository = 'FeatherFramework/second' }, delta = { repository = 'FeatherFramework/third' } })
    h.versions.beta, h.versions.gamma, h.versions.delta = '1.0.0', '1.0.0', '1.0.0'
    e.VersionerScheduler.Run('manual'); eq(#h.requests, 2); eq(e.VersionerScheduler.Run('manual').code, 'in_flight')
    h:respond(1, 404); eq(#h.requests, 3); h:respond(2, 404); h:respond(3, 404)
    assert(not e.VersionerScheduler.running)
    local seen = {}; for _, request in ipairs(h.requests) do assert(not seen[request.url]); seen[request.url] = true end
end)

test('200/304 ETag refresh and freshness', function()
    local h = H.new(); local e = h.env
    e.VersionerScheduler.Run('manual'); h:respond(1, 200, h:body(), { ETag = '"release"' })
    eq(e.VersionerCache.Get(key).etag, '"release"'); assert(e.VersionerCache.IsFresh(e.VersionerCache.Get(key)))
    h:advance(1000); e.VersionerScheduler.Run('manual'); eq(h.requests[2].headers['If-None-Match'], '"release"'); h:respond(2, 304)
    eq(e.VersionerCache.Get(key).fetchedAt, h.now); eq(e.VersionerCache.Get(key).releases[1].version, '2.0.0')
end)

for _, status in ipairs({ 403, 429, 404, 0, 500 }) do
    test('HTTP ' .. status .. ' backoff and bounded reset', function()
        local h = H.new(); local e = h.env
        e.VersionerScheduler.Run('manual'); h:respond(1, status, 'raw secret', { ['X-RateLimit-Reset'] = tostring(h.now + 120) })
        eq(e.VersionerRegistry.Get('alpha').error.code, (status == 403 or status == 429) and 'rate_limited' or status == 404 and 'not_found' or status == 0 and 'network_error' or 'http_error')
        local expected = (status == 403 or status == 429) and 120 or 30
        eq(e.VersionerScheduler.nextAllowedAt[key], h.now + expected)
        e.VersionerScheduler.Run('manual'); eq(#h.requests, 1)
        h:advance(expected * 1000); e.VersionerScheduler.Run('manual'); eq(#h.requests, 2)
        h:respond(2, 429, '', { ['x-ratelimit-reset'] = tostring(h.now + 999999999) })
        eq(e.VersionerScheduler.nextAllowedAt[key], h.now + e.Config.MaxBackoffMinutes * 60)
    end)
end

for _, kind in ipairs({ 'malformed', 'oversized' }) do
    test('HTTP ' .. kind .. ' response stays out of cache', function()
        local h = H.new(); local e = h.env
        e.VersionerScheduler.Run('manual'); h:respond(1, 200, kind == 'malformed' and '{bad' or string.rep('x', e.Config.MaxResponseBytes + 1))
        eq(e.VersionerRegistry.Get('alpha').error.code, kind == 'malformed' and 'invalid_response' or 'response_too_large')
        eq(e.VersionerCache.Get(key), nil)
    end)
end

test('deadline ignores late success without cache/report mutation', function()
    local h = H.new(); local e = h.env
    e.VersionerScheduler.Run('manual'); h:advance(e.Config.ResponseDeadlineSeconds * 1000)
    eq(e.VersionerRegistry.Get('alpha').error.code, 'deadline_exceeded'); assert(not e.VersionerScheduler.running)
    local logs = #h.logs; h:respond(1, 200, h:body()); eq(e.VersionerCache.Get(key), nil); eq(#h.logs, logs)
end)

for _, status in ipairs({ 200, 304 }) do
    test('stop generation blocks late ' .. status .. ' writes and timers', function()
        local h = H.new(); local e = h.env
        e.VersionerCache.Put(key, h:entry()); e.VersionerScheduler.Run('manual'); e.VersionerScheduler.Stop()
        local previous, writes, logs = e.VersionerCache.Get(key).fetchedAt, #h.writes, #h.logs
        h:respond(1, status, h:body('3.0.0')); h:advance(60000)
        eq(e.VersionerCache.Get(key).fetchedAt, previous); eq(#h.writes, writes); eq(#h.logs, logs)
        eq(e.VersionerScheduler.Run('manual').code, 'stopped')
    end)
end

test('shipped smoke commands pass in isolated runtime', function()
    local h = H.new(); h:load('server/main.lua')
    for _, name in ipairs({ 'VersionerContractSmokeTest', 'VersionerSemverSmokeTest', 'VersionerFixtureSmokeTest' }) do h.commands[name](0) end
    assert(not table.concat(h.logs):find('FAIL', 1, true))
    eq(#h.requests, 0); eq(#h.writes, 0)
end)

test('stale current warnings bypass ReportCurrent suppression and clear after recovery', function()
    local h = H.new(); local e = h.env
    e.VersionerRegistry.Build(); local entry = e.VersionerRegistry.Get('alpha')
    e.VersionerReporter.Error(entry, e.VersionerResults.Err('network_error', 'GitHub release request failed.'), h:entry('1.0.0'))
    eq(entry.status, 'current'); assert(not e.Config.ReportCurrent)
    e.VersionerReporter.Print(e.VersionerRegistry.entries)
    assert(table.concat(h.logs):find('Stale reason:', 1, true))
    e.VersionerReporter.Evaluate(entry, h:entry('1.0.0'), false); h.logs = {}
    e.VersionerReporter.Print(e.VersionerRegistry.entries)
    assert(not table.concat(h.logs):find('Stale reason:', 1, true))
end)

test('report order and all comparison states remain deterministic', function()
    local h = H.new(); local e = h.env
    configure(h, { zeta = { repository = 'FeatherFramework/example' }, alpha = { repository = 'FeatherFramework/example' } })
    h.versions.zeta = '1.0.0'; e.Config.ReportCurrent = true; e.VersionerRegistry.Build()
    local entry = e.VersionerRegistry.Get('alpha')
    e.VersionerReporter.Evaluate(entry, h:entry('0.9.0'), false); eq(entry.status, 'ahead')
    e.VersionerReporter.Evaluate(entry, h:entry('1.0.0'), false); eq(entry.status, 'current')
    entry.policy.ignored['2.0.0'] = true
    e.VersionerReporter.Evaluate(entry, h:entry('2.0.0'), false); eq(entry.status, 'ignored')
    e.VersionerReporter.Evaluate(entry, { releases = {} }, false); eq(entry.status, 'unknown')
    e.VersionerReporter.Error(entry, e.VersionerResults.Err('not_found', 'Not found')); eq(entry.status, 'error')
    e.VersionerReporter.Evaluate(e.VersionerRegistry.Get('zeta'), h:entry(), false)
    e.VersionerReporter.Print(e.VersionerRegistry.entries)
    local output = table.concat(h.logs, '\n')
    assert(output:find('alpha', 1, true) < output:find('zeta', 1, true))
    entry.policy.pin = e.VersionerSemver.Parse('2.0.0').value
    e.Config.ReportNewerThanPin = true; h.logs = {}
    e.VersionerReporter.Evaluate(entry, h:entry('3.0.0'), true); eq(entry.status, 'outdated')
    e.VersionerReporter.PrintOne(entry); assert(table.concat(h.logs):find('3.0.0 is newer than pin 2.0.0 stale=true', 1, true))
    e.VersionerReporter.Evaluate(entry, h:entry('1.0.0'), false); eq(entry.status, 'outdated')
    h.logs = {}; e.VersionerReporter.PrintOne(entry); assert(not table.concat(h.logs):find('Upstream information', 1, true))
end)

test('oversized encoded payload retains known-good files and dirty state', function()
    local h = H.new(); local e, path = h.env, h.env.Config.CacheFile
    e.VersionerCache.Put(key, h:entry()); assert(e.VersionerCache.Save().ok)
    local primary, backup, writes = h.files[path], h.files[path .. '.bak'], #h.writes
    h.encodeOversized = true
    eq(e.VersionerCache.Save().code, 'cache_too_large'); assert(e.VersionerCache.dirty)
    eq(h.files[path], primary); eq(h.files[path .. '.bak'], backup); eq(#h.writes, writes)
end)

test('no valid backup falls back empty for every unusable primary', function()
    for _, raw in ipairs({ '', '{bad', string.rep('x', 1048577) }) do
        local h = H.new(); h.files[h.env.Config.CacheFile] = raw
        eq(h.env.VersionerCache.Load().code, 'cache_invalid'); eq(next(h.env.VersionerCache.entries), nil)
    end
end)

test('304 without cache, JSON object and non-finite rate reset are bounded errors', function()
    local h = H.new(); local e = h.env
    e.VersionerScheduler.Run('manual'); h:respond(1, 304)
    eq(e.VersionerRegistry.Get('alpha').error.code, 'http_error')
    h:advance(30000); e.VersionerScheduler.Run('manual'); h:respond(2, 200, e.json.encode({ message = 'secret' }))
    eq(e.VersionerRegistry.Get('alpha').error.code, 'invalid_response')
    h:advance(60000); e.VersionerScheduler.Run('manual'); h:respond(3, 429, '', { ['x-ratelimit-reset'] = 'inf' })
    assert(e.VersionerScheduler.nextAllowedAt[key] <= h.now + e.Config.MaxBackoffMinutes * 60)
end)

test('stop save failure is reported and dirty remains set', function()
    local h = H.new(); local e = h.env
    e.VersionerCache.Put(key, h:entry())
    h.writeFailures[e.Config.CacheFile .. '.bak'] = true
    e.VersionerScheduler.Stop()
    assert(e.VersionerCache.dirty)
    assert(table.concat(h.logs):find('cache warning on stop', 1, true))
end)

test('bootstrap loads recovery without starting disabled outbound checks', function()
    local h = H.new(); local e = h.env
    e.Config.Enabled = false; h.files[e.Config.CacheFile .. '.bak'] = e.json.encode(h:snapshot())
    h:load('server/main.lua'); assert(coroutine.resume(h.threads[1]))
    eq(#h.requests, 0); eq(e.VersionerCache.Get(key).releases[1].version, '2.0.0')
    h.events.onResourceStop('other-resource'); assert(not e.VersionerScheduler.stopped)
    h.events.onResourceStop('feather-versioner'); assert(e.VersionerScheduler.stopped)
end)

test('accepted cache boundary values are normalized and remain usable', function()
    local h = H.new(); local e = h.env; local entry = h:entry()
    entry.fetchedAt, entry.expiresAt = 0, 253402300799
    entry.etag = string.rep('a', 256); entry.releases[1].title = '^1' .. string.rep('a', 158)
    for i = 2, e.Config.MaxReleases do entry.releases[i] = H.copy(entry.releases[1]) end
    h.files[e.Config.CacheFile] = e.json.encode(h:snapshot(entry))
    assert(e.VersionerCache.Load().ok); eq(#e.VersionerCache.Get(key).releases, 50)
    eq(#e.VersionerCache.Get(key).releases[1].title, 158)
    assert(e.VersionerCache.IsFresh(e.VersionerCache.Get(key)))
    assert(e.VersionerCache.Save().ok)
end)

test('numeric native success requires verified persisted bytes', function()
    local h = H.new(); local e = h.env
    h.numericWriteResult = true; e.VersionerCache.Put(key, h:entry())
    assert(e.VersionerCache.Save().ok); assert(not e.VersionerCache.dirty)
    assert(e.VersionerCache.Load().ok)
end)

test('successful native result with partial bytes retains dirty state', function()
    local h = H.new(); local e = h.env
    h.partialWrite = true; e.VersionerCache.Put(key, h:entry())
    local saved = e.VersionerCache.Save()
    eq(saved.code, 'cache_write_failed'); assert(saved.message:find('read-back verification failed', 1, true))
    assert(e.VersionerCache.dirty); eq(h.files[e.Config.CacheFile], nil)
end)

test('write diagnostics distinguish rejection from read-back failure without raw errors', function()
    local h = H.new(); local e = h.env; e.VersionerCache.Put(key, h:entry())
    h.writeFailures[e.Config.CacheFile .. '.bak'] = true
    assert(e.VersionerCache.Save().message:find('native returned false', 1, true))
    h.writeFailures[e.Config.CacheFile .. '.bak'] = 'throw'
    local saved = e.VersionerCache.Save()
    assert(saved.message:find('native raised an error', 1, true)); assert(not saved.message:find('fixture write failure', 1, true))
end)

test('cache acceptance console runner isolates production state and rejects players', function()
    local h = H.new(); local e = h.env
    h:load('server/main.lua')
    local originalRead = e.LoadResourceFile
    local paths = { 'config.lua', 'shared/results.lua', 'tests/harness.lua', 'tests/cache_acceptance.lua' }
    for _, name in ipairs({ 'sanitize', 'semver', 'config', 'registry', 'cache', 'github', 'reporter', 'scheduler', 'commands' }) do
        paths[#paths + 1] = 'server/' .. name .. '.lua'
    end
    local sources = {}
    for _, path in ipairs(paths) do local file = assert(io.open(path, 'rb')); sources[path] = file:read('*a'); file:close() end
    e.LoadResourceFile = function(resource, path) return sources[path] or originalRead(resource, path) end
    local entries = e.VersionerCache.entries
    h.commands.VersionerCacheAcceptanceSmokeTest(1); eq(#h.logs, 0)
    h.commands.VersionerCacheAcceptanceSmokeTest(0)
    assert(table.concat(h.logs):find('done 11/11 passed', 1, true), table.concat(h.logs, '\n'))
    eq(e.VersionerCache.entries, entries); eq(#h.requests, 0); eq(#h.writes, 0)
end)

for _, item in ipairs(tests) do
    local ok, reason = pcall(item[2])
    if ok then passed = passed + 1; print('PASS ' .. item[1]) else print('FAIL ' .. item[1] .. ': ' .. tostring(reason)) end
end
print(('%d/%d offline tests passed'):format(passed, #tests))
if passed ~= #tests then os.exit(1) end
