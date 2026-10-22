lib.locale()

-- Auctioneer NPCs
-- Blips are always shown; peds are only spawned while the player is nearby (lib.points),
-- instead of keeping every auctioneer alive map-wide with a polling loop.

local SPAWN_DISTANCE = 60.0
local TARGET_OPTION_NAME = 'auction_npc_interact'
local BLIP_SPRITE = `blip_shop_store`
local BLIP_COLOR_MODIFIER = `BLIP_MODIFIER_MP_COLOR_5`

local Peds = {}   -- [index] = ped
local Blips = {}  -- [index] = blip

local function createBlip(npc)
    local blip = BlipAddForCoords(1664425300, npc.coords.x, npc.coords.y, npc.coords.z)
    SetBlipSprite(blip, BLIP_SPRITE, true)
    SetBlipScale(blip, 0.2)
    BlipAddModifier(blip, BLIP_COLOR_MODIFIER)
    SetBlipName(blip, locale('blip_name', npc.locationLabel or npc.name))
    return blip
end

local function spawnPed(index, npc)
    if Peds[index] and DoesEntityExist(Peds[index]) then return end

    local model = joaat(npc.model)
    if not lib.requestModel(model, 10000) then
        print(('[Auction NPC] Failed to load model: %s'):format(npc.model))
        return
    end

    local ped = CreatePed(model, npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.heading, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if ped == 0 then return end

    SetRandomOutfitVariation(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = TARGET_OPTION_NAME,
            label = npc.name or locale('target_open_auction'),
            icon = 'fa-solid fa-gavel',
            distance = Config.InteractionDistance or 2.5,
            onSelect = function()
                TriggerServerEvent('auction:server:validateNPCInteraction', { npcIndex = index })
            end
        }
    })

    Peds[index] = ped
end

local function despawnPed(index)
    local ped = Peds[index]
    if ped and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped, TARGET_OPTION_NAME)
        DeleteEntity(ped)
    end
    Peds[index] = nil
end

for index, npc in ipairs(Config.AuctioneerNPCs or {}) do
    Blips[index] = createBlip(npc)
    lib.points.new({
        coords = npc.coords,
        distance = SPAWN_DISTANCE,
        onEnter = function() spawnPed(index, npc) end,
        onExit = function() despawnPed(index) end,
    })
end

RegisterNetEvent('auction:client:openFromNPC', function(locationData)
    NUI.Open(locationData)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for index in pairs(Peds) do despawnPed(index) end
    for _, blip in pairs(Blips) do RemoveBlip(blip) end
end)
