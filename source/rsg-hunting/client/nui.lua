------------------------------------------
-- shared NUI focus manager (trapper sell UI + leaderboard)
-- every open/close goes through HuntingNui.Focus so push-to-talk keeps working
-- and one UI closing never steals focus from another that is still open
------------------------------------------
HuntingNui = {}

local owners, count = {}, 0

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

-- owner = any unique string ('sell', 'board'); enable = true/false
function HuntingNui.Focus(owner, enable)
    if enable then
        if not owners[owner] then owners[owner] = true; count = count + 1 end
        applyNuiFocus(true)
    elseif owners[owner] then
        owners[owner] = nil
        count = count - 1
        if count == 0 then applyNuiFocus(false) end
    end
end

-- block game controls while a UI has focus, but let push-to-talk through
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

CreateThread(function()
    while true do
        if count > 0 and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if count > 0 then
        owners, count = {}, 0
        applyNuiFocus(false)
    end
end)
