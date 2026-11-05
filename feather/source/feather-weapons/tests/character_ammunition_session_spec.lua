for _,file in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_client.lua',
    'shared/character_ammunition_materialization.lua','client/character_ammunition_native.lua',
    'client/character_ammunition_controller.lua','client/character_ammunition_loadout.lua',
    'client/character_ammunition_session.lua'}) do dofile(file) end
local registry={names={regular='AMMO_PISTOL'},limits={regular=200},weapons={gun={nativeWeaponName='WEAPON_PISTOL_M1899',
    family='pistol',compatible={regular=true}}}}
local function bundle(epoch)
    return {runtime={characterId='c',sessionId='s',epoch=epoch,revision=0,phase='restoring',pools={regular=8}},
        creation={identity={characterId='c',sessionId='s',epoch=epoch},dual=false,sameModel=false,
            items={{slot='primary',point=2,itemInstanceId=1,itemRevision=2,definitionId='gun',
                nativeWeaponName='WEAPON_PISTOL_M1899',preferredAmmoType='regular',copyKey='primary:1:2',
                creation='native_zero_ammo_grant',attachments={},cosmetics={}}}}}
end
local pools={AMMO_PISTOL=0}
local blocked,created,writes,removed=true,0,0,0
local queue={}
local api={ped=function() return 10 end,ready=function() return true end,hash=function(name) return name end,
    block=function(value) blocked=value end,read=function(_,hash) return pools[hash] end,
    write=function(_,hash,count) assert(created>0,'ammo restoration must follow successful creation'); writes=writes+1; pools[hash]=count end,
    send=function(kind,id,report,callback) queue[#queue+1]={kind=kind,report=report,callback=callback} end,
    creation=function() return {current=function() return true end,prepareDual=function() return true end,
        createSingle=function(_,ammo) assert(ammo==0 and blocked); created=created+1; return {entity=100} end,
        createPair=function() error('unexpected pair') end,finish=function() return true end,
        remove=function() removed=removed+1; return true end} end}
local session=WeaponCharacterAmmoSession.New(api,registry)
local bad=bundle('bad'); bad.runtime.pools.regular=201
assert(not session.Begin(bad) and created==0 and writes==0,'preflight before native writes')
bad=bundle('bad'); bad.creation.items[1].nativeWeaponName='WEAPON_UNKNOWN'
assert(not session.Begin(bad) and created==0)
assert(session.Begin(bundle('e')) and created==1 and writes==1 and blocked)
assert(not session.Begin(bundle('e2')) and not session.Cleanup(),'no overwrite or unsealed cleanup')
local q=table.remove(queue,1); assert(q.kind=='restore')
local ack=q.report; ack.phase='active'; q.callback({ok=true,value=ack})
assert(session.Tick() and not blocked,'unblock only after exact server ack')
assert(session.Finalize() and blocked)
q=table.remove(queue,1); assert(q.kind=='seal'); ack=q.report; ack.phase='sealed'; q.callback({ok=true,value=ack})
session.Tick(); assert(session.Cleanup() and removed==1 and blocked and session.Status().phase=='cleanup_pending')
q=table.remove(queue,1); assert(q.kind=='cleanup' and q.report.cleanupComplete and q.report.remainingCopies==0)
assert(not session.Cleanup() and session.Status().phase=='cleanup_pending','repeat cleanup does not freeze pending acknowledgement')
ack=q.report; ack.phase='released'; q.callback({ok=true,value=ack})
session.Tick(); assert(session.Status().phase=='closed' and blocked)
-- Cleanup failures cannot reopen input or silently abandon the owner.
local function sealedSession(epoch)
    pools.AMMO_PISTOL=0
    local owner=WeaponCharacterAmmoSession.New(api,registry)
    assert(owner.Begin(bundle(epoch)))
    local request=table.remove(queue,1); request.report.phase='active'
    request.callback({ok=true,value=request.report}); owner.Tick()
    assert(owner.Finalize())
    request=table.remove(queue,1); request.report.phase='sealed'
    request.callback({ok=true,value=request.report}); owner.Tick()
    return owner
end
local failed=sealedSession('timeout')
assert(failed.Cleanup())
q=table.remove(queue,1)
q.callback({ok=false,error={code='runtime_request_timeout'}})
failed.Tick(); assert(failed.Status().phase=='frozen' and blocked,'missing release ack remains frozen')
assert(not failed.Begin(bundle('replacement')),'no replacement after failed acknowledgement')
local oldCreation=api.creation
api.creation=function(...)
    local adapter=oldCreation(...); adapter.remove=function() return false end; return adapter
end
failed=sealedSession('remove-failed')
assert(not failed.Cleanup() and failed.Status().phase=='frozen' and blocked)
assert(#queue==0 and failed.Status().copies==1,'failed removal sends no release acknowledgement')
api.creation=function(...)
    local adapter=oldCreation(...); adapter.cleanupSetup=function() return false end; return adapter
end
failed=sealedSession('setup-failed')
assert(not failed.Cleanup() and failed.Status().phase=='frozen' and #queue==0
    and failed.Status().copies==0,'setup failure must not send cleanup acknowledgement after guns removed')
local setupCleaned=false
api.creation=function(...)
    local adapter=oldCreation(...); adapter.cleanupSetup=function() setupCleaned=true; return true end; return adapter
end
local success=sealedSession('setup-success')
assert(success.Cleanup() and setupCleaned and queue[1].kind=='cleanup')
print('character_ammunition_session_spec PASS (preflight, creation before ammo, ack blocking, seal before owned cleanup)')
