local RSGCore = exports['rsg-core']:GetCoreObject()
local currentWagonCustom = {}
local currentStore, currentWagonModel, currentCustom

local function GetPlayerMoney()
    local player = RSGCore.Functions.GetPlayerData()
    if not player or not player.money then return { cash = 0, gold = 0 } end
    return { cash = player.money.cash or 0, gold = player.money.gold or 0 }
end

local function Notify(type, title, message)
    lib.notify({ title = title, description = message, type = type })
end

RegisterNetEvent("rsg-wagons:client:openStore", function(store)
    currentStore = store
    local categories = {}
    for type in pairs(Config.Wagons) do
        categories[#categories + 1] = { type = type, label = locale(type), image = type .. ".png" }
    end
    table.sort(categories, function(a, b) return a.label:lower() < b.label:lower() end)

    local money = GetPlayerMoney()

    SendNUIMessage({
        action = 'openStore',
        store = store,
        categories = categories,
        playerMoney = money,
        theme = Config.UITheme or 'color'
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('getWagonsByType', function(data, cb)
    local store = data.store
    local wagonType = data.type
    local wagonsData = {}

    if Config.Wagons[wagonType] then
        for model, v in pairs(Config.Wagons[wagonType]) do
            wagonsData[#wagonsData + 1] = {
                name = v.name,
                price = v.price,
                maxAnimals = v.maxAnimals,
                slots = v.slots,
                maxWeight = v.maxWeight,
                model = model
            }
        end
    end

    table.sort(wagonsData, function(a, b) return (a.price or math.huge) < (b.price or math.huge) end)

    SendNUIMessage({ action = 'showWagons', wagons = wagonsData })
    cb('ok')
end)

RegisterNUICallback('previewWagon', function(data, cb)
    SpawnShowroomWagon(data.model, data.store)
    cb('ok')
end)

RegisterNUICallback('previewMyWagon', function(data, cb)
    currentWagonModel = data.model
    currentCustom = data.custom or {}
    SpawnShowroomMyWagon(data.model, currentStore, data.custom or {})
    cb('ok')
end)

RegisterNUICallback('buyWagon', function(data, cb)
    local moneyType = Config.MoneyType.money
    local model = data.model
    local name = data.name

    CloseShowroom()

    local customData = {
        name = name,
        tint = 0,
        livery = -1,
        props = false,
        extras = {},
        buyMoneyType = moneyType,
    }
    TriggerServerEvent("rsg-wagons:saveWagonToDatabase", model, customData, moneyType)

    -- Close the menu on buy (server confirms via notify). Success overlay
    -- is skipped: it would pop over the game once the panel is hidden.
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('getMyWagons', function(data, cb)
    lib.callback('rsg-wagons:checkMyWagons', false, function(wagons, custom)
        if not wagons or #wagons == 0 then
            SendNUIMessage({ action = 'showMyWagons', wagons = {}, customs = {} })
        else
            SendNUIMessage({ action = 'showMyWagons', wagons = wagons, customs = custom })
        end
    end)
    cb('ok')
end)

RegisterNUICallback('activateWagon', function(data, cb)
    CloseShowroom()
    TriggerServerEvent("rsg-wagons:toggleWagonActive", data.model, data.custom)
    cb('ok')
end)

RegisterNUICallback('sellWagon', function(data, cb)
    CloseShowroom()
    TriggerServerEvent("rsg-wagons:sellWagon", data.model, data.custom)
    cb('ok')
end)

RegisterNUICallback('getCustomOptions', function(data, cb)
    local customType = data.type
    local model = string.lower(data.model or '')
    local custom = data.custom or {}
    currentWagonCustom = custom

    local options = {}
    local multi = false
    local categories = nil

    if customType == "livery" then
        options[#options + 1] = { label = "Remove", value = -1 }
        if Custom.livery and Custom.livery[model] then
            for _, v in ipairs(Custom.livery[model]) do
                options[#options + 1] = { label = v[2], value = v[1] }
            end
        end
    elseif customType == "extra" then
        -- Multi-select: entries are { id, label } tables (see mackmerge.lua).
        -- Legacy bare-number entries are still accepted as a fallback.
        multi = true
        local enabled = {}
        if type(custom.extras) == "table" then
            for _, id in ipairs(custom.extras) do
                local nid = tonumber(id)
                if nid then enabled[nid] = true end
            end
        elseif custom.extra and tonumber(custom.extra) and tonumber(custom.extra) ~= -1 then
            enabled[tonumber(custom.extra)] = true
        end
        if Custom.extra and Custom.extra[model] then
            for _, e in ipairs(Custom.extra[model]) do
                local id, label = nil, nil
                if type(e) == "table" then
                    id, label = tonumber(e.id), e.label
                elseif tonumber(e) then
                    id, label = tonumber(e), "Extra " .. tostring(e)
                end
                if id then
                    options[#options + 1] = { label = label or ("Extra " .. tostring(id)), value = id, enabled = enabled[id] == true }
                end
            end
        end
    elseif customType == "tint" then
        options[#options + 1] = { label = "Remove", value = -1 }
        local maxTints = (Custom.tint and Custom.tint[model]) or 0
        for i = 1, maxTints do
            options[#options + 1] = { label = tostring(i), value = i }
        end
    elseif customType == "props" then
        -- Categorized propsets (general / cargo / trade / supplies).
        -- Legacy flat arrays are wrapped as a single 'general' category.
        options[#options + 1] = { label = "Remove", value = -1 }
        local sets = Custom.props and Custom.props[model]
        if sets then
            local cats = nil
            if type(sets.general) == "table" then
                cats = sets
            else
                cats = { general = sets }
            end
            categories = {}
            local seenCats = {}
            local order = { "general", "cargo", "trade", "supplies" }
            local function addCategory(catName)
                local list = cats[catName]
                if type(list) == "table" and #list > 0 and not seenCats[catName] then
                    seenCats[catName] = true
                    local catOpts = {}
                    for _, propset in ipairs(list) do
                        if type(propset) == "string" then
                            catOpts[#catOpts + 1] = { label = propset, value = propset }
                        end
                    end
                    if #catOpts > 0 then
                        categories[#categories + 1] = {
                            name = catName,
                            label = catName:gsub("^%l", string.upper),
                            options = catOpts
                        }
                    end
                end
            end
            for _, catName in ipairs(order) do addCategory(catName) end
            for catName in pairs(cats) do addCategory(catName) end
        end
    elseif customType == "lantern" then
        options[#options + 1] = { label = "Remove", value = -1 }
        if Custom.lantern and Custom.lantern[model] then
            for _, l in pairs(Custom.lantern[model]) do
                local hash, label = nil, nil
                if type(l) == "table" then
                    hash, label = l.value, l.label
                elseif type(l) == "string" then
                    hash, label = l, l
                end
                if hash then
                    options[#options + 1] = { label = label or hash, value = hash }
                end
            end
        end
    end

    local price = Config.CustomPrice[customType] or 0

    SendNUIMessage({
        action = 'showCustomOptions',
        type = customType,
        options = options,
        price = price,
        multi = multi,
        categories = categories
    })
    cb('ok')
end)

RegisterNUICallback('previewCustom', function(data, cb)
    local customType = data.type
    local value = data.value
    local currentShow = {}
    for k, v in pairs(currentWagonCustom or {}) do currentShow[k] = v end
    if customType == 'extra' and type(value) == 'table' then
        -- Multi-extra selection from the checkbox UI
        currentShow['extras'] = value
        currentShow['extra'] = nil
    else
        if (customType == 'props' or customType == 'lantern') and value == -1 then
            -- "Remove": false skips the propset/lantern natives entirely
            -- (GetHashKey(-1) would be invalid)
            value = false
        end
        currentShow[customType] = value
    end
    SpawnShowroomMyWagon(currentWagonModel, currentStore, currentShow)
    cb('ok')
end)

RegisterNUICallback('resetPreview', function(data, cb)
    SpawnShowroomMyWagon(data.model, currentStore, data.custom or {})
    cb('ok')
end)

RegisterNUICallback('saveCustomization', function(data, cb)
    local customType = data.type
    local value = data.value
    local model = data.model

    if customType == 'extra' and type(value) == 'table' then
        -- Multi-extra selection: stored as an array, legacy single key cleared
        currentWagonCustom['extras'] = value
        currentWagonCustom['extra'] = nil
    else
        if (customType == 'props' or customType == 'lantern') and value == -1 then
            -- "Remove": persist false so the propset/lantern is skipped on spawn
            value = false
        end
        currentWagonCustom[customType] = value
    end
    SpawnShowroomMyWagon(model, currentStore, currentWagonCustom)
    TriggerServerEvent("rsg-wagons:saveCustomization", model, currentWagonCustom, customType)
    cb('ok')
end)

RegisterNUICallback('rotateWagon', function(data, cb)
    RotatePreviewWagon(data.direction)
    cb('ok')
end)

RegisterNUICallback('closeShop', function(data, cb)
    CloseShowroom()
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent("rsg-wagons:stashPermission", function(info)
    TriggerServerEvent("rsg-wagons:getOwnerPermission", info)
end)

RegisterNetEvent('rsg-wagons:client:notify', function(type, title, message)
    lib.notify({ title = title, description = message, type = type })
end)

RegisterNetEvent('rsg-wagons:client:success', function(message)
    SendNUIMessage({ action = 'success', message = message })
end)
