local RSGCore = exports['rsg-core']:GetCoreObject()

function GetGroundedZ(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    local timeout = GetGameTimer() + 3000
    while GetGameTimer() < timeout do
        Wait(0)
        local found, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 10.0)
        if found then
            return groundZ
        end
    end
    return z
end

local textureId = -1
local pedloc = vector4(-558.0, -3781.0, 239.0, 91.0)
local camloc = vector4(-560.0, -3781.0, 239.0, 268.0)
local animscene
local selectRight
local selectLeft
local selectEnter
local cam
local CharacterCreatorCamera
local Sheriff
local Deputy
local cameraMale
local cameraFemale
local isSelectSexActive
local lightsOn = false

ClothesCache = {}
OldClothesCache = {}

InCharacterCreator = false
IsInCharCreation   = false
FemalePed          = nil
MalePed            = nil

local PromptGroup1 = GetRandomIntInRange(0, 0xffffff)
local CameraPrompt, RotatePrompt, ZoomPrompt
local RoomPrompts = GetRandomIntInRange(0, 0xffffff)

local Data = require 'data.features'
local Overlays = require 'data.overlays'
local hairs_list = require 'data.hairs_list'
local clothing = require 'data.clothing'

CreateThread(function()
    local str = locale('creator.male')
    selectLeft = PromptRegisterBegin()
    PromptSetControlAction(selectLeft, RSG.Prompt.MalePrompt)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(selectLeft, str)
    PromptSetEnabled(selectLeft, true)
    PromptSetVisible(selectLeft, true)
    PromptSetStandardMode(selectLeft, 1)
    PromptSetGroup(selectLeft, PromptGroup1)
    PromptRegisterEnd(selectLeft)

    str = locale('creator.female')
    selectRight = PromptRegisterBegin()
    PromptSetControlAction(selectRight, RSG.Prompt.FemalePrompt)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(selectRight, str)
    PromptSetEnabled(selectRight, true)
    PromptSetVisible(selectRight, true)
    PromptSetStandardMode(selectRight, 1)
    PromptSetGroup(selectRight, PromptGroup1)
    PromptRegisterEnd(selectRight)

    str = locale('creator.confirm')
    selectEnter = PromptRegisterBegin()
    PromptSetControlAction(selectEnter, RSG.Prompt.ConfirmPrompt)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(selectEnter, str)
    PromptSetEnabled(selectEnter, false)
    PromptSetVisible(selectEnter, true)
    PromptSetStandardMode(selectEnter, 1)
    PromptSetGroup(selectEnter, PromptGroup1)
    PromptRegisterEnd(selectEnter)
end)

CreateThread(function()
    local str = RSG.CameraPromptText
    CameraPrompt = PromptRegisterBegin()
    PromptSetControlAction(CameraPrompt, RSG.Prompt.CameraUp)
    PromptSetControlAction(CameraPrompt, RSG.Prompt.CameraDown)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(CameraPrompt, str)
    PromptSetEnabled(CameraPrompt, true)
    PromptSetVisible(CameraPrompt, true)
    PromptSetStandardMode(CameraPrompt, 1)
    PromptSetGroup(CameraPrompt, RoomPrompts)
    PromptRegisterEnd(CameraPrompt)
    PromptSetEnabled(CameraPrompt, false)
    PromptSetVisible(CameraPrompt, false)

    str = RSG.RotatePromptText
    RotatePrompt = PromptRegisterBegin()
    PromptSetControlAction(RotatePrompt, RSG.Prompt.RotateLeft)
    PromptSetControlAction(RotatePrompt, RSG.Prompt.RotateRight)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(RotatePrompt, str)
    PromptSetEnabled(RotatePrompt, true)
    PromptSetVisible(RotatePrompt, true)
    PromptSetStandardMode(RotatePrompt, 1)
    PromptSetGroup(RotatePrompt, RoomPrompts)
    PromptRegisterEnd(RotatePrompt)
    PromptSetEnabled(RotatePrompt, false)
    PromptSetVisible(RotatePrompt, false)

    str = RSG.ZoomPromptText
    ZoomPrompt = PromptRegisterBegin()
    PromptSetControlAction(ZoomPrompt, RSG.Prompt.Zoom1)
    PromptSetControlAction(ZoomPrompt, RSG.Prompt.Zoom2)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(ZoomPrompt, str)
    PromptSetEnabled(ZoomPrompt, true)
    PromptSetVisible(ZoomPrompt, true)
    PromptSetStandardMode(ZoomPrompt, 1)
    PromptSetGroup(ZoomPrompt, RoomPrompts)
    PromptRegisterEnd(ZoomPrompt)
    PromptSetEnabled(ZoomPrompt, false)
    PromptSetVisible(ZoomPrompt, false)
end)

function ChangeOverlays(name, visibility, tx_id, tx_normal, tx_material, tx_color_type, tx_opacity, tx_unk, palette_id,
    palette_color_primary, palette_color_secondary, palette_color_tertiary, var, opacity)
    for k, v in pairs(Overlays.overlay_all_layers) do
        if v.name == name then
            v.visibility = visibility
            if visibility ~= 0 then
                v.tx_normal = tx_normal
                v.tx_material = tx_material
                v.tx_color_type = tx_color_type
                v.tx_opacity = tx_opacity
                v.tx_unk = tx_unk
                if tx_color_type == 0 then
                    local palette = Overlays.color_palettes[palette_id]
                    if palette then
                        v.palette = palette[1]
                        v.palette_color_primary = palette_color_primary
                        v.palette_color_secondary = palette_color_secondary
                        v.palette_color_tertiary = palette_color_tertiary
                    end
                end
                local overlayInfo = Overlays.overlays_info[name]
                if name == "shadows" or name == "eyeliners" or name == "lipsticks" then
                    v.var = var
                    v.tx_id = overlayInfo and overlayInfo[1] and overlayInfo[1].id
                else
                    v.var = 0
                    v.tx_id = overlayInfo and overlayInfo[tx_id] and overlayInfo[tx_id].id
                end
                v.opacity = opacity
            end
        end
    end
end

function GetHeadIndex(ped)
    local numComponents = Citizen.InvokeNative(0x90403E8107B60E81, ped)
    if not numComponents then return false end
        for i=0, numComponents-1, 1 do
            local componentCategory = Citizen.InvokeNative(0x9b90842304c938a7, ped, i, 0, Citizen.ResultAsInteger())
            if componentCategory == `heads` then
                return i
            end
        end
    return false
