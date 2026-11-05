for _,file in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_client.lua',
    'shared/character_ammunition_materialization.lua','client/character_ammunition_native.lua',
    'client/character_ammunition_controller.lua','client/character_ammunition_loadout.lua',
    'client/character_ammunition_session.lua','client/character_ammunition_owner.lua'}) do dofile(file) end
local registry={names={regular='AMMO_PISTOL'},limits={regular=200},weapons={gun={nativeWeaponName='WEAPON_PISTOL_M1899',
    family='pistol',compatible={regular=true}}}}
local function bundle(epoch)
    return {runtime={characterId='c',sessionId='s',epoch=epoch,revision=0,phase='restoring',pools={regular=8}},
        creation={identity={characterId='c',sessionId='s',epoch=epoch},dual=false,sameModel=false,
            items={{slot='primary',point=2,itemInstanceId=1,itemRevision=2,definitionId='gun',
                nativeWeaponName='WEAPON_PISTOL_M1899',preferredAmmoType='regular',copyKey='primary:1:2',
                creation='native_zero_ammo_grant',attachments={},cosmetics={}}}}}
end
local enabled,ready,ped,character=true,true,10,'c'
local creates,writes,removes,blocked=0,0,0,false
local pools={AMMO_PISTOL=0}; local queue={}
local api={enabled=function() return enabled end,ready=function() return ready end,ped=function() return ped end,
    identity=function() return {characterId=character,sessionId='s'} end,
    block=function(value) blocked=value end,hash=function(name) return name end,
    read=function(_,hash) return pools[hash] end,write=function(_,hash,count) writes=writes+1; pools[hash]=count end,
    send=function(kind,id,report,callback) queue[#queue+1]={kind=kind,report=report,callback=callback} end,
    creation=function() return {current=function() return true end,prepareDual=function() return true end,
        createPair=function() error('unexpected pair') end,
        createSingle=function() creates=creates+1; return {entity=100+creates} end,
        finish=function() return true end,remove=function() removes=removes+1; return true end} end}
local owner=WeaponCharacterAmmoOwner.New(api,registry)
enabled=false; assert(not owner.Receive(bundle('e')) and creates==0); enabled=true
character='other'; assert(not owner.Receive(bundle('e')) and creates==0); character='c'
local bad=bundle('e'); bad.names={regular='AMMO_OTHER'}
assert(not owner.Receive(bad) and creates==0)
assert(owner.Receive(bundle('e')) and blocked and creates==1 and writes==1)
assert(not owner.Receive(bundle('e2')) and creates==1,'cannot replace live owned copies')
local function ack(phase)
    local q=table.remove(queue,1); q.report.phase=phase; q.callback({ok=true,value=q.report}); owner.Tick()
end
ack('active'); assert(not blocked and owner.Status().phase=='active')
assert(owner.Finalize()); ack('sealed'); assert(blocked)
assert(owner.Cleanup()); ack('released'); assert(owner.Status().phase=='closed' and removes==1 and not blocked)
assert(not owner.Receive(bundle('e')),'released epoch cannot replay')
assert(owner.Receive(bundle('e2')))
character='other'; owner.Tick()
assert(owner.Status().phase=='frozen' and blocked and removes==1,'identity loss does not clean or reset ammo')
local q=table.remove(queue,1); q.report.phase='active'; q.callback({ok=true,value=q.report}); owner.Tick()
assert(owner.Status().phase=='frozen' and blocked,'late ack cannot revive frozen owner')
character='c'; queue={}; pools.AMMO_PISTOL=0
owner=WeaponCharacterAmmoOwner.New(api,registry); assert(owner.Receive(bundle('ped')))
ped=11; owner.Tick(); assert(owner.Status().phase=='frozen' and blocked)
queue={}; pools.AMMO_PISTOL=0
owner=WeaponCharacterAmmoOwner.New(api,registry); assert(owner.Receive(bundle('world')))
ready=false; owner.Tick(); assert(owner.Status().phase=='frozen' and blocked)
assert(not owner.Cleanup() and removes==1,'world loss requires explicit recovery')
ready=true; queue={}; pools.AMMO_PISTOL=0
local originalCreation=api.creation
api.creation=function(...)
    local adapter=originalCreation(...)
    adapter.createSingle=function()
        ready=false; owner.Tick(); ready=true
        return {entity=999}
    end
    return adapter
end
owner=WeaponCharacterAmmoOwner.New(api,registry)
local beforeWrites=writes
assert(not owner.Receive(bundle('cancelled')) and owner.Status().phase=='frozen')
assert(writes==beforeWrites,'world regained during yielded creation cannot revive cancelled owner')
api.creation=originalCreation; ready=true; queue={}; pools.AMMO_PISTOL=0; ped=10
api.deathSnapshot=function()
    return {characterId=character,sessionId='s',ped=ped,lifeState='dead',pools={regular=pools.AMMO_PISTOL}}
end
owner=WeaponCharacterAmmoOwner.New(api,registry); assert(owner.Receive(bundle('death'))); ack('active')
ready=false; pools.AMMO_PISTOL=7
local deathRemoves,deathWrites=removes,writes
assert(owner.FinalizeDeath() and blocked and queue[1].kind=='seal')
local deathAck=table.remove(queue,1); deathAck.report.phase='sealed'; deathAck.report.revision=1
deathAck.callback({ok=true,value=deathAck.report}); owner.Tick()
assert(owner.Status().phase=='sealed' and blocked and not owner.Cleanup())
assert(not owner.RecoverDeath(),'cannot recover while dead')
ready=true; assert(not owner.Cleanup(),'alive again cannot bypass explicit death recovery')
assert(removes==deathRemoves and writes==deathWrites,'death seal retains copies and never restores ammo')
assert(owner.RecoverDeath() and removes==deathRemoves+1 and blocked and writes==deathWrites)
ack('released')
assert(owner.Status().phase=='closed' and not blocked,'explicit same-ped recovery waits for server release ack')
queue={}; pools.AMMO_PISTOL=0
owner=WeaponCharacterAmmoOwner.New(api,registry); assert(owner.Receive(bundle('death-ped'))); ack('active')
ready=false; ped=11
assert(not owner.FinalizeDeath() and owner.Status().phase=='frozen' and #queue==0,'replacement ped cannot submit old death')
dofile('client/character_ammunition_lifecycle.lua')
ready=true; ped=10; queue={}; pools.AMMO_PISTOL=0
owner=WeaponCharacterAmmoOwner.New(api,registry); assert(owner.Receive(bundle('lifecycle'))); ack('active')
local medicalDead=false
api.deathSnapshot=function()
    if not medicalDead then return nil end
    return {characterId=character,sessionId='s',ped=ped,lifeState='dead',pools={regular=pools.AMMO_PISTOL}}
end
-- Existing owner/session/controller are real; only native/context/transport are mocked.
local lifecycleHost={Status=owner.Status,Tick=owner.Tick,FinalizeDeath=owner.FinalizeDeath,
    RecoverDeath=owner.RecoverDeath,Suspend=function(why) error('unexpected suspension '..why) end}
local lifecycle=assert(WeaponCharacterAmmoLifecycle.New(lifecycleHost,{
    current=function() return character=='c' and ped==10 and enabled end,
    life=function() return ready and 'alive' or 'dead' end,block=api.block}))
ready=false; pools.AMMO_PISTOL=7
assert(not lifecycle.Step() and owner.Status().phase=='active' and blocked and #queue==0)
medicalDead=true; lifecycle.Step()
assert(queue[1].kind=='seal' and owner.Status().phase~='frozen')
local seal=table.remove(queue,1); seal.report.phase='sealed'; seal.report.revision=1
seal.callback({ok=true,value=seal.report}); lifecycle.Step()
assert(owner.Status().phase=='sealed' and #queue==0)
ready=true; lifecycle.Step(); assert(queue[1].kind=='cleanup')
local cleanup=table.remove(queue,1); cleanup.report.phase='released'
cleanup.callback({ok=true,value=cleanup.report}); lifecycle.Step()
assert(owner.Status().phase=='closed' and pools.AMMO_PISTOL==7 and not blocked)
print('character_ammunition_owner_spec PASS (including real lifecycle death/context-lag/recovery composition)')
