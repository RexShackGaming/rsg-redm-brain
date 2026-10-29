local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

--------------------------------------
-- butcher: sell carried carcasses
--------------------------------------
local AnimalByModel = {}
for _, animal in ipairs(Config.Animal) do
    AnimalByModel[animal.model] = animal
end

-- GetPedQuality: 0 low, 1 medium, 2 high, -1 = high
local QUALITY = { [0] = 'poor', [1] = 'good', [2] = 'perfect', [-1] = 'perfect' }

local butcherBlips, butcherPrompts = {}, {}
local selling = false

local function notify(desc, ntype)
    lib.notify({ title = locale('butcher_title'), description = desc, type = ntype or 'error', duration = 5000 })
end

local function sellCarcass()
    if selling then return end

    local carcass = GetFirstEntityPedIsCarrying(cache.ped)
    if carcass == 0 or not DoesEntityExist(carcass) then
        return notify(locale('butcher_not_holding'))
    end

    local animal = AnimalByModel[GetEntityModel(carcass)]
    if not animal then
        return notify(locale('butcher_unknown_animal'))
    end

    if not NetworkGetEntityIsNetworked(carcass) then
        NetworkRegisterEntityAsNetworked(carcass)
        Wait(200)
    end
    local netId = NetworkGetEntityIsNetworked(carcass) and NetworkGetNetworkIdFromEntity(carcass) or 0
    if netId == 0 then
        return notify(locale('butcher_failed'))
    end

    selling = true
    LocalPlayer.state:set('inv_busy', true, false)

    local quality = QUALITY[GetPedQuality(carcass)] or 'poor'
    local done = lib.progressBar({
        duration = Config.SellTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        label = locale('butcher_selling', animal.name),
    })

    if done and DoesEntityExist(carcass) then
        local ok = lib.callback.await('rsg-hunting:server:sellCarcass', false, netId, quality)
        -- the server deletes the carcass; make sure it isn't left in the player's arms
        if ok and DoesEntityExist(carcass) then
            NetworkRequestControlOfEntity(carcass)
            SetEntityAsMissionEntity(carcass, true, true)
            DeleteEntity(carcass)
        end
    end

    LocalPlayer.state:set('inv_busy', false, false)
    selling = false
end

function OpenButcherMenu()
    lib.registerContext({
        id = 'rsg_hunting_butcher',
        title = locale('butcher_title'),
        position = 'top-right',
        options = {
            {
                title = locale('butcher_sell'),
                description = locale('butcher_sell_desc'),
                icon = 'fas fa-paw',
                onSelect = sellCarcass,
            },
        }
    })
    lib.showContext('rsg_hunting_butcher')
end

AddEventHandler('rsg-hunting:client:butcher:mainmenu', OpenButcherMenu)

--------------------------------------
-- prompts and blips
--------------------------------------
CreateThread(function()
    local sprite = joaat(Config.Blip.blipSprite)
    for _, v in ipairs(Config.ButcherLocations) do
        if not Config.EnableTarget then
            exports['rsg-core']:createPrompt(v.prompt, v.coords, RSGCore.Shared.Keybinds[Config.KeyBind], locale('butcher_prompt', v.name), {
                type = 'client',
                event = 'rsg-hunting:client:butcher:mainmenu',
            })
            butcherPrompts[#butcherPrompts + 1] = v.prompt
        end
        if v.showblip then
            local blip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(blip, sprite, true)
            SetBlipScale(blip, Config.Blip.blipScale)
            SetBlipName(blip, Config.Blip.blipName)
            butcherBlips[#butcherBlips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(butcherBlips) do RemoveBlip(blip) end
    for _, name in ipairs(butcherPrompts) do exports['rsg-core']:deletePrompt(name) end
    if selling then LocalPlayer.state:set('inv_busy', false, false) end
end)
