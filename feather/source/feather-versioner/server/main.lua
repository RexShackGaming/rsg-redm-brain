local resourceName = GetCurrentResourceName()

local function printTests(name, tests)
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[%s] %-28s %s'):format(name, test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[%s] done %d/%d passed'):format(name, passed, #tests))
end

RegisterCommand('VersionerContractSmokeTest', function(source)
    if source ~= 0 then return end
    local config = VersionerConfig.Validate()
    local built = config.ok and VersionerRegistry.Build() or config
    printTests('VersionerContractSmokeTest', {
        { 'server-only manifest', GetNumResourceMetadata(resourceName, 'client_script') == 0 },
        { 'configuration valid', config.ok },
        { 'registry built', built.ok },
        { 'no public initiate API', rawget(_G, 'Feather') == nil },
        { 'bounded response policy', Config.MaxResponseBytes <= 4194304 and Config.MaxReleases <= 100 },
        { 'bounded concurrency', Config.MaxConcurrentRequests >= 1 and Config.MaxConcurrentRequests <= 8 }
    })
end, true)

RegisterCommand('VersionerSemverSmokeTest', function(source)
    if source ~= 0 then return end
    local function comparison(left, right, expected)
        local result = VersionerSemver.Compare(left, right); return result.ok and result.value == expected
    end
    local build = VersionerSemver.Parse('v1.2.3+local.1')
    local prerelease = VersionerSemver.Parse('1.2.3-rc.10')
    local invalid = VersionerSemver.Parse('1.2')
    local trailingBuild = VersionerSemver.Parse('1.2.3+')
    printTests('VersionerSemverSmokeTest', {
        { 'minor numeric precedence', comparison('1.10.0', '1.9.0', 1) },
        { 'major precedence', comparison('2.0.0', '1.99.99', 1) },
        { 'tag normalization', comparison('v1.2.3', '1.2.3', 0) },
        { 'stable over prerelease', comparison('1.2.3', '1.2.3-rc.1', 1) },
        { 'prerelease parsed', prerelease.ok and #prerelease.value.prerelease == 2 and prerelease.value.prerelease[2] == '10' },
        { 'prerelease numeric order', comparison('1.2.3-rc.10', '1.2.3-rc.2', 1) },
        { 'build ignored in precedence', build.ok and comparison(build.value, '1.2.3', 0) },
        { 'short version rejected', not invalid.ok and invalid.code == 'invalid_version' },
        { 'empty build rejected', not trailingBuild.ok and trailingBuild.code == 'invalid_version' },
        { 'large identifier safe', comparison('999999999999999999999.0.0', '999999999999999999998.0.0', 1) }
    })
end, true)

RegisterCommand('VersionerFixtureSmokeTest', function(source)
    if source ~= 0 then return end
    local body = json.encode({
        { tag_name = 'v1.2.0', name = '^1Stable\nTitle', html_url = 'https://github.com/FeatherFramework/example/releases/tag/v1.2.0', draft = false, prerelease = false },
        { tag_name = 'v1.3.0-rc.1', name = 'Candidate', html_url = 'https://github.com/FeatherFramework/example/releases/tag/v1.3.0-rc.1', draft = false, prerelease = true },
        { tag_name = 'v9.0.0', name = 'Draft', html_url = 'https://github.com/FeatherFramework/example/releases/tag/v9.0.0', draft = true, prerelease = false },
        { tag_name = 'bad', name = 'Invalid', html_url = 'https://evil.example/release', draft = false, prerelease = false }
    })
    local decoded = VersionerGithub.DecodeFixture(body, 'FeatherFramework/example')
    local stablePolicy = { channel = 'stable', ignored = {} }
    local prePolicy = { channel = 'prerelease', ignored = {} }
    local stable = decoded.ok and VersionerGithub.Select({ releases = decoded.value }, stablePolicy)
    local prerelease = decoded.ok and VersionerGithub.Select({ releases = decoded.value }, prePolicy)
    local ignored = decoded.ok and VersionerGithub.Select({ releases = decoded.value }, { channel = 'stable', ignored = { ['1.2.0'] = true } })
    local sanitized = decoded.ok and decoded.value[1] and decoded.value[1].title == 'Stable Title'
    printTests('VersionerFixtureSmokeTest', {
        { 'bounded fixture decoded', decoded.ok and #decoded.value == 2 },
        { 'untrusted title sanitized', sanitized },
        { 'stable channel selected', stable and stable.ok and stable.value.target and stable.value.target.release.version == '1.2.0' },
        { 'prerelease channel selected', prerelease and prerelease.ok and prerelease.value.target and prerelease.value.target.release.version == '1.3.0-rc.1' },
        { 'ignored target removed', ignored and ignored.ok and ignored.value.target == nil and ignored.value.ignored and ignored.value.ignored.release.version == '1.2.0' },
        { 'draft and invalid removed', decoded.ok and #decoded.value == 2 }
    })
end, true)

RegisterCommand('VersionerCacheAcceptanceSmokeTest', function(source)
    if source ~= 0 then return end
    -- Read only fixed, local source paths. Tested modules get mocked filesystem,
    -- HTTP, timers and metadata; only the real JSON codec crosses the boundary.
    local allowed = { ['tests/harness.lua'] = true, ['tests/cache_acceptance.lua'] = true,
        ['config.lua'] = true, ['shared/results.lua'] = true }
    for _, name in ipairs({ 'sanitize', 'semver', 'config', 'registry', 'cache', 'github', 'reporter', 'scheduler', 'commands' }) do
        allowed['server/' .. name .. '.lua'] = true
    end
    local env = { assert = assert, error = error, ipairs = ipairs, pairs = pairs, next = next,
        pcall = pcall, tonumber = tonumber, tostring = tostring, type = type, select = select,
        rawget = rawget, math = math, string = string, table = table, coroutine = coroutine }
    env.loadfile = function(path, mode, target)
        assert(allowed[path], 'Unexpected acceptance source path')
        local raw = LoadResourceFile(resourceName, path)
        assert(type(raw) == 'string', 'Acceptance source missing; include tests in the resource package')
        return load(raw, '@' .. path, 't', target or env)
    end
    local ok, results = pcall(function()
        local harness = assert(env.loadfile('tests/harness.lua'))()
        local run = assert(env.loadfile('tests/cache_acceptance.lua'))()
        return run(harness, { encode = json.encode, decode = json.decode })
    end)
    if not ok then
        print('[VersionerCacheAcceptanceSmokeTest] FAIL: acceptance sources could not be loaded; include tests in the resource package')
        return
    end
    print('[VersionerCacheAcceptanceSmokeTest] real JSON; in-memory filesystem; no HTTP or deployed-cache writes')
    printTests('VersionerCacheAcceptanceSmokeTest', results)
end, true)

CreateThread(function()
    local validated = VersionerConfig.Validate()
    if not validated.ok then print(('[feather-versioner] startup disabled: %s (%s)'):format(validated.message, validated.code)); return end
    local cache = VersionerCache.Load()
    if not cache.ok then print(('[feather-versioner] cache warning: %s; continuing with an empty cache'):format(cache.message)) end
    VersionerRegistry.Build()
    print(('[feather-versioner] ready configured=%d cacheEntries=%d'):format(validated.value.count, cache.ok and cache.value.loaded or 0))
    VersionerScheduler.Start()
end)

AddEventHandler('onResourceStop', function(stopped)
    if stopped == resourceName then VersionerScheduler.Stop() end
end)
