-- Shared by client and server so both compute identical child positions for a placed group.
Gizmo = {}

---World position + heading of every item in a group placement.
---Groups are heading-only (no pitch/roll), so the maths is exact on both sides.
---@param items table[] list of { model, offset = vector3|nil, heading = number|nil }; item 1 is the anchor
---@param coords vector3 anchor position
---@param heading number anchor heading in degrees
---@return table[] list of { model, coords = vector3, heading = number }
function Gizmo.GroupTransform(items, coords, heading)
    heading = type(heading) == 'number' and heading or 0.0
    local rad = math.rad(heading)
    local c, s = math.cos(rad), math.sin(rad)
    local out = {}
    for i, it in ipairs(items) do
        local off = it.offset or vector3(0.0, 0.0, 0.0)
        out[i] = {
            model = it.model,
            coords = vector3(coords.x + off.x * c - off.y * s, coords.y + off.x * s + off.y * c, coords.z + off.z),
            heading = (heading + (it.heading or 0.0)) % 360,
        }
    end
    return out
end

exports('GroupTransform', Gizmo.GroupTransform)
