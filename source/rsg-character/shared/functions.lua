local clothing = require 'data.clothing'
local hairs_list = require 'data.hairs_list'

local validHashes = nil

-- Effective birthdate range: RSG.Birthdate.Min/Max, narrowed by MinAge/MaxAge relative to GameYear.
-- Returns minDate, maxDate as YYYY-MM-DD strings.
function RSG.GetBirthdateRange()
    local range = RSG.Birthdate or {}
    local minDate = range.Min or '0000-00-00'
    local maxDate = range.Max or '9999-12-31'
    local gameYear = tonumber(range.GameYear)
    if gameYear then
        local maxAge, minAge = tonumber(range.MaxAge), tonumber(range.MinAge)
        if maxAge then
            local lo = ('%04d-01-01'):format(gameYear - maxAge)
            if lo > minDate then minDate = lo end
        end
        if minAge then
            local hi = ('%04d-12-31'):format(gameYear - minAge)
            if hi < maxDate then maxDate = hi end
        end
    end
    return minDate, maxDate
end

-- YYYY-MM-DD, a real calendar day (no 31 Feb) and inside RSG.GetBirthdateRange()
function RSG.IsValidBirthdate(date)
    if type(date) ~= 'string' then return false end
    local y, m, d = date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not (y and m and d) or m < 1 or m > 12 or d < 1 then return false end
    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
    if d > ((m == 2 and leap) and 29 or daysInMonth[m]) then return false end
    local minDate, maxDate = RSG.GetBirthdateRange()
    return date >= minDate and date <= maxDate
end

-- First / last name check, shared by the creator (client) and the server (the server decides).
-- Rules live in RSG.NameRules: letters incl. accents, one apostrophe or hyphen between letters,
-- optional single spaces, limited capitals (McGregor, DeLuca), blocked words and reserved names.
function RSG.IsValidName(name)
    local rules = RSG.NameRules or {}
    if type(name) ~= 'string' then return false end
    local len = utf8.len(name)
    if not len or len < (rules.MinLength or 2) or len > (rules.MaxLength or 20) then return false end

    local capitals, letters = 0, 0
    local prev -- 'upper' | 'lower' | 'sep'
    local first, last = true, nil
    for _, cp in utf8.codes(name) do
        local kind
        if cp >= 65 and cp <= 90 then
            kind = 'upper'
        elseif cp >= 97 and cp <= 122 then
            kind = 'lower'
        elseif cp == 39 or cp == 45 then -- ' and -
            kind = 'sep'
        elseif cp == 32 and rules.AllowSpaces then
            kind = 'sep'
        elseif cp >= 0xC0 and cp ~= 0xD7 and cp ~= 0xF7 then -- Latin-1 and beyond: accented letters
            kind = 'lower'
        else
            return false
        end
        if first then
            if kind == 'sep' or kind == 'lower' and cp < 0x80 then return false end
            first = false
        end
        if kind == 'sep' and prev == 'sep' then return false end
        if kind == 'upper' then
            capitals = capitals + 1
            if prev == 'upper' then return false end
        end
        if kind ~= 'sep' then letters = letters + 1 end
        prev, last = kind, kind
    end
    if last == 'sep' or letters < 2 or capitals > (rules.MaxCapitals or 3) then return false end

    local lower = name:lower()
    if rules.ProfanityWords and rules.ProfanityWords[lower] then return false end
    for _, word in ipairs(rules.BlockedSubstrings or {}) do
        if lower:find(word, 1, true) then return false end
    end
    return true
end

-- true when "first last" is on RSG.NameRules.ReservedNames
function RSG.IsReservedName(firstname, lastname)
    local reserved = RSG.NameRules and RSG.NameRules.ReservedNames
    if not reserved or type(firstname) ~= 'string' or type(lastname) ~= 'string' then return false end
    return reserved[(firstname .. ' ' .. lastname):lower()] == true
end

local function BuildValidHashSet()
    if validHashes then return end
    validHashes = {}
    local function indexInto(data)
        for gender, genderData in pairs(data) do
            validHashes[gender] = validHashes[gender] or {}
            for category, categoryData in pairs(genderData) do
                validHashes[gender][category] = validHashes[gender][category] or {}
                for _, modelData in pairs(categoryData) do
                    for _, textureData in pairs(modelData) do
                        if textureData.hash then
                            validHashes[gender][category][tonumber(textureData.hash)] = true
                        end
                    end
                end
            end
        end
    end
    indexInto(clothing)
    indexInto(hairs_list)
end

function ValidateClothesData(newClothes, isMale)
    if type(newClothes) ~= 'table' then
        return false, locale('clothing_validation.invalid_data')
    end
    BuildValidHashSet()
    local genderKey = isMale and 'male' or 'female'
    local clothingG = clothing[genderKey]
    for categoryName, item in pairs(newClothes) do
        if type(item) ~= 'table' then
            return false, locale('clothing_validation.invalid_item', tostring(categoryName))
        end
        if not clothingG[categoryName] then
            if not hairs_list[genderKey] or not hairs_list[genderKey][categoryName] then
                return false, locale('clothing_validation.invalid_category', tostring(categoryName))
            end
        end
        if item.hash then
            local hash = tonumber(item.hash)
            local categoryHashes = validHashes[genderKey] and validHashes[genderKey][categoryName]
            if not hash or not categoryHashes or not categoryHashes[hash] then
                return false, locale('clothing_validation.invalid_hash', tostring(categoryName))
            end
        end
    end
    return true
end

function CalculatePrice(newClothes, currentClothes, isMale)
    local price = 0
    local clothingG = isMale and clothing['male'] or clothing['female']
    for categoryName,_ in pairs(clothingG) do
        local newHash = newClothes[categoryName]?.hash
        local currentHash = currentClothes[categoryName]?.hash
        if newHash and newHash ~= currentHash then
            price = price + (RSG.Price[categoryName] or 0)
        end
    end
    return price
end