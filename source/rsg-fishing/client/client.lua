local RSGCore = exports['rsg-core']:GetCoreObject()
local fishing_minigame_struct = {}
local fishing_lure_cooldown = 0
local ready = false
local fishing = false
local fishStatus = 0
local fishForce = 0.6
local nextAttTime = 0
local tempoPuxando = 0
local horizontalMove = 0
local currentLure = nil
local hasMinigameOn = false
lib.locale()

local fishing_data = {
    fish                   = { weight = 0, rodweight = 0 },
    prompt_prepare_fishing = { group = nil, change_bait = nil, throw_hook = nil },
    prompt_waiting_hook    = { group = nil, hook_fish = nil, reel_lure = nil, cancel = nil },
    prompt_hook            = { group = nil, reel = nil, cancel = nil },
    prompt_finish          = { group = nil, keep_fish = nil, throw_fish = nil }
}

local fishs = {
    [`A_C_FISHBLUEGIL_01_MS`]        = Config.fishData.A_C_FISHBLUEGIL_01_MS[1],
    [`A_C_FISHBLUEGIL_01_SM`]        = Config.fishData.A_C_FISHBLUEGIL_01_SM[1],
    [`A_C_FISHBULLHEADCAT_01_MS`]    = Config.fishData.A_C_FISHBULLHEADCAT_01_MS[1],
    [`A_C_FISHBULLHEADCAT_01_SM`]    = Config.fishData.A_C_FISHBULLHEADCAT_01_SM[1],
    [`A_C_FISHCHAINPICKEREL_01_MS`]  = Config.fishData.A_C_FISHCHAINPICKEREL_01_MS[1],
    [`A_C_FISHCHAINPICKEREL_01_SM`]  = Config.fishData.A_C_FISHCHAINPICKEREL_01_SM[1],
    [`A_C_FISHCHANNELCATFISH_01_LG`] = Config.fishData.A_C_FISHCHANNELCATFISH_01_LG[1],
    [`A_C_FISHCHANNELCATFISH_01_XL`] = Config.fishData.A_C_FISHCHANNELCATFISH_01_XL[1],
    [`A_C_FISHLAKESTURGEON_01_LG`]   = Config.fishData.A_C_FISHLAKESTURGEON_01_LG[1],
    [`A_C_FISHLARGEMOUTHBASS_01_LG`] = Config.fishData.A_C_FISHLARGEMOUTHBASS_01_LG[1],
    [`A_C_FISHLARGEMOUTHBASS_01_MS`] = Config.fishData.A_C_FISHLARGEMOUTHBASS_01_MS[1],
    [`A_C_FISHLONGNOSEGAR_01_LG`]    = Config.fishData.A_C_FISHLONGNOSEGAR_01_LG[1],
    [`A_C_FISHMUSKIE_01_LG`]         = Config.fishData.A_C_FISHMUSKIE_01_LG[1],
    [`A_C_FISHNORTHERNPIKE_01_LG`]   = Config.fishData.A_C_FISHNORTHERNPIKE_01_LG[1],
    [`A_C_FISHPERCH_01_MS`]          = Config.fishData.A_C_FISHPERCH_01_MS[1],
    [`A_C_FISHPERCH_01_SM`]          = Config.fishData.A_C_FISHPERCH_01_SM[1],
    [`A_C_FISHRAINBOWTROUT_01_LG`]   = Config.fishData.A_C_FISHRAINBOWTROUT_01_LG[1],
    [`A_C_FISHRAINBOWTROUT_01_MS`]   = Config.fishData.A_C_FISHRAINBOWTROUT_01_MS[1],
    [`A_C_FISHREDFINPICKEREL_01_MS`] = Config.fishData.A_C_FISHREDFINPICKEREL_01_MS[1],
    [`A_C_FISHREDFINPICKEREL_01_SM`] = Config.fishData.A_C_FISHREDFINPICKEREL_01_SM[1],
    [`A_C_FISHROCKBASS_01_MS`]       = Config.fishData.A_C_FISHROCKBASS_01_MS[1],
    [`A_C_FISHROCKBASS_01_SM`]       = Config.fishData.A_C_FISHROCKBASS_01_SM[1],
    [`A_C_FISHSALMONSOCKEYE_01_LG`]  = Config.fishData.A_C_FISHSALMONSOCKEYE_01_LG[1],
    [`A_C_FISHSALMONSOCKEYE_01_ML`]  = Config.fishData.A_C_FISHSALMONSOCKEYE_01_ML[1],
    [`A_C_FISHSALMONSOCKEYE_01_MS`]  = Config.fishData.A_C_FISHSALMONSOCKEYE_01_MS[1],
    [`A_C_FISHSMALLMOUTHBASS_01_LG`] = Config.fishData.A_C_FISHSMALLMOUTHBASS_01_LG[1],
    [`A_C_FISHSMALLMOUTHBASS_01_MS`] = Config.fishData.A_C_FISHSMALLMOUTHBASS_01_MS[1],
}

