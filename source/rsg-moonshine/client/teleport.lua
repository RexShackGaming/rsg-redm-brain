-- speakeasy teleports: outside hatch <-> inside cellar
local cfg = Config.Speakeasy
if not cfg or not cfg.enabled then return end

local group = GetRandomIntInRange(0, 0xffffff)
local prompt
local busy = false

local function createPrompt()
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, cfg.promptKey)
    UiPromptSetText(prompt, VarString(10, 'LITERAL_STRING', locale('cl_speakeasy_use')))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetHoldMode(prompt, cfg.holdTime)
    UiPromptSetGroup(prompt, group, 0)
    UiPromptRegisterEnd(prompt)
end

local function teleport(dest)
    if busy then return end
    busy = true
    local ped = cache.ped
    DoScreenFadeOut(cfg.fadeTime)
    while not IsScreenFadedOut() do Wait(0) end

    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(dest.x, dest.y, dest.z)
    SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, false)
    SetEntityHeading(ped, dest.w)

    -- wait for the speakeasy interior itself to be ready (not just the terrain above it)
    local timeout = GetGameTimer() + 5000
    local interior = GetInteriorAtCoords(dest.x, dest.y, dest.z)
    while GetGameTimer() < timeout do
        RequestCollisionAtCoord(dest.x, dest.y, dest.z)
        if interior == 0 then
            interior = GetInteriorAtCoords(dest.x, dest.y, dest.z)
        end
        local interiorOk = interior == 0 or IsInteriorReady(interior)
        if interiorOk and HasCollisionLoadedAroundEntity(ped) then break end
        Wait(0)
    end
    Wait(500)

    -- re-place once everything is loaded, then release
    SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, false)
    SetEntityHeading(ped, dest.w)
    FreezeEntityPosition(ped, false)

    DoScreenFadeIn(cfg.fadeTime)
    busy = false
end

CreateThread(function()
    createPrompt()
    while true do
        local sleep = 1000
        local ped = cache.ped
        if not busy and not IsPedInAnyVehicle(ped, false) and not IsPedOnMount(ped) and not IsEntityDead(ped) then
            local pos = GetEntityCoords(ped)
            for _, loc in ipairs(cfg.locations) do
                local to, label
                if #(pos - loc.outside.xyz) <= cfg.dist then
                    to, label = loc.inside, locale('cl_speakeasy_enter')
                elseif #(pos - loc.inside.xyz) <= cfg.dist then
                    to, label = loc.outside, locale('cl_speakeasy_exit')
                end
                if to then
                    sleep = 0
                    UiPromptSetActiveGroupThisFrame(group, VarString(10, 'LITERAL_STRING', loc.name .. ' - ' .. label), 0, 0, 0, 0)
                    if UiPromptHasHoldModeCompleted(prompt) then
                        teleport(to)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if prompt then UiPromptDelete(prompt) end
    if IsScreenFadedOut() then DoScreenFadeIn(0) end
end)
