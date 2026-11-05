local Assert = {}

function Assert.equal(expected, actual, message)
    if expected ~= actual then
        error(message or ('expected %s, received %s'):format(tostring(expected), tostring(actual)), 2)
    end
end

function Assert.truthy(value, message)
    if not value then error(message or 'expected truthy value', 2) end
end

function Assert.falsy(value, message)
    if value then error(message or 'expected falsy value', 2) end
end

return Assert
