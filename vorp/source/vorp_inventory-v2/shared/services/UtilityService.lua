local SharedUtils <const> = {
    TABLE_EQUALS = function(o1, o2, ignore_mt)
        if o1 == o2 then return true end
        local o1Type = type(o1)
        local o2Type = type(o2)
        if o1Type ~= o2Type then return false end

        if o1Type ~= 'table' then return false end

        if not ignore_mt then
            local mt1 = getmetatable(o1)
            if mt1 and mt1.__eq then
                --compare using built in method
                return o1 == o2
            end
        end

        local keySet = {}

        for key1, value1 in pairs(o1) do
            local value2 = o2[key1]
            if value2 == nil or SHARED_UTILS.TABLE_EQUALS(value1, value2, ignore_mt) == false then
                return false
            end
            keySet[key1] = true
        end

        for key2, _ in pairs(o2) do
            if not keySet[key2] then return false end
        end

        return true
    end,
    TABLE_CONTAINS = function(o1, o2)
        if o1 == o2 then return true end
        local o1Type = type(o1)
        local o2Type = type(o2)

        if o1Type ~= o2Type then
            return false
        end

        if o1Type ~= 'table' or o2Type ~= 'table' then
            return false
        end

        for key2, value2 in pairs(o2) do
            local value1 = o1[key2]
            if value1 == nil or not SHARED_UTILS.TABLE_EQUALS(value1, value2, true) then
                return false
            end
        end

        return true
    end,

    TO_TABLE = function(v)
        if v == nil then return {} end

        if type(v) == "string" then
            local decoded = json.decode(v)
            if type(decoded) ~= "table" then
                return {}
            end
            v = decoded
        end

        if type(v) == "table" or type(v) == "userdata" then
            local t = {}
            for k, val in pairs(v) do t[k] = val end
            return t
        end

        return {}
    end,

    MERGE_TABLES = function(a, b)
        local A = SHARED_UTILS.TO_TABLE(a)
        local B = SHARED_UTILS.TO_TABLE(b)

        local newTable = {}
        for k, v in pairs(A) do
            newTable[k] = v
        end
        for k, v in pairs(B) do
            newTable[k] = v
        end

        return newTable
    end,
    IS_VALUE_IN_ARRAY = function(value, array)
        for _, v in ipairs(array) do
            if v == value then
                return true
            end
        end
        return false
    end,

}

SHARED_UTILS = SharedUtils
