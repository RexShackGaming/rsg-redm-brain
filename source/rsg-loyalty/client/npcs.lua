lib.locale()

if not Config.Enabled then return end

local spawnDistance = Config.Performance.NpcSpawnDistance or 20.0
local fadeIn = Config.Performance.NpcFadeIn
local fadeSpeed = Config.Performance.NpcFadeSpeed or 40
local points = {}

local function setAlphaFade(ped, from, to, step)
    for alpha = from, to, step do
        if not DoesEntityExist(ped) then return end
        SetEntityAlpha(ped, alpha, false)
        Wait(fadeSpeed)
    end
end

local blips = {}

local function spawnNpc(loc)
    local model = loc.npcmodel
    local ok = pcall(lib.requestModel, model, 10000)
    if not ok then
        print(('[rsg-loyalty] Failed to load model for %s'):format(loc.name))
        return nil
    end

    local c = loc.npccoords
    local ped = CreatePed(model, c.x, c.y, c.z - 1.0, c.w, false, false, 0, 0)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return nil end

    SetEntityAlpha(ped, fadeIn and 0 or 255, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    if loc.scenario then
        Citizen.InvokeNative(0x524B54361229154F, ped, joaat(loc.scenario), -1, true, false, false, false, -1, false) -- TaskStartScenarioInPlaceHash
    end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'npc_loyalty',
            icon = 'far fa-eye',
            label = locale('open_loyalty_shop'),
            distance = 3.0,
            onSelect = function()
                TriggerEvent('rsg-loyalty:client:openloyaltyUI', loc.npccoords.xyz)
            end,
        }
    })

    if fadeIn then
        CreateThread(function() setAlphaFade(ped, 0, 255, 51) end)
    end

    return ped
end

local function despawnNpc(ped, fade)
    if not ped or not DoesEntityExist(ped) then return end
    exports.ox_target:removeLocalEntity(ped, 'npc_loyalty')
    if fade then setAlphaFade(ped, 255, 0, -51) end
    DeletePed(ped)
end

for _, loc in ipairs(Config.LoyaltyLocations) do
    if loc.showblip then
        local blip = BlipAddForCoords(1664425300, loc.npccoords.x, loc.npccoords.y, loc.npccoords.z)
        SetBlipSprite(blip, joaat(loc.blip.blipSprite), true)
        SetBlipScale(blip, loc.blip.blipScale)
        SetBlipName(blip, locale(loc.blip.blipName))
        blips[#blips + 1] = blip
    end

    points[#points + 1] = lib.points.new({
        coords = loc.npccoords.xyz,
        distance = spawnDistance,
        -- spawn/despawn in their own threads so model loading and fades
        -- never stall the shared lib.points loop
        onEnter = function(self)
            self.inside = true
            if self.ped or self.spawning then return end
            self.spawning = true
            CreateThread(function()
                local ped = spawnNpc(loc)
                self.spawning = false
                if self.inside then
                    self.ped = ped
                else
                    despawnNpc(ped, false) -- player left while the model was loading
                end
            end)
        end,
        onExit = function(self)
            self.inside = false
            local ped = self.ped
            self.ped = nil
            if ped then CreateThread(function() despawnNpc(ped, fadeIn) end) end
        end,
    })
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do
        RemoveBlip(blip)
    end
    for _, point in ipairs(points) do
        if point.ped and DoesEntityExist(point.ped) then
            DeletePed(point.ped)
        end
    end
end)
