VersionerCache = { entries = {}, dirty = false }
local resourceName = GetCurrentResourceName()
local knownGood
local maxEntries = 512

local function timestamp(value)
    return type(value) == 'number' and value == value and value >= 0
        and value <= 253402300799 and value % 1 == 0
end

local function arrayLength(value, maximum)
    if type(value) ~= 'table' then return nil end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > maximum then return nil end
        count = count + 1
    end
    if count ~= #value or count > maximum then return nil end
    return count
end

local function normalizeEntry(key, value)
    if type(value) ~= 'table' then return nil end
    local repo = VersionerSanitize.Repository(value.repository)
    if not repo.ok or key ~= repo.value.key or not timestamp(value.fetchedAt)
        or not timestamp(value.expiresAt) or value.expiresAt < value.fetchedAt
        or not arrayLength(value.releases, Config.MaxReleases) then return nil end
    if value.etag ~= nil and (type(value.etag) ~= 'string' or #value.etag > 256
        or value.etag:find('[%c]')) then return nil end
    local releases = {}
    for _, release in ipairs(value.releases) do
        if type(release) ~= 'table' or type(release.prerelease) ~= 'boolean'
            or type(release.title) ~= 'string' or #release.title > Config.MaxReleaseTitleBytes then return nil end
        local tag, version = VersionerSemver.Parse(release.tag), VersionerSemver.Parse(release.version)
        local url = VersionerSanitize.ReleaseUrl(release.url, value.repository)
        if not tag.ok or not version.ok or tag.value.normalized ~= version.value.normalized or not url then return nil end
        releases[#releases + 1] = { tag = tag.value.raw, version = version.value.normalized,
            title = VersionerSanitize.Text(release.title, Config.MaxReleaseTitleBytes), url = url,
            prerelease = release.prerelease }
    end
    return { repository = value.repository, fetchedAt = value.fetchedAt, expiresAt = value.expiresAt,
        etag = value.etag, releases = releases }
end

local function normalize(snapshot)
    if type(snapshot) ~= 'table' or snapshot.schema ~= 1 or not timestamp(snapshot.writtenAt)
        or type(snapshot.entries) ~= 'table' then return nil end
    local entries, count, dropped, total = {}, 0, 0, 0
    for key, value in pairs(snapshot.entries) do
        total = total + 1
        if total > maxEntries then return nil end
        local entry = normalizeEntry(key, value)
        if entry then entries[key] = entry; count = count + 1 else dropped = dropped + 1 end
    end
    if count == 0 and dropped > 0 then return nil end
    return { schema = 1, writtenAt = snapshot.writtenAt, entries = entries }, count, dropped
end

local function encode(snapshot)
    local ok, raw = pcall(json.encode, snapshot)
    if ok and type(raw) == 'string' and #raw <= Config.MaxResponseBytes then return raw end
end

local function read(path)
    local ok, raw = pcall(LoadResourceFile, resourceName, path)
    if not ok or type(raw) ~= 'string' or raw == '' or #raw > Config.MaxResponseBytes then return nil end
    local decodedOk, decoded = pcall(json.decode, raw)
    if not decodedOk then return nil end
    return normalize(decoded)
end

function VersionerCache.Load()
    VersionerCache.entries, VersionerCache.dirty, knownGood = {}, false, nil
    local snapshot, count, dropped = read(Config.CacheFile)
    local recovered = false
    if not snapshot then snapshot, count, dropped = read(Config.CacheFile .. '.bak'); recovered = snapshot ~= nil end
    if not snapshot then
        local ok, primary = pcall(LoadResourceFile, resourceName, Config.CacheFile)
        local backupOk, backup = pcall(LoadResourceFile, resourceName, Config.CacheFile .. '.bak')
        if ok and backupOk and primary == nil and backup == nil then return VersionerResults.Ok({ loaded = 0 }) end
        return VersionerResults.Err('cache_invalid', 'No usable primary or backup cache; continuing empty.')
    end
    VersionerCache.entries = snapshot.entries
    knownGood = encode(snapshot)
    VersionerCache.dirty = recovered or dropped > 0
    if recovered or dropped > 0 then
        print(('[feather-versioner] cache recovery backup=%s droppedEntries=%d'):format(tostring(recovered), dropped))
    end
    return VersionerResults.Ok({ loaded = count, recovered = recovered, dropped = dropped })
end

local function write(path, raw)
    local ok, saved = pcall(SaveResourceFile, resourceName, path, raw, #raw)
    if not ok then return false, 'native raised an error' end
    if saved ~= true and saved ~= 1 then
        if saved == false then return false, 'native returned false' end
        if saved == 0 then return false, 'native returned 0' end
        return false, 'unexpected native result type ' .. type(saved)
    end
    local readOk, persisted = pcall(LoadResourceFile, resourceName, path)
    if not readOk or persisted ~= raw then return false, 'read-back verification failed' end
    return true
end

function VersionerCache.Save()
    VersionerCache.dirty = true
    local snapshot, _, dropped = normalize({ schema = 1, writtenAt = os.time(), entries = VersionerCache.entries })
    if not snapshot or dropped > 0 then return VersionerResults.Err('cache_invalid', 'Refusing to persist invalid cache entries.') end
    local payload = encode(snapshot)
    if not payload then return VersionerResults.Err('cache_too_large', 'Cache encoding failed or exceeded its size limit.') end
    -- Backup the previous validated snapshot, never the bytes currently on disk.
    -- On first save the new validated payload seeds recovery before primary write.
    local backupSaved, backupReason = write(Config.CacheFile .. '.bak', knownGood or payload)
    if not backupSaved then
        return VersionerResults.Err('cache_write_failed', ('Cache backup could not be written (%s); primary retained.'):format(backupReason))
    end
    local primarySaved, primaryReason = write(Config.CacheFile, payload)
    if not primarySaved then return VersionerResults.Err('cache_write_failed', ('Cache primary could not be written (%s); validated backup retained.'):format(primaryReason)) end
    knownGood = payload
    VersionerCache.dirty = false
    return VersionerResults.Ok({ bytes = #payload })
end

function VersionerCache.Get(key) return VersionerCache.entries[key] end
function VersionerCache.IsFresh(entry, now) return entry and timestamp(entry.expiresAt) and entry.expiresAt > (now or os.time()) end
function VersionerCache.Put(key, value) VersionerCache.entries[key] = value; VersionerCache.dirty = true end