RegisterNetEvent('rsg-fishing:client:usebait')
AddEventHandler('rsg-fishing:client:usebait', function(UsableBait)
    if fishing then
        -- already mid-cast, ignore duplicate/rapid bait usage instead of stacking threads
        lib.notify({ title = locale('cl_error'), description = locale('cl_already_fishing'), type = 'error', duration = 5000 })
        return
    end

    local weapon = GetPedCurrentHeldWeapon(cache.ped)
    local weaponName = GetWeaponName(weapon)

    if weaponName ~= 'WEAPON_FISHINGROD' then
        lib.notify({ title = locale('cl_error'), description = locale('cl_you_need_use_your_fishing_rod_first'), type = 'error', duration = 7000 })
        return
    end

    CreateThread(function()
        Citizen.InvokeNative(0x1096603B519C905F, "MMFSH")
        prepareMyPrompt()
        fishing = true
        local sleep = 1500
        currentLure = UsableBait
        UsableBait = nil
        ready = false

        TriggerServerEvent('rsg-fishing:server:removeBaitItem', currentLure)
        StartBobberMarker()
        
        local noRodSince = nil
        while fishing do
            -- every other way out of this loop needs the minigame to be running; putting the rod away before the cast
            -- (holster, another weapon, death) never ended it, so the panel and the last bait stayed for good
            if GetWeaponName(GetPedCurrentHeldWeapon(cache.ped)) == 'WEAPON_FISHINGROD' and not IsPedDeadOrDying(cache.ped, true) then
                noRodSince = nil
            elseif not noRodSince then
                noRodSince = GetGameTimer()
            elseif GetGameTimer() - noRodSince > 2000 then
                fishing = false
                SetFishingBait(cache.ped, "", 0, 1)
                break
            end
            GET_TASK_FISHING_DATA()
            if FISHING_GET_MINIGAME_STATE() == 1 and ready == false then
                ready = true
                if Config.Debug then print("Current bait: "..currentLure) end
                TaskSwapFishingBait(cache.ped, currentLure, 0)
                SetFishingBait(cache.ped, currentLure, 0, 1)
            end

            if hasMinigameOn then
                sleep = 4

                if FISHING_GET_MINIGAME_STATE() == 2 then
                    FISHING_SET_F_(1, math.random(25.0, 30.0))
                end

                if FISHING_GET_MINIGAME_STATE() == 6 then

                    if IsControlJustPressed(0, 0x8FFC75D6) then
                        FISHING_SET_F_(6, 128)
                    end

                    local bobberPosition = FISHING_GET_BOBBER_HANDLE()

                    local hookHandle = FISHING_GET_HOOK_HANDLE()
                    local hookPosition = GetEntityCoords(hookHandle)
                    local lured = false

                    if IsControlPressed(0, GetHashKey("INPUT_DUCK")) then
                        local actualReelSpeed = Config.ReelSpeed
                        local playerCoords = GetEntityCoords(cache.ped, true, true)
                        local distance = playerCoords - hookPosition

                        distance = hookPosition + distance * actualReelSpeed
                        SetEntityCoords(hookHandle, distance.x, distance.y, distance.z, false, false, false, false)
                    end

                    if FISHING_GET_LINE_DISTANCE() < 4.0 then
                        FISHING_SET_F_(14, 1.0)
                    else
                        FISHING_SET_F_(14, 0.4)
                    end

                    local fishHandle
                    for _, f in pairs(GetNearbyFishs(hookPosition, 50.0)) do
                        local fishPosition = GetEntityCoords(f)
                        if Config.Debug then
                            Citizen.InvokeNative(GetHashKey("DRAW_LINE") & 0xFFFFFFFF, fishPosition, fishPosition + vec3(0, 0, 2.0), 255, 255, 0, 255)
                        end
                        if fishing_lure_cooldown <= GetGameTimer() then
                            local dist = #(hookPosition - fishPosition)
                            if dist <= 1.6 then
                                fishHandle = f
                            else
                                if isFishInterested(GetEntityModel(f)) then
                                    TaskGoToEntity(f, bobberPosition, 100, 1, 1.0, 2.0, 0)
                                end
                            end

                            if lured == false then
                                lured = true
                            end
                        end
                    end

                    if lured then
                        fishing_lure_cooldown = GetGameTimer() + (1 * 1000)
                    end

                    if fishHandle then
                        local probabilidadePuxar = math.random()
                        if probabilidadePuxar > 0.9 or probabilidadePuxar < 0.2 then -- soltar linha
                            if FISHING_GET_F_(5) == 1 then
                                Citizen.InvokeNative(0xF0FBF193F1F5C0EA, fishHandle)

                                SetPedConfigFlag(fishHandle, 17, true)

                                Citizen.InvokeNative(0x1F298C7BD30D1240, cache.ped)

                                ClearPedTasksImmediately(fishHandle, false, true)
                                TaskSetBlockingOfNonTemporaryEvents(fishHandle, true)

                                PedFishingrodHookEntity(cache.ped, fishHandle)

                                FISHING_SET_FISH_HANDLE(fishHandle)
                                fishForce = 0.6

                                FISHING_SET_TRANSITION_FLAG(4)
                            end
                        end
                    end
                end

                if FISHING_GET_MINIGAME_STATE() == 7 then
                    fishing_data.fish.weight = FISHING_GET_F_(8)

                    if IsControlJustPressed(0, 0x8FFC75D6) then
                        FISHING_SET_F_(6, 11)
                    end
                    local fishHandle = FISHING_GET_FISH_HANDLE()

                    if GetControlNormal(0, 0x390948DC) > 0 then -- Direita
                        horizontalMove = horizontalMove - (0.05 * GetControlNormal(0, 0x390948DC))
                    end
                    if GetControlNormal(0, 0x390948DC) < 0 then -- Esquerda
                        horizontalMove = horizontalMove + (0.05 * -GetControlNormal(0, 0x390948DC))
                    end
                    if horizontalMove < 0 then
                        horizontalMove = 0
                    end
                    if horizontalMove > 1 then
                        horizontalMove = 1
                    end
                    FISHING_SET_F_(22, horizontalMove)


                    if FISHING_GET_LINE_DISTANCE() < 4.0 then
                        FISHING_SET_F_(6, 12)
                        FISHING_SET_F_(14, 1.0)
                    else
                        FISHING_SET_F_(14, 1.0)
                    end

                     if GetGameTimer() >= nextAttTime then
                         local probabilidadePuxar = math.random()
                         if probabilidadePuxar < Config.StruggleChance then -- fish struggles (less frequently)
                             fishForce = 0.6 -- reduced force required
                             tempoPuxando = math.random(1, 3) * 1000 -- shorter struggle duration
                             fishStatus = 1 -- agitated
                             nextAttTime = GetGameTimer() + tempoPuxando

                            local fishHandle = FISHING_GET_FISH_HANDLE()
                            local x,y,z = table.unpack(GetEntityCoords(fishHandle))

                            local r = exports["rsg-fishing"]:VERTICAL_PROBE(x, y,  z, 1)
                            local valid, height = r[1], r[2]

                        -- import from ptfx on rsg-fishing c# version
                        local particlecoords = GetEntityCoords(fishHandle)
                        RequestNamedPtfxAsset(GetHashKey('scr_mg_fishing'))
                            while not HasNamedPtfxAssetLoaded(GetHashKey('scr_mg_fishing')) do
                                Wait(5)
                            end
                        UseParticleFxAsset("scr_mg_fishing")
                        local Fisheffect = StartParticleFxNonLoopedAtCoord("scr_mg_fish_struggle", particlecoords, 0.0, 0.0, math.random(0, 360) + 0.0001, 1.5, 0, 0, 0)
                        SetParticleFxLoopedAlpha(Fisheffect, 1.0)
                        else
                             fishForce = 0
                             tempoPuxando = math.random(2, 5) * 1000
                             fishStatus = 0 -- relaxed
                             nextAttTime = GetGameTimer() + tempoPuxando
                         end
                    end

                    if fishStatus == 1 then
                        if IsControlPressed(0, GetHashKey("INPUT_GAME_MENU_OPTION")) then
                            FISHING_SET_ROD_WEIGHT(4)
                            fishForce = fishForce + 0.005
                        else
                            fishForce = fishForce - 0.005
                        end

                        if IsControlJustReleased(0, GetHashKey("INPUT_GAME_MENU_OPTION")) then
                            FISHING_SET_ROD_WEIGHT(2)
                        end

                         if fishForce >= 1.0 then -- reduced threshold for catching
                             FISHING_SET_F_(6, 11)
                         else
                             if fishForce < 0.6 then
                                 fishForce = 0.6
                             end
                         end
                        TaskSmartFleeCoord(fishHandle, GetEntityCoords(cache.ped), 40.0, 50, 8, 1077936128)

                         -- import from ptfx on rsg-fishing c# version
                        local particlecoords = GetEntityCoords(fishHandle)
                        RequestNamedPtfxAsset(GetHashKey('scr_mg_fishing'))
                            while not HasNamedPtfxAssetLoaded(GetHashKey('scr_mg_fishing')) do
                                Wait(5)
                            end
                        UseParticleFxAsset("scr_mg_fishing")
                        local Fisheffect = StartParticleFxNonLoopedAtCoord("scr_mg_fish_struggle", particlecoords, 0.0, 0.0, math.random(0, 360) + 0.0001, 1.5, 0, 0, 0)
                        SetParticleFxLoopedAlpha(Fisheffect, 1.0)

                    else
                        if IsControlJustPressed(0, GetHashKey("INPUT_GAME_MENU_OPTION")) or (IsControlPressed(0, GetHashKey("INPUT_GAME_MENU_OPTION")) and GetGameTimer() % 25 == 0) then
                            FISHING_SET_ROD_WEIGHT(4)
                            TaskGoToEntity(fishHandle, cache.ped, Config.Difficulty, 1.0, 1.5, 0.0, 0)
                        end

                        if IsControlJustReleased(0, GetHashKey("INPUT_GAME_MENU_OPTION")) then
                            FISHING_SET_ROD_WEIGHT(2)
                        end
                    end

                    if FISHING_GET_F_(6) ~= 11 and FISHING_GET_F_(6) ~= 12 then
                        FISHING_SET_F_(13, fishForce)
                        FISHING_SET_F_(21, fishForce)
                    end

                    if IsControlJustPressed(0, GetHashKey("INPUT_ATTACK")) then
                        FISHING_SET_ROD_POSITION_UD(0.6)
                    end

                    if IsControlJustReleased(0, GetHashKey("INPUT_ATTACK")) then
                        FISHING_SET_ROD_POSITION_UD(0.0)
                    end            
                end

                if FISHING_GET_MINIGAME_STATE() == 12 then
                    if IsControlJustPressed(0, GetHashKey("INPUT_ATTACK")) then
                        if fishing then
                            FISHING_SET_TRANSITION_FLAG(32)
                            fishing = false
                            local entity = FISHING_GET_FISH_HANDLE()
                            local fishModel = GetEntityModel(entity)
                            local fishWeight = fishing_data.fish.weight
                            TriggerServerEvent("rsg-fishing:FishToInventory", fishModel, fishWeight)
                            SetEntityAsMissionEntity(entity, true, true)
                            Wait(3000)
                            DeleteEntity(entity)
                            SetFishingBait(cache.ped, "", 0, 1)
                        end
                    end

                    if IsControlJustPressed(0, GetHashKey("INPUT_AIM")) then
                        if fishing then
                            fishing = false
                            local entity = FISHING_GET_FISH_HANDLE()
                            local fishModel = GetEntityModel(entity)
                            SetFishingBait(cache.ped, "", 0, 1)
                            FISHING_SET_TRANSITION_FLAG(64)
                            SetEntityAsMissionEntity(entity, true, true)
                            Wait(3000)
                            DeleteEntity(entity)
                        end
                    end

                    if FISHING_GET_F_(5) == 96 and FISHING_GET_F_(6) == 0 then
                        fishing = false
                        SetFishingBait(cache.ped, "", 0, 1)
                        local entity = FISHING_GET_FISH_HANDLE()
                        SetEntityAsMissionEntity(entity, true, true)
                        Wait(3000)
                        DeleteEntity(entity)
                    end
                end

                if IsControlJustPressed(0, GetHashKey("INPUT_TOGGLE_HOLSTER")) then
                    fishing = false
                    FISHING_SET_TRANSITION_FLAG(8)
                    SetFishingBait(cache.ped, "", 0, 1)
                end
            end
            Wait(sleep)
        end
        -- the cast is over (kept, thrown back, line cut, rod put away): forget the bait so the next one starts clean
        currentLure = nil
        ready = false
    end)
end)

