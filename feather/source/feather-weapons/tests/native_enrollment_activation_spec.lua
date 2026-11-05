dofile('shared/constants.lua')
dofile('shared/character_ammunition_activation.lua')
local first='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local second='e5e9955d-c29e-11f1-9ae2-e0d55eaa2deb'
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaCharacterId=first,NativeAlphaAdditionalCharacters={[second]=true}}
local sessions={[1]={characterId=first,sessionId='a'},[2]={characterId=second,sessionId='b'},
 [3]={characterId='outside',sessionId='c'}}
local calls,states={},{}
CoreAdapter={ResolveSession=function(source) return {ok=true,value=sessions[source]} end}
WeaponCharacterAmmoInventoryProvider={Status=function() return 'ready' end}
WeaponCharacterAmmoService={ReconcileSession=function(source,identity)
 assert(identity==sessions[source]); return {ok=true,value={retired={}}}
end}
WeaponDefinitionCatalog={}
WeaponCharacterAmmoPolicy={Build=function() return {limits={ammo=2}} end}
WeaponCharacterAmmoDispatch={New=function()
 return {Start=function(source)
  calls[source]=(calls[source] or 0)+1
  states[source]={phase='active',identity=sessions[source]}
  return {ok=true}
 end,Status=function(source) return states[source] end,Forget=function(source) states[source]=nil end}
end}
AddEventHandler=function() end
dofile('server/services/character_ammunition_dispatch.lua')
local owner=WeaponCharacterAmmoActivationOwner
assert(owner.Ready(1,sessions[1]).ok and owner.Ready(2,sessions[2]).ok)
assert(not owner.Ready(3,sessions[1]).ok and calls[3]==nil)
assert(not owner.Ready(1,sessions[2]).ok and calls[1]==1,'cross-character hint never substitutes Core identity')
assert(not owner.Ready(2,sessions[2]).ok and calls[2]==1,'repeated readiness cannot replace active second owner')
-- A third and fourth player need no allowlist or mode configuration.
sessions[3]={characterId='aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',sessionId='c'}
sessions[4]={characterId='bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',sessionId='d'}
assert(owner.Ready(3,sessions[3]).ok and calls[3]==1)
assert(not owner.Ready(4,sessions[3]).ok and calls[4]==nil)
assert(owner.Ready(4,sessions[4]).ok and calls[4]==1)
assert(not owner.Ready(4,sessions[4]).ok and calls[4]==1)
Config.DevMode=false;states[4]=nil
assert(owner.Ready(4,sessions[4]).ok and calls[4]==2,'ordinary activation works with developer mode disabled')
Config.NativeAlphaRuntime=false;states[4]=nil
assert(not owner.Ready(4,sessions[4]).ok and calls[4]==2,'native runtime gate remains required')
print('All-player activation PASS (Core identity, third/fourth owners, duplicate and runtime refusal)')
