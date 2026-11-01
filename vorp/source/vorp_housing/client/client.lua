local LIB <const>     = Import({ "/config", 'blips', 'prompts' })
local CONFIG <const>  = LIB.CONFIG --[[@as vorp_housing_config]]
local Blips <const>   = LIB.Blips --[[@as MAP]]
local Prompts <const> = LIB.Prompts --[[@as PROMPTS]]
local CHARID          = 0
local OWNED_INDEX     = 0
local running         = false
local Core <const>    = exports.vorp_core:GetCore()



local function registerLocations()
    local values <const> = CONFIG.HOUSES[OWNED_INDEX]
    if not values then return end

    local data <const> = {
        sleep = 800,
        locations = {},
        prompts = {
            {
                type = "Press",
                key = `INPUT_SHOP_SELL`, -- R
                label = CONFIG.TRANSLATION.press,
                mode = 'Standard',
            },
        }
    }

    for index, storage in ipairs(values.STORAGES) do
        table.insert(data.locations, {
            coords = storage.LOCATION,
            label = storage.LABEL,
            distance = 2.0,
            id = ("storage_%s"):format(index),
        })
    end

    if values.WARDROBE.ENABLE then
        table.insert(data.locations, {
            coords = values.WARDROBE.LOCATION,
            label = values.WARDROBE.LABEL,
            distance = 2.0,
            id = "wardrobe",
        })
    end


    Prompts:Register(data, function(_, index, _, value)
        local location <const> = CONFIG.HOUSES[OWNED_INDEX]
        if not location then return end

        if not location.OWNERS[CHARID] then
            return Core.NotifyObjective(CONFIG.TRANSLATION.not_owner, 5000)
        end

        if value.id == ("storage_%s"):format(index) then
            local storage <const> = location.STORAGES[index]
            if not storage then return end
            return TriggerServerEvent("vorp_housing:Server:OpenStorage", OWNED_INDEX, index)
        end

        if value.id == "wardrobe" then
            TriggerServerEvent("vorp_housing:Server:OpenWardrobe", OWNED_INDEX)
        end
    end, true) -- auto start on register
end

RegisterNetEvent("vorp_housing:Client:RegisterHouse", function(index, charId)
    OWNED_INDEX = index
    CHARID = charId

    local value <const> = CONFIG.HOUSES[OWNED_INDEX]
    if not value then return end

    if running then return end
    running = true

    if value.BLIP.ENABLE and value.OWNERS[CHARID].BLIP_VISIBLE then
        Blips:Create('coords', {
            Pos = value.POSITION,
            Blip = value.BLIP.STYLE,
            Options = {
                sprite = value.BLIP.SPRITE,
                name = value.BLIP.NAME,
            },
        })
    end

    if not value.OWNERS[CHARID].STORAGE then return end
    Wait(5000)
    registerLocations()
end)


--FOR TESTS
if CONFIG.DEV_MODE then
    -- on resource start
    AddEventHandler("onResourceStart", function(resource)
        if resource ~= GetCurrentResourceName() then return end
        TriggerServerEvent("vorp_housing:Server:DevMode")
    end)

    local blips <const> = {}
    RegisterNetEvent("vorp_housing:Client:ShowHouses", function()
        local houses <const> = CONFIG.HOUSES

        for _, blip in ipairs(blips) do
            RemoveBlip(blip)
        end

        table.wipe(blips)

        for index, house in ipairs(houses) do
            local blip = Blips:Create('coords', {
                Pos = house.POSITION,
                Blip = `BLIP_STYLE_PROPERTY_OWNER`,
                Options = {
                    sprite = `blip_mp_base`,
                    name = "House index: " .. index,
                },
            })
            table.insert(blips, blip:GetHandle())
        end
    end)
end
