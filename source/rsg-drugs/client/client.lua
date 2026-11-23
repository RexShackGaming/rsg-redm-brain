local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false
local opening = false
local labPos = vector3(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)

---------------------------------
-- npc
---------------------------------
-- on-duty law (same rule the server uses)
local function isLaw()
    local job = RSGCore.Functions.GetPlayerData().job
    if not job or job.onduty == false then return false end
    return (Config.Heat.LawJobTypes[job.type] or Config.Heat.LawJobs[job.name]) and true or false
end

DrugsProximityNpc(Config.NPC, {
    {
        name = 'rsg_drugs_talk',
        icon = 'far fa-comments',
        label = locale('target_talk'),
        onSelect = function() TriggerEvent('rsg-drugs:client:open') end,
    },
    {
        name = 'rsg_drugs_raid',
        icon = 'fa-solid fa-handcuffs',
        label = locale('raid_target'),
        canInteract = function() return Config.Heat.Enabled and isLaw() end,
        onSelect = function() TriggerServerEvent('rsg-drugs:server:raid') end, -- the server checks job, duty, distance and that a raid exists
    },
})

-- the law is told a lab was reported: pulsing blip around the lab for the raid window
local raidBlips = {}
RegisterNetEvent('rsg-drugs:client:raidAlert', function(minutes)
    local c = Config.NPC.coords
    local blip = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, c.x, c.y, c.z, Config.Heat.AlertRadius) -- BlipAddForRadius (same hash as the sell alert)
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, joaat('BLIP_MODIFIER_AREA_PULSE'))                         -- BlipAddModifier
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, locale('raid_alert_title'))                                   -- SetBlipName
    raidBlips[blip] = true
    RSGCore.Functions.Notify({ title = locale('raid_alert_title'), description = locale('raid_alert', minutes), type = 'warning', duration = 8000 })
    SetTimeout((minutes or 10) * 60000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        raidBlips[blip] = nil
    end)
end)

---------------------------------
-- nui
---------------------------------
local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    TriggerServerEvent('rsg-drugs:server:closed')
    DrugsNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

AddEventHandler('rsg-drugs:client:open', function()
    if uiOpen or opening then return end
    opening = true
    local data = RSGCore.Functions.AwaitCallback('rsg-drugs:server:getLab', 10000) -- includes supplies
    opening = false
    if not data then return end
    uiOpen = true
    DrugsNuiFocus(true)
    SendNUIMessage({ action = 'open', data = data, locale = locale() })
    -- close when the player walks away or dies (the server also rejects actions from too far away)
    DrugsWatchPanel(labPos, Config.NPC.interactDistance + 1.0, function() return uiOpen end, closeUI)
end)

RegisterNetEvent('rsg-drugs:client:refresh', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'update', data = data })
end)

RegisterNUICallback('close', function(_, cb) closeUI() cb('ok') end)

RegisterNUICallback('action', function(body, cb)
    local data = RSGCore.Functions.AwaitCallback('rsg-drugs:server:action', 10000, body and body.action, body and body.data)
    cb(data or false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for b in pairs(raidBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if uiOpen then uiOpen = false; DrugsNuiFocus(false) end
end)

-- don't leave the cursor stuck if the player dies / logs out with the lab open
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() if uiOpen then closeUI() end end)