end

function GetMetaPedAssetGuids(ped, index)
    return Citizen.InvokeNative(0xA9C28516A6DC9D56, ped, index, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
end

function ApplyOverlays(overlayTarget)
    if IsPedMale(overlayTarget) then
        Overlays.current_texture_settings = Overlays.texture_types["male"]
    else
        Overlays.current_texture_settings = Overlays.texture_types["female"]
    end
    if textureId ~= -1 then
        Citizen.InvokeNative(0xB63B9178D0F58D82, textureId)
        Citizen.InvokeNative(0x6BEFAA907B076859, textureId)
    end
    local index = GetHeadIndex(overlayTarget)
    if not index then
        return
    end
    local _, albedo, normal, material = GetMetaPedAssetGuids(overlayTarget, index)
    textureId = Citizen.InvokeNative(0xC5E7204F322E49EB, albedo, normal, material);
    for k, v in pairs(Overlays.overlay_all_layers) do
        if v.visibility ~= 0 then
            local overlay_id = Citizen.InvokeNative(0x86BB5FF45F193A02, textureId, v.tx_id, v.tx_normal, v.tx_material,
                v.tx_color_type, v.tx_opacity, v.tx_unk);
            if v.tx_color_type == 0 then
                Citizen.InvokeNative(0x1ED8588524AC9BE1, textureId, overlay_id, v.palette);
                Citizen.InvokeNative(0x2DF59FFE6FFD6044, textureId, overlay_id, v.palette_color_primary,
                    v.palette_color_secondary, v.palette_color_tertiary)
            end
            Citizen.InvokeNative(0x3329AAE2882FC8E4, textureId, overlay_id, v.var);
            Citizen.InvokeNative(0x6C76BC24F8BB709A, textureId, overlay_id, v.opacity);
        end
    end
    local textureLoadDeadline = GetGameTimer() + 5000
    while not Citizen.InvokeNative(0x31DC8D3F216D8509, textureId) do
        if GetGameTimer() > textureLoadDeadline then
            break
        end
        Wait(0)
    end
    Citizen.InvokeNative(0x92DAABA2C1C10B0E, textureId)
    Citizen.InvokeNative(0x8472A1789478F82F, textureId)
    Citizen.InvokeNative(0x0B46E25761519058, overlayTarget, GetHashKey("heads"), textureId)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, overlayTarget, 0, 1, 1, 1, false);
end

function RemoveImaps()
    if IsImapActive(183712523) then
        RemoveImap(183712523)
    end

    if IsImapActive(-1699673416) then
        RemoveImap(-1699673416)
    end

    if IsImapActive(1679934574) then
        RemoveImap(1679934574)
    end
end

function LoadModel(target, model)
    local model_ = model
    if type(model_) ~= "number" then
        model_ = GetHashKey(model_)
    end

    RequestModel(model_)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model_) and GetGameTimer() < deadline do
        Wait(10)
    end

    Citizen.InvokeNative(0xED40380076A31506, PlayerId(), model_, false)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, PlayerPedId(), 7, true)
    NativeUpdatePedVariation(PlayerPedId())
end

function LoadPlayer(model)
    RequestModel(model)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(10)
    end
end

local function Setup()
    DoScreenFadeOut(500)
    Wait(2000)
    pcall(function() exports['rsg-weather']:setSyncEnabled(false) end)
    pcall(function() exports['rsg-weather']:setMyTime(0, 0, 0, 0) end)
    lightsOn = true
    Citizen.InvokeNative(0x513F8AA5BF2F17CF, -561.4, -3782.6, 237.6, 50.0, 20)
    Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area", true, true)
    Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area_Other_Zones_Disable", false, true)
    SetTimecycleModifier('Online_Character_Editor')
    SetEntityCoords(PlayerPedId(), -549.4303588867188, -3778.28271484375, 238.597412109375, false, false, false, false)
    local collisionDeadline = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) do
        if GetGameTimer() > collisionDeadline then
            break
        end
        Wait(500)
    end
end

function StartCreatorSimple(selectedSex)
    Setup()

    DisplayRadar(false)
    Citizen.InvokeNative(0x0E3F4AF2D63491FB)
    Citizen.InvokeNative(0xFA08722A5EA82DA7, "Online_Character_Editor")
    Citizen.InvokeNative(0xFDB74C9CC54C3F37, 1.0)

    InCharacterCreator = true
    StartSelectCam()

    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), false, 0, true)

    StartCharacterCreatorCamera(selectedSex, cam)
    CreateThread(StartPrompts)
end

