-- Miner's hat (based on rex-mininghat): needs the Config.MiningHat.item in the
-- inventory. Worn automatically near mining rocks, and can be used from the
-- inventory to put it on / take it off. The player's own hat is given back.
local RSGCore = exports['rsg-core']:GetCoreObject()
local Hat = Config.MiningHat or {}

local HAT_CATEGORY = 0x9925C067 -- 'hats' meta ped category

local helmet, projector = nil, nil
local savedHat = nil    -- component hash of the player's own hat (when it could be read)
local hatRemoved = false -- the player's own hat was taken off for the miner's hat
local inside = false  -- near a mining rock (zone loop)
local worn   = false  -- hat props currently on
local manual = nil    -- nil = auto, true = put on by the player, false = taken off by the player

local function SpawnAndAttach(model, ped, bone, o)
    local hash = RSGCore.Functions.RequestModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, GetEntityCoords(ped), true, true, false)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, ped, bone, o[1], o[2], o[3], o[4], o[5], o[6], true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function DeleteEntitySafe(obj)
    if not obj or not DoesEntityExist(obj) then return end
    if NetworkGetEntityIsNetworked(obj) and not NetworkHasControlOfEntity(obj) then
        NetworkRequestControlOfEntity(obj)
    end
    DetachEntity(obj, true, true)
    SetEntityAsMissionEntity(obj, true, true)
    DeleteObject(obj)
    if DoesEntityExist(obj) then DeleteEntity(obj) end
end

local function DeleteProps()
    DeleteEntitySafe(helmet)
    DeleteEntitySafe(projector)
    helmet, projector = nil, nil

    -- sweep any hat/lamp props still attached to the player (e.g. left over after a reattach)
    local ped = PlayerPedId()
    local models = { [joaat(Hat.hatModel)] = true, [joaat(Hat.projectorModel)] = true }
    for _, obj in ipairs(GetGamePool('CObject')) do
        if models[GetEntityModel(obj)] and IsEntityAttachedToEntity(obj, ped) then
            DeleteEntitySafe(obj)
        end
    end
end

local function UpdatePed(ped)
    Citizen.InvokeNative(0x704C908E9C405136, ped) -- _REFRESH_META_PED_SHOP_ITEMS
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) -- _UPDATE_PED_VARIATION
end

-- is the ped wearing its own (clothing) hat right now?
local function IsWearingOwnHat(ped)
    local r = Citizen.InvokeNative(0xFB4891BD7578CDC1, ped, HAT_CATEGORY) -- _IS_META_PED_USING_COMPONENT
    return r ~= nil and r ~= false and r ~= 0
end

-- hat of the current outfit as known by rsg-character (fallback when it can't be read off the ped)
local function CachedHat()
    if GetResourceState('rsg-character') ~= 'started' then return nil end
    local ok, cache = pcall(function() return exports['rsg-character']:GetClothesCache() end)
    local entry = ok and type(cache) == 'table' and cache.hats
    local hash = type(entry) == 'table' and tonumber(entry.hash)
    if hash and hash ~= 0 then return hash end
    return nil
end

-- find the hat component the ped is wearing
local function GetCurrentHat(ped)
    local metaType = Citizen.InvokeNative(0xEC9A1261BF0CE510, ped) -- _GET_META_PED_TYPE
    local count = Citizen.InvokeNative(0x90403E8107B60E81, ped) or 0 -- _GET_NUM_COMPONENTS_IN_PED
    for i = 0, count - 1 do
        local comp = Citizen.InvokeNative(0x77BA37622E22023B, ped, i, true, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.ResultAsInteger()) -- _GET_SHOP_ITEM_COMPONENT_AT_INDEX
        if comp and comp ~= 0 then
            local cat = Citizen.InvokeNative(0x5FF9A878C3D115B8, comp, metaType, true, Citizen.ResultAsInteger()) -- _GET_SHOP_ITEM_COMPONENT_CATEGORY
            if cat == HAT_CATEGORY then return comp end
        end
    end
    return nil
end

-- take the player's own hat off so the miner's hat doesn't clip into it. Removal no
-- longer depends on reading the hat's component hash (that lookup can fail, which left
-- the hat on); same natives as rsg-wardrobe's /hat.
local function RemoveOwnHat(ped)
    if not IsWearingOwnHat(ped) then return end
    savedHat = GetCurrentHat(ped) or CachedHat() or savedHat
    hatRemoved = true
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, HAT_CATEGORY, true, true, true) -- _REMOVE_SHOP_ITEM_FROM_PED_BY_CATEGORY
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, HAT_CATEGORY, 0) -- _REMOVE_TAG_FROM_META_PED
    UpdatePed(ped)
