VersionerSemver = {}

local function numericCompare(left, right)
    left = left:gsub('^0+', '')
    right = right:gsub('^0+', '')
    if left == '' then left = '0' end
    if right == '' then right = '0' end
    if #left ~= #right then return #left < #right and -1 or 1 end
    if left == right then return 0 end
    return left < right and -1 or 1
end

local function splitDots(value)
    local output = {}
    for part in (value .. '.'):gmatch('(.-)%.') do output[#output + 1] = part end
    return output
end

function VersionerSemver.Parse(value)
    if type(value) ~= 'string' or #value < 5 or #value > 128 then
        return VersionerResults.Err('invalid_version', 'Version must be a bounded semantic version string.')
    end
    value = value:match('^%s*(.-)%s*$')
    if value:sub(1, 1):lower() == 'v' then value = value:sub(2) end
    local precedence, build = value, nil
    local plus = value:find('+', 1, true)
    if plus then
        if plus == #value or value:find('+', plus + 1, true) then return VersionerResults.Err('invalid_version', 'Build metadata is invalid.') end
        precedence, build = value:sub(1, plus - 1), value:sub(plus + 1)
    end
    local core, prerelease = precedence, ''
    local dash = precedence:find('-', 1, true)
    if dash then
        if dash == #precedence then return VersionerResults.Err('invalid_version', 'Prerelease identifier is invalid.') end
        core, prerelease = precedence:sub(1, dash - 1), precedence:sub(dash + 1)
    end
    -- Keep the pattern call as the assignment's final expression so Lua
    -- preserves all three captures. Routing it through `and` collapses the
    -- return list to the first capture and leaves minor/patch nil.
    local major, minor, patch = core:match('^(%d+)%.(%d+)%.(%d+)$')
    if not major then
        return VersionerResults.Err('invalid_version', 'Version must use major.minor.patch semantic versioning.', { input = value })
    end
    for _, number in ipairs({ major, minor, patch }) do
        if #number > 1 and number:sub(1, 1) == '0' then return VersionerResults.Err('invalid_version', 'Numeric identifiers cannot contain leading zeroes.') end
    end
    local identifiers = {}
    if prerelease and prerelease ~= '' then
        for _, identifier in ipairs(splitDots(prerelease)) do
            if identifier == '' or not identifier:match('^[0-9A-Za-z-]+$') or (identifier:match('^%d+$') and #identifier > 1 and identifier:sub(1, 1) == '0') then
                return VersionerResults.Err('invalid_version', 'Prerelease identifier is invalid.')
            end
            identifiers[#identifiers + 1] = identifier
        end
    end
    if build then
        for _, identifier in ipairs(splitDots(build)) do
            if identifier == '' or not identifier:match('^[0-9A-Za-z-]+$') then
                return VersionerResults.Err('invalid_version', 'Build metadata is invalid.')
            end
        end
    end
    local normalized = table.concat({ major, minor, patch }, '.')
    if #identifiers > 0 then normalized = normalized .. '-' .. table.concat(identifiers, '.') end
    if build then normalized = normalized .. '+' .. build end
    return VersionerResults.Ok({ raw = value, normalized = normalized, major = major, minor = minor, patch = patch, prerelease = identifiers, build = build })
end

function VersionerSemver.Compare(left, right)
    if type(left) == 'string' then local parsed = VersionerSemver.Parse(left); if not parsed.ok then return parsed end; left = parsed.value end
    if type(right) == 'string' then local parsed = VersionerSemver.Parse(right); if not parsed.ok then return parsed end; right = parsed.value end
    if type(left) ~= 'table' or type(right) ~= 'table' then return VersionerResults.Err('invalid_version', 'Two parsed semantic versions are required.') end
    for _, field in ipairs({ 'major', 'minor', 'patch' }) do
        local compared = numericCompare(left[field], right[field]); if compared ~= 0 then return VersionerResults.Ok(compared) end
    end
    local leftPre, rightPre = left.prerelease or {}, right.prerelease or {}
    if #leftPre == 0 and #rightPre > 0 then return VersionerResults.Ok(1) end
    if #rightPre == 0 and #leftPre > 0 then return VersionerResults.Ok(-1) end
    for index = 1, math.max(#leftPre, #rightPre) do
        if leftPre[index] == nil then return VersionerResults.Ok(-1) end
        if rightPre[index] == nil then return VersionerResults.Ok(1) end
        if leftPre[index] ~= rightPre[index] then
            local leftNumeric, rightNumeric = leftPre[index]:match('^%d+$'), rightPre[index]:match('^%d+$')
            if leftNumeric and rightNumeric then return VersionerResults.Ok(numericCompare(leftPre[index], rightPre[index])) end
            if leftNumeric then return VersionerResults.Ok(-1) end
            if rightNumeric then return VersionerResults.Ok(1) end
            return VersionerResults.Ok(leftPre[index] < rightPre[index] and -1 or 1)
        end
    end
    return VersionerResults.Ok(0)
end