function SpawnPeds()
    Setup()

    DisplayRadar(false)
    Citizen.InvokeNative(0x0E3F4AF2D63491FB)
    Citizen.InvokeNative(0xFA08722A5EA82DA7, "Online_Character_Editor")
    Citizen.InvokeNative(0xFDB74C9CC54C3F37, 1.0)
    local fModel = joaat("mp_female")
    local mModel = joaat("mp_male")

    LoadPlayer(fModel)
    FemalePed = CreatePed(fModel, vector4(0.0, 0.0, 0.0, 0.0), false)
    SetModelAsNoLongerNeeded(fModel)
    SetPedOutfitPreset(FemalePed, 3, true)

    LoadPlayer(mModel)
    MalePed = CreatePed(mModel, vector4(0.0, 0.0, 0.0, 0.0), false)
    SetModelAsNoLongerNeeded(mModel)
    SetPedOutfitPreset(MalePed, 3, true)

    Sheriff = CreatePedAtCoords(`MP_U_M_O_BlWPoliceChief_01`, vector4(0.0, 0.0, 0.0, 0.0), false)
    Citizen.InvokeNative(0x283978A15512B2FE, Sheriff, true)
    AddEntityToAudioMixGroup(Sheriff, "rdro_character_creator_guard_group", 0.0)
    SetPedConfigFlag(Sheriff, 130, true)
    SetPedConfigFlag(Sheriff, 301, true)
    SetPedConfigFlag(Sheriff, 315, true)
    FreezeEntityPosition(Sheriff, true)
    SetPedOutfitPreset(Sheriff, 7, true)

    Deputy = CreatePedAtCoords(`CS_MP_MARSHALL_DAVIES`, vector4(0.0, 0.0, 0.0, 0.0), false)
    Citizen.InvokeNative(0x283978A15512B2FE, Deputy, true)
    AddEntityToAudioMixGroup(Deputy, "rdro_character_creator_guard_group", 0.0)
    SetPedConfigFlag(Deputy, 130, true)
    SetPedConfigFlag(Deputy, 301, true)
    SetPedConfigFlag(Deputy, 315, true)
    GiveWeaponToPed_2(Deputy, `WEAPON_REPEATER_CARBINE`, 100, true, false, 0, false, 0.5, 1.0, 752097756, false, 0.0, false)
    FreezeEntityPosition(Deputy, true)

    animscene = CreateAnimScene("script@mp@character_creator@transitions", 0.25, "pl_intro", false, true)
    SetAnimSceneEntity(animscene, "Male_MP", MalePed, 0)
    SetAnimSceneEntity(animscene, "Female_MP", FemalePed, 0)
    SetAnimSceneEntity(animscene, "Sheriff", Sheriff, 0)
    SetAnimSceneEntity(animscene, "Deputy", Deputy, 0)

    LoadAnimScene(animscene)
    while not Citizen.InvokeNative(0x477122B8D05E7968, animscene) do
        Wait(0)
    end
    StartAnimScene(animscene)

    DoScreenFadeIn(1000)
    Wait(14000)
    InCharacterCreator = true
    StartSelectCam()
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1000, true, false)
    isSelectSexActive = true

    local str = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", locale('creator.select_gender_1'), Citizen.ResultAsLong())
    Citizen.InvokeNative(0xFA233F8FE190514C, str)
    Citizen.InvokeNative(0xE9990552DEC71600)

    local Label
    CreateThread(function()
        while InCharacterCreator do
            if not IsInCharCreation then
                Wait(0)

                if isSelectSexActive and not IsCamActive(cameraFemale) and not IsCamActive(cameraMale) then
                    Label = CreateVarString(10, "LITERAL_STRING", locale('creator.select_gender_2'))
                end

                if IsCamActive(cameraFemale) and isSelectSexActive then
                    Label = CreateVarString(10, "LITERAL_STRING", locale('creator.female'))
                end

                if IsCamActive(cameraMale) and isSelectSexActive then
                    Label = CreateVarString(10, "LITERAL_STRING", locale('creator.male'))
                end

                PromptSetActiveGroupThisFrame(PromptGroup1, Label)

                if Citizen.InvokeNative(0xC92AC953F0A982AE, selectLeft) then
                    PlaySoundFrontend("gender_left", "RDRO_Character_Creator_Sounds", true, 0)
                    PromptSetEnabled(selectEnter, 1)
                    if IsCamActive(cam) then
                        SetCamActiveWithInterp(cameraMale, cam, 2000, 0, 0)
                        SetCamActive(cam, false)
                    elseif IsCamActive(cameraMale) then
                        SetCamActiveWithInterp(cam, cameraMale, 2000, 0, 0)
                        SetCamActive(cameraMale, false)
                        PromptSetEnabled(selectEnter, 0)
                    elseif IsCamActive(cameraFemale) then
                        SetCamActiveWithInterp(cameraMale, cameraFemale, 2000, 0, 0)
                        SetCamActive(cameraFemale, false)
                        PromptSetEnabled(selectEnter, 1)
                    end
                    Wait(200)
                    InCharacterCreator = true
                end

                if Citizen.InvokeNative(0xC92AC953F0A982AE, selectRight) then
                    PlaySoundFrontend("gender_right", "RDRO_Character_Creator_Sounds", true, 0)
                    PromptSetEnabled(selectEnter, 1)
                    if IsCamActive(cam) then
                        SetCamActiveWithInterp(cameraFemale, cam, 2000, 0, 0)
                        SetCamActive(cam, false)
                    elseif IsCamActive(cameraMale) then
                        SetCamActiveWithInterp(cameraFemale, cameraMale, 2000, 0, 0)
                        SetCamActive(cameraMale, false)
                        PromptSetEnabled(selectEnter, 1)
                    elseif IsCamActive(cameraFemale) then
                        SetCamActiveWithInterp(cam, cameraFemale, 2000, 0, 0)
                        SetCamActive(cameraFemale, false)
                        PromptSetEnabled(selectEnter, 0)
                    end
                    Wait(200)
                    InCharacterCreator = true
                end

                if Citizen.InvokeNative(0xC92AC953F0A982AE, selectEnter) then
                    Citizen.InvokeNative(0x706D57B0F50DA710, "MC_MUSIC_STOP")
                    PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0)

                    if IsCamActive(cameraMale) then
                        Citizen.InvokeNative(0xAB5E7CAB074D6B84, animscene, ("Pl_Start_to_Edit_Male"))
                        SetCamActiveWithInterp(cam, cameraMale, 2000, 0, 0)
                        SetCamActive(cameraMale, false)
                        local selectedSex = 1
                        StartCharacterCreatorCamera(selectedSex, cameraMale)
                        isSelectSexActive = false
                        Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), false, 0, true)
                    elseif IsCamActive(cameraFemale) then
                        Citizen.InvokeNative(0xAB5E7CAB074D6B84, animscene, ("Pl_Start_to_Edit_Female"))
                        SetCamActiveWithInterp(cam, cameraFemale, 2000, 0, 0)
                        SetCamActive(cameraFemale, false)
                        local selectedSex = 2
                        StartCharacterCreatorCamera(selectedSex, cameraFemale)
                        isSelectSexActive = false
                        Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), false, 0, true)
                    end
                    Wait(2000)
                    IsInCharCreation = true
                    CreateThread(StartPrompts)
                end
            else
                FreezeEntityPosition(PlayerPedId(), false)
                Wait(100)
            end
        end
    end)
end

local defaultX, defaultY, defaultZ = -561.93, -3776.27, 239.09
local defaultPitch, defaultRoll, defaultHeading, defaultZoom = -5.61, 0.00, -89.74, 45.00

