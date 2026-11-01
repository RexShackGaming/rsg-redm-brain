local RSGCore = exports['rsg-core']:GetCoreObject()
--------------------------------------
-- butcher: sell carried carcasses
--------------------------------------
local AnimalByModel = {}
for _, animal in ipairs(Config.Animal) do
    AnimalByModel[animal.model] = animal
end

-- decompiled short_update.c: -1 = no quality (not shown), 0 low, 1 medium, 2 high
local QUALITY = { [0] = 'poor', [1] = 'good', [2] = 'perfect' }

local butcherBlips, butcherPrompts = {}, {}
local selling = false

local function notify(desc, ntype)
    RSGCore.Functions.Notify({ title = locale('butcher_title'), description = desc, type = ntype or 'error', duration = 5000 })
end

-- carcass strapped to the player's horse (same itemset loop as Rockstar's shop_butcher.c)
local function getHorseCarcass()
    local ped = PlayerPedId()
    local horse = Citizen.InvokeNative(0x4C8B59171957BCF7, ped) -- _GET_LAST_MOUNT
    if not horse or horse == 0 or not DoesEntityExist(horse) then return 0 end
    if #(GetEntityCoords(ped) - GetEntityCoords(horse)) > (Config.HorseCarcassRange or 6.0) - 1.0 then return 0 end
    if not Citizen.InvokeNative(0xA911EE21EDF69DAF, horse) then return 0 end -- IS_PED_CARRYING_SOMETHING

    local found = 0
    local set = Citizen.InvokeNative(0xA1AF16083320065A, true, Citizen.ResultAsInteger()) -- CREATE_ITEMSET
    Citizen.InvokeNative(0xB5ACE8B23A438EC0, horse, set) -- FIND_ALL_ATTACHED_CARRIABLE_ENTITIES
    local size = Citizen.InvokeNative(0x55F2E375AC6018A9, set, Citizen.ResultAsInteger()) -- GET_ITEMSET_SIZE
    for i = 0, size - 1 do
        local item = Citizen.InvokeNative(0x275A2E2C0FAB7612, i, set, Citizen.ResultAsInteger()) -- GET_INDEXED_ITEM_IN_ITEMSET
        local ent = Citizen.InvokeNative(0xEE04C0AFD4EFAF0E, item, Citizen.ResultAsInteger()) -- _GET_ENTITY_FROM_ITEM
        if ent ~= 0 and DoesEntityExist(ent) and IsEntityAPed(ent) and AnimalByModel[GetEntityModel(ent)] then
            found = ent
            break
        end
    end
    Citizen.InvokeNative(0x712BC69F10549B92, set) -- DESTROY_ITEMSET
    return found
end

local function sellCarcass()
    if selling then return end

    local carcass = GetFirstEntityPedIsCarrying(PlayerPedId())
    if carcass == 0 or not DoesEntityExist(carcass) then
        carcass = Config.SellFromHorse and getHorseCarcass() or 0
    end
    if carcass == 0 or not DoesEntityExist(carcass) then
        return notify(locale(Config.SellFromHorse and 'butcher_not_holding_horse' or 'butcher_not_holding'))
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
    local done = RSGCore.Functions.ProgressBar({
        duration = Config.SellTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        label = locale('butcher_selling', animal.name),
    })

    if done and DoesEntityExist(carcass) then
        local ok = RSGCore.Functions.AwaitCallback('rsg-hunting:server:sellCarcass', nil, netId, quality)
        -- the server deletes the carcass; make sure it isn't left in the player's arms
        if ok and DoesEntityExist(carcass) then
            DetachEntity(carcass, true, true)
            NetworkRequestControlOfEntity(carcass)
            SetEntityAsMissionEntity(carcass, true, true)
            DeleteEntity(carcass)
        end
    end

    LocalPlayer.state:set('inv_busy', false, false)
    selling = false
end

function OpenButcherMenu()
    CreateThread(sellCarcass)
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
