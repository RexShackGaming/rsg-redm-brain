-- Hands live server info to the loading screen (read in html/script.js via window.nuiHandoverData).
local function serverName()
    local name = GetConvar('sv_projectName', '')
    if name == '' then name = GetConvar('sv_hostname', '') end
    return (name:gsub('%^%d', ''))   -- strip ^1 colour codes
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not Config.ServerInfo then return end
    deferrals.handover({
        rsgLoading = {
            players    = #GetPlayers(),
            maxPlayers = GetConvarInt('sv_maxclients', 48),
            serverName = serverName(),
        }
    })
end)