function StartSelectCam()
    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", defaultX, defaultY, defaultZ, defaultPitch, defaultRoll, defaultHeading, defaultZoom, false, 0)
    cameraMale   = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", -560.47,   -3775.64, 239.09, -7.62,    0.00, -89.67,     defaultZoom,    false, 0)
    cameraFemale = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", -560.47,   -3776.94,  239.09, -7.62,    0.00, -89.67,    defaultZoom,    false, 0)
    local HasZ, z = GetGroundZAndNormalFor_3dCoord(camloc.x, camloc.y, camloc.z + 0.5)
    CharacterCreatorCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camloc.x, camloc.y, z + 1.5, 0.0, 0.0, camloc.w, 65.00, false, 0)
end

CreatePedAtCoords = function(model, coords, isNetworked)
    if type(model) ~= "number" then model = joaat(model) end

    if IsModelInCdimage(model) then
        isNetworked = isNetworked or false

        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end

        local handle = CreatePed(model, coords, isNetworked, isNetworked, false, false)
        Citizen.InvokeNative(0x283978A15512B2FE, handle, true)
        SetModelAsNoLongerNeeded(model)

        return handle
    end
end

function StartPrompts()
    lightsOn = false
    local label = CreateVarString(10, 'LITERAL_STRING', RSG.GroupPromptText)
    while IsInCharCreation do
        Wait(0)
        DrawLightWithRange(camloc.x, camloc.y, camloc.z, 255, 255, 255, 10.0, 100.0)
        PromptSetActiveGroupThisFrame(RoomPrompts, label)
    end
end

local creatorCameraMoving = false
local creatorCameraDirection = nil

local CREATOR_MIN_FOV = 20.0
local CREATOR_MAX_FOV = 65.0

local function CreatorCameraMoveLoop()
    if creatorCameraMoving then return end
    creatorCameraMoving = true

    CreateThread(function()
        while creatorCameraMoving do
            if IsInCharCreation and CharacterCreatorCamera and DoesCamExist(CharacterCreatorCamera) then
                if creatorCameraDirection == "up" or creatorCameraDirection == "down" then
                    local camCoords = GetCamCoord(CharacterCreatorCamera)
                    local hasZ, posZ = GetGroundZAndNormalFor_3dCoord(camloc.x, camloc.y, camloc.z + 0.5)
                    local minZ = (hasZ and posZ or camloc.z) + 0.2
                    local maxZ = camloc.z + 1

                    local z
                    if creatorCameraDirection == "up" then
                        z = math.min(camCoords.z + 0.015, maxZ)
                    else
                        z = math.max(camCoords.z - 0.015, minZ)
                    end

                    SetCamCoord(CharacterCreatorCamera, camloc.x, camloc.y, z)
                elseif creatorCameraDirection == "zoomin" or creatorCameraDirection == "zoomout" then
                    local fov = GetCamFov(CharacterCreatorCamera)
                    local newFov
                    if creatorCameraDirection == "zoomin" then
                        newFov = math.max(fov - 0.5, CREATOR_MIN_FOV)
                    else
                        newFov = math.min(fov + 0.5, CREATOR_MAX_FOV)
                    end
                    SetCamFov(CharacterCreatorCamera, newFov)
                elseif creatorCameraDirection == "rotateleft" or creatorCameraDirection == "rotateright" then
                    local heading = GetEntityHeading(PlayerPedId())
                    if creatorCameraDirection == "rotateleft" then
                        SetEntityHeading(PlayerPedId(), heading - 1.2)
                    else
                        SetEntityHeading(PlayerPedId(), heading + 1.2)
                    end
                end
            end
            Wait(0)
        end
    end)
end

AddEventHandler('rsg-character:client:CameraMoveStart', function(direction)
    creatorCameraDirection = direction
    CreatorCameraMoveLoop()
end)

AddEventHandler('rsg-character:client:CameraMoveStop', function()
    creatorCameraMoving = false
end)

AddEventHandler('rsg-character:client:CameraReset', function()
    if not (IsInCharCreation and CharacterCreatorCamera and DoesCamExist(CharacterCreatorCamera)) then return end
    local _, z = GetGroundZAndNormalFor_3dCoord(camloc.x, camloc.y, camloc.z + 0.5)
    SetCamCoord(CharacterCreatorCamera, camloc.x, camloc.y, z + 1.5)
    SetCamRot(CharacterCreatorCamera, 0.0, 0.0, camloc.w, 2)
    SetCamFov(CharacterCreatorCamera, 65.0)
    SetEntityHeading(PlayerPedId(), pedloc.w)
end)

function StartCharacterCreatorCamera(selected, camera)

    ClothesCache = {}
    CreatorCache = {}
    Firstname = nil
    Lastname = nil
    Nationality = nil
    Selectedsex = nil
    Birthdate = nil

    CreatorCache["sex"] = selected
    InCharacterCreator = false
    Selectedsex = selected

    Wait(1000)
    DoScreenFadeOut(3000)
    Wait(3000)

    Citizen.InvokeNative(0x203BEFFDBE12E96A, PlayerPedId(), pedloc, false, false, false)
    local Sexmodel = GetPedModel(selected)
    LoadModel(PlayerPedId(), Sexmodel)
    FixIssues(PlayerPedId())
    RandomizeCreatorAppearance(PlayerPedId())
    SetEntityVisible(PlayerPedId(), true)
    RenderScriptCams(false, true, 3000, true, true, 0)
    SetCamActive(cam, false)
    SetCamActive(camera, false)
    SetCamActive(CharacterCreatorCamera, true)

    RenderScriptCams(true, true, 1000, true, true, 0)
    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), true, 0, false)
    CreateThread(function()
        if DoesEntityExist(FemalePed) then
            DeletePed(FemalePed)
        end
        if DoesEntityExist(MalePed) then
            DeletePed(MalePed)
        end
    end)

    SetTimecycleModifier('Online_Character_Editor')
    Wait(1000)
    if UI and UI.HideLoadingScreen then UI.HideLoadingScreen() end
    DoScreenFadeIn(1000)
    repeat Wait(0) until IsScreenFadedIn()
    PrepareCreatorMusic()

    IsInCharCreation = true
    FirstMenu()
end

function PrepareCreatorMusic()
    Citizen.InvokeNative(0x120C48C614909FA4, "AZL_RDRO_Character_Creation_Area", true)
    Citizen.InvokeNative(0x9D5A25BADB742ACD, "AZL_RDRO_Character_Creation_Area_Other_Zones_Disable", true)
    PrepareMusicEvent("MP_CHARACTER_CREATION_START")
    Wait(100)
    TriggerMusicEvent("MP_CHARACTER_CREATION_START")
