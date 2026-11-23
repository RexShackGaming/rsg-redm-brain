local RSGCore = exports['rsg-core']:GetCoreObject()

local function isNum(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

local function limitDistance(maxDistance)
    if not isNum(maxDistance) then maxDistance = Config.Defaults.maxDistance end
    if Config.Limits.enabled then maxDistance = math.min(maxDistance, Config.Limits.maxDistance) end
    return maxDistance
end

---Server-side check for coords sent back by a client after placement.
---Calling scripts MUST still run their own checks (items, money, zones, limits).
---@param src number
---@param coords vector3|table
---@param maxDistance number|nil
---@return boolean ok, string|nil reason
local function IsPlacementValid(src, coords, maxDistance)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return false, 'bad_coords' end
    if not (isNum(coords.x) and isNum(coords.y) and isNum(coords.z)) then return false, 'bad_coords' end
    if Config.Limits.enabled and (coords.z < Config.Limits.minZ or coords.z > Config.Limits.maxZ) then
        return false, 'out_of_bounds'
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'no_player' end
    local dist = #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z))
    if dist > (limitDistance(maxDistance) + 2.0) then return false, 'too_far' end
    return true
end

---Clean a rotation table/vector from the client into a vector3 with values in range.
local function SanitiseRotation(rot)
    if type(rot) ~= 'vector3' and type(rot) ~= 'table' then return vector3(0.0, 0.0, 0.0) end
    local function c(n) return isNum(n) and (n % 360) or 0.0 end
    return vector3(c(rot.x), c(rot.y), c(rot.z))
end

---Validate a group placement (PlaceMany) and rebuild every item's position on the server.
---`items` must come from YOUR server config, never from the client: only the anchor coords and heading
---are taken from the client, children are calculated here with the same maths the client used.
---@param src number
---@param items table[] { model, offset?, heading? }
---@param coords vector3 anchor coords sent by the client
---@param heading number heading sent by the client
---@param maxDistance number|nil
---@return boolean ok, string|nil reasonOrNil, table[]|nil placed list of { model, coords, heading }
local function IsGroupPlacementValid(src, items, coords, heading, maxDistance)
    if type(items) ~= 'table' or #items == 0 then return false, 'bad_items' end
    local ok, reason = IsPlacementValid(src, coords, maxDistance)
    if not ok then return false, reason end
    heading = isNum(heading) and (heading % 360) or 0.0
    local placed = Gizmo.GroupTransform(items, vector3(coords.x, coords.y, coords.z), heading)
    if Config.Limits.enabled then
        for _, p in ipairs(placed) do
            if p.coords.z < Config.Limits.minZ or p.coords.z > Config.Limits.maxZ then return false, 'out_of_bounds' end
        end
    end
    return true, nil, placed
end

exports('IsPlacementValid', IsPlacementValid)
exports('SanitiseRotation', SanitiseRotation)
exports('IsGroupPlacementValid', IsGroupPlacementValid)

if Config.TestCommand.enabled then
    RSGCore.Commands.Add(Config.TestCommand.name, locale('cmd_test_help'),
        { { name = 'model', help = locale('cmd_test_arg') } }, false,
        function(source, args)
            TriggerClientEvent('rsg-gizmo:client:test', source, args[1])
        end, Config.TestCommand.permission)

    RSGCore.Commands.Add(Config.TestCommand.groupName, locale('cmd_testgroup_help'), {}, false,
        function(source)
            TriggerClientEvent('rsg-gizmo:client:testgroup', source)
        end, Config.TestCommand.permission)
end
