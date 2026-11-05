-- Read-only host adapter; no threads, events, native writes or automatic Begin.
WeaponCharacterAmmoWorldContext=WeaponCharacterAmmoContext.New({
    state=GetResourceState,ped=PlayerPedId,network=NetworkIsSessionStarted,
    exists=DoesEntityExist,dead=IsEntityDead,
    character=function() return exports['feather-character']:GetMedicalContext() end,
    medical=function() return exports['feather-medical']:GetLifeState() end,
})
