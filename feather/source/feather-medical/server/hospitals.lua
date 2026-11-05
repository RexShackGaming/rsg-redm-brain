MedicalHospitals = {}
local H = MedicalHospitals
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function H.Validate(points)
    if type(points) ~= 'table' then return false, 'hospitals must be a list' end
    local ids, count = {}, 0
    for key, point in pairs(points) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return false, 'hospitals must be a dense list' end
        count = count + 1
        if type(point) ~= 'table' or type(point.id) ~= 'string' or #point.id == 0 or #point.id > 64
            or ids[point.id] or type(point.label) ~= 'string' or #point.label == 0 or #point.label > 128 then
            return false, 'each hospital needs a unique id and label'
        end
        ids[point.id] = true
        for _, field in ipairs({'x', 'y', 'z', 'heading'}) do
            if not finite(point[field]) then return false, 'hospital coordinates and heading must be finite numbers' end
        end
        if point.enabled ~= nil and type(point.enabled) ~= 'boolean' then return false, 'hospital enabled must be boolean' end
    end
    if count ~= #points then return false, 'hospitals must be a dense list' end
    return true
end

function H.HasEnabled(points)
    for _, point in ipairs(points) do if point.enabled ~= false then return true end end
    return false
end

function H.Nearest(points, position)
    if not position or not finite(position.x) or not finite(position.y) or not finite(position.z) then return nil, 'position_unavailable' end
    local selected, distance
    for _, point in ipairs(points) do
        if point.enabled ~= false then
            local d = (point.x - position.x)^2 + (point.y - position.y)^2 + (point.z - position.z)^2
            if not distance or d < distance or (d == distance and point.id < selected.id) then selected, distance = point, d end
        end
    end
    if not selected then return nil, 'hospital_unavailable' end
    return {id = selected.id, label = selected.label, x = selected.x, y = selected.y, z = selected.z, heading = selected.heading}
end
return H
