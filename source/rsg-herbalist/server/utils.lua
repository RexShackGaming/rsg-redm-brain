----------------------------------------------------------------------------
-- Shared server helpers (loaded first). Replaces the Notify/IsDead helpers
-- that were copy-pasted into server.lua and mysterybox.lua.
----------------------------------------------------------------------------

Herbalist = {}

function Herbalist.Notify(src, title, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title, description = description, type = nType or 'error', duration = 5000,
    })
end

function Herbalist.IsDead(Player)
    local md = Player.PlayerData.metadata
    return md and md.isdead or false
end
