-- Real orchestration/driver factories; Core, native world and persistence are mocks.
dofile('shared/character_ammunition_dispatch.lua')
dofile('shared/character_ammunition_activation.lua')
dofile('shared/character_ammunition_readiness.lua')
dofile('client/character_ammunition_lifecycle.lua')
dofile('client/character_ammunition_driver.lua')
local session,ped,now,sequence,copies='old',7,0,0,0
local state={phase='closed'}
local identity=function() return {characterId='Jane',sessionId=session} end
local host={Status=function() return state end,Receive=function(bundle)
    assert(copies==0); copies=1
    state={phase='active',session={ammo={baseline=bundle.runtime}}}; return true
end,Tick=function() return true end,Suspend=function() error('unexpected suspension') end,
    FinalizeDeath=function() error('not a death test') end,RecoverDeath=function() error('not a death test') end}
WeaponCharacterAmmoOwner={New=function() return host end}
dofile('client/character_ammunition_receiver.lua')
local receiver=WeaponCharacterAmmoReceiver.New({identity=identity,ready=function() return true end,
    block=function() end},{})
local driver=assert(WeaponCharacterAmmoDriver.New(receiver,{ped=function() return ped end,
    identity=identity,life=function() return 'alive' end,now=function() return now end,block=function() end}))
local service={OpenLoadout=function()
    sequence=sequence+1
    local id={characterId='Jane',sessionId=session,epoch='epoch'..sequence}
    return {ok=true,value={runtime={characterId=id.characterId,sessionId=id.sessionId,epoch=id.epoch,
        phase='restoring',revision=9,pools={regular=0}},creation={identity=id,items={}}}}
end,ValidateLoadout=function() return {ok=true} end,FreezeLoadout=function() error('unexpected freeze') end}
for method,phase in pairs({ConfirmRestore='active',CheckpointAndSeal='sealed',ConfirmCleanup='released'}) do
    service[method]=function(_,report)
        local value={}; for key,item in pairs(report) do value[key]=item end
        value.phase=phase; return {ok=true,value=value}
    end
end
local dispatcher=WeaponCharacterAmmoDispatch.New({enabled=function() return true end,service=service,
    timeout=function() end,dispatch=function(_,bundle) assert(driver.Receive(bundle,true)) end})
local activation=WeaponCharacterAmmoActivation.New({enabled=function() return true end,
    identity=identity,dispatcher=dispatcher})
local client
local readiness=WeaponCharacterAmmoReadiness.Server({enabled=function() return true end,
    now=function() return now end,owner=activation,
    reply=function(_,id,hint,ok,why) client.Reply(id,hint,ok,why,true) end})
client=WeaponCharacterAmmoReadiness.Client({enabled=function() return true end,now=function() return now end,
    owner={Readiness=function() return state.phase=='closed' and identity() or nil end},
    send=function(id,hint) assert(readiness.Receive(2,id,hint)) end})
client.Step(); assert(sequence==1 and copies==1)
local report=dispatcher.Status(2).identity; report.revision=9; report.pools={regular=0}
assert(dispatcher.ConfirmRestore(2,report).ok)
client.Step() -- Active native owner parks this identity.
receiver.Quiesce() -- Actual checkpoint receiver retirement, not a mock closed-state shortcut.
assert(dispatcher.CheckpointAndSeal(2,report).ok)
copies=0; assert(dispatcher.ConfirmCleanup(2,report).ok)
state.phase='closed'; assert(driver.Step())
client.Step(); assert(sequence==1,'logout cleanup must not reopen before selection')
assert(dispatcher.Forget(2,'old')); readiness.Cancel(2,'old'); activation.Cancel(2,'old')
session='new'; ped=8; now=2000
client.Step(); assert(sequence==2 and copies==1,'new session restores exactly one copy')
report=dispatcher.Status(2).identity; report.revision=9; report.pools={regular=0}
assert(dispatcher.ConfirmRestore(2,report).ok and driver.Step())
assert(not receiver.Status().quiescing,'new independently current session resumes actual receiver')
assert(not dispatcher.Forget(2,'old') and not readiness.Cancel(2,'old')
    and not activation.Cancel(2,'old'),'late leave cannot tear down the new owner')
client.Step(); assert(sequence==2 and copies==1 and not driver.Status().deathRecovery)
print('character_ammunition_login_cycle_spec PASS (combined factories, one copy per session, no logout reopen, late-leave protection; mocked world/persistence)')