-- =========================================================
-- Controls HUD (NUI, top-left) – replaces native prompt groups
-- =========================================================
local hudKey = nil
local hudRows = nil

local function resolveControl(c)
    if type(c) == 'string' then return joaat(c) end
    return c
end

-- live key-press feedback: highlights a row while its button is held
CreateThread(function()
    local last = {}
    while true do
        if hudRows then
            local changed, pressed = false, {}
            for _, r in ipairs(hudRows) do
                local c = resolveControl(Config.ControlInputs[r.id])
                local down = c and (IsControlPressed(0, c) or IsDisabledControlPressed(0, c)) or false
                pressed[r.id] = down
                if last[r.id] ~= down then changed = true end
            end
            if changed then
                last = pressed
                SendNUIMessage({ action = 'pressed', pressed = pressed })
            end
            Wait(0)
        else
            last = {}
            Wait(250)
        end
    end
end)

local function holdingRod()
    local weapon = GetPedCurrentHeldWeapon(cache.ped)
    return weapon and GetWeaponName(weapon) == 'WEAPON_FISHINGROD'
end

local function baitLabel()
    if not currentLure then return nil end
    local item = RSGCore.Shared.Items[currentLure]
    return (item and item.label) or currentLure
end

local function controlsFor(state)
    local k = Config.ControlKeys
    if not fishing then
        if holdingRod() then
            return locale('cl_no_bait'), 'nobait', {
                { id = 'UseBait', key = k.UseBait, label = locale('cl_use_bait_hint') },
            }, nil
        end
        return nil
    end
    if state ~= 6 and state ~= 7 and state ~= 12 then
        -- baited / preparing / aiming / casting: keep showing cast instructions
        return locale('cl_ready_to_fish'), nil, {
            { id = 'Prepare', key = k.Prepare, label = locale('cl_prepare_fishing_rod') },
            { id = 'Cast', key = k.Cast,    label = locale('cl_cast_fishing_rod') },
        }
    elseif state == 6 then
        return locale('cl_fishing'), nil, {
            { id = 'Hook', key = k.Hook,      label = locale('cl_hook') },
            { id = 'ResetCast', key = k.ResetCast, label = locale('cl_reset_cast') },
            { id = 'ReelLure', key = k.ReelLure,  label = locale('cl_reel_lure') },
        }
    elseif state == 7 then
        return locale('cl_get_the_fish'), 'hooked', {
            { id = 'ReelIn', key = k.ReelIn,    label = locale('cl_reel_in') },
            { id = 'ResetCast', key = k.ResetCast, label = locale('cl_reset_cast') },
        }
    elseif state == 12 then
        local name = fishs[GetEntityModel(FISHING_GET_FISH_HANDLE())]
        if not name then
            return locale('cl_ready_to_fish'), nil, {
                { id = 'Prepare', key = k.Prepare, label = locale('cl_prepare_fishing_rod') },
                { id = 'Cast',    key = k.Cast,    label = locale('cl_cast_fishing_rod') },
            }
        end
        local sub = locale('cl_name')..": "..name.."  //  "..locale('cl_weight')..": "..string.format("%.2f", fishing_data.fish.weight * Config.FishWeightMultiplier).."Kg"
        return sub, 'caught', {
            { id = 'KeepFish', key = k.KeepFish,  label = locale('cl_keep_fish') },
            { id = 'ThrowFish', key = k.ThrowFish, label = locale('cl_throw_fish') },
        }
    end
