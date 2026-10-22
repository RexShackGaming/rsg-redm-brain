local clothing = require 'data.clothing'
local hairs_list = require 'data.hairs_list'

local validHashes = nil
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