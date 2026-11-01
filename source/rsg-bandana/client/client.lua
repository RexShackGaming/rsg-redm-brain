local RSGCore = exports['rsg-core']:GetCoreObject()

local busy, lastToggle = false, 0

local function notify(msg, kind)
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = kind or 'inform' })
end

-- Find the neckwear item the ped is wearing (works for mp_male and mp_female).
-- Returns componentHash, currentWearableState or nil.
local function getNeckwear(ped)
    local count = Citizen.InvokeNative(0x90403E8107B60E81, ped, Citizen.ResultAsInteger()) -- _GET_NUM_COMPONENTS_IN_PED
    if not count or count <= 0 then return nil end
    local metaType = Citizen.InvokeNative(0xEC9A1261BF0CE510, ped, Citizen.ResultAsInteger()) -- _GET_META_PED_TYPE
    local struct = string.rep('\0', 8 * 16) -- scratch buffer for the argStruct out-param

    for i = 0, count - 1 do
        local comp, state = Citizen.InvokeNative(0x77BA37622E22023B, ped, i, true, struct,
            Citizen.PointerValueIntInitialized(0), Citizen.ResultAsInteger()) -- _GET_SHOP_ITEM_COMPONENT_AT_INDEX
        if comp and comp ~= 0 then
            local cat = Citizen.InvokeNative(0x5FF9A878C3D115B8, comp, metaType, true, Citizen.ResultAsInteger()) -- _GET_SHOP_ITEM_COMPONENT_CATEGORY
            if cat and (cat & 0xFFFFFFFF) == Config.NeckwearCategory then
                return comp, state
            end
        end
    end
    return nil
end

local function u32(v) return v and (v & 0xFFFFFFFF) or 0 end

-- Only the exact StateUp hash is trusted as "up". Any other state the game reports
-- (0, BASE, or a remapped/default variant hash) falls back to the statebag, so an
-- unknown default state no longer gets mistaken for "up" (which made /bandana
-- always try to lower it).
local function isUp(ped)
    local comp, state = getNeckwear(ped)
    if not comp then return false, nil end
    local s = u32(state)
    if Config.Debug then print(('[rsg-bandana] comp=%s state=%s bag=%s'):format(u32(comp), s, tostring(LocalPlayer.state.bandana))) end
    if s == u32(Config.StateUp) then return true, comp end
    if s == u32(Config.StateDown) then return false, comp end
    return LocalPlayer.state.bandana == true, comp
end

-- Some RedM natives return 0/1 instead of false/true, and 0 is truthy in Lua
local function yes(v) return v == true or v == 1 end

local function canToggle(ped)
    if yes(IsEntityDead(ped)) or yes(IsPedRagdoll(ped)) or yes(IsPedSwimming(ped))
        or yes(IsPedHogtied(ped)) or yes(IsPedCuffed(ped)) or yes(IsPedInAnyVehicle(ped, false)) then
        return false
    end
    return LocalPlayer.state.isLoggedIn == true
end

-- Swap the wearable state and keep the statebag in sync
local function applyState(ped, comp, up)
    Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, comp, up and Config.StateUp or Config.StateDown, 0, true, 1) -- _UPDATE_SHOP_ITEM_WEARABLE_STATE
    if not up then
        -- female peds can ignore BASE; fall back to clearing the wearable state
        local _, state = getNeckwear(ped)
        if u32(state) ~= u32(Config.StateDown) and u32(state) ~= 0 then
            Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, comp, 0, 0, true, 1)
        end
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) -- _UPDATE_PED_VARIATION
    LocalPlayer.state:set('bandana', up, true)
end

local function toggle()
    if busy then return end
    if GetGameTimer() - lastToggle < Config.Cooldown then return notify(locale('wait'), 'error') end

    local ped = PlayerPedId()
    if not canToggle(ped) then return notify(locale('cant_now'), 'error') end

    local up, comp = isUp(ped)
    if not comp then return notify(locale('no_bandana'), 'error') end
    up = not up

    busy, lastToggle = true, GetGameTimer()
    if Config.PlayAnim then
        local set = up and Config.Anims.up or Config.Anims.down
        Citizen.InvokeNative(0xAE72E7DF013AAA61, ped, 0, yes(IsPedOnMount(ped)) and set.mounted or set.foot, 1, 0, -1.0) -- START_TASK_ITEM_INTERACTION
        Wait(Config.AnimTime)
        -- player may have died / been cuffed / changed clothes during the animation
        if ped ~= PlayerPedId() or not canToggle(ped) or select(2, isUp(ped)) ~= comp then
            ClearPedTasks(ped)
            busy = false
            return notify(locale('cant_now'), 'error')
        end
    end

    applyState(ped, comp, up)
    notify(up and locale('up') or locale('down'), 'success')
    busy = false
end

RegisterNetEvent('rsg-bandana:client:toggle', toggle)

-- Other resources: exports['rsg-bandana']:IsWearingBandana()
-- Reads the real ped state, so it stays correct after wardrobe changes.
exports('IsWearingBandana', function()
    return (isUp(PlayerPedId()))
end)

-- Clothing reloads (relog) reset the wearable state, keep the statebag honest
local function resetState() LocalPlayer.state:set('bandana', false, true) end
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', resetState)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', resetState)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    local up, comp = isUp(ped)
    if up then applyState(ped, comp, false) end
    resetState()
end)
