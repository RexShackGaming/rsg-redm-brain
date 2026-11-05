FeatherAuditProducerId = {}

local function randomByte()
    return math.random(0, 255)
end

function FeatherAuditProducerId.Generate()
    local bytes = {}
    for index = 1, 16 do bytes[index] = randomByte() end
    bytes[7] = (bytes[7] % 16) + 64
    bytes[9] = (bytes[9] % 64) + 128
    local hex = {}
    for index, value in ipairs(bytes) do hex[index] = ('%02x'):format(value) end
    return table.concat(hex, '', 1, 4) .. '-' .. table.concat(hex, '', 5, 6) .. '-'
        .. table.concat(hex, '', 7, 8) .. '-' .. table.concat(hex, '', 9, 10) .. '-'
        .. table.concat(hex, '', 11, 16)
end
