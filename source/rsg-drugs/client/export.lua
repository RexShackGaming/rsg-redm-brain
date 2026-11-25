if not Config.Export.Enabled then return end
local RSGCore = exports['rsg-core']:GetCoreObject()

local E = Config.Export
local open = false
local opening = false
local buyerPos = vector3(E.NPC.coords.x, E.NPC.coords.y, E.NPC.coords.z)

local getNpc = DrugsProximityNpc(E.NPC, {
    name = 'rsg_drugs_export',
    icon = 'fa-solid fa-boxes-packing',
    label = locale('export_target'),
    onSelect = function() TriggerEvent('rsg-drugs:client:exportOpen') end,
})

local function close()
    if not open then return end
    open = false
    DrugsNuiFocus(false)
    SendNUIMessage({ action = 'export:close' })
end

AddEventHandler('rsg-drugs:client:exportOpen', function()
    if open or opening then return end
    opening = true
    local data = RSGCore.Functions.AwaitCallback('rsg-drugs:server:exportOpen', 10000)
    opening = false
    if not data then return end
    open = true
    DrugsNuiFocus(true)
    SendNUIMessage({ action = 'export:open', data = data, locale = locale() })
    -- the server rejects sales beyond interactDistance, so close a little earlier
    DrugsWatchPanel(buyerPos, math.max(2.0, E.NPC.interactDistance - 0.5), function() return open end, close)
end)

RegisterNUICallback('exportSell', function(body, cb)
    local res = RSGCore.Functions.AwaitCallback('rsg-drugs:server:exportSell', 10000, body and body.amount)
    cb(res or false)
    -- deal done: close the panel and hand the bricks over
    if res and res.sold then
        close()
        local npc = getNpc()
        if npc then
            DrugsHandover(npc, true, Config.Corner.Anim.Prop)
            if DoesEntityExist(npc) then SetBlockingOfNonTemporaryEvents(npc, true) end -- keep the buyer calm
        end
    end
end)
RegisterNUICallback('exportClose', function(_, cb) close() cb('ok') end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', close)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if open then open = false; DrugsNuiFocus(false) end
end)
