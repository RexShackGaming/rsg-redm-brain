-- Minimal native-event buffer used by Feather World's focused event dispatcher.
WorldEventBuffer = {}

local makeBlob = string.blob or function(length)
    return string.rep('\0', math.max(41, length))
end

function WorldEventBuffer.Create(fieldCount)
    local blob = makeBlob(fieldCount * 8)
    return {
        Buffer = function()
            return blob
        end,
        ReadInt = function(_, index)
            return string.unpack('<i4', blob, (index * 8) + 1)
        end,
        ReadFloat = function(_, index)
            return string.unpack('<f', blob, (index * 8) + 1)
        end
    }
end
