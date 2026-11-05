VersionerReporter = {}

local colors = {
    reset = '^0',
    label = '^5',
    current = '^2',
    pinned = '^2',
    outdated = '^3',
    ahead = '^4',
    ignored = '^3',
    unknown = '^1',
    error = '^1'
}

local function colorize(value, color)
    value = tostring(value)
    if Config.ConsoleColors == false or not color then return value end
    return color .. value .. colors.reset
end

local function prefix()
    return colorize('[Feather Versions]', colors.label)
end

local function statusColor(status)
    return colors[status or 'unknown'] or colors.unknown
end

local function compareInstalled(entry, target)
    local compared = VersionerSemver.Compare(entry.installed.parsed, target)
    if not compared.ok then return 'error', compared end
    if compared.value < 0 then return 'outdated' end
    if compared.value > 0 then return 'ahead' end
    return 'current'
end

function VersionerReporter.Evaluate(entry, cache, stale)
    if not entry.installed then return entry end
    entry.error, entry.warning = nil, nil
    local selected = VersionerGithub.Select(cache, entry.policy)
    if not selected.ok then entry.status = 'error'; entry.error = selected; return entry end
    entry.stale, entry.checkedAt = stale == true, os.time()
    entry.upstream = selected.value.upstream and selected.value.upstream.release or nil
    if entry.policy.pin then
        entry.target = { version = entry.policy.pin.normalized, tag = entry.policy.pin.raw }
        local status, failure = compareInstalled(entry, entry.policy.pin)
        entry.status, entry.error = status == 'current' and 'pinned' or status, failure
        return entry
    end
    local target = selected.value.target
    if not target then
        local ignored = selected.value.ignored
        if not ignored then entry.status = 'unknown'; entry.target = nil; return entry end
        entry.target = ignored.release
        local compared = VersionerSemver.Compare(entry.installed.parsed, ignored.parsed)
        entry.status = not compared.ok and 'error' or compared.value < 0 and 'ignored' or compared.value > 0 and 'ahead' or 'current'
        entry.error = compared.ok and nil or compared
        return entry
    end
    entry.target = target.release
    entry.status, entry.error = compareInstalled(entry, target.parsed)
    if selected.value.ignored then
        local versusInstalled = VersionerSemver.Compare(selected.value.ignored.parsed, entry.installed.parsed)
        if versusInstalled.ok and versusInstalled.value > 0 and entry.status ~= 'outdated' then entry.status = 'ignored' end
    end
    return entry
end

function VersionerReporter.Error(entry, failure, staleCache)
    if staleCache then
        VersionerReporter.Evaluate(entry, staleCache, true)
        entry.warning = failure
        return entry
    end
    entry.target, entry.upstream, entry.warning, entry.stale = nil, nil, nil, false
    entry.status, entry.error, entry.checkedAt = 'error', failure, os.time()
    return entry
end

function VersionerReporter.PrintOne(entry)
    local installed = entry.installed and entry.installed.raw or 'unknown'
    local target = entry.target and (entry.target.version or entry.target.tag) or 'unknown'
    local status = entry.status or 'unknown'
    print(('%s %s %s installed=%s target=%s%s'):format(prefix(), colorize(('[%s]'):format(status:upper()), statusColor(status)), entry.label, installed, target, entry.stale and ' stale=true' or ''))
    if entry.status == 'outdated' and entry.target and entry.target.url then print(('  %s %s'):format(colorize('Release:', colors.outdated), entry.target.url)) end
    if Config.IncludeReleaseTitle and entry.target and entry.target.title and entry.target.title ~= '' then print(('  Title: %s'):format(entry.target.title)) end
    if entry.error then print(('  %s %s (%s)'):format(colorize('Reason:', colors.error), entry.error.message or 'Unknown error', entry.error.code or 'error')) end
    if entry.warning then print(('  %s %s (%s)'):format(colorize('Stale reason:', colors.ignored), entry.warning.message or 'Unknown error', entry.warning.code or 'error')) end
    if Config.ReportNewerThanPin and entry.policy.pin and entry.upstream then
        local compared = VersionerSemver.Compare(entry.upstream.version, entry.policy.pin)
        if compared.ok and compared.value > 0 then
            print(('  Upstream information: %s is newer than pin %s%s (pin remains target)'):format(
                entry.upstream.version, entry.policy.pin.normalized, entry.stale and ' stale=true' or ''))
            print(('  Upstream release: %s'):format(entry.upstream.url))
        end
    end
end

function VersionerReporter.Print(entries, requestedName)
    if requestedName then local entry = entries[requestedName]; if not entry then print(('%s %s'):format(prefix(), colorize(('Resource is not configured: %s'):format(requestedName), colors.error))); return end; VersionerReporter.PrintOne(entry); return end
    local counts, total = {}, 0
    local names = {}; for name in pairs(entries) do names[#names + 1] = name end; table.sort(names)
    for _, name in ipairs(names) do local entry=entries[name];counts[entry.status or 'unknown'] = (counts[entry.status or 'unknown'] or 0) + 1; total = total + 1 end
    if Config.ReportSummary then
        local summary = {
            ('%d checked:'):format(total),
            colorize(('%d current'):format(counts.current or 0), colors.current),
            colorize(('%d pinned'):format(counts.pinned or 0), colors.pinned),
            colorize(('%d update available'):format(counts.outdated or 0), colors.outdated),
            colorize(('%d ahead'):format(counts.ahead or 0), colors.ahead),
            colorize(('%d ignored'):format(counts.ignored or 0), colors.ignored),
            colorize(('%d unknown/error'):format((counts.unknown or 0) + (counts.error or 0)), colors.error)
        }
        print(('%s %s %s'):format(prefix(), summary[1], table.concat(summary, ', ', 2)))
    end
    for _, name in ipairs(names) do
        local entry = entries[name]
        if Config.ReportCurrent or entry.status ~= 'current' or entry.warning then VersionerReporter.PrintOne(entry) end
    end
end