end

function EndCharacterCreatorCam(anim, anim1)
    IsInCharCreation = false
    DoScreenFadeOut(0)
    repeat Wait(0) until IsScreenFadedOut()
    DisplayHud(true)
    DisplayRadar(true)
    DestroyAllCams(true)
    FreezeEntityPosition(PlayerPedId() , false)
    if Sheriff then DeleteEntity(Sheriff) end
    if Deputy then DeleteEntity(Deputy) end
    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), true, 0, false)
    Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area", false, false)
    Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area_Other_Zones_Disable", false, false)
    Citizen.InvokeNative(0x706D57B0F50DA710, "MC_MUSIC_STOP")
    if animscene then
        Citizen.InvokeNative(0x84EEDB2C6E650000, animscene)
    end
    Citizen.InvokeNative(0x5A8B01199C3E79C3)
    pcall(function() exports['rsg-weather']:setSyncEnabled(true) end)
    ClearTimecycleModifier()
    RemoveImaps()
    AnimpostfxStopAll()
    ClearPedTasksImmediately(PlayerPedId(), true)
    if anim and anim1 then
        Citizen.InvokeNative(0x84EEDB2C6E650000, anim)
        Citizen.InvokeNative(0x84EEDB2C6E650000, anim1)
    end
    -- the server resets the routing bucket once the skin is saved
    local clothesHashes = ConvertCacheToHash(ClothesCache)
    local skin = ConvertCacheToHash(CreatorCache)

    TriggerServerEvent('rsg-character:server:SaveSkin', skin, clothesHashes)
end

function ConvertCacheToHash(ClothesCache)
    local clothesHashes = {}
    for k, v in pairs(ClothesCache) do
        if type(v) == 'table' then
            if v.model then
                local id = tonumber(v.model)
                if id >= 1 then
                    local list
                    if k == "beard" or k == "hair" then
                        list = hairs_list[IsPedMale(PlayerPedId()) and "male" or "female"][k]
                    else
                        list = clothing[IsPedMale(PlayerPedId()) and "male" or "female"][k]
                    end
                    if list?[id]?[tonumber(v.texture)] then
                        clothesHashes[k] = { hash = tonumber(list[id][tonumber(v.texture)].hash) }
                    end
                end
            elseif v.hash then
                clothesHashes[k] = v
            else
                clothesHashes[k] = v
            end
        else
            clothesHashes[k] = v
        end
    end
    return clothesHashes
end

function GetGender()
    if not IsPedMale(PlayerPedId()) then
        return "Female"
    end

    return "Male"
end

function SetCamFocusDistance(cam, focus)
    N_0x11f32bb61b756732(cam, focus)
end

function FotoMugshots()
    PromptSetVisible(CameraPrompt, 0)
    PromptSetVisible(RotatePrompt, 0)
    PromptSetVisible(ZoomPrompt, 0)
    local fullName = ('%s %s'):format(Firstname or '', Lastname or '')
    local animscenes = SetupScenes("Pl_Edit_to_Photo_" .. GetGender())
    StartAnimScene(animscenes)
    repeat Wait(0) until Citizen.InvokeNative(0xCBFC7725DE6CE2E0, animscenes)
    local NewCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", -560.55, -3782.15, 238.93, -5.73, 0.00, -96.05, 45, false, 0)
    SetCamFov(NewCam, 40.0)
    RenderScriptCams(true, false, 0, true, true, 0)
    Wait(2100)
    SetCamActive(NewCam, true)
    Wait(500)
    DoScreenFadeOut(50)
    SetCamFocusDistance(NewCam, 4.0)
    AnimpostfxPlay("CameraViewfinderStudioPosse")
    DoScreenFadeIn(0)
    local animxcene1 = SetupScenes("PI_Show_Hands_" .. GetGender())
    StartAnimScene(animxcene1)
    repeat Wait(0) until Citizen.InvokeNative(0xCBFC7725DE6CE2E0, animxcene1)
    Wait(4000)
    AnimpostfxPlay("l_00078a17dm")
    Wait(2000)
    CreateThread(function()
        while IsInCharCreation do
            Wait(0)
            DrawText3D(-558.64, -3782.30, 238.5, fullName, { 255, 255, 255, 255 })
        end
    end)
    ShowBusyspinnerWithText(locale('creator.photo_tip'))
    PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)
    TakePhoto()
    Wait(7000)
    BusyspinnerOff()
    SetCamFocusDistance(NewCam, 1.0)
    EndCharacterCreatorCam(animscenes, animxcene1)
end

function DrawText3D(x, y, z, text, color)
    local r, g, b, a = 255, 255, 255, 255
    if color then
        r, g, b, a = table.unpack(color)
    end
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    if onScreen then
        SetTextScale(0.4, 0.4)
        SetTextFontForCurrentCommand(25)
        SetTextColor(r, g, b, a)
        SetTextCentre(1)
        DisplayText(str, _x, _y)
        local factor = (string.len(text)) / 100
        DrawSprite("feeds", "toast_bg", _x, _y + 0.0125, 0.015 + factor, 0.03, 0.1, 0, 0, 0, 200, false)
    end
end

function TakePhoto()
    N_0x3c8f74e8fe751614()
    Citizen.InvokeNative(0xD45547D8396F002A)
    Citizen.InvokeNative(0xA15BFFC0A01B34E1)
    Citizen.InvokeNative(0xFA91736933AB3D93, true)
    Citizen.InvokeNative(0x8B3296278328B5EB, 2)
    Citizen.InvokeNative(0x2705D18C11B61046, false)
    Citizen.InvokeNative(0xD1031B83AC093BC7, "SetRegionPhotoTakenStat")
    Citizen.InvokeNative(0x9937FACBBF267244, "SetDistrictPhotoTakenStat")
    Citizen.InvokeNative(0x8952E857696B8A79, "SetStatePhotoTakenStat")
    Citizen.InvokeNative(0x57639FD876B68A91, 0)
end

function SetupScenes(string)
    local animzcene = CreateAnimScene("script@mp@character_creator@transitions", 0.25, string, false, true)
    SetAnimSceneEntity(animzcene, GetGender() .. "_MP", PlayerPedId(), 0)
    LoadAnimScene(animzcene)
    while not Citizen.InvokeNative(0x477122B8D05E7968, animzcene) do
        Wait(0)
    end
    return animzcene
