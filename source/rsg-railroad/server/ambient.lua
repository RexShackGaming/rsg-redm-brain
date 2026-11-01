local RSGCore = exports['rsg-core']:GetCoreObject()
---------------------------------------------------------------
-- AMBIENT TRAIN OWNERSHIP
-- Only one client at a time drives the ambient (NPC) train. Only that
-- client can release it; it is also released if that client leaves.
---------------------------------------------------------------
local ambientOwner = nil

lib.callback.register('rsg-railroad:shouldSpawnAmbient', function(source)
    if ambientOwner and GetPlayerName(ambientOwner) then return false end
    ambientOwner = source
    return true
end)

RegisterNetEvent('rsg-railroad:ambientDespawned', function()
    if source == ambientOwner then ambientOwner = nil end
end)

AddEventHandler('playerDropped', function()
    if source == ambientOwner then ambientOwner = nil end
end)


----------------------------------
-- admin commands
----------------------------------
RSGCore.Commands.Add('trainpos', 'Show train locations (admin)', {}, false, function(source)
    TriggerClientEvent('rsg-railroad:client:trainpos', source)
end, 'admin')

RSGCore.Commands.Add('setjunction', 'Set a train track junction (admin)', {
    { name = 'trackName', help = 'Track name e.g. TRAINS_OLD_WEST03' },
    { name = 'junctionIndex', help = 'Junction index' },
    { name = 'state', help = '0 or 1' },
}, true, function(source, args)
    TriggerClientEvent('rsg-railroad:client:setjunction', source, args)
end, 'admin')
