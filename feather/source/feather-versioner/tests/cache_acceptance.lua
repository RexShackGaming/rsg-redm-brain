-- Run manually through VersionerCacheAcceptanceSmokeTest with Cfx JSON.
-- Every cache path below exists only in Harness.files. No native writes/HTTP.
return function(Harness, codec)
    local results = {}
    local key = 'featherframework/example'
    local function check(name, callback)
        local ok = pcall(callback)
        results[#results + 1] = { name, ok }
    end
    for _, kind in ipairs({ 'missing', 'empty', 'malformed', 'oversized', 'schema' }) do
        check('backup recovery: ' .. kind, function()
            local h = Harness.new(codec); local e, path = h.env, h.env.Config.CacheFile
            h.files[path .. '.bak'] = e.json.encode(h:snapshot())
            if kind == 'empty' then h.files[path] = ''
            elseif kind == 'malformed' then h.files[path] = '{bad'
            elseif kind == 'oversized' then h.files[path] = string.rep('x', e.Config.MaxResponseBytes + 1)
            elseif kind == 'schema' then local snapshot = h:snapshot(); snapshot.schema = 99; h.files[path] = e.json.encode(snapshot) end
            local loaded = e.VersionerCache.Load()
            assert(loaded.ok and loaded.value.recovered and loaded.value.loaded == 1)
            assert(e.VersionerCache.Get(key).releases[1].version == '2.0.0')
            assert(#h.requests == 0 and #h.writes == 0)
        end)
    end
    check('corrupt pair starts empty', function()
        local h = Harness.new(codec); local e, path = h.env, h.env.Config.CacheFile
        h.files[path], h.files[path .. '.bak'] = '{bad', '{bad'
        assert(e.VersionerCache.Load().code == 'cache_invalid')
        assert(next(e.VersionerCache.entries) == nil)
    end)
    check('deep validation drops entry', function()
        local h = Harness.new(codec); local e = h.env; local snapshot = h:snapshot()
        snapshot.entries[key].releases[1].url = 'https://evil.example'
        local good = h:entry(); good.repository = 'FeatherFramework/good'; good.releases = {}
        snapshot.entries['featherframework/good'] = good
        h.files[e.Config.CacheFile] = e.json.encode(snapshot)
        local loaded = e.VersionerCache.Load()
        assert(loaded.ok and loaded.value.dropped == 1 and loaded.value.loaded == 1)
        assert(e.VersionerCache.Get(key) == nil)
    end)
    check('save reload and known-good backup', function()
        local h = Harness.new(codec); local e, path = h.env, h.env.Config.CacheFile
        h.files[path] = e.json.encode(h:snapshot()); assert(e.VersionerCache.Load().ok)
        h.files[path] = '{bad'; e.VersionerCache.Put(key, h:entry('3.0.0'))
        assert(e.VersionerCache.Save().ok)
        assert(e.json.decode(h.files[path .. '.bak']).entries[key].releases[1].version == '2.0.0')
        assert(e.VersionerCache.Load().ok and e.VersionerCache.Get(key).releases[1].version == '3.0.0')
        h.files[path] = '{bad'
        assert(e.VersionerCache.Load().value.recovered)
        assert(e.VersionerCache.Get(key).releases[1].version == '2.0.0' and #h.requests == 0)
    end)
    for _, target in ipairs({ 'backup', 'primary' }) do
        check(target .. ' write fails safely', function()
            local h = Harness.new(codec); local e, path = h.env, h.env.Config.CacheFile
            e.VersionerCache.Put(key, h:entry()); assert(e.VersionerCache.Save().ok)
            local previous = h.files[path]
            h.writeFailures[target == 'backup' and path .. '.bak' or path] = true
            e.VersionerCache.Put(key, h:entry('3.0.0'))
            assert(e.VersionerCache.Save().code == 'cache_write_failed' and e.VersionerCache.dirty)
            assert(h.files[path] == previous)
            h.writeFailures = {}; assert(e.VersionerCache.Save().ok)
            assert(e.VersionerCache.Load().ok and e.VersionerCache.Get(key).releases[1].version == '3.0.0')
        end)
    end
    check('partial write rejected', function()
        local h = Harness.new(codec); local e = h.env
        h.partialWrite = true; e.VersionerCache.Put(key, h:entry())
        local saved = e.VersionerCache.Save()
        assert(saved.code == 'cache_write_failed' and saved.message:find('read-back verification failed', 1, true))
        assert(e.VersionerCache.dirty and h.files[e.Config.CacheFile] == nil)
    end)
    return results
end