end

function ShowBusyspinnerWithText(text)
    N_0x7f78cd75cc4539e4(CreateVarString(10, "LITERAL_STRING", text))
end

local HEAD_COLOR_MAP = { 1, 4, 3, 5, 2, 6 }
local HEAD_NUM_MAP_MALE = { [16] = 18, [17] = 21, [18] = 22, [19] = 25, [20] = 28 }
local HEAD_NUM_MAP_FEMALE = { [17] = 20, [18] = 22, [19] = 27, [20] = 28 }

function GetHashHead(aMale, num, color)
    color = HEAD_COLOR_MAP[tonumber(color) or 1] or 1
    num = tonumber(num) or 1
    num = (aMale and HEAD_NUM_MAP_MALE or HEAD_NUM_MAP_FEMALE)[num] or num
    local suffix = ("%03d"):format(num)..'_V_'..("%03d"):format(color)
    local sex = (aMale == true) and "M" or "F"
    local hashname = ('CLOTHING_ITEM_%s_HEAD_%s'):format(sex,suffix)
    if HeadHashTable and HeadHashTable[hashname] then
        return HeadHashTable[hashname]
    end
    return GetHashKey(hashname)
end

function LoadBoody(target, data)
    local bodySize = math.min(6, math.max(1, tonumber(data.body_size) or 1))
    local skinTone = math.min(6, math.max(1, tonumber(data.skin_tone) or 1))
    local output = GetSkinColorFromBodySize(bodySize, skinTone)
    local head, torso, legs
    local headNum = math.ceil((data.head or 1)/6)
    if IsPedMale(target) then
        head = GetHashHead(true, headNum, skinTone)
        torso = ComponentsMale["BODIES_UPPER"][output]
        legs = ComponentsMale["BODIES_LOWER"][output]
    else
        head = GetHashHead(false, headNum, skinTone)
        torso = ComponentsFemale["BODIES_UPPER"][output]
        legs = ComponentsFemale["BODIES_LOWER"][output]
    end
    NativeSetPedComponentEnabled(target, tonumber(head), false, true, true)
    NativeSetPedComponentEnabled(target, tonumber(torso), false, true, true)
    NativeSetPedComponentEnabled(target, tonumber(legs), false, true, true)
end

-- [body size][skin tone] -> BODIES_UPPER/LOWER component index
local SKIN_BODY_INDEX = {
    { 7, 10, 9, 11, 8, 12 },
    { 1, 4, 3, 5, 2, 6 },
    { 13, 16, 15, 17, 14, 18 },
    { 19, 22, 21, 23, 20, 24 },
    { 25, 28, 27, 29, 26, 30 },
    { 31, 34, 33, 35, 32, 36 },
}

function GetSkinColorFromBodySize(body, color)
    local row = SKIN_BODY_INDEX[body]
    return row and row[color]
end

function LoadHair(target, data)
    if data.hair ~= nil then
        if type(data.hair) ~= "table" then data.hair = { hash = data.hair } end
        if data.hair.model ~= nil then
            local model = tonumber(data.hair.model)
            if model and model > 0 then
                if IsPedMale(target) then
                    if hairs_list["male"]["hair"][tonumber(data.hair.model)] ~= nil then
                        if hairs_list["male"]["hair"][tonumber(data.hair.model)][tonumber(data.hair.texture)] ~= nil then
                            local hair = hairs_list["male"]["hair"][tonumber(data.hair.model)][tonumber(data.hair.texture)].hash
                            NativeSetPedComponentEnabled(target, tonumber(hair), false, true, true)
                        end
                    end
                else
                    if hairs_list["female"]["hair"][tonumber(data.hair.model)] ~= nil then
                        if hairs_list["female"]["hair"][tonumber(data.hair.model)][tonumber(data.hair.texture)] ~=
                            nil then
                            local hair = hairs_list["female"]["hair"][tonumber(data.hair.model)][tonumber(data.hair.texture)].hash
                            NativeSetPedComponentEnabled(target, tonumber(hair), false, true, true)
                        end
                    end
                end
            else
                Citizen.InvokeNative(0xD710A5007C2AC539, target, 0x864B03AE, 0)
                NativeUpdatePedVariation(target)
            end
        elseif data.hair.hash then
            if data.hair.hash ~= 0 then
                NativeSetPedComponentEnabled(target, tonumber(data.hair.hash), false, true, true)
            else
                Citizen.InvokeNative(0xD710A5007C2AC539, target, 0x864B03AE, 0)
                NativeUpdatePedVariation(target)
            end
        end
    end
end

function LoadBeard(target, data)
    if data.beard ~= nil then
        if type(data.beard) ~= "table" then data.beard = { hash = data.beard } end
        if data.beard.model ~= nil then
            local model = tonumber(data.beard.model)
            if model and model > 0 then
                if IsPedMale(target) then
                    if hairs_list["male"]["beard"][tonumber(data.beard.model)] ~= nil then
                        if hairs_list["male"]["beard"][tonumber(data.beard.model)][tonumber(data.beard.texture)] ~=
                            nil then
                            local beard = hairs_list["male"]["beard"][tonumber(data.beard.model)][tonumber(data.beard.texture)].hash
                            NativeSetPedComponentEnabled(target, tonumber(beard), false, true, true)
                        end
                    end
                end
            else
                Citizen.InvokeNative(0xD710A5007C2AC539, target, 0xF8016BCA, 0)
                NativeUpdatePedVariation(target)
            end
        elseif data.beard.hash then
            if data.beard.hash ~= 0 then
                NativeSetPedComponentEnabled(target, tonumber(data.beard.hash), false, true, true)
            else
                Citizen.InvokeNative(0xD710A5007C2AC539, target, 0xF8016BCA, 0)
                NativeUpdatePedVariation(target)
            end
        end
    end
end

function LoadHead(target, data)
    local headNum = math.max(1, math.ceil((tonumber(data.head) or 1) / 6))
    local head = GetHashHead(IsPedMale(target), headNum, data.skin_tone)
    NativeSetPedComponentEnabled(target, tonumber(head), false, true, true)
end

