--------------------------------------------------------------------------------------------
-- RSG SAMPLES — Client: NUI + revive notification
--------------------------------------------------------------------------------------------

local nuiOpen = false

-- taglistener.js fires this locally when the game reports an animal revive event
AddEventHandler('rsg-samples:ReviveData', function(reviveData)
    lib.notify({ title = locale('ui_title'), description = locale('revived'), type = 'success' })
    if Config.DebugClient then print('[rsg-samples] Revive event:', reviveData) end
end)

--------------------------------------------------------------------------------------------
-- Open the Samples NUI
-- viewMode = 'menu'        → main tabbed UI
-- viewMode = 'certificate' → jump straight to the certificate overlay
--------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-samples:client:openSamplesMenu', function(data)
    if type(data) ~= 'table' then return end

    SendNUIMessage({
        action             = data.viewMode == 'certificate' and 'openCertificate' or 'openSamplesMenu',
        allSamples         = data.allSamples,
        collectedSamples   = data.collectedSamples,
        topCollectors      = data.topCollectors,
        globalStats        = data.globalStats,
        currentCitizenId   = data.currentCitizenId,
        playerName         = data.playerName,
        featuredAnimal     = data.featuredAnimal,
        featuredMultiplier = data.featuredMultiplier,
        lang               = data.lang,
    })

    SetNuiFocus(true, true)
    nuiOpen = true
end)

RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb('ok')
end)

-- Never leave the player stuck with NUI focus if the resource restarts while open
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and nuiOpen then
        SetNuiFocus(false, false)
    end
end)
