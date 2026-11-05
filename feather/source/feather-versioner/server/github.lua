VersionerGithub = { sequence = 0 }

local function header(headers, name)
    if type(headers) ~= 'table' then return nil end
    for key, value in pairs(headers) do if tostring(key):lower() == name:lower() then return type(value) == 'table' and value[1] or value end end
end

local function decodeReleases(body, repository)
    if type(body) ~= 'string' or #body > Config.MaxResponseBytes then return VersionerResults.Err('response_too_large', 'GitHub response exceeds its size limit.') end
    local ok, decoded = pcall(json.decode, body)
    if not ok or type(decoded) ~= 'table' then return VersionerResults.Err('invalid_response', 'GitHub returned malformed JSON.') end
    local count = 0
    for key in pairs(decoded) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return VersionerResults.Err('invalid_response', 'GitHub releases must be a list.') end
        count = count + 1
    end
    if count ~= #decoded then return VersionerResults.Err('invalid_response', 'GitHub releases must be a dense list.') end
    local releases = {}
    for index = 1, math.min(#decoded, Config.MaxReleases) do
        local source = decoded[index]
        if type(source) == 'table' and source.draft ~= true and type(source.tag_name) == 'string' then
            local parsed = VersionerSemver.Parse(source.tag_name)
            local url = VersionerSanitize.ReleaseUrl(source.html_url, repository)
            if parsed.ok and url then
                releases[#releases + 1] = {
                    tag = VersionerSanitize.Text(source.tag_name, 128), version = parsed.value.normalized,
                    title = VersionerSanitize.Text(source.name or '', Config.MaxReleaseTitleBytes),
                    url = url, prerelease = source.prerelease == true
                }
            end
        end
    end
    return VersionerResults.Ok(releases)
end

VersionerGithub.DecodeFixture = decodeReleases

function VersionerGithub.Fetch(repositoryRecord, generation, callback)
    local function active()
        return Config.Enabled == true and not VersionerScheduler.stopped and generation == VersionerScheduler.generation
    end
    if not active() then return nil end
    VersionerGithub.sequence = VersionerGithub.sequence + 1
    local requestId = VersionerGithub.sequence
    local cached = VersionerCache.Get(repositoryRecord.key)
    local headers = { ['Accept'] = 'application/vnd.github+json', ['User-Agent'] = 'Feather-Versioner/0.1' }
    if cached and type(cached.etag) == 'string' and cached.etag ~= '' then headers['If-None-Match'] = cached.etag end
    local completed = false
    SetTimeout(math.floor(Config.ResponseDeadlineSeconds * 1000), function()
        if completed or not active() then return end
        completed = true
        callback(VersionerResults.Err('deadline_exceeded', 'GitHub response deadline expired.', { requestId = requestId, generation = generation }))
    end)
    local url = ('https://api.github.com/repos/%s/releases?per_page=%d'):format(repositoryRecord.repository, Config.MaxReleases)
    PerformHttpRequest(url, function(status, body, responseHeaders, errorData)
        if completed or not active() then return end
        completed = true
        status = tonumber(status) or 0
        if status == 304 and cached then
            cached.fetchedAt = os.time(); cached.expiresAt = os.time() + math.floor(Config.CacheTtlMinutes * 60)
            VersionerCache.Put(repositoryRecord.key, cached)
            return callback(VersionerResults.Ok({ cache = cached, notModified = true, generation = generation, requestId = requestId }))
        end
        if status ~= 200 then
            local code = status == 403 and 'rate_limited' or status == 429 and 'rate_limited' or status == 404 and 'not_found' or status == 0 and 'network_error' or 'http_error'
            return callback(VersionerResults.Err(code, 'GitHub release request failed.', {
                status = status, reset = header(responseHeaders, 'x-ratelimit-reset'), error = VersionerSanitize.Text(errorData, 160), generation = generation, requestId = requestId
            }))
        end
        local decoded = decodeReleases(body, repositoryRecord.repository)
        if not decoded.ok then return callback(decoded) end
        local cache = {
            repository = repositoryRecord.repository, releases = decoded.value,
            etag = VersionerSanitize.Text(header(responseHeaders, 'etag'), 256),
            fetchedAt = os.time(), expiresAt = os.time() + math.floor(Config.CacheTtlMinutes * 60)
        }
        VersionerCache.Put(repositoryRecord.key, cache)
        callback(VersionerResults.Ok({ cache = cache, generation = generation, requestId = requestId }))
    end, 'GET', '', headers)
    return requestId
end

function VersionerGithub.Select(cache, policy)
    local eligible, ignored = {}, {}
    for _, release in ipairs(cache and cache.releases or {}) do
        if policy.channel == 'prerelease' or release.prerelease ~= true then
            local parsed = VersionerSemver.Parse(release.version)
            if parsed.ok then
                local precedence = parsed.value.normalized:match('^[^+]+')
                if policy.ignored[precedence] then ignored[#ignored + 1] = { release = release, parsed = parsed.value }
                else eligible[#eligible + 1] = { release = release, parsed = parsed.value } end
            end
        end
    end
    local function newest(list)
        local selected
        for _, candidate in ipairs(list) do
            if not selected then selected = candidate else local compared = VersionerSemver.Compare(candidate.parsed, selected.parsed); if compared.ok and compared.value > 0 then selected = candidate end end
        end
        return selected
    end
    return VersionerResults.Ok({ target = newest(eligible), ignored = newest(ignored), upstream = newest((function() local all={};for _,v in ipairs(eligible) do all[#all+1]=v end;for _,v in ipairs(ignored) do all[#all+1]=v end;return all end)()) })
end
