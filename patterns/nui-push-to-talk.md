# Push-to-talk while an NUI is open

**Rule:** every RSG script that gives an NUI focus must let players keep using push-to-talk (rsg-voice) while it is open.
Reference fix: rsg-hunting commit `4b5458e` (`client/vendor.lua`, `client/leaderboard.lua`).

## How
1. Never call `SetNuiFocus` directly for open/close. Route open, close, pin/unfocus, NUI close callbacks and `onResourceStop` through one `applyNuiFocus(enable)` helper.
2. Open: `SetNuiFocus(true, true)` then `SetNuiFocusKeepInput(true)`. Close: `SetNuiFocusKeepInput(false)` first, then `SetNuiFocus(false, false)`.
3. KeepInput passes **all** keys to the game, so while focused run a per-frame whitelist: `DisableAllControlActions` on groups 0, 1, 2, then `EnableControlAction` for each push-to-talk control. Idle at `Wait(250)` when not focused.
4. Only run the whitelist while the UI actually has focus (a pinned overlay without focus does not need it).
5. Document the two config options in the resource's README.md and DOCS.md.

## config.lua
```lua
-- While NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
```

## client
```lua
local uiFocus = false

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, c in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, c, true)
                EnableControlAction(1, c, true)
                EnableControlAction(2, c, true)
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and uiFocus then applyNuiFocus(false) end
end)
```
Set `uiFocus = true` before `applyNuiFocus(true)` and back to `false` in every close path.

## Trap
When copying the helpers, don't duplicate the whitelist body after the function's `end`: the original rsg-hunting commit did this and it is a Lua syntax error that stops the client file loading.
