-- Closes the loading screen once the player has loaded in (see Config.CloseOnPlayerLoaded).
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    if not Config.CloseOnPlayerLoaded then return end
    SendLoadingScreenMessage(json.encode({ type = 'endLoading' }))
    ShutdownLoadingScreenNui()
end)
