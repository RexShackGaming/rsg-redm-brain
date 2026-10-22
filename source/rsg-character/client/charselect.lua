
local spawnedPeds = {}

local PreviewScenarios = {
    'WORLD_HUMAN_BADASS',
    'WORLD_HUMAN_GUARD_LAZY',
    'WORLD_HUMAN_GUARD_MILITARY',
    'WORLD_HUMAN_SMOKE',
    'WORLD_HUMAN_SMOKE_CIGAR',
    'WORLD_HUMAN_SMOKE_NERVOUS_STRESSED',
    'WORLD_HUMAN_WRITE_NOTEBOOK',
}
local FindSpawnedPed
local sceneCam = nil
local sceneActive = false
local sceneInputPaused = false
local pendingDeleteLoading = false
local focusIndex = 1

local activeEntry = nil
local lastShownKey = nil

LocalPlayer.state.inCharacterSelect = false

local function LockPlayer(lock)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, lock)
    SetEntityVisible(ped, not lock, false)
    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), not lock, 0, lock)
    DisplayHud(not lock)
    DisplayRadar(not lock)
end

local function SlotDisplayName(slot)
    if slot.exists then
        local name = ((slot.firstname or '') .. ' ' .. (slot.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' then name = locale('charselect.unnamed') end
        return name
    end
    return locale('charselect.empty.label')
end


local function ClearPeds()
    for _, p in ipairs(spawnedPeds) do
        if DoesEntityExist(p.handle) then
            DeletePed(p.handle)
        end
    end
    spawnedPeds = {}
end

local function EndScene()
    sceneActive = false
    LocalPlayer.state.inCharacterSelect = false
    ClearOverrideWeather()
    NetworkClearClockTimeOverride()
    pcall(function() exports['rsg-weather']:setSyncEnabled(true) end)
    ClearPeds()
    if sceneCam then
        RenderScriptCams(false, true, 500, true, true, 0)
        if DoesCamExist(sceneCam) then
            DestroyCam(sceneCam, false)
        end
        sceneCam = nil
    end

    UI.HideCharacterInfo()
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    activeEntry = nil
    lastShownKey = nil
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        EndScene()
    end
end)


local function RowBasis(heading)
    local rad = math.rad(heading)
    local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local right = vector3(math.cos(rad), math.sin(rad), 0.0)
    return forward, right
end

local function ClearNearbyPeds(coords, radius)
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not FindSpawnedPed(ped) then
            if #(GetEntityCoords(ped) - coords) <= radius then
                DeletePed(ped)
            end
        end
    end
end

local function ClearNearbyVehicles(coords, radius)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            if #(GetEntityCoords(veh) - coords) <= radius then
                DeleteVehicle(veh)
            end
        end
    end
end


local function SexFromGender(gender)
    return tonumber(gender) == 1 and 2 or 1
end

local function ComputeCameraBack(loc, totalSlots)
    local camCfg = loc.camera or {}
    local configuredBack = camCfg.back or 3.4
    local fov = camCfg.fov or 45.0
    local spacing = loc.spacing or 1.65
    local halfWidth = ((math.max(totalSlots, 1) - 1) / 2) * spacing + 0.5
    local neededBack = halfWidth / math.tan(math.rad(fov) / 2)
    return math.max(configuredBack, neededBack)
end

local function ComputeCameraPosition(loc, totalSlots)
    local forward = RowBasis(loc.coords.w)
    local camCfg = loc.camera or {}
    local back = ComputeCameraBack(loc, totalSlots)
    local camZ = GetGroundedZ(loc.coords.x, loc.coords.y, loc.coords.z) + (camCfg.height or 0.55)
    local camX = loc.coords.x - forward.x * back
    local camY = loc.coords.y - forward.y * back
    return camX, camY, camZ
end

local function RequestAndLoadModel(model)
    local modelHash = type(model) == "number" and model or joaat(model)
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        return nil
    end

    RequestModel(modelHash)
    local timeout = 5000
    while not HasModelLoaded(modelHash) and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end

    if not HasModelLoaded(modelHash) then
        return nil
    end

    return modelHash
end

local function SpawnSlotPed(slot, index, total, loc, camX, camY)
    local _, right = RowBasis(loc.coords.w)
    local offset = (index - (total + 1) / 2) * (loc.spacing or 1.65)
    local x = loc.coords.x + right.x * offset
    local y = loc.coords.y + right.y * offset
    local z = GetGroundedZ(x, y, loc.coords.z)
    local pedHeading = GetHeadingFromVector_2d(camX - x, camY - y)

    local sex = slot.exists and SexFromGender(slot.gender) or 1
    local rawModel = GetPedModel(sex)

    local modelHash = RequestAndLoadModel(rawModel)
    if not modelHash then return end

    local handle = CreatePed(modelHash, x, y, z, pedHeading, false, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not handle or handle == 0 or not DoesEntityExist(handle) then return end

    FreezeEntityPosition(handle, true)
    SetEntityInvincible(handle, true)
    SetBlockingOfNonTemporaryEvents(handle, true)

    TaskStartScenarioInPlace(handle, joaat(PreviewScenarios[math.random(#PreviewScenarios)]), 0, true)

    if slot.exists and slot.skin then
        local waited = 0
        while not ComponentsReady and waited < 3000 do
            Wait(50)
            waited = waited + 50
        end

        local ok, err = pcall(function()
            exports[GetCurrentResourceName()]:ApplySkinMultiChar(slot.skin, handle, slot.clothes or {})
        end)
        if not ok then
            print(('[rsg-character] ApplySkinMultiChar failed for slot %s (citizenid %s): %s')
                :format(tostring(index), tostring(slot.citizenid), tostring(err)))
        end
    else
        SetPedOutfitPreset(handle, 3, true)
    end

    SetEntityAlpha(handle, 140, false)

    spawnedPeds[#spawnedPeds + 1] = {
        handle = handle,
        slot = slot,
        coords = vector3(x, y, z),
    }
end


local function StartSceneCamera(loc, camX, camY, camZ)
    local camCfg = loc.camera or {}
    sceneCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camX, camY, camZ, 0.0, 0.0, loc.coords.w, camCfg.fov or 45.0, false, 0)
    PointCamAtCoord(sceneCam, loc.coords.x, loc.coords.y, camZ)
    SetCamActive(sceneCam, true)
    RenderScriptCams(true, true, 0, true, true, 0)
end


local function DrawText3D(coords, text, big)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return end

    local scale = big and 0.42 or 0.32
    local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())

    SetTextScale(scale, scale)
    SetTextFontForCurrentCommand(25)
    if big then
        SetTextColor(120, 255, 140, 230)
    else
        SetTextColor(255, 255, 255, 200)
    end
    SetTextCentre(1)
    DisplayText(str, sx, sy)
end

local function DrawHeaderText()
    local titleStr = CreateVarString(10, "LITERAL_STRING", locale('charselect.title'), Citizen.ResultAsLong())
    SetTextScale(0.55, 0.55)
    SetTextFontForCurrentCommand(25)
    SetTextColor(255, 255, 255, 220)
    SetTextCentre(1)
    DisplayText(titleStr, 0.5, 0.06)

end


local function GetCursorScreenCoords()
    local x, y = GetControlNormal(0, INPUT_CURSOR_X), GetControlNormal(0, INPUT_CURSOR_Y)
    return x, y
end

local function GetEntityUnderCursor()
    if not sceneCam or not DoesCamExist(sceneCam) then return nil end

    local screenX, screenY = GetCursorScreenCoords()
    local camCoords = GetCamCoord(sceneCam)
    local targetCoords = GetWorldCoordFromScreenCoord(screenX, screenY)

    local dir = targetCoords - camCoords
    local mag = #dir
    if mag == 0.0 then return nil end
    dir = dir / mag

    local dest = camCoords + dir * 100.0
    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
    if hit == 1 and entityHit and entityHit ~= 0 then
        return entityHit
    end
    return nil
end

FindSpawnedPed = function(handle)
    for _, p in ipairs(spawnedPeds) do
        if p.handle == handle then return p end
    end
    return nil
end


local function IsLeftClickJustPressed()
    return IsDisabledControlJustPressed(0, 0x07CE1E61)
end

local function IsRightClickJustPressed()
    return IsDisabledControlJustPressed(0, 0xF84FA74F)
end

local function IsCycleLeftJustPressed()
    return IsDisabledControlJustPressed(0, 0xA65EBAB4)
end

local function IsCycleRightJustPressed()
    return IsDisabledControlJustPressed(0, 0xDEB34313)
end

local function IsConfirmJustPressed()
    return IsDisabledControlJustPressed(0, 0xC7B5340A)
end

local function IsDeleteJustPressed()
    return IsDisabledControlJustPressed(0, 0x4AF4D473)
end


local pendingGender = 1

AddEventHandler('rsg-character:client:CharInfoGenderChange', function(gender)
    pendingGender = (gender == 'female') and 2 or 1
end)

local function HandlePickPed(entry)
    if entry.slot.exists then
        local citizenid = entry.slot.citizenid
        DoScreenFadeOut(250)
        Wait(250)
        EndScene()
        UI.ShowLoadingScreen(locale('charselect.play_loading'))
        TriggerServerEvent('rsg-character:server:SelectCharacterSlot', citizenid)
    else
        local selectedSex = pendingGender
        local cid = entry.slot.cid
        DoScreenFadeOut(250)
        Wait(250)
        EndScene()
        UI.ShowLoadingScreen(locale('charselect.loading'))
        LockPlayer(false)
        TriggerServerEvent('rsg-character:server:RequestCreateCharacterSlot', cid, selectedSex)
    end
end

local function HandleDeletePed(entry)
    sceneInputPaused = true
    local confirmed = UI.alertDialog({
        header = locale('charselect.delete.confirm_header'),
        cancel = true,
    })
    if confirmed == 'confirm' then
        DoScreenFadeOut(250)
        Wait(250)
        UI.ShowLoadingScreen(locale('charselect.delete.loading'))
        pendingDeleteLoading = true
        TriggerServerEvent('rsg-character:server:DeleteCharacterSlot', entry.slot.citizenid)
    else
        sceneInputPaused = false
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    end
end

local function FormatCash(amount)
    amount = math.floor(tonumber(amount) or 0)
    local sign = ''
    if amount < 0 then
        sign = '-'
        amount = -amount
    end
    local formatted = tostring(amount)
    while true do
        local newFormatted, subs = formatted:gsub('^(%d+)(%d%d%d)', '%1,%2')
        formatted = newFormatted
        if subs == 0 then break end
    end
    return sign .. formatted
end

local function EntryKey(entry)
    if not entry then return nil end
    return entry.slot.cid
end

local function UpdateSelectionAlpha(selected)
    for _, p in ipairs(spawnedPeds) do
        if DoesEntityExist(p.handle) then
            SetEntityAlpha(p.handle, p == selected and 255 or 140, false)
        end
    end
end

local function UpdateCharInfoBox(entry)
    local key = EntryKey(entry)
    if key == lastShownKey then return end
    lastShownKey = key
    activeEntry = entry
    UpdateSelectionAlpha(entry)

    if not entry then
        UI.HideCharacterInfo()
        return
    end

    local slot = entry.slot
    if slot.exists then
        UI.ShowCharacterInfo({
            empty = false,
            name = SlotDisplayName(slot),
            job = (slot.job and slot.job.label) or locale('charselect.info.unemployed'),
            birthdate = slot.birthdate or '-',
            nationality = slot.nationality or '-',
            cash = '$' .. FormatCash(slot.cash),
        })
    else
        pendingGender = 1
        UI.ShowCharacterInfo({
            empty = true,
            name = locale('charselect.empty.label'),
            desc = locale('charselect.empty.desc'),
        })
    end
end

AddEventHandler('rsg-character:client:CharInfoPlay', function()
    if activeEntry then HandlePickPed(activeEntry) end
end)

AddEventHandler('rsg-character:client:CharInfoDelete', function()
    if activeEntry and activeEntry.slot.exists then HandleDeletePed(activeEntry) end
end)


local function RunSceneLoop(loc)
    local lightCoords = vector3(loc.coords.x, loc.coords.y, GetGroundedZ(loc.coords.x, loc.coords.y, loc.coords.z) + 2.0)
    local sweepCoords = vector3(loc.coords.x, loc.coords.y, loc.coords.z)
    local sweepTimer = 100

    CreateThread(function()
        while sceneActive do
            Wait(0)
            SetMouseCursorActiveThisFrame()
            -- keep it sunny/midday every frame so nothing darkens the lineup
            Citizen.InvokeNative(0x59174F1AFE095B5A, `SUNNY`, true, true, true, 0.0, false)
            NetworkClockTimeOverride(12, 0, 0, 0, true)
            DrawLightWithRange(lightCoords.x, lightCoords.y, lightCoords.z, 255, 250, 235, 20.0, 60.0)
            DrawHeaderText()

            sweepTimer = sweepTimer - 1
            if sweepTimer <= 0 then
                sweepTimer = 100
                ClearNearbyPeds(sweepCoords, 20.0)
                ClearNearbyVehicles(sweepCoords, 20.0)
            end

            if not sceneInputPaused then
                if IsCycleLeftJustPressed() then
                    focusIndex = math.max(1, focusIndex - 1)
                elseif IsCycleRightJustPressed() then
                    focusIndex = math.min(#spawnedPeds, focusIndex + 1)
                end
            end

            local hoveredEntry = nil
            if not sceneInputPaused then
                local hovered = GetEntityUnderCursor()
                if hovered then
                    hoveredEntry = FindSpawnedPed(hovered)
                end
            end

            for i, p in ipairs(spawnedPeds) do
                local isFocused = (i == focusIndex)
                local isHovered = (hoveredEntry == p)
                DrawText3D(p.coords, SlotDisplayName(p.slot), isFocused or isHovered)
            end

            if not sceneInputPaused then
                UpdateCharInfoBox(hoveredEntry or spawnedPeds[focusIndex])
            end

            if not sceneInputPaused then
                if hoveredEntry then
                    if IsLeftClickJustPressed() then
                        HandlePickPed(hoveredEntry)
                    elseif hoveredEntry.slot.exists and IsRightClickJustPressed() then
                        HandleDeletePed(hoveredEntry)
                    end
                elseif IsConfirmJustPressed() and spawnedPeds[focusIndex] then
                    HandlePickPed(spawnedPeds[focusIndex])
                end

                if IsDeleteJustPressed() then
                    local focused = spawnedPeds[focusIndex]
                    if focused and focused.slot.exists then
                        HandleDeletePed(focused)
                    end
                end
            end
        end
    end)
end

local function FadeInSceneIfNeeded()
    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end
    if pendingDeleteLoading then
        pendingDeleteLoading = false
        UI.HideLoadingScreen()
    end
end

local function RunCharSelectScene(slots)
    EndScene()

    local loc = RSG.CharSelectLocation
    if not loc or not loc.coords then
        LockPlayer(false)
        FadeInSceneIfNeeded()
        return
    end

    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, loc.coords.x, loc.coords.y, loc.coords.z, false, false, false, false)
    RequestCollisionAtCoord(loc.coords.x, loc.coords.y, loc.coords.z)
    
    local timeout = 2000
    while not HasCollisionLoadedAroundEntity(playerPed) and timeout > 0 do
        Wait(50)
        timeout = timeout - 50
    end

    local camX, camY, camZ = ComputeCameraPosition(loc, #slots)

    local clearCoords = vector3(loc.coords.x, loc.coords.y, loc.coords.z)
    ClearNearbyPeds(clearCoords, 20.0)
    ClearNearbyVehicles(clearCoords, 20.0)

    -- Stop weathersync fighting the scene, and force a bright clear midday
    pcall(function() exports['rsg-weather']:setSyncEnabled(false) end)
    pcall(function() exports['rsg-weather']:setMyWeather('sunny', 0, false) end)
    pcall(function() exports['rsg-weather']:setMyTime(12, 0, 0, 0) end)
    ClearTimecycleModifier()
    Citizen.InvokeNative(0x59174F1AFE095B5A, `SUNNY`, true, true, true, 0.0, false)
    NetworkClockTimeOverride(12, 0, 0, 0, true)
    NetworkClockTimeOverride_2(12, 0, 0, 0, true, true)
    Citizen.InvokeNative(0x193DFC0526830FD6, 0.0)

    for i, slot in ipairs(slots) do
        SpawnSlotPed(slot, i, #slots, loc, camX, camY)
    end

    if #spawnedPeds == 0 then
        LockPlayer(false)
        FadeInSceneIfNeeded()
        return
    end

    focusIndex = 1
    for i, p in ipairs(spawnedPeds) do
        if p.slot.exists then focusIndex = i break end
    end

    StartSceneCamera(loc, camX, camY, camZ)
    sceneActive = true
    sceneInputPaused = false
    LocalPlayer.state.inCharacterSelect = true

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    FadeInSceneIfNeeded()

    RunSceneLoop(loc)
end

RegisterNetEvent('rsg-character:client:ReceiveCharacterSlots', function(slots)
    RunCharSelectScene(slots)
end)

RegisterNetEvent('rsg-character:client:CharSelectFailed', function()
    pendingDeleteLoading = false
    UI.HideLoadingScreen()
    lib.notify({
        title = locale('charselect.login_failed.title'),
        description = locale('charselect.login_failed.description'),
        type = 'error',
        duration = 5000,
    })
    sceneInputPaused = false
    OpenCharacterSelect()
end)

function OpenCharacterSelect()
    LockPlayer(true)
    TriggerServerEvent('rsg-character:server:RequestCharacterSlots')
end
RegisterNetEvent('rsg-character:client:OpenCharSelect', OpenCharacterSelect)

local started = false
local function StartCharSelect()
    if started then return end
    started = true

    DoScreenFadeOut(10)
    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityVisible(PlayerPedId(), false, false)
    Wait(500)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    OpenCharacterSelect()
end

CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            Wait(500)
            StartCharSelect()
            return
        end
    end
end)