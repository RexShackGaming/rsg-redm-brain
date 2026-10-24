-- Belt / back attachments (merged from bln_belt_attachments).
-- Client only: objects are created as networked entities attached to the player ped, so other
-- players see them through normal entity sync. No server relay (the old relay let any client
-- delete arbitrary entities by network id).
local Belt = Config.Belt
if not Belt or not Belt.enabled then return end

local items = {}            -- [key] = config with hash/key resolved
local attached = {}         -- [key] = entity
local states = {}           -- [key] = boolean (should be attached)
local lastChange = {}       -- [key] = game timer
local stopping = false
local lastPed = 0

local MASK = 0xFFFFFFFF

local function normalize(hash)
    return hash & MASK
end

---------------------------------------------
-- LOOKUP TABLE
---------------------------------------------
local function InitializeLookup()
    for _, category in pairs(Belt.categories) do
        if category.enabled == false then goto continue end
        for _, item in ipairs(category) do
            local names = type(item.hashName) == 'table' and item.hashName or { item.hashName }
            for _, hashName in ipairs(names) do
                local hash = joaat(hashName)
                items[normalize(hash)] = {
                    hash = hash,
                    name = hashName,
                    model = item.model,
                    bone = item.bone,
                    offset = item.offset,
                    alwaysAttached = item.alwaysAttached,
                }
            end
        end
        ::continue::
    end
end

---------------------------------------------
-- HELPERS
---------------------------------------------
local function PickBySex(tbl, ped)
    if not IsPedMale(ped) then
        local female = tbl.female
        if female ~= nil and female ~= false then
            return female
        end
    end
    return tbl.male
end

---------------------------------------------
-- ATTACH / DETACH
---------------------------------------------
local function DetachItem(key)
    local entity = attached[key]
    if entity then
        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
        attached[key] = nil
    end
end

local function AttachItem(key, cfg)
    if stopping or attached[key] then return attached[key] ~= nil end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return false end
    if not BP.LoadModel(cfg.model, 5000) then return false end

    local coords = GetEntityCoords(ped)
    local entity = CreateObject(cfg.model, coords.x, coords.y, coords.z, true, true, true)
    SetModelAsNoLongerNeeded(cfg.model)

    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local offset = PickBySex(cfg.offset, ped)
    local bone = PickBySex(cfg.bone, ped)
    local boneIndex = GetEntityBoneIndexByName(ped, bone)

    AttachEntityToEntity(entity, ped, boneIndex,
        offset.x, offset.y, offset.z,
        offset.pitch, offset.roll, offset.yaw,
        false, false, false, false, 2, true) -- hard pinned, no collision: no wobble / physics

    attached[key] = entity
    return true
end

local function ClearAll()
    for key in pairs(attached) do
        DetachItem(key)
    end
    states = {}
    lastChange = {}
end

---------------------------------------------
-- MAIN LOOP
---------------------------------------------
CreateThread(function()
    InitializeLookup()

    while not stopping do
        local ped = PlayerPedId()

        -- ped recreated (skin refresh / respawn / character switch): old attachments are gone
        if ped ~= lastPed then
            ClearAll()
            lastPed = ped
        end

        local _, currentWeapon = GetCurrentPedWeapon(ped, true)
        local equipped = normalize(currentWeapon or 0)
        local now = GetGameTimer()

        for key, cfg in pairs(items) do
            local result = HasPedGotWeapon(ped, cfg.hash, 0, false)
            local hasWeapon = (result == true or result == 1)
            local shouldBeAttached = hasWeapon and (cfg.alwaysAttached or equipped ~= key) or false

            if states[key] ~= shouldBeAttached and (not lastChange[key] or (now - lastChange[key]) > Belt.debounceTime) then
                local ok = true
                if shouldBeAttached then
                    ok = AttachItem(key, cfg)
                else
                    DetachItem(key)
                end

                states[key] = ok and shouldBeAttached or nil -- failed attach is retried after the debounce
                lastChange[key] = now
            end

            -- re-attach if the entity vanished while it should be attached
            if shouldBeAttached and states[key] and attached[key] and not DoesEntityExist(attached[key]) then
                attached[key] = nil
                states[key] = nil
            end
        end

        Wait(250)
    end
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    ClearAll()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopping = true
    ClearAll()
end)