end

CreateThread(function()
    while true do
        local t = 250
        local state = FISHING_GET_MINIGAME_STATE()
        if state == 7 then fishing_data.fish.weight = FISHING_GET_F_(8) end

        local title, mode, rows = controlsFor(state)
        local info = (fishing and baitLabel()) and (locale('cl_bait') .. ": " .. baitLabel()) or nil
        local key = title and (tostring(state) .. "|" .. title .. "|" .. tostring(info)) or nil
        if key ~= hudKey then
            hudKey = key
            if rows then
                hudRows = rows
                SendNUIMessage({ action = 'controls', show = true, title = title, info = info, mode = mode, rows = rows })
            else
                hudRows = nil
                SendNUIMessage({ action = 'controls', show = false })
            end
        end
        Wait(t)
    end
end)

function GET_TASK_FISHING_DATA()
    local r = exports["rsg-fishing"]:GET_TASK_FISHING_DATA_EXTRA()
    hasMinigameOn = r[1]
    local outAsInt = r[2]
    local outAsFloat = r[3]

    fishing_minigame_struct = {}

    fishing_minigame_struct = {
        f_0 = outAsInt["0"],
        f_1 = outAsFloat["2"],
        f_2 = outAsFloat["4"],
        f_3 = outAsFloat["6"],
        f_4 = outAsFloat["8"],
        f_5 = outAsInt["10"],
        f_6 = outAsInt["12"],
        f_7 = outAsInt["14"],
        f_8 = outAsFloat["16"],
        f_9 = outAsFloat["18"],
        f_10 = outAsInt["20"],
        f_11 = outAsInt["22"],
        f_12 = outAsInt["24"],
        f_13 = outAsFloat["26"],
        f_14 = outAsFloat["28"],
        f_15 = outAsFloat["30"],
        f_16 = outAsInt["32"],
        f_17 = outAsFloat["34"],
        f_18 = outAsInt["36"],
        f_19 = outAsInt["38"],
        f_20 = outAsFloat["40"],
        f_21 = outAsFloat["42"],
        f_22 = outAsFloat["44"],
        f_23 = outAsFloat["46"],
        f_24 = outAsFloat["48"],
        f_25 = outAsFloat["50"],
        f_26 = outAsFloat["52"],
        f_27 = outAsFloat["54"]
    }
