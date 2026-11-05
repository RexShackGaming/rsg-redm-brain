WeaponMoveDelivery={Start=function() end}
dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
local calls,threads={},{ }
RegisterCommand=function() end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
json={encode=function() return '' end}
local function result() return {ok=true,value={}} end
CoreAdapter={CheckCapabilities=result,CheckCharacterCapabilities=result}
DefinitionRegistry={Start=function() calls[#calls+1]='definitions'; return result() end}
WeaponCharacterAmmoInventoryProvider={Install=function() calls[#calls+1]='native-guards'; return true end}
WeaponNativeOwnershipReader={Install=function() calls[#calls+1]='native-reader'; return true end}
WeaponProvenanceService={Start=function() calls[#calls+1]='provenance'; return result() end}
InstallFeatherInventoryProvider=function() error('legacy usable provider must not install') end
ReconciliationService={BootstrapActiveSessions=function() error('legacy restoration must not start') end}
local function server()
    threads={}; dofile('server/main.lua'); return coroutine.resume(threads[1])
end
Config={DevMode=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
assert(not server() and #calls==0,'native flags alone are not an alpha startup authorization')
Config.NativeAlphaRuntime=true; Config.NativeAlphaCharacterId='Jane'
Config.CharacterAmmunitionEnabled=false; Config.CharacterAmmoTransportEnabled=false
assert(not server() and #calls==0,'disabled flags cannot start the obsolete host')
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
assert(server() and #calls==4 and calls[2]=='native-reader' and calls[3]=='provenance' and calls[4]=='native-guards')
Config.DevMode=false; assert(server() and #calls==8,'ordinary startup does not require developer mode'); Config.DevMode=true
local readerInstall=WeaponNativeOwnershipReader.Install
WeaponNativeOwnershipReader.Install=function() return nil,'reader refused' end
local before=#calls
assert(not server() and #calls==before+1,'reader failure cannot install guards or start legacy gameplay')
WeaponNativeOwnershipReader.Install=readerInstall
local ledgerStart=WeaponProvenanceService.Start
WeaponProvenanceService.Start=function() return {ok=false,error={message='ledger refused'}} end
before=#calls
assert(not server() and #calls==before+2,'ledger failure cannot install native guards')
WeaponProvenanceService.Start=ledgerStart
local now,readied,starts,binds=0,false,0,0
Config.DevMode=false
GetGameTimer=function() return now end
Wait=function() coroutine.yield() end
WeaponCharacterAmmoWorldContext={Read=function()
    return readied and {ok=true,value={characterId='Jane'}} or {ok=false}
end}
WeaponCharacterAmmoNativeOwner={New=function() return {Start=function() starts=starts+1; return true end,
    BindReadiness=function() binds=binds+1; return true end} end}
threads={}; dofile('client/character_ammunition_startup.lua')
assert(coroutine.resume(threads[1]) and starts==0)
readied=true; assert(coroutine.resume(threads[1]) and starts==1 and binds==1)
assert(coroutine.status(threads[1])=='dead')
threads={}; Config.CharacterAmmoTransportEnabled=false
dofile('client/character_ammunition_startup.lua'); assert(coroutine.resume(threads[1]) and starts==1)
Config.CharacterAmmoTransportEnabled=true; readied=false
threads={}; dofile('client/character_ammunition_startup.lua'); assert(coroutine.resume(threads[1]))
Config.NativeAlphaRuntime=false; assert(coroutine.resume(threads[1]) and starts==1)
print('character_ammunition_startup_spec PASS (explicit alpha gates, native-only provider, alive wait/shutdown)')
