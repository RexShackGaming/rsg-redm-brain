-- rsg-skills: admin commands (permission: Config.AdminPermission)
RSGSkills = RSGSkills or {}
local RSGCore = exports['rsg-core']:GetCoreObject()
local TAG = '[rsg-skills]'
local Defs = RSGSkills.Defs

local function reply(source, text, kind)
    if source == 0 then
        print(('%s %s'):format(TAG, text))
        return
    end
    TriggerClientEvent('RSGCore:Client:Notify', source, {
        title = locale('notify_title'),
        description = text,
        type = kind or 'inform',
        duration = 6000,
    })
end

local function audit(source, text)
    local who = source == 0 and 'console' or ('%s [%d]'):format(GetPlayerName(source) or '?', source)
    print(('%s %s: %s'):format(TAG, who, text))
end

-- resolves "id skill" arguments. Returns targetSrc, skillKey or nil (after telling the admin why)
local function resolve(source, args)
    local target = tonumber(args[1])
    if not target or not RSGCore.Functions.GetPlayer(target) then
        reply(source, locale('cmd_player_offline'), 'error')
        return nil
    end
    local skill = tostring(args[2] or ''):lower()
    if not Defs[skill] then
        local keys = {}
        for _, k in ipairs(RSGSkills.Order) do keys[#keys + 1] = k end
        reply(source, locale('cmd_unknown_skill', table.concat(keys, ', ')), 'error')
        return nil
    end
    return target, skill
end

local perm = Config.AdminPermission or 'admin'

RSGCore.Commands.Add('addskillxp', locale('cmd_addxp_help'), {
    { name = locale('cmd_arg_id'), help = locale('cmd_arg_id_help') },
    { name = locale('cmd_arg_skill'), help = locale('cmd_arg_skill_help') },
    { name = locale('cmd_arg_amount'), help = locale('cmd_arg_amount_help') },
}, true, function(source, args)
    local target, skill = resolve(source, args)
    if not target then return end
    local amount = tonumber(args[3])
    if not amount or amount <= 0 then return reply(source, locale('cmd_invalid_number'), 'error') end
    -- admin awards skip multipliers and the per-award cap, and do not count toward weekly boards
    local ok, xp, level = RSGSkills.AddXP(target, skill, amount, 'admin', { raw = true, noWeekly = true })
    if not ok then return reply(source, locale('cmd_failed', tostring(xp)), 'error') end
    audit(source, ('added %d %s xp to %d (now %d xp, level %d)'):format(math.floor(amount), skill, target, xp, level))
    reply(source, locale('cmd_done', locale(Defs[skill].label), level, xp), 'success')
end, perm)

RSGCore.Commands.Add('setskillxp', locale('cmd_setxp_help'), {
    { name = locale('cmd_arg_id'), help = locale('cmd_arg_id_help') },
    { name = locale('cmd_arg_skill'), help = locale('cmd_arg_skill_help') },
    { name = locale('cmd_arg_xp'), help = locale('cmd_arg_xp_help') },
}, true, function(source, args)
    local target, skill = resolve(source, args)
    if not target then return end
    local amount = tonumber(args[3])
    if not amount or amount < 0 then return reply(source, locale('cmd_invalid_number'), 'error') end
    local ok, xp, level = RSGSkills.SetXP(target, skill, amount)
    if not ok then return reply(source, locale('cmd_failed', tostring(xp)), 'error') end
    audit(source, ('set %s xp of %d to %d (level %d)'):format(skill, target, xp, level))
    reply(source, locale('cmd_done', locale(Defs[skill].label), level, xp), 'success')
end, perm)

RSGCore.Commands.Add('setskilllevel', locale('cmd_setlevel_help'), {
    { name = locale('cmd_arg_id'), help = locale('cmd_arg_id_help') },
    { name = locale('cmd_arg_skill'), help = locale('cmd_arg_skill_help') },
    { name = locale('cmd_arg_level'), help = locale('cmd_arg_level_help') },
}, true, function(source, args)
    local target, skill = resolve(source, args)
    if not target then return end
    local lvl = tonumber(args[3])
    if not lvl or lvl < 1 then return reply(source, locale('cmd_invalid_number'), 'error') end
    local ok, xp, level = RSGSkills.SetLevel(target, skill, lvl)
    if not ok then return reply(source, locale('cmd_failed', tostring(xp)), 'error') end
    audit(source, ('set %s level of %d to %d (%d xp)'):format(skill, target, level, xp))
    reply(source, locale('cmd_done', locale(Defs[skill].label), level, xp), 'success')
end, perm)

RSGCore.Commands.Add('resetskill', locale('cmd_reset_help'), {
    { name = locale('cmd_arg_id'), help = locale('cmd_arg_id_help') },
    { name = locale('cmd_arg_skill'), help = locale('cmd_arg_skill_help') },
}, true, function(source, args)
    local target, skill = resolve(source, args)
    if not target then return end
    local ok, xp, level = RSGSkills.SetXP(target, skill, 0)
    if not ok then return reply(source, locale('cmd_failed', tostring(xp)), 'error') end
    audit(source, ('reset %s of %d'):format(skill, target))
    reply(source, locale('cmd_done', locale(Defs[skill].label), level, xp), 'success')
end, perm)

RSGCore.Commands.Add('skillinfo', locale('cmd_info_help'), {
    { name = locale('cmd_arg_id'), help = locale('cmd_arg_id_help') },
}, true, function(source, args)
    local target = tonumber(args[1])
    if not target or not RSGCore.Functions.GetPlayer(target) then
        return reply(source, locale('cmd_player_offline'), 'error')
    end
    local skills = RSGSkills.GetSkills(target)
    local lines = {}
    for _, key in ipairs(RSGSkills.Order) do
        local s = skills[key]
        if s then lines[#lines + 1] = ('%s: %d (%d xp)'):format(locale(Defs[key].label), s.level, s.xp) end
    end
    local text = table.concat(lines, ' | ')
    if source == 0 then
        print(('%s [%d] %s'):format(TAG, target, text))
    else
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 255, 255 }, multiline = true, args = { TAG, text } })
    end
end, perm)

RSGCore.Commands.Add('skillboost', locale('cmd_boost_help'), {
    { name = locale('cmd_arg_multiplier'), help = locale('cmd_arg_multiplier_help') },
    { name = locale('cmd_arg_minutes'), help = locale('cmd_arg_minutes_help') },
}, false, function(source, args)
    local mult, minutes = tonumber(args[1]), tonumber(args[2])
    if not mult or mult <= 1.0 then
        RSGSkills.SetBoost(1.0, 0)
        audit(source, 'cleared the xp boost')
        return reply(source, locale('boost_cleared'), 'success')
    end
    if not minutes or minutes <= 0 then return reply(source, locale('cmd_invalid_number'), 'error') end
    local appliedMult, appliedMinutes = RSGSkills.SetBoost(mult, minutes)
    audit(source, ('started a x%s xp boost for %d minutes'):format(appliedMult, appliedMinutes))
    TriggerClientEvent('RSGCore:Client:Notify', -1, {
        title = locale('boost_title'),
        description = locale('boost_started', appliedMult, appliedMinutes),
        type = 'success',
        duration = 10000,
    })
end, perm)
