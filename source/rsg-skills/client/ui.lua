-- rsg-skills: skills panel (NUI) with push-to-talk kept working while it is open
local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

local function labels()
    return {
        title        = locale('ui_title'),
        subtitle     = locale('ui_subtitle'),
        tabSkills    = locale('ui_tab_skills'),
        tabBoard     = locale('ui_tab_board'),
        totalLevel   = locale('ui_total_level'),
        totalXP      = locale('ui_total_xp'),
        xp           = locale('ui_xp'),
        next         = locale('ui_next_level'),
        maxed        = locale('ui_max_level'),
        unlocksAt    = locale('ui_unlocks_at'),
        boardAll    = locale('board_all_time'),
        boardWeekly  = locale('board_weekly'),
        boardOverall = locale('board_overall'),
        colRank      = locale('board_col_rank'),
        colPlayer    = locale('board_col_player'),
        colLevel     = locale('board_col_level'),
        colXP        = locale('board_col_xp'),
        empty        = locale('board_empty'),
        yourRank     = locale('board_your_rank'),
        unranked     = locale('board_unranked'),
        loading      = locale('ui_loading'),
        boost        = locale('ui_boost'),
        close        = locale('ui_close'),
    }
end

-- skill / rank / perk names are locale keys (plain text also works: a missing key returns itself)
local function translate(data)
    for _, s in ipairs(data.skills) do
        s.label = locale(s.label)
        -- the default description key is hidden when it has no translation; custom text is always shown
        local defaultKey = 'skill_' .. s.key .. '_desc'
        local desc = locale(s.description)
        s.description = (s.description == defaultKey and desc == defaultKey) and '' or desc
        s.rank = locale(s.rank)
        for _, p in ipairs(s.perks) do
            p.label = locale(p.label)
        end
    end
    return data
end

function CloseSkills()
    if not uiOpen then return end
    uiOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

function OpenSkills()
    -- using the command again closes the panel
    if uiOpen then return CloseSkills() end

    local data = RSGCore.Functions.AwaitCallback('rsg-skills:server:getSkills', 5000)
    if not data then
        RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale('ui_unavailable'), type = 'error' })
        return
    end

    uiOpen = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', data = translate(data), labels = labels(), weeklyEnabled = Config.Weekly and Config.Weekly.Enabled or false })
end

exports('OpenSkills', OpenSkills)
exports('CloseSkills', CloseSkills)

RegisterNUICallback('close', function(_, cb)
    if uiOpen then
        uiOpen = false
        applyNuiFocus(false)
    end
    cb('ok')
end)

-- the server only accepts known modes and skill keys, so passing the NUI values straight through is safe
RegisterNUICallback('leaderboard', function(body, cb)
    if not uiOpen then return cb({}) end
    local mode = type(body) == 'table' and body.mode or 'all'
    local skill = type(body) == 'table' and body.skill or 'all'
    local data = RSGCore.Functions.AwaitCallback('rsg-skills:server:getLeaderboard', 5000, mode, skill)
    cb(data or {})
end)

CreateThread(function()
    local cmd = Config.Command
    if cmd and cmd ~= '' then
        RegisterCommand(cmd, OpenSkills, false)
        TriggerEvent('chat:addSuggestion', '/' .. cmd, locale('cmd_open_help'))
    end
end)

-- keep push-to-talk usable while the panel has focus
CreateThread(function()
    while true do
        if uiOpen and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    CloseSkills()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and uiOpen then
        applyNuiFocus(false)
    end
end)
