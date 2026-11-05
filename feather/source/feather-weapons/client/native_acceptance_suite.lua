RegisterNetEvent('feather-weapons:client:acceptance-read',function(ticket,bound)
 if Config.DevMode~=true or Config.NativeAlphaRuntime~=true or type(ticket)~='string' or #ticket>128
  or #ticket==0 or type(bound)~='table' then return end
 local ok,view=pcall(WeaponNativeAcceptanceView.Read,WeaponCharacterAmmoActiveOwner,bound)
 TriggerServerEvent('feather-weapons:server:acceptance-report',ticket,ok and view or nil)
end)
