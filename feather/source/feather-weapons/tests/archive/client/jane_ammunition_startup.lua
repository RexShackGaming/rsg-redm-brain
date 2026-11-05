-- Jane-only development readiness hint. No baseline, native writes or grants.
-- Loaded only by the temporary startup manifest, never by normal production.
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
CreateThread(function()
    local deadline=GetGameTimer()+30000
    local expected=nil
    while GetGameTimer()<deadline do
        if Config.DevMode~=true or Config.CharacterAmmunitionEnabled==true
            or Config.CharacterAmmoTransportEnabled==true then return end
        local identity=WeaponCharacterAmmoWorldContext.Identity()
        if identity then
            if identity.characterId~=jane then return end
            if expected and identity.sessionId~=expected then return end
            expected=identity.sessionId
        elseif expected then return end
        local read=WeaponCharacterAmmoWorldContext.Read()
        if expected and read.ok and read.value.characterId==jane and read.value.sessionId==expected then
            TriggerServerEvent('feather-weapons:jane-zero:startup-ready',jane,expected)
            return
        end
        Wait(100)
    end
    print('[WeaponJanePrimaryStartup] NOT READY within30s; no native restore requested')
end)
