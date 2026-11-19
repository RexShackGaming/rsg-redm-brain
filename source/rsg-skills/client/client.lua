-- rsg-skills: read-only mirror of the player's skills for client-side scripts.
-- The server is the only place XP can change. Never base rewards, prices or items on these values
-- without the server checking them again (use the server exports for that).
local mirror = {} -- [skill] = { xp, level, perks = { perk = value } }

RegisterNetEvent('rsg-skills:client:sync', function(data, partial)
    if type(data) ~= 'table' then return end
    if not partial then mirror = {} end
    for skill, entry in pairs(data) do
        mirror[skill] = entry
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    mirror = {}
end)

exports('GetXP', function(skill)
    local s = mirror[skill]
    return s and s.xp or 0
end)

-- returns level (1 when unknown)
exports('GetLevel', function(skill)
    local s = mirror[skill]
    return s and s.level or 1
end)

exports('HasLevel', function(skill, level)
    local s = mirror[skill]
    return (s and s.level or 1) >= (tonumber(level) or 1)
end)

-- returns the perk value at the player's current level (0 when none)
exports('GetPerk', function(skill, perk)
    local s = mirror[skill]
    return s and s.perks and s.perks[perk] or 0
end)

exports('GetSkills', function()
    return mirror
end)
