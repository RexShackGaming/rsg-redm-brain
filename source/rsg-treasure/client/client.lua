lib.locale()

local hunt = nil   -- { loc, centre, blip, icon, chest }
local textShown = false
local lastText = nil

local function hideText()
    if textShown then SendNUIMessage({ action = 'signal', show = false }) textShown = false lastText = nil end
end

-- drives the detector's own vibration/needle (femga AI/BLACKBOARDS: 0.1 - 1.0)
local function setDetectorValue(v)
    Citizen.InvokeNative(0x437C08DB4FEBE2BD, PlayerPedId(), 'MetalDetectorDetectionValue', v, -1) -- SET_PED_BLACKBOARD_FLOAT
end

local function removeChest()
    if hunt and hunt.chest and DoesEntityExist(hunt.chest) then
        DeleteEntity(hunt.chest)
    end
    if hunt then hunt.chest = nil end
end

local function cleanup()
    hideText()
    setDetectorValue(0.0)
    if not hunt then return end
    if hunt.blip and DoesBlipExist(hunt.blip) then RemoveBlip(hunt.blip) end
    if hunt.icon and DoesBlipExist(hunt.icon) then RemoveBlip(hunt.icon) end
    removeChest()
    hunt = nil
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > t then return false end
        Wait(50)
    end
    return true
end

local function detectorEquipped(ped)
    return GetPedCurrentHeldWeapon(ped) == Config.Detector
end

local function dig()
    local ped = PlayerPedId()
    hideText()
    -- put the metal detector away before digging (it's a kit item held in hand,
    -- so force-holster and remove it from the hand slot, then wait until it's gone)
    Citizen.InvokeNative(0xFCCC886EDE3C63EC, ped, 2, true)                       -- HIDE_PED_WEAPONS
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true, 0, false, false)
    local t = GetGameTimer() + 2000
    while GetPedCurrentHeldWeapon(ped) == Config.Detector and GetGameTimer() < t do Wait(50) end
    Wait(300)
    -- dig-up-chest anim scene (from the old rsg-treasure: script@mech@treasure_hunting@chest)
    if not hunt or not hunt.pinpointed then return end
    hunt.digging = true   -- hides the [J] prompt

    local pos = GetEntityCoords(ped)
    local rot = GetEntityRotation(ped)
    local found, groundZ = GetGroundZAndNormalFor_3dCoord(pos.x, pos.y, pos.z + 10.0)
    if not found then groundZ = pos.z - 1.0 end

    -- the strongbox only exists from here: spawned underground, the anim scene pulls it up
    if not loadModel(Config.ChestModel) then hunt.digging = false return end
    local chest = CreateObjectNoOffset(Config.ChestModel, pos.x, pos.y, groundZ - 5.0, false, false, false)
    SetModelAsNoLongerNeeded(Config.ChestModel)
    SetEntityVisible(chest, false)   -- keep it hidden until the dig is under way
    hunt.chest = chest
    TriggerServerEvent('rsg-treasure:server:digStart')

    local scene = Citizen.InvokeNative(0x1FCA98E33C1437B3, Config.DigAnim.dict, 0, Config.DigAnim.playlist, 0, 1) -- _CREATE_ANIM_SCENE
    Citizen.InvokeNative(0x020894BF17A02EF2, scene, pos.x, pos.y, groundZ, rot.x, rot.y, rot.z, 2)     -- SET_ANIM_SCENE_ORIGIN
    Citizen.InvokeNative(0x8B720AD451CA2AB3, scene, 'player', ped, 0)                                  -- SET_ANIM_SCENE_ENTITY
    Citizen.InvokeNative(0x8B720AD451CA2AB3, scene, 'CHEST', chest, 0)
    Citizen.InvokeNative(0xAF068580194D9DC7, scene)                                                    -- LOAD_ANIM_SCENE
    local t2 = GetGameTimer() + 3000
    while not Citizen.InvokeNative(0x477122B8D05E7968, scene, 1, 0) and GetGameTimer() < t2 do Wait(0) end -- IS_ANIM_SCENE_LOADED
    Citizen.InvokeNative(0xF4D94AF761768700, scene)                                                    -- START_ANIM_SCENE

    -- only show the strongbox once the player has started digging it out
    Wait(Config.ChestRevealDelay)
    if DoesEntityExist(chest) then SetEntityVisible(chest, true) end

    Wait(math.max(0, Config.DigTime - Config.ChestRevealDelay))
    Citizen.InvokeNative(0x84EEDB2C6E650000, scene)                                                    -- _DELETE_ANIM_SCENE

    local current = hunt
    if lib.callback.await('rsg-treasure:server:dig', false) then return end -- server ends the hunt on success
    -- rejected (too far, cooldown, missing item...): bury the box again and let them retry
    if hunt == current and current then
        removeChest()
        current.digging = false -- the prompt loop that called dig() picks up again
    end
