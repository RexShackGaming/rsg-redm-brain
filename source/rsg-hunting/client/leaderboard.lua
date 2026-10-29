lib.locale()

------------------------------------------
-- hunting leaderboard (movable NUI panel)
------------------------------------------
local boardOpen = false   -- visible on screen
local boardFocus = false  -- has mouse focus (not pinned)

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
    }
end

local function closeBoard()
    if not boardOpen then return end
    boardOpen, boardFocus = false, false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'boardClose' })
end

function OpenHuntingLeaderboard()
    -- command while pinned / open = close it again
    if boardOpen then return closeBoard() end

    local data = lib.callback.await('rsg-hunting:server:getLeaderboard', false)
    if not data then
        lib.notify({ title = locale('hunting_board_title'), description = locale('hunting_board_unavailable'), type = 'error' })
        return
    end

    boardOpen, boardFocus = true, true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'boardOpen', labels = labels(), top = data.top, total = data.total, me = data.me })
end

RegisterNUICallback('boardClose', function(_, cb)
    boardOpen, boardFocus = false, false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- pinned: stays on screen, control goes back to the game
RegisterNUICallback('boardPin', function(_, cb)
    boardFocus = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- keep a pinned board up to date
CreateThread(function()
    while true do
        if boardOpen then
            Wait(math.max(15, (Config.HuntingXP.Leaderboard.CacheSeconds or 60)) * 1000)
            if boardOpen then
                local data = lib.callback.await('rsg-hunting:server:getLeaderboard', false)
                if data and boardOpen then
                    SendNUIMessage({ action = 'boardUpdate', top = data.top, total = data.total, me = data.me })
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

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and boardFocus then
        SetNuiFocus(false, false)
    end
end)
