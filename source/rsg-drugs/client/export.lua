if not Config.Export.Enabled then return end
lib.locale()

local E = Config.Export
local open = false

local getNpc = DrugsProximityNpc(E.NPC, {
    name = 'rsg_drugs_export',
    icon = 'fa-solid fa-boxes-packing',
    label = locale('export_target'),
    onSelect = function() TriggerEvent('rsg-drugs:client:exportOpen') end,
})

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'export:close' })
end

AddEventHandler('rsg-drugs:client:exportOpen', function()
    if open then return end
    local data = lib.callback.await('rsg-drugs:server:exportOpen', false)
    if not data then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'export:open', data = data, locale = lib.getLocales() })
end)

RegisterNUICallback('exportSell', function(body, cb)
    local res = lib.callback.await('rsg-drugs:server:exportSell', false, body and body.amount)
    cb(res or false)
    -- deal done: close the panel and hand the bricks over
    if res and res.sold then
        close()
        local npc = getNpc()
        if npc then
            DrugsHandover(npc, true)
            if DoesEntityExist(npc) then SetBlockingOfNonTemporaryEvents(npc, true) end -- keep the buyer calm
        end
    end
end)
RegisterNUICallback('exportClose', function(_, cb) close() cb('ok') end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', close)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
end)
