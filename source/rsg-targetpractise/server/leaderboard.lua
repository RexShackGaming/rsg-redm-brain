lib.locale()

TargetPractiseLeaderboard = {}

function TargetPractiseLeaderboard.name(charinfo)
    charinfo = type(charinfo) == 'table' and charinfo or {}
    local first = type(charinfo.firstname) == 'string' and charinfo.firstname or ''
    local last = type(charinfo.lastname) == 'string' and charinfo.lastname or ''
    local name = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name:sub(1, 100) or locale('unknown_player')
end

-- Pure projection: never exposes citizen IDs or modifies the stored totals.
function TargetPractiseLeaderboard.build(totals, online, viewer)
    local combined = {}
    for citizenid, total in pairs(totals) do
        if total.hits > 0 then
            combined[citizenid] = {
                key = citizenid, name = total.name or locale('unknown_player'),
                points = total.points, hits = total.hits, best = total.best or 0,
                bullseyes = total.bullseyes or 0, arrows = total.arrows or 0,
                knives = total.knives or 0, arrowDistance = total.arrowDistance or 0,
                knifeDistance = total.knifeDistance or 0, online = false, you = citizenid == viewer
            }
        end
    end
    for citizenid, name in pairs(online) do
        local row = combined[citizenid]
        if row then row.name, row.online = name, true end
    end
    local rows = {}
    for _, row in pairs(combined) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        if a.best ~= b.best then return a.best > b.best end
        if a.hits ~= b.hits then return a.hits < b.hits end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    for index, row in ipairs(rows) do
        row.rank = index
        row.average = row.hits > 0 and math.floor(row.points / row.hits * 10 + 0.5) / 10 or 0
    end
    local records = { arrow = nil, knife = nil }
    local function better(candidate, current)
        if not current then return true end
        if candidate.distance ~= current.distance then return candidate.distance > current.distance end
        if candidate.name ~= current.name then return candidate.name < current.name end
        return candidate.key < current.key
    end
    for _, row in ipairs(rows) do
        for _, kind in ipairs({ 'arrow', 'knife' }) do
            local raw = row[kind .. 'Distance'] or 0
            if raw > 0 then
                local candidate = {
                    key = row.key, name = row.name,
                    distance = math.floor(raw * 10 + 0.5) / 10
                }
                if better(candidate, records[kind]) then records[kind] = candidate end
            end
        end
    end
    for _, row in ipairs(rows) do
        row.key, row.arrowDistance, row.knifeDistance = nil, nil, nil
    end
    for _, record in pairs(records) do record.key = nil end
    return rows, records
end