end

-- spot pinpointed: nothing is shown, the player just gets the [J] dig prompt there
local function markSpot()
    hunt.pinpointed = true
    local spot = hunt.loc
    if hunt.promptActive then return end -- old prompt thread still alive (left & came back quickly)
    hunt.promptActive = true

    -- [J] Dig up treasure prompt while standing at the strongbox
    CreateThread(function()
        local group = GetRandomIntInRange(0, 0xffffff)
        local prompt = UiPromptRegisterBegin()
        UiPromptSetControlAction(prompt, Config.DigKey)
        UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', locale('dig_target')))
        UiPromptSetEnabled(prompt, true)
        UiPromptSetVisible(prompt, true)
        UiPromptSetStandardMode(prompt, true)
        UiPromptSetGroup(prompt, group, 0)
        UiPromptRegisterEnd(prompt)

        local current = hunt
        while hunt == current and current.pinpointed and not current.digging do
            local sleep = 500
            local ped = PlayerPedId()
            if #(GetEntityCoords(ped) - spot) <= Config.DigDistance and not IsPedOnMount(ped)
                and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                sleep = 0
                UiPromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', locale('title')), 0, 0, 0, 0)
                if UiPromptHasStandardModeCompleted(prompt, 0) then
                    dig()
                end
            end
            Wait(sleep)
        end
        UiPromptDelete(prompt)
        current.promptActive = false
    end)

    lib.notify({ title = locale('title'), description = locale('pinpointed'), type = 'success', duration = 5000 })
end

local function signalBars(strength)
    local n = math.floor(strength * 5 + 0.5)
    return string.rep('■', n) .. string.rep('□', 5 - n)
end

RegisterNetEvent('rsg-treasure:client:startHunt', function(loc, centre)
    cleanup()
    hunt = { loc = loc, centre = centre }

    -- search circle (BLIP_STYLE_AREA, femga) + treasure icon at its centre
    hunt.blip = BlipAddForRadius(`BLIP_STYLE_AREA`, centre.x, centre.y, centre.z, Config.SearchRadius)
    hunt.icon = BlipAddForCoords(1664425300, centre.x, centre.y, centre.z)
    SetBlipSprite(hunt.icon, Config.BlipSprite, true)
    Citizen.InvokeNative(0x9CB1A1623062F402, hunt.icon, locale('blip')) -- _SET_BLIP_NAME

    CreateThread(function()
        local current = hunt
        local nextBeep, warned = 0, false
        while hunt == current do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local inCircle = #(pos - current.centre) <= Config.SearchRadius + 20.0
            local dist = #(pos - current.loc)
            local wait = 2000

            if inCircle and detectorEquipped(ped) then
                wait = 100
                warned = false
                local strength = 0.0
                if dist <= Config.DetectRange then
                    strength = 1.0 - math.max(0.0, dist - Config.PinpointDistance) / (Config.DetectRange - Config.PinpointDistance)
                end

                setDetectorValue(strength > 0 and math.max(0.1, strength) or 0.0)

                local text = locale('signal', signalBars(strength))
                if text ~= lastText then
                    SendNUIMessage({ action = 'signal', show = true, text = text, title = locale('title') })
                    textShown = true lastText = text
                end

                -- bleep gets louder, higher and faster as you close in
                if strength > 0 and GetGameTimer() >= nextBeep then
                    local b = Config.Bleep
                    SendNUIMessage({
                        action = 'beep',
                        volume = b.minVolume + (b.maxVolume - b.minVolume) * strength,
                        pitch  = b.minPitch + (b.maxPitch - b.minPitch) * strength,
                        length = b.length,
                    })
                    nextBeep = GetGameTimer() + math.floor(b.slowest - (b.slowest - b.fastest) * strength)
                end

                if dist <= Config.PinpointDistance and not current.pinpointed then
                    markSpot()
                end
            else
                hideText()
                setDetectorValue(0.0)
                if inCircle and not warned and not current.pinpointed then
                    lib.notify({ title = locale('title'), description = locale('need_detector'), type = 'inform', duration = 5000 })
                    warned = true
                end
                wait = inCircle and 500 or 2000
            end

            -- wandered off? lose the pinpoint (not while digging)
            if current.pinpointed and not current.digging and dist > Config.DetectRange then
                current.pinpointed = false
            end

            Wait(wait)
        end
    end)
end)

RegisterNetEvent('rsg-treasure:client:endHunt', cleanup)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then cleanup() end
end)
