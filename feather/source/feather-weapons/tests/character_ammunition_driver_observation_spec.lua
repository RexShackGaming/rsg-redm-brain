-- Real driver/controller/client/server runtime; native/network/persistence mocked.
for _,file in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_runtime.lua',
    'shared/character_ammunition_client.lua','client/character_ammunition_native.lua',
    'client/character_ammunition_controller.lua','client/character_ammunition_lifecycle.lua',
    'client/character_ammunition_driver.lua'}) do dofile(file) end
local runtime=WeaponCharacterAmmoRuntime.New(function() return true end)
local caps={regular=100,express=100}
local names={regular='AMMO_PISTOL',express='AMMO_PISTOL_EXPRESS'}
local native={AMMO_PISTOL=0,AMMO_PISTOL_EXPRESS=0}
local queue,now,writes,saves,blocked={},0,0,0,false
local controller=WeaponCharacterAmmoController.New({ped=function() return 10 end,
    ready=function() return true end,hash=function(name) return name end,
    read=function(_,name) return native[name] end,
    write=function(_,name,count) writes=writes+1; native[name]=count end,
    send=function(kind,id,report,callback) queue[#queue+1]={kind=kind,report=report,callback=callback} end})
-- Narrow host facade isolates the sampling driver from creation/cleanup adapters.
local host={Receive=function(bundle) return controller.Begin(bundle.runtime,names,caps) end,
    Status=function() local status=controller.Status(); return {phase=status.phase,session={ammo=status}} end,
    Tick=controller.Tick,Suspend=function() blocked=true end,
    FinalizeDeath=controller.FinalizeDeath,RecoverDeath=function() error('not a recovery test') end}
local driver=assert(WeaponCharacterAmmoDriver.New(host,{ped=function() return 10 end,
    identity=function() return {characterId='c',sessionId='s'} end,
    life=function() return 'alive' end,now=function() return now end,
    block=function(value) blocked=value end}))
local baseline=assert(runtime.Open({source=1,characterId='c',sessionId='s'},
    {characterId='c',revision=0,pools={regular=8,express=4}},caps,'observation'))
assert(driver.Receive({runtime=baseline},true))
local function flush()
    local q=table.remove(queue,1); assert(q)
    local value
    if q.kind=='restore' then value=assert(runtime.ConfirmRestore(1,q.report))
    else
        local op=assert(runtime.PrepareObservation(1,q.report))
        assert(not op.unchanged); saves=saves+1
        value=assert(runtime.Complete(op.context,{ok=true,value={characterId='c',
            revision=op.spec.expectedRevision+1,pools=op.spec.pools}}))
    end
    q.callback({ok=true,value=value}); return q,value
end
flush(); assert(driver.Step())
local restorationWrites=writes
native.AMMO_PISTOL=7; now=250; assert(driver.Step() and #queue==1)
native.AMMO_PISTOL=6; native.AMMO_PISTOL_EXPRESS=3
now=500; driver.Step(); assert(#queue==1,'shots during pending save cannot send a competing revision')
local old,reply=flush()
assert(runtime.Get(1).pools.regular==7 and native.AMMO_PISTOL==6,
    'save reply must not restore the older count over a later shot')
now=750; assert(driver.Step() and #queue==1)
assert(queue[1].report.pools.regular==6 and queue[1].report.pools.express==3)
flush(); assert(runtime.Get(1).revision==2 and saves==2)
old.callback({ok=true,value=reply})
assert(controller.Status().phase=='active' and controller.Status().baseline.revision==2,
    'duplicate old save reply must not regress the current baseline')
for frame=1,80 do now=750+frame*16; driver.Step() end
assert(#queue==0 and saves==2 and writes==restorationWrites,'idle and save acknowledgements cannot write native ammo')
native.AMMO_PISTOL=7; now=2500; assert(not driver.Step())
assert(controller.Status().phase=='frozen' and blocked and #queue==0 and writes==restorationWrites,
    'uncredited native increase must freeze without credit or replenishment')
now=2501; assert(not driver.Step() and blocked)
print('driver sustained observations PASS (pending shots, mixed pools, duplicate replies, idle no-write, increase freeze; mocked persistence)')