end

function isFishInterested(fishModel)
    local baitedFish = Config.BaitsPerFish[currentLure]
    if baitedFish ~= nil then
        for _, fish in pairs(baitedFish) do
            if fishModel == joaat(fish) then
                return true
            end
        end
    end
    return false
end

function SET_TASK_FISHING_DATA()
    if fishing_minigame_struct.f_0 ~= nil then
        exports["rsg-fishing"]:SET_TASK_FISHING_DATA_EXTRA(fishing_minigame_struct)
    end
end

function FISHING_GET_F_(f)
    return fishing_minigame_struct["f_" .. f]
end

function FISHING_GET_MINIGAME_STATE()
    return FISHING_GET_F_(0)
end

function FISHING_GET_LINE_DISTANCE()
    return FISHING_GET_F_(2)
end

function FISHING_GET_FISH_HANDLE()
    return FISHING_GET_F_(7)
end

function FISHING_GET_BOBBER_HANDLE()
    return FISHING_GET_F_(11)
end

function FISHING_GET_HOOK_HANDLE()
    return FISHING_GET_F_(12)
end

function FISHING_SET_F_(f, v)
    fishing_minigame_struct["f_" .. f] = v
    SET_TASK_FISHING_DATA()
end

function FISHING_SET_TRANSITION_FLAG(v)
    FISHING_SET_F_(6, v)
