-- Server-side exact binding and item holds; actual plan contracts, mocked CFX.
Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition_catalog.lua')
dofile('shared/character_ammunition_policy.lua'); dofile('shared/character_ammunition_item.lua')
dofile('shared/character_ammunition_materialization.lua')
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local pools={}; for id in pairs(registry.limits) do pools[id]=0 end
local scope,current,character='1',true,jane
GetConvar=function() return scope end; GetResourceState=function() return 'stopped' end
GetGameTimer=function() return 1 end
local commands,events,guards,sent={},{},{},{}
RegisterCommand=function(name,fn) commands[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
TriggerClientEvent=function(name,target,plan) sent[#sent+1]={target=target,plan=plan} end
local api={Guards={}}
for _,kind in ipairs({'Move','Destroy','InstanceChange'}) do
    api.Guards['Register'..kind..'Guard']=function(_,fn) guards[kind]=fn; return {ok=true} end
    api.Guards['Unregister'..kind..'Guard']=function() guards[kind]=nil end
end
local revision=1
api.GetItemForCharacter=function(char,id)
    assert(char==jane and id==112)
    for _,fn in pairs(guards) do assert(fn({id=112})==false and fn({id=113})==true) end
    return {ok=true,value={id=112,revision=revision,definition={name='weapon_revolver_cattleman'},metadata={
        schemaVersion=2,weaponDefinitionId='revolver_cattleman',serialNumber='FW-REVO-6AC9DCDE-FDEBF3-0001',
        condition=100,quality=100,maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
        ammo={ownership='character',type='ammo_revolver_regular'},attachments={},cosmetics={},
        flags={stolen=false,evidence=false,disabled=false},provenance={}}}}
end
exports={['feather-core']={GetSessionContext=function() return {ok=true,value={characterId=character,sessionId='s'}} end,
    IsSessionCurrent=function() return current end},['feather-inventory']={initiate=function() return api end,
    GetCharacterFirearmRuntimeSnapshot=function() return {ok=true,value={characterId=jane,revision=0,pools=pools,equipment={}}} end}}
dofile('tests/archive/server/jane_ammunition_zero.lua')
local run=commands.WeaponJaneZero
run(1,{'1',jane}); assert(#sent==0)
scope='0'; run(0,{'1',jane}); assert(#sent==0)
scope='1'; character='original'; run(0,{'1',jane}); assert(#sent==0)
character=jane; revision=2; run(0,{'1',jane}); assert(#sent==0 and next(guards)==nil)
revision=1; run(0,{'1',jane}); assert(#sent==1 and next(guards))
assert(sent[1].plan.items[1].itemInstanceId==112 and sent[1].plan.items[1].point==2)
run(0,{'1',jane}); assert(#sent==1,'active reservation blocks overlap')
source=2; events['feather-weapons:jane-zero:ack'](sent[1].plan.identity.epoch,'cleaned'); assert(next(guards))
source=1; events['feather-weapons:jane-zero:ack']('old','cleaned'); assert(next(guards))
events['feather-weapons:jane-zero:ack'](sent[1].plan.identity.epoch,'cleaned'); assert(next(guards)==nil)
local saved={primary={id=112,revision=1,itemName='weapon_revolver_cattleman',metadata=api.GetItemForCharacter(jane,112).value.metadata}}
local savedPrimary=saved.primary
local beltRevision=3
exports['feather-inventory'].GetCharacterFirearmRuntimeSnapshot=function()
 return {ok=true,value={characterId=jane,revision=beltRevision,pools=pools,equipment=saved}}
end
api.GetItemForCharacter=function() error('saved-primary plan must use actual saved snapshot, not standalone item') end
local restore=commands.WeaponJanePrimaryNative
saved.primary=nil; restore(0,{'1',jane}); assert(#sent==1 and next(guards)==nil,'empty slot cannot restore')
saved.primary=savedPrimary
saved.offhand=saved.primary; restore(0,{'1',jane}); assert(#sent==1); saved.offhand=nil
beltRevision=2; restore(0,{'1',jane}); assert(#sent==1); beltRevision=3
pools.ammo_revolver_regular=1; restore(0,{'1',jane}); assert(#sent==1); pools.ammo_revolver_regular=0
restore(0,{'1',jane}); assert(#sent==2 and next(guards))
assert(sent[2].plan.items[1].point==2 and sent[2].plan.items[1].itemInstanceId==112)
source=1; events['feather-weapons:jane-zero:ack'](sent[2].plan.identity.epoch,'cleaned')
assert(next(guards)==nil and saved.primary.id==112 and beltRevision==3,'cleanup never clears saved assignment')
print('Jane saved-primary native plan PASS (actual saved snapshot only, missing/extra slot, revision/nonzero refusal, zero copy cleanup retains saved assignment; mocked CFX)')
print('Jane zero native server gate PASS (exact item/identity, holds before reads, overlap and stale/wrong-source ack refusal; mocked CFX)')

local coreSession='before-login'
exports['feather-core'].GetSessionContext=function() return {ok=true,value={characterId=jane,sessionId=coreSession}} end
exports['feather-core'].IsSessionCurrent=function(_,target,session,char)
    return current and target==1 and session==coreSession and char==jane
end
beltRevision=7
local login=commands.WeaponJanePrimaryLogin
login(1,{'1',jane}); assert(#sent==2)
login(0,{'1',jane}); assert(#sent==3 and sent[3].plan=='before-login' and not next(guards))
source=1; events['feather-weapons:jane-zero:login-ready'](jane,'before-login'); assert(#sent==3)
coreSession='after-login'
source=2; events['feather-weapons:jane-zero:login-ready'](jane,coreSession); assert(#sent==3)
source=1; events['feather-weapons:jane-zero:login-ready']('original',coreSession); assert(#sent==3)
events['feather-weapons:jane-zero:login-ready'](jane,'forged-session'); assert(#sent==3)
events['feather-weapons:jane-zero:login-ready'](jane,coreSession)
assert(#sent==4 and sent[4].plan.identity.sessionId==coreSession and next(guards))
events['feather-weapons:jane-zero:login-ready'](jane,coreSession); assert(#sent==4,'login arm is one-use')
events['feather-weapons:jane-zero:ack'](sent[4].plan.identity.epoch,'cleaned')
assert(not next(guards) and saved.primary==savedPrimary and beltRevision==7)
events['feather-weapons:jane-zero:login-ready'](jane,coreSession); assert(#sent==4)
print('Jane automatic saved-primary login server PASS (console arm, new Core session, source/identity binding, exact ledger7, one-use, no SQL writes; mocked CFX)')

-- Core validation may yield: overlapping hints cannot dispatch twice and the
-- ambient CFX source cannot redirect the captured console-authorized target.
dofile('tests/archive/server/jane_ammunition_zero.lua')
coreSession='before-second-login'
commands.WeaponJanePrimaryLogin(0,{'1',jane})
coreSession='second-login'
local ordinaryCurrent=exports['feather-core'].IsSessionCurrent
local delayed=true
exports['feather-core'].IsSessionCurrent=function(...)
    if delayed then delayed=false; coroutine.yield('core_wait') end
    return ordinaryCurrent(...)
end
source=1
local worker=coroutine.create(function() events['feather-weapons:jane-zero:login-ready'](jane,coreSession) end)
assert(coroutine.resume(worker))
events['feather-weapons:jane-zero:login-ready'](jane,coreSession)
assert(#sent==5,'overlapping readiness hint cannot bypass Core reservation')
source=99
assert(coroutine.resume(worker) and #sent==6 and sent[6].target==1)
source=1; events['feather-weapons:jane-zero:ack'](sent[6].plan.identity.epoch,'cleaned')
exports['feather-core'].IsSessionCurrent=ordinaryCurrent
print('Jane login yielded Core/source capture barrier PASS')

for _,bad in ipairs({'revision','ammo','slot'}) do
    dofile('tests/archive/server/jane_ammunition_zero.lua')
    coreSession='arm-'..bad
    commands.WeaponJanePrimaryLogin(0,{'1',jane})
    local before=#sent
    coreSession='login-'..bad
    if bad=='revision' then beltRevision=6 elseif bad=='ammo' then pools.ammo_revolver_regular=1
    else saved.offhand=savedPrimary end
    source=1; events['feather-weapons:jane-zero:login-ready'](jane,coreSession)
    assert(#sent==before and next(guards)==nil,'invalid saved baseline cannot dispatch or retain undispatched holds')
    beltRevision=7; pools.ammo_revolver_regular=0; saved.offhand=nil
    events['feather-weapons:jane-zero:login-ready'](jane,coreSession)
    assert(#sent==before,'refused login does not silently retry')
end
print('Jane login exact baseline refusal PASS (revision, nonzero ammo, extra slot; mocked CFX)')

-- Resource-start ingress has no console arm, but still requires independent
-- Core identity, exact opt-in and the current immutable saved ledger9 plan.
dofile('tests/archive/server/jane_ammunition_zero.lua')
local startupScope='0'
GetConvar=function(name) return name=='feather_jane_primary_startup' and startupScope or scope end
beltRevision=9; coreSession='startup-session'
local startup=events['feather-weapons:jane-zero:startup-ready']
local before=#sent
source=1; startup(jane,coreSession); assert(#sent==before and not next(guards))
startupScope='1'
source=2; startup(jane,coreSession); assert(#sent==before)
source=1; startup('original',coreSession); startup(jane,'forged'); assert(#sent==before)
local coreCurrent=exports['feather-core'].IsSessionCurrent
local waiting=true
exports['feather-core'].IsSessionCurrent=function(...)
    if waiting then waiting=false; coroutine.yield('startup_core_wait') end
    return coreCurrent(...)
end
worker=coroutine.create(function() startup(jane,coreSession) end)
assert(coroutine.resume(worker))
startup(jane,coreSession); assert(#sent==before,'yielded validation reserves ingress')
startupScope='0'; assert(coroutine.resume(worker) and #sent==before and not next(guards))
startupScope='1'; source=1; startup(jane,coreSession)
assert(#sent==before+1 and sent[#sent].target==1 and sent[#sent].plan.identity.sessionId==coreSession and next(guards))
events['feather-weapons:jane-zero:ack'](sent[#sent].plan.identity.epoch,'cleaned')
startup(jane,coreSession)
assert(#sent==before+1 and not next(guards) and beltRevision==9 and saved.primary==savedPrimary)
print('Jane resource-start server PASS (opt-in, exact ledger9, independently current Core, source/UUID forgery refusal, yielded disable/overlap, one-use owned cleanup; mocked CFX)')
