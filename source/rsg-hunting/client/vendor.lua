local RSGCore = exports['rsg-core']:GetCoreObject()
local vendorPeds = {}
lib.locale()

CreateThread(function()
    for vendorIndex, vendor in ipairs(Config.Vendors) do
        local model = GetHashKey(vendor.pedModel)
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        if not HasModelLoaded(model) then
            print(('[rsg-hunting] vendor: failed to load ped model "%s", skipping vendor "%s"'):format(tostring(vendor.pedModel), tostring(vendor.blipname or vendor.pedModel)))
            goto continue
        end

        local ped = CreatePed(model, vendor.coords.x, vendor.coords.y, vendor.coords.z - 1.0, vendor.coords.w, false, false)
        SetRandomOutfitVariation(ped, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        TaskStandStill(ped, -1)

        vendorPeds[#vendorPeds + 1] = ped

        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'vendor_sell',
                label = locale('sell_items'),
                icon = 'fa-solid fa-hand-holding-dollar',
                distance = 2.0,
                onSelect = function()
                    OpenSellMenu(vendorIndex)
                end
            }
        })

        ::continue::
    end
end)

--------------------------------------
-- trapper sell UI (NUI)
--------------------------------------
local sellUiOpen = false
local currentVendor = nil

local function closeSellUi()
    if not sellUiOpen then return end
    sellUiOpen = false
    currentVendor = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function OpenSellMenu(vendorIndex)
    if sellUiOpen then return end
    local data = lib.callback.await('rsg-hunting:server:getSellData', false, vendorIndex)
    if not data then return end

    sellUiOpen = true
    currentVendor = vendorIndex
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = data.title,
        imagePath = 'nui://' .. Config.Image,
        items = data.items,
    })
end

RegisterNUICallback('close', function(_, cb)
    closeSellUi()
    cb('ok')
end)

RegisterNUICallback('sellBasket', function(basket, cb)
    if not sellUiOpen or not currentVendor then return cb({ ok = false }) end
    local result = lib.callback.await('rsg-hunting:server:sellBasket', false, currentVendor, basket) or { ok = false }
    if not result.ok then
        lib.notify({ title = locale('vendor'), description = result.message or locale('sale_failed'), type = 'error' })
    end
    cb(result)
end)

-- close the UI if the player wanders off / dies while it's open
CreateThread(function()
    while true do
        if sellUiOpen and currentVendor then
            local vendor = Config.Vendors[currentVendor]
            local ped = PlayerPedId()
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - vector3(vendor.coords.x, vendor.coords.y, vendor.coords.z)) > 5.0 then
                closeSellUi()
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, ped in ipairs(vendorPeds) do
            DeleteEntity(ped)
        end
        if sellUiOpen then SetNuiFocus(false, false) end
    end
end)
