-- decorating: furniture placed by tenants with rsg-gizmo, spawned locally near the house
local RSGCore = exports['rsg-core']:GetCoreObject()

local HousesById = {}
local DecorByKey = {}
local MyHouses   = {}     -- [houseid] = true for houses this player rents
local Loaded     = {}     -- [houseid] = { [propId] = { id, key, model, coords, rot, entity } }
local Loading    = {}
local placing    = false

for _, house in ipairs(Config.Houses) do HousesById[house.houseid] = house end
for _, def in ipairs(Config.DecorProps or {}) do DecorByKey[def.key] = def end

local function notify(result)
    if not result or not result.msg then return end
    RSGCore.Functions.Notify({ title = locale('menu_decor_title'), description = result.msg, type = result.type or 'inform' })
end

---------------------------------------
-- spawning
---------------------------------------
local function removeEntity(prop)
    if prop.entity and DoesEntityExist(prop.entity) then
        pcall(function() exports['rsg-target']:removeLocalEntity(prop.entity) end)
        DeleteObject(prop.entity)
    end
    prop.entity = nil
end

local movePropFlow, removePropFlow

local function spawnProp(houseid, prop)
    if prop.entity and DoesEntityExist(prop.entity) then return end
    local hash = joaat(prop.model)
    RSGCore.Functions.RequestModel(hash)
    local obj = CreateObject(hash, prop.coords.x, prop.coords.y, prop.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return end

    SetEntityRotation(obj, prop.rot.x, prop.rot.y, prop.rot.z, 2, true)
    FreezeEntityPosition(obj, true)
    prop.entity = obj

    exports['rsg-target']:addLocalEntity(obj, {
        {
            name = 'rsg-housing:prop:move:' .. prop.id, icon = 'fa-solid fa-up-down-left-right',
            label = locale('prop_move'), distance = 2.5,
            canInteract = function() return MyHouses[houseid] == true and not placing end,
            onSelect = function() movePropFlow(houseid, prop) end,
        },
        {
            name = 'rsg-housing:prop:remove:' .. prop.id, icon = 'fa-solid fa-trash',
            label = locale('prop_remove'), distance = 2.5,
            canInteract = function() return MyHouses[houseid] == true and not placing end,
            onSelect = function() removePropFlow(houseid, prop) end,
        },
    })
end

local function despawnHouse(houseid)
    local list = Loaded[houseid]
    if not list then return end
    for _, prop in pairs(list) do removeEntity(prop) end
end

local function loadHouse(houseid)
    if Loaded[houseid] or Loading[houseid] then return end
    Loading[houseid] = true
    local list = RSGCore.Functions.AwaitCallback('rsg-housing:server:getProps', nil, houseid)
    Loading[houseid] = nil
    if type(list) ~= 'table' then return end

    Loaded[houseid] = {}
    for _, prop in ipairs(list) do
        Loaded[houseid][prop.id] = prop
        spawnProp(houseid, prop)
    end
end

local function unloadHouse(houseid)
    despawnHouse(houseid)
    Loaded[houseid] = nil
end

CreateThread(function()
    while true do
        Wait(2000)
        if Config.Decorating then
            local pos = GetEntityCoords(PlayerPedId())
            for houseid, house in pairs(HousesById) do
                local dist = #(pos - house.menucoords)
                if dist <= Config.PropStreamDistance then
                    if not Loaded[houseid] then CreateThread(function() loadHouse(houseid) end) end
                elseif dist > Config.PropStreamDistance + 30.0 and Loaded[houseid] then
                    unloadHouse(houseid)
                end
            end
        end
    end
end)

---------------------------------------
-- own houses (who may move / remove)
---------------------------------------
local function refreshMine()
    local _, _, mine = RSGCore.Functions.AwaitCallback('rsg-housing:server:getState', nil)
    MyHouses = mine or {}
end

RegisterNetEvent('rsg-housing:client:SyncOwnedHouses', function(_, mine) MyHouses = mine or {} end)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() refreshMine() end)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    MyHouses = {}
    for houseid in pairs(Loaded) do unloadHouse(houseid) end
end)
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then refreshMine() end
end)

---------------------------------------
-- server sync
---------------------------------------
RegisterNetEvent('rsg-housing:client:propAdded', function(houseid, prop)
    if not Loaded[houseid] then return end
    Loaded[houseid][prop.id] = prop
    spawnProp(houseid, prop)
end)

RegisterNetEvent('rsg-housing:client:propMoved', function(houseid, id, coords, rot)
    local prop = Loaded[houseid] and Loaded[houseid][id]
    if not prop then return end
    prop.coords, prop.rot = coords, rot
    if prop.entity and DoesEntityExist(prop.entity) then
        SetEntityCoordsNoOffset(prop.entity, coords.x, coords.y, coords.z, false, false, false)
        SetEntityRotation(prop.entity, rot.x, rot.y, rot.z, 2, true)
    end
end)

RegisterNetEvent('rsg-housing:client:propRemoved', function(houseid, id)
    local prop = Loaded[houseid] and Loaded[houseid][id]
    if not prop then return end
    removeEntity(prop)
    Loaded[houseid][id] = nil
end)

RegisterNetEvent('rsg-housing:client:propsCleared', function(houseid)
    despawnHouse(houseid)
    if Loaded[houseid] then Loaded[houseid] = {} end
end)

---------------------------------------
-- placing, moving, removing (rsg-gizmo)
---------------------------------------
RegisterNetEvent('rsg-housing:client:placeProp', function(houseid, key)
    if placing then return end
    local def = DecorByKey[key]
    if not def then return end

    CreateThread(function()
        local pre = RSGCore.Functions.AwaitCallback('rsg-housing:server:prePlaceProp', nil, houseid, key)
        if not pre or not pre.ok then return notify(pre) end

        placing = true
        local res = exports['rsg-gizmo']:Place(def.model, { rotation = 'z', maxDistance = 5.0 })
        placing = false
        if not res then return end

        notify(RSGCore.Functions.AwaitCallback('rsg-housing:server:placeProp', nil, houseid, key, res.coords, res.rotation))
    end)
end)

movePropFlow = function(houseid, prop)
    if placing or not prop.entity then return end
    CreateThread(function()
        placing = true
        local res = exports['rsg-gizmo']:Edit(prop.entity, { rotation = 'z' })
        placing = false
        if not res then return end

        local result = RSGCore.Functions.AwaitCallback('rsg-housing:server:moveProp', nil, houseid, prop.id, res.coords, res.rotation)
        notify(result)
        if not result or not result.ok then
            -- refused: put it back where the server has it
            if prop.entity and DoesEntityExist(prop.entity) then
                SetEntityCoordsNoOffset(prop.entity, prop.coords.x, prop.coords.y, prop.coords.z, false, false, false)
                SetEntityRotation(prop.entity, prop.rot.x, prop.rot.y, prop.rot.z, 2, true)
            end
        end
    end)
end

removePropFlow = function(houseid, prop)
    CreateThread(function()
        notify(RSGCore.Functions.AwaitCallback('rsg-housing:server:removeProp', nil, houseid, prop.id))
    end)
end

---------------------------------------
-- cleanup
---------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for houseid in pairs(Loaded) do despawnHouse(houseid) end
end)