function LoadEyes(target, data)
    if IsPedMale(target) then
        local eyes_color = ComponentsMale["eyes"][tonumber(data.eyes_color) or 1]
        NativeSetPedComponentEnabled(target, tonumber(eyes_color), false, true, true)
    else
        local eyes_color = ComponentsFemale["eyes"][tonumber(data.eyes_color) or 1]
        NativeSetPedComponentEnabled(target, tonumber(eyes_color), false, true, true)
    end
end

function LoadBodyFeature(target, data, bodyFeatureTable)
    Citizen.InvokeNative(0x1902C4CFCC5BE57C, target, bodyFeatureTable[tonumber(data)])
    Citizen.InvokeNative(0xCC8CA3E88256E58F, target, false, true, true, true, false)
end

function LoadFeatures(target, data)
    for k, v in pairs(Data.features) do
        if data[k] ~= nil then
            local value = data[k] / 100
            NativeSetPedFaceFeature(target, v, value)
        end
    end
    LoadTeeth(target, data)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, target, false, true, true, true, false)
end

function LoadTeeth(target, data)
    if not data or data.teeth == nil then return end
    local list = (IsPedMale(target) and ComponentsMale or ComponentsFemale)["teeth"]
    local hash = list and list[tonumber(data.teeth) or 1]
    if hash then
        NativeSetPedComponentEnabled(target, tonumber(hash), false, true, true)
        NativeUpdatePedVariation(target)
    end
end

function LoadHeight(target, data)
    if data.height then
        local height = tonumber(data.height * 0.01)

        Wait(100)

        SetPedScale(target, height)
    end
end

