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
