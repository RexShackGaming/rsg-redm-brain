local runtimeConfig = Config.PlayerRuntime
local started = false

PlayerRuntimeActive = false
LootPromptSuppressionActive = false

local function ClearChallengeFeed()
    Citizen.InvokeNative(0x6035E8FBCA32AC5E)
end

local function EnforceDisabledControls()
    if runtimeConfig.disableWeaponSoftlockControls then
        DisableControlAction(0, 0x7DA48D2A, true)
    end

    if runtimeConfig.disableWeaponSoftlockControls or runtimeConfig.disableFrameworkHudControls then
        DisableControlAction(0, 0x9CC7A1A4, true)
    end

    if runtimeConfig.disableFrameworkHudControls then
        DisableControlAction(0, 0x580C4473, true)
        DisableControlAction(0, 0xCF8A4ECA, true)
        DisableControlAction(0, 0x1F6D95E5, true)
    end
end

local function StartControlSafeguards()
    if not runtimeConfig.disableWeaponSoftlockControls and not runtimeConfig.disableFrameworkHudControls then return end

    CreateThread(function()
        while PlayerRuntimeActive do
            EnforceDisabledControls()
            Wait(0)
        end
    end)
end

local function StartLootPromptSuppression()
    if not runtimeConfig.suppressRandomLootPrompts then return end

    LootPromptSuppressionActive = true
    CreateThread(function()
        while LootPromptSuppressionActive do
            Citizen.InvokeNative(0xFC094EF26DD153FA, 2)
            Wait(0)
        end
    end)
end

function StartPlayerRuntime()
    if started then return end
    started = true
    PlayerRuntimeActive = true

    if runtimeConfig.clearChallengeFeed then
        assert(WorldEvents.Register('EVENT_CHALLENGE_GOAL_COMPLETE', ClearChallengeFeed))
        assert(WorldEvents.Register('EVENT_CHALLENGE_REWARD', ClearChallengeFeed))
        assert(WorldEvents.Register('EVENT_DAILY_CHALLENGE_STREAK_COMPLETED', ClearChallengeFeed))
    end

    StartControlSafeguards()
    StartLootPromptSuppression()
end
