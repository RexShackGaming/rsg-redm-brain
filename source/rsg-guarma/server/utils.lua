local RSGCore = exports['rsg-core']:GetCoreObject()

function Guarma.Notify(src, title, nType, description)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = 6000,
    })
end

function Guarma.Round(amount)
    return math.floor(amount * 100 + 0.5) / 100
end

function Guarma.IsRunning(resource)
    return GetResourceState(resource) == 'started'
end

-- returns the port if the player is standing within radius of its worker
function Guarma.GetNearPort(src, portId, radius)
    local port = type(portId) == 'string' and Config.Ports[portId]
    if not port then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    if #(GetEntityCoords(ped) - port.npccoords.xyz) > (radius or Config.InteractRadius) then return nil end
    return port
end

function Guarma.CanAct(Player)
    local meta = Player.PlayerData.metadata
    return not (meta.isdead or meta.inlaststand or meta.ishandcuffed or (tonumber(meta.injail) or 0) > 0)
end

function Guarma.ItemCount(src, item)
    return exports['rsg-inventory']:GetItemCount(src, item) or 0
end

function Guarma.ItemLabel(item)
    local shared = RSGCore.Shared.Items[item]
    return shared and shared.label or item
end
