local commands,output={},{}
RegisterCommand=function(name,fn) commands[name]=fn end
Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
local scope='1'
GetConvar=function() return scope end
GetResourceState=function() return 'stopped' end
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local character,current=jane,true
local reads=0
WeaponDefinitionCatalog={}
local limits={}
for id=1,27 do limits['ammo'..id]=100 end
WeaponCharacterAmmoPolicy={Build=function() return {limits=limits} end}
local inventory={GetHealth=function() return {ok=true,value={state='ready'}} end}
local function snapshot()
    reads=reads+1
    local pools={}; for id in pairs(limits) do pools[id]=0 end
    return {ok=true,value={characterId=jane,revision=0,pools=pools,equipment={}}}
end
inventory.GetCharacterAmmunitionSnapshot=snapshot
inventory.GetCharacterFirearmRuntimeSnapshot=snapshot
local denials=0
local function denied(_,context,spec)
    assert(context.characterId==jane and next(spec)==nil)
    denials=denials+1
    return {ok=false,error={code='denied'}}
end
inventory.ObserveCharacterAmmunition=denied
inventory.MutateCharacterAmmunition=denied
exports={['feather-core']={GetSessionContext=function() return {ok=true,value={characterId=character,sessionId='s'}} end,
    IsSessionCurrent=function() return current end},['feather-inventory']=inventory}
local originalPrint=print; print=function(line) output[#output+1]=line end
dofile('tests/archive/server/jane_ammunition_readonly.lua')
local run=commands.WeaponJaneAmmoRead
run(1,{'1',jane}); assert(reads==0)
run(0,{'1','original'}); assert(reads==0)
character='original'; run(0,{'1',jane}); assert(reads==0)
character=jane; scope='0'; run(0,{'1',jane}); assert(reads==0)
scope='1'; run(0,{'1',jane})
assert(reads==2 and output[#output]:find('PASS snapshots=2',1,true))
assert(denials==2 and output[#output]:find('writeDenials=2',1,true))
inventory.MutateCharacterAmmunition=function() return {ok=true} end
run(0,{'1',jane})
assert(output[#output]:find('FAIL',1,true),'unexpected write permission must fail gate')
inventory.MutateCharacterAmmunition=denied
inventory.GetCharacterAmmunitionSnapshot=function() current=false; return snapshot() end
run(0,{'1',jane})
assert(reads==5 and output[#output]:find('FAIL',1,true),'world loss stops second read')
print=originalPrint
local file=assert(io.open('tests/archive/fxmanifest.jane-readonly.lua')); local manifest=file:read('*a'); file:close()
assert(not manifest:find('client_script',1,true) and not manifest:find('server/main.lua',1,true))
assert(not manifest:find('DB.lua',1,true),'isolated test resource cannot issue SQL')
print('Jane server-only export read gate PASS (isolated manifest, exact identity, canonical zero snapshot, context loss; mocked CFX)')
