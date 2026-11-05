dofile('client/character_ammunition_context.lua')
local character,session,ped,life,revision='c','s',10,'alive',2
local stopped,throw,flip,nativeDead=false,false,false,false
local context=WeaponCharacterAmmoContext.New({state=function() return stopped and 'stopped' or 'started' end,
    ped=function() return ped end,network=function() return true end,exists=function() return true end,
    dead=function() return nativeDead end,character=function() if throw then error('unavailable') end
        return {characterId=character,sessionId=session} end,
    medical=function()
        local value={characterId=character,sessionId=session,lifeState=life,revision=revision}
        if flip then session='changed' end
        return {ok=true,value=value}
    end})
assert(context.Read().ok and context.Ready() and context.Identity().characterId=='c')
life='dead'; assert(not context.Ready() and context.Identity().sessionId=='s','identity remains independently readable while dead')
assert(not context.ReadDeath().ok,'Medical dead without native death is not a stable death snapshot')
nativeDead=1
local death=context.ReadDeath()
assert(death.ok and death.value.lifeState=='dead' and death.value.ready==false and not context.Ready())
flip=true; assert(not context.ReadDeath().ok,'session flip during death context must refuse'); flip=false; session='s'
nativeDead=false
life='alive'; revision=0/0; assert(not context.Ready()); revision=2
flip=true; assert(not context.Read().ok,'identity read must be stable across Medical export'); flip=false
ped=0; assert(not context.Ready()); ped=10
stopped=true; assert(context.Identity()==nil and not context.Ready()); stopped=false
throw=true; assert(not context.Read().ok and context.Identity()==nil,'export failure is unavailable, never a fabricated identity')
print('character_ammunition_context_spec PASS (independent identity, alive/current Medical, stable ped/session, fail closed)')
local numeric=WeaponCharacterAmmoContext.New({state=function() return 'started' end,
    character=function() return {characterId='c',sessionId='s'} end,
    medical=function() return {ok=true,value={characterId='c',sessionId='s',lifeState='alive',revision=0}} end,
    ped=function() return 10 end,network=function() return 1 end,
    exists=function() return 1 end,dead=function() return 0 end})
assert(numeric.Ready(),'numeric native BOOL one/zero must match true/false')
print('context numeric native BOOL PASS')
