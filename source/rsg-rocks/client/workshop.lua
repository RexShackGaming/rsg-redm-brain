local RSGCore = exports['rsg-core']:GetCoreObject()
local SpawnedBlips    = {}
local SpawnedPropsets = {}
local isWorking       = false
local batchActive     = false -- a batch drill loop is running (also covers the pause between rocks)

local function Notify(title, description, nType)
    RSGCore.Functions.Notify({
        title = title,
        description = description,
        type = nType or 'inform',
        duration = Config.NotificationDuration,
    })
end

local function ItemLabel(name)
    local item = RSGCore.Shared.Items[name]
    return item and item.label or name
end

---------------------------------
-- blips & camp propsets
---------------------------------
CreateThread(function()
    for _, v in ipairs(Config.WorkshopTents) do
        if v.showblip then
            local blip = BlipAddForCoords(Config.BlipStyle, v.blipcoords)
            SetBlipSprite(blip, joaat(v.blipsprite), true)
            SetBlipScale(blip, v.blipscale)
            SetBlipName(blip, v.blipname)
            SpawnedBlips[#SpawnedBlips + 1] = blip
        end
    end
end)

CreateThread(function()
    local propsetHash = joaat(Config.WorkshopPropset)
    Citizen.InvokeNative(0xF3DE57A46D5585E9, propsetHash) -- REQUEST_PROPSET
    local timeout = GetGameTimer() + 5000
    while not Citizen.InvokeNative(0x48A88FC684C55FDC, propsetHash) and GetGameTimer() < timeout do -- HAS_PROPSET_LOADED
        Wait(50)
    end
    if not Citizen.InvokeNative(0x48A88FC684C55FDC, propsetHash) then return end

    for _, v in ipairs(Config.WorkshopTents) do
        local handle = Citizen.InvokeNative(0x899C97A1CCE7D483, propsetHash, -- CREATE_PROPSET_INSTANCE
            v.coords.x, v.coords.y, v.coords.z, 0, v.coords.w, 1200.0, false, true)
        if handle then SpawnedPropsets[#SpawnedPropsets + 1] = handle end
    end
    Citizen.InvokeNative(0xB1964A83B345B4AB, propsetHash) -- RELEASE_PROPSET
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, blip in ipairs(SpawnedBlips) do RemoveBlip(blip) end
    for _, handle in ipairs(SpawnedPropsets) do
        Citizen.InvokeNative(0x58A39BE577CE9284, handle, true) -- DELETE_PROPSET
    end
    if isWorking then LocalPlayer.state:set('inv_busy', false, true) end
end)

---------------------------------
-- timed work (drill / smelt) with a server-side session
---------------------------------
local function DoTimedWork(startEvent, finishEvent, arg, duration, label, arg2)
    if isWorking then
        Notify(locale('drill_title'), locale('busy'), 'inform')
        return
    end
    isWorking = true
    TriggerServerEvent(startEvent, arg, arg2)
    LocalPlayer.state:set('inv_busy', true, true)

    local success = RSGCore.Functions.ProgressBar({
        duration = duration,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, mouse = false },
        label = label,
        anim = { dict = Config.DrillAnimDict, clip = Config.DrillAnimClip, flag = Config.DrillAnimFlag },
    })

    LocalPlayer.state:set('inv_busy', false, true)
    TriggerServerEvent(success and finishEvent or 'rsg-rocks:server:CancelWork', arg, arg2)
    isWorking = false
    return success
end

local drillBatchStop = false

-- server says the batch can't continue (inventory full / out of rocks)
RegisterNetEvent('rsg-rocks:client:StopDrillBatch', function() drillBatchStop = true end)

-- drills one rock at a time: each rock is its own timed session and pays out
-- when it finishes, then the next rock starts until the amount is reached
function RocksDrill(item, amount)
    if isWorking or batchActive then
        Notify(locale('drill_title'), locale('busy'), 'inform')
        return
    end
    amount = math.max(1, math.min(math.floor(tonumber(amount) or 1), Config.DrillMaxBatch or 50))
    if not RSGCore.Functions.HasItem(item, 1) then
        Notify(locale('drill_title'), locale('no_rocks'), 'error')
        return
    end

    drillBatchStop = false
    batchActive = true
    local done = 0
    for i = 1, amount do
        if drillBatchStop or not RSGCore.Functions.HasItem(item, 1) then break end
        local ok = DoTimedWork('rsg-rocks:server:StartDrill', 'rsg-rocks:server:FinishDrill', item,
            Config.DrillTime, locale('drill_batch_label', i, amount))
        if not ok then break end -- cancelled
        done = i
        if i < amount then Wait(Config.DrillBatchPause or 500) end -- let the inventory update before the next rock
    end
    batchActive = false

    if amount > 1 and done > 0 then
        Notify(locale('drill_title'), locale('drill_batch_done', done, amount), done == amount and 'success' or 'inform')
    end
end

function RocksIsWorking() return isWorking or batchActive end

function RocksSmelt(index)
    local recipe = Config.SmeltRecipes[index]
    if not recipe then return end
    if isWorking or batchActive then
        Notify(locale('smelt_title'), locale('busy'), 'inform')
        return
    end
    local need = recipe.inputAmount or 1
    if not RSGCore.Functions.HasItem(recipe.input, need) then
        Notify(locale('smelt_title'), locale('smelt_missing'), 'error')
        return
    end
    local label = locale('smelt_progress', need, ItemLabel(recipe.input), recipe.outputAmount or 1, ItemLabel(recipe.output))
    DoTimedWork('rsg-rocks:server:StartSmelt', 'rsg-rocks:server:FinishSmelt', index, recipe.time or 8000, label)
end

-- target options shown on the camp foreman
function RocksWorkshopOptions()
    local options = {
        {
            name = 'rsg-rocks:drill_menu',
            icon = 'fa-solid fa-bore-hole',
            label = locale('drill_menu_option'),
            distance = 3.0,
            onSelect = function()
                if RocksIsWorking() then return Notify(locale('drill_title'), locale('busy'), 'inform') end
                RocksOpenDrillMenu()
            end,
        },
    }

    if Config.SmeltingEnabled and Config.SmeltRecipes then
        for index, recipe in ipairs(Config.SmeltRecipes) do
            options[#options + 1] = {
                name = 'rsg-rocks:smelt:' .. index,
                icon = 'fa-solid fa-fire',
                label = locale('smelt_option', recipe.inputAmount or 1, ItemLabel(recipe.input),
                    recipe.outputAmount or 1, ItemLabel(recipe.output)),
                distance = 3.0,
                -- only list recipes the player can currently afford
                canInteract = function() return RSGCore.Functions.HasItem(recipe.input, recipe.inputAmount or 1) end,
                onSelect = function() RocksSmelt(index) end,
            }
        end
    end
    return options
end
