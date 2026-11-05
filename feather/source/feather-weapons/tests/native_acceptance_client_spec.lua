local handlers,reads,replies={},0,0
Config={DevMode=true,NativeAlphaRuntime=true}
RegisterNetEvent=function(name,fn) handlers[name]=fn end
WeaponCharacterAmmoActiveOwner={}
local bound={characterId='jane',sessionId='s',epoch='e'}
WeaponNativeAcceptanceView={Read=function(owner,identity) assert(owner==WeaponCharacterAmmoActiveOwner and identity==bound);reads=reads+1;return {identity=bound} end}
TriggerServerEvent=function(name,ticket,view) assert(name=='feather-weapons:server:acceptance-report' and ticket=='ticket' and view.identity==bound);replies=replies+1 end
dofile('client/native_acceptance_suite.lua')
local fn=handlers['feather-weapons:client:acceptance-read']
Config.DevMode=false;fn('ticket',bound);assert(reads==0)
Config.DevMode=true;fn('',bound);assert(reads==0)
fn('ticket',bound);assert(reads==1 and replies==1)
print('PASS client audit: development gate, bounded challenge and read-only reply')
