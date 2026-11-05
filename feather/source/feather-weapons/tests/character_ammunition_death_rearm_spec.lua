dofile('client/character_ammunition_lifecycle.lua')
dofile('client/character_ammunition_driver.lua')
dofile('shared/character_ammunition_readiness.lua')
local state,life,ack,now={phase='closed'},'alive',false,0
local host={Status=function() return state end,
    Receive=function() state={phase='active',session={ammo={}}}; return true end,
    Suspend=function() state.phase='frozen' end,
    FinalizeDeath=function() state.phase='sealed'; return true end,
    RecoverDeath=function() state.phase='cleanup_pending'; return true end,
    Tick=function() if state.phase=='cleanup_pending' and ack then state.phase='closed' end; return true end}
local driver=assert(WeaponCharacterAmmoDriver.New(host,{ped=function() return 7 end,
    identity=function() return {characterId='Jane',sessionId='current'} end,
    life=function() return life end,now=function() return now end,block=function() end}))
assert(driver.Receive({runtime={characterId='Jane',sessionId='current',epoch='death-epoch'}},true))
life='dead'; driver.Step(); assert(state.phase=='sealed' and not driver.Status().deathRecovery)
life='alive'; driver.Step(); assert(state.phase=='cleanup_pending' and not driver.Status().deathRecovery)
ack=true; driver.Step(); assert(state.phase=='closed')
local recovery=assert(driver.Status().deathRecovery)
assert(recovery.epoch=='death-epoch' and recovery.ped==7)
recovery.epoch='mutated'; assert(driver.Status().deathRecovery.epoch=='death-epoch')
driver.Step(); assert(driver.Status().deathRecovery.epoch=='death-epoch','signal survives closed frame')
-- Ordinary logout release does not produce a death-recovery permission.
state={phase='closed'}; ack=false
local logout=assert(WeaponCharacterAmmoDriver.New(host,{ped=function() return 7 end,
    identity=function() return {characterId='Jane',sessionId='current'} end,
    life=function() return 'alive' end,now=function() return now end,block=function() end}))
assert(logout.Receive({runtime={characterId='Jane',sessionId='current',epoch='logout'}},true))
state.phase='closed'; logout.Step(); assert(not logout.Status().deathRecovery)
local hint={characterId='Jane',sessionId='current'}
local ready,signal,sends=hint,nil,0
local client=WeaponCharacterAmmoReadiness.Client({enabled=function() return true end,
    now=function() return now end,owner={Readiness=function() return ready end,
        Recovery=function() return signal end},send=function() sends=sends+1 end})
client.Step(); assert(sends==1)
ready=nil; client.Step(); ready=hint
client.Step(); assert(sends==1,'logout/active transition parks same identity')
signal={characterId='foreign',sessionId='current',epoch='death-epoch'}
client.Step(); assert(sends==1)
signal=driver.Status().deathRecovery
client.Step(); assert(sends==2,'exact local death release explicitly rearms')
ready=nil; client.Step(); ready=hint; client.Step()
assert(sends==2,'recovery signal cannot be replayed')
signal={characterId='Jane',sessionId='current',epoch='next-death'}
client.Step(); assert(sends==3,'subsequent distinct death release rearms once')
print('character_ammunition_death_rearm_spec PASS (death-only post-ack signal, no logout reopen, exact one-use rearm)')
