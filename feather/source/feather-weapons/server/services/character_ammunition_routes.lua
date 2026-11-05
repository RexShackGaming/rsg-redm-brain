-- Registered but inert behind BOTH disabled gates; does not open/enroll/grant.
WeaponCharacterAmmoTransport.Server({
    enabled=function() return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true end,
    service=WeaponCharacterAmmoDispatcher,
    register=function(handler)
        RegisterNetEvent('feather-weapons:server:character-ammo',function(kind,id,report)
            handler(source,kind,id,report)
        end)
    end,
    reply=function(target,id,epoch,result)
        TriggerClientEvent('feather-weapons:client:character-ammo',target,id,epoch,result)
    end
})

-- Inert until both native gates and the native-only provider are ready.
local readiness=WeaponCharacterAmmoReadiness.Server({
    enabled=function()
        return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
            and WeaponCharacterAmmoInventoryProvider.Status()=='ready'
    end,
    now=GetGameTimer,
    owner=WeaponCharacterAmmoActivationOwner,
    reply=function(target,id,identity,ok,reason)
        TriggerClientEvent('feather-weapons:client:character-ammo-ready',target,id,identity,ok,reason)
    end,
})
RegisterNetEvent('feather-weapons:server:character-ammo-ready',function(id,identity)
    local playerSource=source -- CFX source must be captured before Core yields.
    readiness.Receive(playerSource,id,identity)
end)
AddEventHandler('playerDropped',function() readiness.Cancel(source) end)
AddEventHandler('core.session.left.v1',function(session)
    if type(session)=='table' and session.source and session.sessionId then
        readiness.Cancel(session.source,session.sessionId)
    end
end)
