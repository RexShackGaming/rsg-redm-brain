-- Interleaved real coordinator, mocked provider/native boundaries. Not live SQL.
dofile('shared/constants.lua')
local secondCharacter='e5e9955d-c29e-11f1-9ae2-e0d55eaa2deb'
Config={NativeAlphaCharacterId='Jane',NativeAlphaAdditionalCharacters={[secondCharacter]=true}}
dofile('server/services/native_equipment_transition.lua')
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
for _,outcome in ipairs({'confirmed','refused','uncertain'}) do
    local identities={
        [11]={characterId='Jane',sessionId='jane-session',epoch='jane-epoch'},
        [22]={characterId=secondCharacter,sessionId='other-session',epoch='other-epoch'}}
    local sessions={[11]='jane-session',[22]='other-session'}
    local pending,contexts,specs,commits,rebuilds={},{},{},{[11]=0,[22]=0},{[11]=0,[22]=0}
    local coordinator
    coordinator=assert(WeaponNativeEquipmentTransition.New({
        enabled=function() return true end,
        prepare=function(source)
            return {ok=true,value={identity=copy(identities[source]),spec={characterId=identities[source].characterId,
                action='unequip',expected={weapon={itemId=source*10,revision=1}}}}}
        end,
        current=function(source,scope) return sessions[source]==scope.sessionId and WeaponNativeEnrollment.Allows(Config,scope.characterId) end,
        released=function() return true end,
        ticket=function(source) return 'ticket:'..source end,
        requestRelease=function(source,request) pending[source]=copy(request); return true end,
        commit=function(context,spec)
            local source=context.actorSource
            assert(coordinator.CanCommit(context,spec))
            contexts[source],specs[source]=copy(context),copy(spec)
            commits[source]=commits[source]+1
            if source==11 then
                coroutine.yield('provider-pending')
                if outcome=='refused' then return {ok=false,error={code='rollback'}} end
                if outcome=='uncertain' then error('acknowledgement lost') end
            end
            return {ok=true,value={}}
        end,
        rebuild=function(source)
            rebuilds[source]=rebuilds[source]+1
            local fresh=copy(identities[source]); fresh.epoch=fresh.epoch..'-restored'
            return {ok=true,value=fresh}
        end,
        restored=function() return true end,
    }))
    assert(coordinator.Begin(11,{}).ok and coordinator.Begin(22,{}).ok)
    assert(not coordinator.Released(22,pending[11].ticket,pending[11].identity).ok,'cross-player release must fail')
    local result
    local worker=coroutine.create(function()
        result=coordinator.Released(11,pending[11].ticket,pending[11].identity)
    end)
    local ok,phase=coroutine.resume(worker)
    assert(ok and phase=='provider-pending' and coordinator.Status(11).commitOutcome=='pending')
    assert(not coordinator.Begin(11,{}).ok,'overlap blocked only for same player')
    assert(not coordinator.Released(11,pending[11].ticket,pending[11].identity).ok,'duplicate release cannot dispatch twice')
    local forged=copy(contexts[11]); forged.actorSource=22
    assert(not coordinator.CanCommit(forged,specs[11]),'source cannot borrow another player ticket')
    assert(coordinator.Released(22,pending[22].ticket,pending[22].identity).ok,'other player can finish while first provider yields')
    local fresh=copy(identities[22]); fresh.epoch=fresh.epoch..'-restored'
    assert(not coordinator.Restored(11,pending[22].ticket,fresh).ok)
    assert(coordinator.Restored(22,pending[22].ticket,fresh).ok)
    assert(commits[22]==1 and rebuilds[22]==1 and coordinator.Status(22).phase=='active')

    assert(not coordinator.Cancel(11,'other-session'),'foreign session cannot cancel player')
    assert(coordinator.Cancel(11,'jane-session'))
    assert(coroutine.resume(worker) and not result.ok,'late cancelled reply cannot rebuild')
    assert(commits[11]==1 and rebuilds[11]==0 and coordinator.Status(11).phase=='frozen')
    assert(coordinator.Status(11).commitOutcome==outcome,'actual provider outcome retained after cancellation')
    assert(not coordinator.CanCommit(contexts[11],specs[11]))
    assert(coordinator.Status(22).phase=='active' and coordinator.Status(22).commitOutcome=='confirmed')

    sessions[11]='new-session'
    assert(coordinator.Retire(11,'jane-session') and not coordinator.Status(11))
    identities[11]={characterId='Jane',sessionId='new-session',epoch='new-epoch'}
    assert(coordinator.Begin(11,{}).ok)
    assert(not coordinator.Released(11,'ticket:11',contexts[11]).ok,'same ticket text cannot override session/epoch')
    assert(not coordinator.Cancel(11,'jane-session') and coordinator.Status(11).phase=='releasing')
    assert(coordinator.Status(22).phase=='active' and commits[22]==1)
end
print('Multiplayer transition isolation PASS (two interleaved players, cross-ticket/source refusal, per-player overlap, late confirmed/refused/unknown outcomes, cancellation and source reuse; mocked provider)')

local now=0
local identity={[11]={characterId='Jane',sessionId='s11',epoch='e11'},[22]={characterId=secondCharacter,sessionId='s22',epoch='e22'}}
local busy,requests={},{}
local sampler=WeaponNativePeriodicWear.New({enabled=function() return true end,now=function() return now end,
    interval=function() return 60000 end,
    status=function(source) return {phase='active',identity=copy(identity[source])} end,
    busy=function(source) return busy[source] end,
    items=function(source) return {{id=source*10},{id=source*10+1}} end,
    request=function(source,item) requests[#requests+1]={source=source,item=item}; return true end})
assert(not sampler.Step(11) and not sampler.Step(22))
now=60000; busy[11]=true
assert(not sampler.Step(11) and sampler.Step(22) and requests[1].source==22)
assert(not sampler.Complete(11,identity[22],'persisted'),'foreign completion cannot increment counters')
assert(sampler.Complete(22,identity[22],'persisted'))
busy[11]=false; assert(sampler.Step(11) and requests[2].item==110)
assert(sampler.Complete(11,identity[11],'unchanged'))
assert(sampler.Status(11).persisted==0 and sampler.Status(22).persisted==1)
assert(not sampler.Forget(22,'s11') and sampler.Forget(11,'s11'))
now=120000; assert(sampler.Step(22) and requests[3].item==221,'other player cursor/deadline survives retirement')
assert(sampler.Status(22).persisted==1)
print('Multiplayer periodic isolation PASS (per-player busy/deadline/cursor/counters, foreign completion/session cleanup refusal)')
