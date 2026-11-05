dofile('client/character_ammunition_lifecycle.lua')
local life,phase,deathClosing='alive','active',false
local ticks,finals,recovers,suspends=0,0,0,0
local deathReady=false
local host={Status=function() return {phase=phase,session={ammo={deathClosing=deathClosing}}} end,
    Tick=function() ticks=ticks+1; if deathClosing then phase='sealed' end; return true end,
    FinalizeDeath=function()
        finals=finals+1
        if not deathReady then return nil,'death_context_not_ready' end
        deathClosing=true; return nil,'in_flight'
    end,
    RecoverDeath=function() recovers=recovers+1; phase='cleaning'; return true end,
    Suspend=function() suspends=suspends+1 end}
local blocked=false
local current=true
local api={life=function() return life end,block=function(value) blocked=value end,current=function() return current end}
local owner=assert(WeaponCharacterAmmoLifecycle.New(host,api))
assert(owner.Step() and ticks==1)
life='dead'
assert(not owner.Step() and ticks==1 and finals==1 and blocked,'block and do not ordinary-tick before Medical dead context')
deathReady=true
assert(owner.Step() and ticks==2 and phase=='sealed')
assert(not owner.Step() and ticks==2 and recovers==0,'retain sealed owner while dead')
life='alive'
assert(owner.Step() and recovers==1 and owner.Status().recovering)
assert(owner.Step() and recovers==1,'cleanup recovery must start once')
assert(suspends==0)
phase='closed'; assert(owner.Step())
phase='restoring'; life='dead'; deathClosing=false
local rejected=assert(WeaponCharacterAmmoLifecycle.New(host,api))
assert(not rejected.Step() and suspends==1,'death during initial restore must fail closed')
assert(not rejected.Step() and suspends==1,'failed lifecycle cannot resume')
local invalid=assert(WeaponCharacterAmmoLifecycle.New(host,{life=function() return false end,block=api.block,current=api.current}))
assert(not invalid.Step() and invalid.Status().fault=='invalid_lifecycle_life')
phase='sealed'; deathClosing=true; life='dead'; current=false
local lost=assert(WeaponCharacterAmmoLifecycle.New(host,api))
local beforeTicks,beforeRecovery=ticks,recovers
assert(not lost.Step() and lost.Status().fault=='lifecycle_identity_or_ped_changed' and blocked)
assert(ticks==beforeTicks and recovers==beforeRecovery,'sealed dead boundary loss cannot tick or clean')
current=true; assert(not lost.Step(),'regained context cannot revive failed owner')
print('dormant lifecycle death ordering PASS')