end

function FISHING_SET_FISH_HANDLE(v)
    FISHING_SET_F_(7, v)
    local weight_index = FishModelToSomeSortOfWeightIndex(GetEntityModel(v))

    FISHING_SET_CALCULATED_FISH_WEIGHT(GetRandomFishWeightForWeightIndex(weight_index) / Config.FishWeightMultiplier)

    fishing_data.fish.rodweight = 2
    FISHING_SET_ROD_WEIGHT(fishing_data.fish.rodweight)
end

function FISHING_SET_CALCULATED_FISH_WEIGHT(v)
    fishing_data.fish.weight = v * Config.FishWeightMultiplier

    FISHING_SET_F_(8, v)
end

function FISHING_SET_ROD_WEIGHT(v)
    FISHING_SET_F_(18, v)
end

function FISHING_SET_ROD_POSITION_UD(v)
    FISHING_SET_F_(23, v)
end

function GetNearbyFishs(coords, radius)
    local r = {}

    local itemSet = CreateItemset(true)
    local size = Citizen.InvokeNative(0x59B57C4B06531E1E, coords, radius, itemSet, 1, Citizen.ResultAsInteger())

    if size > 0 then
        for index = 0, size - 1 do
            local entity = GetIndexedItemInItemset(index, itemSet)
            if GetEntityPopulationType(entity) == 6 and not IsPedDeadOrDying(entity, 0) then
                table.insert(r, entity)
            end
        end
    end

    if IsItemsetValid(itemSet) then
        DestroyItemset(itemSet)
    end

    return r