end

local function PutOn()
    local ped = PlayerPedId()
    RemoveOwnHat(ped)
    local bone = GetEntityBoneIndexByName(ped, Hat.bone)
    helmet = SpawnAndAttach(Hat.hatModel, ped, bone, Hat.hatOffset)
    -- the projector prop has its own built-in white light, so it's skipped while the
    -- adjustable lamp (hatlight.lua) is enabled: one light source only
    if Hat.useProjector and not (Hat.light and Hat.light.enabled) then
        projector = SpawnAndAttach(Hat.projectorModel, ped, bone, Hat.projectorOffset)
    end
end

local function TakeOff()
    DeleteProps()
    if hatRemoved then
        local ped = PlayerPedId()
        local hash = savedHat or CachedHat()
        if hash and not IsWearingOwnHat(ped) then
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, HAT_CATEGORY) -- _SET_PED_COMPONENT_ENABLED (category)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, false, true, true) -- _APPLY_SHOP_ITEM_TO_PED
            UpdatePed(ped)
        end
    end
    savedHat, hatRemoved = nil, false
end

local function HasHatItem()
    if not Hat.requireItem then return true end
    local items = (RSGCore.Functions.GetPlayerData() or {}).items or {}
    for _, item in pairs(items) do
        if item and item.name == Hat.item and (item.amount or 1) > 0 then return true end
    end
    return false
end

local function Notify(key, nType)
    RSGCore.Functions.Notify({
        title = locale('mininghat_title'),
        description = locale(key),
        type = nType or 'inform',
        duration = Config.NotificationDuration,
    })
end

local function SetWorn(state)
    if state == worn then return end
    worn = state
    TriggerEvent('rsg-rocks:client:HatWorn', state)
    if Hat.debug then print(('[rsg-rocks] mining hat %s'):format(state and 'ON' or 'OFF')) end
    -- pcall so a native failure can never kill the zone streaming loop
    local ok, err = pcall(state and PutOn or TakeOff)
    if not ok then print(('[rsg-rocks] mining hat error: %s'):format(err)) end
end

-- work out whether the hat should be on and apply it
local function Refresh()
    if not Hat.enabled then return end
    local hasItem = HasHatItem()
    if not hasItem then manual = nil end
    local want = hasItem and (manual == true or (manual == nil and Hat.autoWear and inside))
    SetWorn(want)
end

-- called by the zone streaming loop in client.lua
function RocksSetInMine(state)
    if not Hat.enabled or state == inside then return end
    inside = state
    if not state and manual == false then manual = nil end -- taken off in this mine: auto again next visit
    Refresh()
end

-- used from the inventory (server: CreateUseableItem)
RegisterNetEvent('rsg-rocks:client:ToggleMiningHat', function()
    if not Hat.enabled then return end
    if not HasHatItem() then return Notify('mininghat_missing', 'error') end
    if IsEntityDead(PlayerPedId()) then return end
    manual = not worn
    if manual == false and not inside then manual = nil end -- off outside a mine: auto-wear again at the next mine
    Refresh()
    Notify(worn and 'mininghat_on' or 'mininghat_off', 'success')
end)

-- inventory changed: hat item lost -> off, hat item gained while at a mine -> on
RegisterNetEvent('RSGCore:Player:SetPlayerData', function()
    if worn or inside then Refresh() end
end)

-- keep the hat attached (death, model/clothing reload)
CreateThread(function()
    if not Hat.enabled then return end
    while true do
        Wait(1000)
        if worn and not HasHatItem() then Refresh() end
        if worn then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                DeleteProps()
            elseif not helmet or not DoesEntityExist(helmet) or not IsEntityAttachedToEntity(helmet, ped) then
                DeleteProps()
                PutOn() -- savedHat is kept, so the original hat isn't overwritten
            elseif IsWearingOwnHat(ped) then
                -- own hat came back (/hat, outfit change, revive re-applying clothes): take it off again
                RemoveOwnHat(ped)
            end
        end
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    inside, manual = false, nil
    if worn then worn = false; TakeOff(); TriggerEvent('rsg-rocks:client:HatWorn', false) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and worn then TakeOff() end
end)
