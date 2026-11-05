dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_runtime.lua')
dofile('shared/character_ammunition_client.lua'); dofile('client/character_ammunition_native.lua')
dofile('client/character_ammunition_controller.lua')
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local caps={regular=200,express=200}; local names={regular='AMMO_PISTOL',express='AMMO_PISTOL_EXPRESS'}
local context={source=1,characterId='c',sessionId='s'}
local ped,ready,writes,saves=10,true,0,0
local pools={AMMO_PISTOL=0,AMMO_PISTOL_EXPRESS=0}; local queue={}
local api={ped=function() return ped end,ready=function() return ready end,hash=function(n) return n end,
    read=function(_,hash) return pools[hash] end,
    write=function(_,hash,count) writes=writes+1; pools[hash]=count end,
    send=function(kind,id,report,callback) queue[#queue+1]={kind=kind,id=id,report=report,callback=callback} end}
local function flush()
    local q=table.remove(queue,1); assert(q)
    local value,reason
    if q.kind=='restore' then value,reason=R.ConfirmRestore(1,q.report)
    else
        local op
        if q.kind=='seal' then op,reason=R.PrepareFinalObservation(1,q.report)
        else op,reason=R.PrepareObservation(1,q.report) end
        if op then
            if op.unchanged then value=op.value
            else
                saves=saves+1
                value,reason=R.Complete(op.context,{ok=true,value={characterId='c',revision=op.spec.expectedRevision+1,pools=op.spec.pools}})
            end
        end
    end
    q.callback(value and {ok=true,value=value} or {ok=false,error={code=reason}})
    return q
end
local T=WeaponCharacterAmmoController.New(api)
local value=assert(R.Open(context,{characterId='c',revision=0,pools={regular=8,express=4}},caps,'first'))
ready=false; assert(not T.Begin(value,names,caps)); assert(writes==0)
ready=true; assert(T.Begin(value,names,caps)); assert(writes==2)
assert(not T.Tick()); flush(); assert(T.Status().phase=='active')
assert(T.Tick()); assert(#queue==0 and saves==0,'idle never polls server')
pools.AMMO_PISTOL=7; assert(T.Tick())
pools.AMMO_PISTOL=6; assert(not T.Finalize()); assert(T.Status().closing)
api.deathSnapshot=function() error('must not interrupt an existing orderly seal') end
local conflict,why=T.FinalizeDeath()
assert(not conflict and why=='orderly_seal_in_progress' and not T.Status().deathClosing)
local old=flush(); assert(T.Status().phase=='active')
assert(T.Tick()); assert(queue[1].kind=='seal' and queue[1].report.pools.regular==6)
flush(); assert(T.Status().phase=='sealed' and saves==2 and writes==2)
assert(not T.Tick()); assert(R.Get(1).pools.regular==6)
value=assert(R.Open(context,{characterId='c',revision=2,pools={regular=6,express=4}},caps,'second'))
T.Close(); ped=11; assert(T.Begin(value,names,caps)); assert(writes==4)
old.callback({ok=false}); assert(T.Status().phase=='restoring','old reply cannot freeze a new request')
flush(); assert(T.Status().phase=='active')
ped=12; pools.AMMO_PISTOL=0
assert(not T.Tick()); assert(T.Status().phase=='suspended' and #queue==0 and saves==2)
assert(not T.Begin(value,names,caps),'new ped cannot implicitly rebase old active epoch')
T.Close()
R.Revoke(1); ready=true
value=assert(R.Open(context,{characterId='c',revision=0,pools={regular=8,express=4}},caps,'death'))
api.deathSnapshot=function()
    return {characterId='c',sessionId='s',ped=ped,lifeState='dead',pools={regular=pools.AMMO_PISTOL,express=pools.AMMO_PISTOL_EXPRESS}}
end
assert(T.Begin(value,names,caps)); flush()
pools.AMMO_PISTOL=7; assert(T.Tick()) -- normal save is still pending at death
pools.AMMO_PISTOL=6; ready=false
local deathWrites=writes
assert(not T.FinalizeDeath() and T.Status().deathClosing and #queue==1)
flush(); assert(T.Tick() and queue[1].kind=='seal' and queue[1].report.pools.regular==6)
flush(); assert(T.Status().phase=='sealed' and R.Get(1).pools.regular==6 and writes==deathWrites,
    'same-ped death seals final reduction after pending save, without restoring ammo')
T.Close(); R.Revoke(1); ready=true
value=assert(R.Open(context,{characterId='c',revision=0,pools={regular=8,express=4}},caps,'death-increase'))
assert(T.Begin(value,names,caps)); flush(); ready=false; pools.AMMO_PISTOL=9
assert(not T.FinalizeDeath() and T.Status().phase=='frozen' and #queue==0,'death cannot credit an increase')
print('character_ammunition_controller_spec PASS')