end

function FishModelToSomeSortOfWeightIndex(fishModel)
    if fishModel == GetHashKey("A_C_FISHBLUEGIL_01_SM") or fishModel == GetHashKey("A_C_FISHBLUEGIL_01_MS") then
        return 0
    elseif fishModel == GetHashKey("A_C_FISHBULLHEADCAT_01_MS") or fishModel == GetHashKey("A_C_FISHBULLHEADCAT_01_SM") then
        return 1
    elseif fishModel == GetHashKey("A_C_FISHCHAINPICKEREL_01_MS") or fishModel == GetHashKey("A_C_FISHCHAINPICKEREL_01_SM") then
        return 2
    elseif fishModel == GetHashKey("A_C_FISHCHANNELCATFISH_01_XL") or fishModel == GetHashKey("A_C_FISHCHANNELCATFISH_01_LG") then
        return 3
    elseif fishModel == GetHashKey("A_C_FISHLAKESTURGEON_01_LG") then
        return 4
    elseif fishModel == GetHashKey("A_C_FISHLARGEMOUTHBASS_01_MS") or fishModel == GetHashKey("A_C_FISHLARGEMOUTHBASS_01_LG") then
        return 5
    elseif fishModel == GetHashKey("A_C_FISHLONGNOSEGAR_01_LG") then
        return 6
    elseif fishModel == GetHashKey("A_C_FISHMUSKIE_01_LG") then
        return 7
    elseif fishModel == GetHashKey("A_C_FISHNORTHERNPIKE_01_LG") then
        return 8
    elseif fishModel == GetHashKey("A_C_FISHPERCH_01_MS") or fishModel == GetHashKey("A_C_FISHPERCH_01_SM") then
        return 9
    elseif fishModel == GetHashKey("A_C_FISHREDFINPICKEREL_01_MS") or fishModel == GetHashKey("A_C_FISHREDFINPICKEREL_01_SM") then
        return 10
    elseif fishModel == GetHashKey("A_C_FISHROCKBASS_01_MS") or fishModel == GetHashKey("A_C_FISHROCKBASS_01_SM") then
        return 11
    elseif fishModel == GetHashKey("A_C_FISHSMALLMOUTHBASS_01_LG") or fishModel == GetHashKey("A_C_FISHSMALLMOUTHBASS_01_MS") then
        return 12
     elseif fishModel == GetHashKey("A_C_FISHSALMONSOCKEYE_01_MS") or fishModel == GetHashKey("A_C_FISHSALMONSOCKEYE_01_ML") or fishModel == GetHashKey("A_C_FISHSALMONSOCKEYE_01_LG") then
         return 13
     elseif fishModel == GetHashKey("A_C_FISHRAINBOWTROUT_01_LG") or fishModel == GetHashKey("A_C_FISHRAINBOWTROUT_01_MS") then
         return 14
     end
end

function GetMinMaxWeightForWeightIndex(index)
    local min = 0.0
    local max = 0.0

    if index == 0 or index == 1 or index == 3 or index == 9 or index == 10 or index == 11 or index == 2 then
        min = 0.5
        max = 3.0
    elseif index == 3 or index == 4 or index == 6 or index == 7 or index == 8 then
        min = 14.0
        max = 20.0
    elseif index == 5 or index == 12 or index == 13 or index == 14 then
        min = 4.0
        max = 6.0
    end

    min = min * 0.25
    max = max * 0.25

    return min, max
end

function GetRandomFishWeightForWeightIndex(index)
    local min, max = GetMinMaxWeightForWeightIndex(index)
    local weight = math.random() * (max - min) + min

    return weight
end

