-- Drives the always-on Resource Strip NUI (cash/gold/tokens/XP). Unlike the
-- old togglable popup this replaced, the NUI page is live from resource
-- start, not opened on demand -- so there's no "toggle" event to hang state
-- pushes off of. Instead:
--   1. The page calls the 'ready' NUI callback once it's mounted, and Lua
--      answers synchronously with both the validated config and the
--      current state in one round trip (see RegisterNUICallback below).
--      This sidesteps the classic NUI race where a SendNUIMessage fires
--      before the page's JS listener is attached -- a real risk here since
--      there's no user action (like opening a menu) to guarantee the page
--      has had time to load first.
--   2. After that, every economy/spawn/revive event pushes a fresh
--      SendNUIMessage the same way the old popup did.
local state = {
    cash = 0,
    gold = 0,
    cashMinor = 0,
    goldMinor = 0,
    cashPrecision = 2,
    goldPrecision = 2,
    tokens = 0,
    xp = 0,
    level = 1,
    xpPercent = 0,
    visible = false
}

-- Derives level/xpPercent from raw xp -- there's no `level` column/field
-- anywhere in the character schema (checked feather-recipe's migration.sql),
-- so this is the only source of truth for it.
local function applyCharacter(character)
    if not character then return end

    state.tokens = tonumber(character.tokens) or 0

    local xp = tonumber(character.xp) or 0
    local perLevel = math.max(1, tonumber(Config.XPPerLevel) or 1900)

    state.xp = xp
    state.level = math.floor(xp / perLevel) + 1
    state.xpPercent = math.floor((xp % perLevel) / perLevel * 100)
end

local paused, refreshRequested, epoch = false, true, 0
local function pushState()
    local snapshot = {}
    for key, value in pairs(state) do snapshot[key] = value end
    snapshot.visible = state.visible and not paused
    SendNUIMessage({
        type = 'state',
        state = snapshot
    })
end

-- Falls back to HudPosition.BottomRight on anything that isn't one of the
-- HudPosition.* values from config.lua -- a server owner typo shouldn't be
-- able to break the NUI's layout math.
local function validAnchors()
    local valid = {}
    for _, value in pairs(HudPosition) do
        valid[value] = true
    end
    return valid
end

local function getValidatedConfig()
    local valid = validAnchors()
    local anchor = Config.ResourceStrip.anchor

    if not valid[anchor] then
        print(("[feather-hud] Config.ResourceStrip.anchor (%s) is not a valid HudPosition value -- falling back to bottom-right"):format(tostring(anchor)))
        anchor = HudPosition.BottomRight
    end

    return {
        anchor = anchor,
        padding = tonumber(Config.ResourceStrip.padding) or 26,
        topPadding = tonumber(Config.ResourceStrip.topPadding) or 56,
        scale = tonumber(Config.ResourceStrip.scale) or 1.0,
        scrim = Config.ResourceStrip.scrim ~= false
    }
end

RegisterNUICallback('ready', function(_, cb)
    cb({
        config = getValidatedConfig(),
        state = state
    })
end)

RegisterNetEvent("Feather:Character:Spawned", function(character)
    epoch = epoch + 1
    state.visible = false
    refreshRequested = true
    applyCharacter(character)
    pushState()
end)

RegisterNetEvent('feather-hud:wallets:invalidate', function() refreshRequested = true end)

RegisterNetEvent('Feather:Character:Logout', function()
    epoch = epoch + 1
    state.visible = false
    state.cash, state.gold, state.tokens, state.xp = 0, 0, 0, 0
    state.cashMinor, state.goldMinor = 0, 0
    state.level, state.xpPercent = 1, 0
    refreshRequested = true
    pushState()
end)

RegisterNetEvent("Feather:Character:Revive", function()
    refreshRequested = true
    pushState()
end)

-- Feather:Character:Spawned only fires once, at the moment of spawning --
-- it never replays for a resource that (re)starts after that already
-- happened. Ask the server directly on start: a successful reply is proof
-- a character is currently active, so the strip doesn't stay stuck hidden
-- until the player's next actual spawn.
-- Money comes exclusively from Economy. Serialized refreshes also recover
-- missed invalidation signals and HUD restarts; Character retains tokens/XP.
CreateThread(function()
    local ready = exports['feather-core']:AwaitReady(30000)
    if type(ready) ~= 'table' or not ready.ok then return end
    local lastRead = -10000
    while true do
        Wait(250)
        local now = GetGameTimer()
        if (refreshRequested or now - lastRead >= 10000) and now - lastRead >= 1500 then
            refreshRequested, lastRead = false, now
            local expectedEpoch = epoch
            local called, result = pcall(function() return FeatherCore.RPC.CallAsync('hud.state.get.v1', {}, nil, 5000) end)
            if expectedEpoch == epoch then
                if called and type(result) == 'table' and result.ok and type(result.value) == 'table'
                    and type(result.value.cash) == 'number' and type(result.value.gold) == 'number'
                    and type(result.value.cashMinor) == 'number' and type(result.value.goldMinor) == 'number'
                    and type(result.value.cashPrecision) == 'number' and type(result.value.goldPrecision) == 'number' then
                    state.cash, state.gold, state.visible = result.value.cash, result.value.gold, true
                    state.cashMinor, state.goldMinor = result.value.cashMinor, result.value.goldMinor
                    state.cashPrecision, state.goldPrecision = result.value.cashPrecision, result.value.goldPrecision
                else state.visible = false end
                pushState()
            end
        end
    end
end)

-- Hide the strip while the pause menu is open; edge-triggered so it only
-- pushes an NUI update on actual state changes, not every frame.

CreateThread(function()
    while true do
        Wait(0)
        local nowPaused = IsPauseMenuActive()
        if nowPaused ~= paused then
            paused = nowPaused
            pushState()
        end
    end
end)
