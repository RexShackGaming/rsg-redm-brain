local RSGCore = exports['rsg-core']:GetCoreObject()
------------------------------------------
-- hunting leaderboard (movable NUI panel)
------------------------------------------
local boardOpen = false   -- visible on screen
local boardFocus = false  -- has mouse focus (not pinned)
local boardMode = 'all'   -- 'all' | 'weekly'

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
    if not Config.AllowPushToTalkWhileOpen then return end
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
        title     = locale('hunting_board_title'),
        total     = locale('hunting_board_total'),
        level     = locale('hunting_board_level'),
        unranked  = locale('hunting_board_unranked'),
        next      = locale('hunting_board_next'),
        maxed     = locale('hunting_board_maxed'),
        trapper   = locale('hunting_board_trapper'),
        butcher   = locale('hunting_board_butcher'),
        extraSkin = locale('hunting_board_extraskin'),
        empty     = locale('hunting_board_empty'),
        hint      = locale('hunting_board_hint'),
        xp        = locale('hunting_board_xp'),
        drag      = locale('hunting_board_drag'),
        pin       = locale('hunting_board_pin'),
        close     = locale('ui_close'),
        allTime   = locale('hunting_board_alltime'),
        weekly    = locale('hunting_board_weekly'),
        weekXP    = locale('hunting_board_weekxp'),
        bounties  = locale('bounty_title'),
        rewards   = locale('hunting_board_rewards'),
        unclaimed = locale('hunting_board_unclaimed'),
    }
end

local function closeBoard()
    if not boardOpen then return end
    boardOpen, boardFocus = false, false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'boardClose' })
end

function OpenHuntingLeaderboard()
    -- command while pinned / open = close it again
    if boardOpen then return closeBoard() end

    boardMode = 'all'
    local data = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getLeaderboard', nil, boardMode)
    if not data then
        RSGCore.Functions.Notify({ title = locale('hunting_board_title'), description = locale('hunting_board_unavailable'), type = 'error' })
        return
    end

    boardOpen, boardFocus = true, true
    applyNuiFocus(true)
    data.action, data.labels = 'boardOpen', labels()
    SendNUIMessage(data)
end

RegisterNUICallback('boardClose', function(_, cb)
    boardOpen, boardFocus = false, false
    applyNuiFocus(false)
    cb('ok')
end)

-- switch all-time / weekly tab
RegisterNUICallback('boardMode', function(body, cb)
    boardMode = body and body.mode == 'weekly' and 'weekly' or 'all'
    local data = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getLeaderboard', nil, boardMode)
    if data and boardOpen then
        data.action = 'boardUpdate'
        SendNUIMessage(data)
    end
    cb('ok')
end)

-- pinned: stays on screen, control goes back to the game
RegisterNUICallback('boardPin', function(_, cb)
    boardFocus = false
    applyNuiFocus(false)
    cb('ok')
end)

-- keep a pinned board up to date
CreateThread(function()
    while true do
        if boardOpen then
            Wait(math.max(15, (Config.HuntingXP.Leaderboard.CacheSeconds or 60)) * 1000)
            if boardOpen then
                local data = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getLeaderboard', nil, boardMode)
                if data and boardOpen then
                    data.action = 'boardUpdate'
                    SendNUIMessage(data)
                end
            end
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    local cmd = Config.HuntingXP and Config.HuntingXP.Enabled and Config.HuntingXP.Leaderboard.Command
    if cmd and cmd ~= '' then
        RegisterCommand(cmd, OpenHuntingLeaderboard, false)
        TriggerEvent('chat:addSuggestion', '/' .. cmd, locale('hunting_board_title'))
    end
end)

CreateThread(function()
    while true do
        if boardFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and boardFocus then
        applyNuiFocus(false)
    end
end)
