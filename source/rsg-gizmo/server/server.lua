local RSGCore = exports['rsg-core']:GetCoreObject()

local function isNum(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

---Server-side check for coords sent back by a client after placement.
---Calling scripts MUST still run their own checks (items, money, zones, limits).
---@param src number
---@param coords vector3|table
---@param maxDistance number|nil
---@return boolean ok, string|nil reason
local function IsPlacementValid(src, coords, maxDistance)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return false, 'bad_coords' end
    if not (isNum(coords.x) and isNum(coords.y) and isNum(coords.z)) then return false, 'bad_coords' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'no_player' end
    local dist = #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z))
    if dist > ((maxDistance or Config.Defaults.maxDistance) + 2.0) then return false, 'too_far' end
    return true
end

---Clean a rotation table/vector from the client into a vector3 with values in range.
local function SanitiseRotation(rot)
    if type(rot) ~= 'vector3' and type(rot) ~= 'table' then return vector3(0.0, 0.0, 0.0) end
    local function c(n) return isNum(n) and (n % 360) or 0.0 end
    return vector3(c(rot.x), c(rot.y), c(rot.z))
end

exports('IsPlacementValid', IsPlacementValid)
exports('SanitiseRotation', SanitiseRotation)

if Config.TestCommand.enabled then
    RSGCore.Commands.Add(Config.TestCommand.name, locale('cmd_test_help'),
        { { name = 'model', help = locale('cmd_test_arg') } }, false,
        function(source, args)
            TriggerClientEvent('rsg-gizmo:client:test', source, args[1])
        end, Config.TestCommand.permission)
end
