------------------------------------------
-- skill gates: dangerous animals need hunting level (and optionally an rsg-skills level)
------------------------------------------
HuntingGates = {}

-- returns true, or false + the failing requirement ('level' or 'skill') and the number needed
function HuntingGates.Check(src, model)
    local gate = Config.Gates and Config.Gates[model]
    if not gate then return true end

    if gate.level and Config.HuntingXP and Config.HuntingXP.Enabled then
        local lvl = HuntingXP.GetLevelData(HuntingXP.GetXP(src))
        if (lvl.level or 1) < gate.level then return false, 'level', gate.level end
    end
    if gate.skill and SkillsActive() then
        local ok, level = pcall(function() return exports['rsg-skills']:GetLevel(src, Config.Skills.Skill) end)
        if ok and (tonumber(level) or 0) < gate.skill then return false, 'skill', gate.skill end
    end
    return true
end

function HuntingGates.Notify(src, why, need)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('hunting_xp_title'),
        description = locale(why == 'skill' and 'gate_skill' or 'gate_level', need),
        type = 'error',
        duration = 7000,
    })
end
