local clothing = require 'data.clothing'
local hairs_list = require 'data.hairs_list'

local validHashes = nil

-- YYYY-MM-DD inside RSG.Birthdate.Min/Max and a real calendar day (no 31 Feb)
function RSG.IsValidBirthdate(date)
    if type(date) ~= 'string' then return false end
    local y, m, d = date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not (y and m and d) or m < 1 or m > 12 or d < 1 then return false end
    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
    if d > ((m == 2 and leap) and 29 or daysInMonth[m]) then return false end
    local range = RSG.Birthdate or {}
    return date >= (range.Min or '0000-00-00') and date <= (range.Max or '9999-12-31')
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