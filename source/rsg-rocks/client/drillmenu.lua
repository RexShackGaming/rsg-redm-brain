-- Foreman drill menu (NUI): pick an amount of rocks or drill them all.
local RSGCore = exports['rsg-core']:GetCoreObject()
local uiFocus = false

local function CountItem(name)
    local total = 0
    for _, item in pairs((RSGCore.Functions.GetPlayerData() or {}).items or {}) do
        if item and item.name == name then total = total + (item.amount or 0) end
    end
    return total
end

local function BuildRocks()
    local list = {}
    for _, r in ipairs(Config.DrillableRocks or {}) do
        local shared = RSGCore.Shared.Items[r.item]
        list[#list + 1] = {
            item  = r.item,
            label = locale(r.label) or (shared and shared.label) or r.item,
            image = shared and shared.image or nil,
            count = CountItem(r.item),
        }
    end
    return list
end

local function CloseMenu()
    if not uiFocus then return end
    uiFocus = false
    RocksSetNuiFocus('drill', false)
    SendNUIMessage({ action = 'close' })
end

function RocksOpenDrillMenu()
    if uiFocus or RocksIsWorking() then return end
    uiFocus = true
    RocksSetNuiFocus('drill', true)
    SendNUIMessage({
        action = 'open',
        rocks = BuildRocks(),
        maxBatch = Config.DrillMaxBatch or 50,
        firstTime = Config.DrillTime,
        perRock = Config.DrillTime + (Config.DrillBatchPause or 500),
        locale = {
            title     = locale('drill_menu_title'),
            subtitle  = locale('drill_menu_subtitle'),
            owned     = locale('drill_menu_owned'),
            drill     = locale('drill_menu_drill'),
            drillAll  = locale('drill_menu_all'),
            time      = locale('drill_menu_time'),
            none      = locale('drill_menu_none'),
            close     = locale('drill_menu_close'),
        },
    })
end

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('drill', function(data, cb)
    cb('ok')
    CloseMenu()
    local valid = false
    for _, r in ipairs(Config.DrillableRocks or {}) do
        if r.item == data.item then valid = true break end
    end
    if not valid then return end
    local amount = tonumber(data.amount) or 1
    if data.all then amount = CountItem(data.item) end
    RocksDrill(data.item, amount)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', CloseMenu)