function FixIssues(target)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, target, 7, 0)
    NativeUpdatePedVariation(target)
    if IsPedMale(target) then
        NativeSetPedComponentEnabled(target, tonumber(ComponentsMale["BODIES_UPPER"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsMale["BODIES_LOWER"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsMale["heads"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsMale["eyes"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsMale["teeth"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsMale["heads"][1]), false, true, true)
        Citizen.InvokeNative(0xD710A5007C2AC539, target, 0x1D4C528A, 0)
    else
        NativeSetPedComponentEnabled(target, tonumber(ComponentsFemale["BODIES_UPPER"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsFemale["BODIES_LOWER"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsFemale["heads"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsFemale["eyes"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsFemale["teeth"][1]), false, true, true)
        NativeSetPedComponentEnabled(target, tonumber(ComponentsFemale["heads"][1]), false, true, true)
    end
    Citizen.InvokeNative(0xD710A5007C2AC539, target, 0x3F1F01E5, 0)
    Citizen.InvokeNative(0xD710A5007C2AC539, target, 0xDA0E2C55, 0)
    NativeUpdatePedVariation(target)
end

function LoadOverlays(target, data)

    if tonumber(data.eyebrows_t) ~= nil and tonumber(data.eyebrows_op) ~= nil then
        ChangeOverlays("eyebrows", 1, tonumber(data.eyebrows_t), 0, 0, 0, 1.0, 0, tonumber(data.eyebrows_id) or 1,
            tonumber(data.eyebrows_c1) or 0, 0, 0, 0, tonumber(data.eyebrows_op / 100))
    else
        ChangeOverlays("eyebrows", 1, 1, 0, 0, 0, 1.0, 0, 10, 0, 0, 0, 0, 1.0)
    end

    if tonumber(data.scars_t) ~= nil and tonumber(data.scars_op) ~= nil then
        ChangeOverlays("scars", 1, tonumber(data.scars_t), 0, 0, 1, 1.0, 0, tonumber(0), 0, 0, 0, tonumber(0),
            tonumber(data.scars_op / 100))
    end

    if tonumber(data.ageing_t) ~= nil and tonumber(data.ageing_op) ~= nil then
        ChangeOverlays("ageing", 1, tonumber(data.ageing_t), 0, 0, 1, 1.0, 0, tonumber(0), 0, 0, 0, tonumber(0),
            tonumber(data.ageing_op / 100))
    end

    if tonumber(data.freckles_t) ~= nil and tonumber(data.freckles_op) ~= nil then
        ChangeOverlays("freckles", 1, tonumber(data.freckles_t), 0, 0, 1, 1.0, 0, tonumber(0), 0, 0, 0, tonumber(0),
            tonumber(data.freckles_op / 100))
    end

    if tonumber(data.moles_t) ~= nil and tonumber(data.moles_op) ~= nil then
        ChangeOverlays("moles", 1, tonumber(data.moles_t), 0, 0, 1, 1.0, 0, tonumber(0), 0, 0, 0, tonumber(0),
            tonumber(data.moles_op / 100))
    end

    if tonumber(data.spots_t) ~= nil and tonumber(data.spots_op) ~= nil then
        ChangeOverlays("spots", 1, tonumber(data.spots_t), 0, 0, 1, 1.0, 0, tonumber(0), 0, 0, 0, tonumber(0),
            tonumber(data.spots_op / 100))
    end

    if tonumber(data.eyeliners_t) ~= nil and tonumber(data.eyeliners_op) ~= nil then
        ChangeOverlays("eyeliners", 1, 1, 0, 0, 0, 1.0, 0, tonumber(data.eyeliners_id) or 1,
            tonumber(data.eyeliners_c1) or 0, 0, 0, tonumber(data.eyeliners_t), tonumber(data.eyeliners_op / 100))
    end

    if tonumber(data.shadows_t) ~= nil and tonumber(data.shadows_op) ~= nil then
        ChangeOverlays("shadows", 1, tonumber(1), 0, 0, 0, 1.0, 0, tonumber(data.shadows_id) or 1,
            tonumber(data.shadows_c1) or 0, 0, 0, tonumber(data.shadows_t), tonumber(data.shadows_op / 100))
    end

    if tonumber(data.lipsticks_t) ~= nil and tonumber(data.lipsticks_op) ~= nil then
        ChangeOverlays("lipsticks", 1, 1, 0, 0, 0, 1.0, 0, tonumber(data.lipsticks_id) or 1,
            tonumber(data.lipsticks_c1) or 0, tonumber(data.lipsticks_c2) or 0, 0, tonumber(data.lipsticks_t),
            tonumber(data.lipsticks_op / 100))
    end

    if tonumber(data.blush_t) ~= nil and tonumber(data.blush_op) ~= nil then
        ChangeOverlays("blush", 1, tonumber(data.blush_t), 0, 0, 0, 1.0, 0, tonumber(data.blush_id) or 1,
            tonumber(data.blush_c1) or 0, 0, 0, 0, tonumber(data.blush_op / 100))
    end

    if tonumber(data.beardstabble_t) ~= nil and tonumber(data.beardstabble_op) ~= nil then
        ChangeOverlays("beardstabble", 1, 1, 0, 0, 0, 1.0, 0, 10, 0, 0, 0, 0, tonumber(data.beardstabble_op / 100))
    end
    ApplyOverlays(target)
end

function GetMaxTexturesForModel(category, model, isClothing)
    if model == 0 then
        model = 1
    end
    local gender = IsPedMale(PlayerPedId()) and "male" or "female"

    if isClothing then
        return #clothing[gender][category][model]
    else
        return #hairs_list[gender][category][model]
    end
end

function NativeSetPedFaceFeature(ped, index, value)
    Citizen.InvokeNative(0x5653AB26C82938CF, ped, index, value)
    NativeUpdatePedVariation(ped)
end

function NativeSetPedComponentEnabled(ped, componentHash, immediately, isMp)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, componentHash, immediately, isMp, true)
    NativeUpdatePedVariation(ped)
end

function NativeHasPedComponentLoaded(ped)
    return Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped)
end

function GetPedModel(sex)
    local model = "mp_male"
    if sex == 1 then
        model = "mp_male"
    elseif sex == 2 then
        model = "mp_female"
    end
    return model
end

function pairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, f)
    local i = 0
    local iter = function ()
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function NativeSetPedComponentEnabledClothes(ped, componentHash, immediately, isMp)
    local categoryHash = NativeGetPedComponentCategory(not IsPedMale(ped), componentHash)

    NativeFixMeshIssues(ped, categoryHash)

    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, componentHash, immediately, isMp, true)
    NativeUpdatePedVariation(ped)
end

function NativeGetPedComponentCategory(isFemale, componentHash)
    return Citizen.InvokeNative(0x5FF9A878C3D115B8, componentHash, isFemale, true)
end

function NativeFixMeshIssues(ped, categoryHash)
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, categoryHash)
end

function NativeUpdatePedVariation(ped)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    Citizen.InvokeNative(0xAAB86462966168CE, ped or PlayerPedId(), true)
    local deadline = GetGameTimer() + 5000
    while not NativeHasPedComponentLoaded(ped) do
        if GetGameTimer() > deadline then
            break
        end
        Wait(0)
    end
end

CreateThread(function()
    while true do
        local sleep = 1000
        if lightsOn then
            sleep = 1
            DrawLightWithRange(-560.1646, -3782.066, 238.5975, 255, 255, 255, 10.0, 100.0)
        end
        Wait(sleep)
    end
end)

function RandomizeCreatorAppearance(target)
    local function rnd(min, max) return math.random(min, max) end
    local function rndFeature() return rnd(-8, 8) * 5 end
    local isMale = IsPedMale(target)
    local gender = isMale and "male" or "female"

    CreatorCache["head"] = rnd(1, 120)
    CreatorCache["skin_tone"] = rnd(1, 6)
    CreatorCache["body_size"] = rnd(1, math.min(6, #Data.Appearance.body_size))
    CreatorCache["body_waist"] = rnd(1, #Data.Appearance.body_waist)
    CreatorCache["eyes_color"] = rnd(1, 18)
    CreatorCache["teeth"] = rnd(1, 7)

    CreatorCache["eyebrows_t"] = rnd(1, 15)
    CreatorCache["eyebrows_op"] = rnd(14, 20) * 5
    CreatorCache["eyebrows_id"] = 10
    CreatorCache["eyebrows_c1"] = rnd(0, 64)

    local hairModels = hairs_list[gender]["hair"]
    local hairModel = rnd(1, #hairModels)
    CreatorCache["hair"] = { model = hairModel, texture = rnd(1, #hairModels[hairModel]) }

    if isMale then
        local beards = hairs_list["male"]["beard"]
        if rnd(1, 100) <= 40 then
            CreatorCache["beard"] = { model = 0, texture = 1 }
        else
            local beardModel = rnd(1, #beards)
            local tex = math.min(CreatorCache["hair"].texture, #beards[beardModel])
            CreatorCache["beard"] = { model = beardModel, texture = tex }
        end
    end

    local faceKeys = {
        "face_width", "eyes_depth", "eyes_angle", "eyes_distance", "eyelid_height", "eyelid_width",
        "eyebrow_height", "eyebrow_width", "eyebrow_depth",
        "nose_width", "nose_size", "nose_height", "nose_angle", "nose_curvature", "nostrils_distance",
        "mouth_width", "mouth_depth", "mouth_x_pos", "mouth_y_pos",
        "upper_lip_height", "upper_lip_width", "upper_lip_depth",
        "lower_lip_height", "lower_lip_width", "lower_lip_depth",
        "cheekbones_height", "cheekbones_width", "cheekbones_depth",
        "jaw_height", "jaw_width", "jaw_depth", "chin_height", "chin_width", "chin_depth",
        "ears_width", "ears_angle", "ears_height", "ears_size",
    }
    for _, k in ipairs(faceKeys) do
        if Data.features[k] then CreatorCache[k] = rndFeature() end
    end

    LoadBoody(target, CreatorCache)
    LoadBodyFeature(target, CreatorCache.body_size, Data.Appearance.body_size)
    LoadBodyFeature(target, CreatorCache.body_waist, Data.Appearance.body_waist)
    LoadBoody(target, CreatorCache)
    LoadEyes(target, CreatorCache)
    LoadHair(target, CreatorCache)
    if isMale then LoadBeard(target, CreatorCache) end
    LoadFeatures(target, CreatorCache)
    LoadOverlays(target, CreatorCache)
    NativeUpdatePedVariation(target)

    RandomizeToken = (RandomizeToken or 0) + 1
    local token = RandomizeToken
    CreateThread(function()
        for _ = 1, 2 do
            local timeout = GetGameTimer() + 3000
            while not NativeHasPedComponentLoaded(target) and GetGameTimer() < timeout do Wait(0) end
            if token ~= RandomizeToken then return end
            LoadBoody(target, CreatorCache)
            NativeUpdatePedVariation(target)
            Wait(100)
        end
        if token == RandomizeToken then LoadOverlays(target, CreatorCache) end
    end)
end
