-- The server sends ApplySkin and OpenSpawnSelect back to back. Applying the skin swaps the
-- player model (new ped handle), so the spawn flow must wait for it or it ends up making the
-- old, deleted ped visible and the player stays invisible.
local skinApplying = false
RegisterNetEvent('rsg-character:client:ApplySkin', function(skin, clothes)
    skinApplying = true
    local ok, err = pcall(function()
        exports[GetCurrentResourceName()]:ApplySkinMultiChar(skin or {}, PlayerPedId(), clothes or {})
    end)
    if not ok then print(('[rsg-character] ApplySkin failed: %s'):format(tostring(err))) end
    skinApplying = false
end)

local function WaitForSkin()
    local deadline = GetGameTimer() + 15000
    while skinApplying and GetGameTimer() < deadline do Wait(50) end
end

local OpenSpawnMenu
local pendingFullHeal = false

-- new characters: the creator's model swap leaves the ped at the model's default health and empty cores
local function RestoreFullHealth(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped), 0)
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, 100) -- health core
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100) -- stamina core
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 2, 100) -- deadeye core
    RestorePlayerStamina(PlayerId(), 100.0)
end


local function TeleportToSpawn(coords, heading, fromMenu)
    local ped = PlayerPedId()

    DoScreenFadeOut(500)
    local fadeTimeout = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do
        Wait(0)
    end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    FreezeEntityPosition(ped, true)

    -- interiors are not streamed by collision requests alone: pin the interior and wait until it is ready
    local interior = 0
    if not fromMenu then
        interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        if interior ~= 0 and IsValidInterior(interior) then
            PinInteriorInMemory(interior)
            local interiorTimeout = GetGameTimer() + 10000
            while not IsInteriorReady(interior) and GetGameTimer() < interiorTimeout do
                RequestCollisionAtCoord(coords.x, coords.y, coords.z)
                Wait(50)
            end
            if RSG.Debug then print(('[rsg-character] interior %s ready=%s'):format(interior, tostring(IsInteriorReady(interior)))) end
        else
            interior = 0
        end
    end

    -- saved logout positions get a longer wait: interiors stream in slower than open world
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local collisionTimeout = GetGameTimer() + (fromMenu and 3000 or 10000)
    while GetGameTimer() < collisionTimeout do
        if HasCollisionLoadedAroundEntity(ped) then break end
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
    end

    if fromMenu then
        -- preset spawns are outdoors, snap to ground
        local groundZ = GetGroundedZ(coords.x, coords.y, coords.z)
        SetEntityCoords(ped, coords.x, coords.y, groundZ, false, false, false, false)
    else
        -- saved position: use the exact saved z; a ground probe from above would land on the roof / upper floor
        SetEntityCoords(ped, coords.x, coords.y, coords.z - 1.0, false, false, false, false)
    end
    SetEntityHeading(ped, heading or 0.0)

    SetEntityVisible(ped, true, false)
    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), true, 0, false)
    DisplayHud(true)
    DisplayRadar(true)

    -- give streaming a moment behind the loading screen before revealing the world
    local streamDeadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < streamDeadline do
        Wait(100)
    end
    Wait(1500)

    if interior ~= 0 then
        -- re-place the ped now the interior exists so the engine assigns it to the correct room (fixes invisible/stuck ped)
        SetEntityCoords(ped, coords.x, coords.y, coords.z - 1.0, false, false, false, false)
        SetEntityHeading(ped, heading or 0.0)
        Wait(100)
        UnpinInterior(interior)
    end

    ped = PlayerPedId() -- re-fetch: the model may have been swapped while we waited
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    if pendingFullHeal then
        pendingFullHeal = false
        RestoreFullHealth(ped)
    end
    FreezeEntityPosition(ped, false)
    UI.HideLoadingScreen()
    DoScreenFadeIn(1000)
    TriggerServerEvent('RSGCore:Server:OnPlayerLoaded')
    TriggerEvent('RSGCore:Client:OnPlayerLoaded')

end

local function BuildSpawnElements()
    local elements = {}

    for i, loc in ipairs(RSG.SpawnLocations or {}) do
        elements[#elements + 1] = {
            label = loc.label,
            value = 'preset_' .. i,
            desc = locale('spawn.preset.desc'),
            image = loc.image,
        }
    end

    return elements
end

OpenSpawnMenu = function()
    -- loading screen (z-index 50) sits above the spawn panel (z-index 20); hide it or the menu is invisible
    UI.HideLoadingScreen()
    local value = UI.OpenSpawnSelect({
        title = locale('spawn.title'),
        subtitle = locale('spawn.subtitle'),
        elements = BuildSpawnElements(),
    })

    local idx = value and tonumber(value:match('^preset_(%d+)$'))
    local loc = idx and RSG.SpawnLocations[idx]
    if loc then
        UI.ShowLoadingScreen(locale('spawn.loading'))
        TeleportToSpawn(loc.coords, loc.coords.w, true)
    end
end

RegisterNetEvent('rsg-character:client:OpenSpawnSelect', function(lastPos, isNewCharacter)
    WaitForSkin()
    pendingFullHeal = isNewCharacter == true
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    if lastPos then
        TeleportToSpawn(lastPos, lastPos.w, false)
        return
    end

    OpenSpawnMenu()
end)

local function getFirstVector(value)
    if type(value) == 'table' then
        return value[1]
    end
    return value
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    local spawnChecks = RSG.SpawnChecks
    if not spawnChecks then
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    if RSG.Debug then
        print('Checking spawn: ' .. tostring(playerCoords))
    end

    for checkName, check in pairs(spawnChecks) do
        local radius = check.Radius or check.radius or 200
        local moveTo = getFirstVector(check.moveTo)

        if moveTo then
            for _, badSpawn in ipairs(check.badSpawn or {}) do
                if #(playerCoords - badSpawn) < radius then
                    if RSG.Debug then
                        print(('Bad spawn matched: %s'):format(checkName))
                    end
                    SetEntityCoords(playerPed, moveTo.x, moveTo.y, moveTo.z, 0, 0, 0, false)
                    return
                end
            end
        end
    end
end)
