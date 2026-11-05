VersionerSanitize = {}

local function truncateBytes(value, maximum)
    value = tostring(value or '')
    maximum = math.max(0, tonumber(maximum) or 0)
    if #value <= maximum then return value end
    return value:sub(1, maximum)
end

function VersionerSanitize.Text(value, maximum)
    value = tostring(value or '')
    value = value:gsub('\27%[[0-?]*[ -/]*[@-~]', '')
    value = value:gsub('[%z\1-\31\127]', ' ')
    value = value:gsub('%^%d', '')
    value = value:gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    return truncateBytes(value, maximum)
end

function VersionerSanitize.Repository(value)
    if type(value) ~= 'string' or #value < 3 or #value > 201 then
        return VersionerResults.Err('invalid_repository', 'Repository must be a bounded owner/repository identifier.')
    end
    local owner, repository = value:match('^([A-Za-z0-9][A-Za-z0-9_.-]*)/([A-Za-z0-9][A-Za-z0-9_.-]*)$')
    if not owner or not repository or #owner > 100 or #repository > 100 or owner:find('..', 1, true) or repository:find('..', 1, true) then
        return VersionerResults.Err('invalid_repository', 'Repository must be a valid owner/repository identifier.')
    end
    return VersionerResults.Ok({ owner = owner, repository = repository, key = (owner .. '/' .. repository):lower() })
end

function VersionerSanitize.ReleaseUrl(value, repository)
    if type(value) ~= 'string' or #value > 512 then return nil end
    local prefix = ('https://github.com/%s/releases/'):format(repository)
    if value:sub(1, #prefix):lower() ~= prefix:lower() then return nil end
    if value:find('[%c%s%?%#\\]') then return nil end
    local path = value:sub(#prefix + 1)
    if not path:match('^tag/.+') then return nil end
    for segment in path:gmatch('[^/]+') do
        if segment == '.' or segment == '..' then return nil end
    end
    return value
end