function prepareMyPrompt()
    if fishing_data.prompt_prepare_fishing.group then return end -- already registered; onResourceStop deletes them
    fishing_data.prompt_prepare_fishing.group = GetRandomIntInRange(0, 0xffffff)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, GetHashKey("INPUT_AIM")) -- MOUSE LEFT CLICK
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_prepare_fishing_rod')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_prepare_fishing.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_prepare_fishing.change_bait = prompt

    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0x07CE1E61) -- LEFT CONTROL
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_cast_fishing_rod')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_prepare_fishing.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_prepare_fishing.throw_hook = prompt

    fishing_data.prompt_waiting_hook.group = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, GetHashKey("INPUT_ATTACK")) -- MOUSE LEFT CLICK
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_hook')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_waiting_hook.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_waiting_hook.hook_fish = prompt

    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0x8FFC75D6) -- LEFT SHIFT
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_reset_cast')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_waiting_hook.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_waiting_hook.cancel = prompt

    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0xDB096B85) -- LEFT CONTROL
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING",  locale('cl_reel_lure')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_waiting_hook.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_waiting_hook.reel_lure = prompt

    -- Puxando Peixe
    fishing_data.prompt_hook.group = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0xFBD7B3E6) -- SPACE
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_reel_in')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_hook.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_hook.reel = prompt

    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0x8FFC75D6) -- LEFT SHIFT
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_reset_cast')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_hook.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_hook.cancel = prompt

    -- Peixe Pego
    fishing_data.prompt_finish.group = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, GetHashKey("INPUT_ATTACK")) -- MOUSE LEFT CLICK
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_keep_fish')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_finish.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_finish.keep_fish = prompt

    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt,  GetHashKey("INPUT_AIM")) -- MOUSE RIGHT CLICK
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_throw_fish')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_finish.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_finish.throw_fish = prompt

end

local DeleteThis = function(holding)
    NetworkRequestControlOfEntity(holding)
    SetEntityAsMissionEntity(holding, true, true)

    Wait(100)

    DeleteEntity(holding)

    Wait(500)

    local entitycheck = GetFirstEntityPedIsCarrying(cache.ped)
    local holdingcheck = GetPedType(entitycheck)

    if holdingcheck == 0 then
        return true
    end

    return false
end

-- Pickup Fish and Store in Inventory
CreateThread(function()
    while true do
        Wait(1000)

        local ped = PlayerPedId()
        local holding = GetFirstEntityPedIsCarrying(ped)

        -- GetFirstEntityPedIsCarrying returns entity handle 0 (not nil) when carrying nothing;
        -- `if holding then` was always true since 0 is truthy in Lua, wasting work every tick.
        if holding ~= 0 then
            local heldModel = GetEntityModel(holding)
            for k, _ in pairs(Config.fishData) do
                local model = GetHashKey(k)
                if tonumber(heldModel) == tonumber(model) then
                    local deleted = DeleteThis(holding)
                    if deleted then
                        TriggerServerEvent('rsg-fishing:FishToInventory', model, 0)
                        break
                    end
                end
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SendNUIMessage({ action = 'controls', show = false })
        fishing = false
        PromptDelete(fishing_data.prompt_prepare_fishing.change_bait)
        PromptDelete(fishing_data.prompt_prepare_fishing.throw_hook)
        PromptDelete(fishing_data.prompt_waiting_hook.hook_fish)
        PromptDelete(fishing_data.prompt_waiting_hook.reel_lure)
        PromptDelete(fishing_data.prompt_waiting_hook.cancel)
        PromptDelete(fishing_data.prompt_hook.reel)
        PromptDelete(fishing_data.prompt_hook.cancel)
        PromptDelete(fishing_data.prompt_finish.keep_fish)
        PromptDelete(fishing_data.prompt_finish.throw_fish)
    end
end)


-- =========================================================
-- Bobber visibility marker
-- =========================================================
local bobberMarkerActive = false

function StartBobberMarker()
    local cfg = Config.BobberMarker
    if not cfg or not cfg.Enabled or not cfg.ScreenIcon or bobberMarkerActive then return end
    bobberMarkerActive = true

    CreateThread(function()
        while fishing do
            local state = FISHING_GET_MINIGAME_STATE()
            if state == 6 or state == 7 then
                local bobber = FISHING_GET_BOBBER_HANDLE()
                if not bobber or bobber == 0 or not DoesEntityExist(bobber) then
                    bobber = FISHING_GET_HOOK_HANDLE()
                end
                if bobber and bobber ~= 0 and DoesEntityExist(bobber) then
                    local pos = GetEntityCoords(bobber)
                    do
                        local onScreen, sx, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z + 0.15)
                        SendNUIMessage({ action = 'bobber', show = onScreen and true or false, x = sx, y = sy,
                            hooked = state == 7, size = cfg.ScreenIconSize })
                    end
                    Wait(0)
                else
                    SendNUIMessage({ action = 'bobber', show = false })
                    Wait(100)
                end
            else
                SendNUIMessage({ action = 'bobber', show = false })
                Wait(250)
            end
        end
        bobberMarkerActive = false
        SendNUIMessage({ action = 'bobber', show = false })
    end)
end
