dofile('shared/character_ammunition_activation.lua')
local enabled,starts,state=true,0,nil
local identity={characterId='Jane',sessionId='current'}
local api={enabled=function() return enabled end,identity=function() return identity end,
    dispatcher={Status=function() return state end,Start=function()
        starts=starts+1; state={phase='restoring'}; return {ok=true}
    end}}
local owner=WeaponCharacterAmmoActivation.New(api)
local hint={characterId='Jane',sessionId='current',pools={regular=999}}
enabled=false; assert(not owner.Ready(2,hint).ok and starts==0); enabled=true
assert(not owner.Ready(2,{characterId='Jane',sessionId='old'}).ok and starts==0)
assert(owner.Ready(2,hint).ok and starts==1)
for _,phase in ipairs({'opening','restoring','active','sealed','frozen'}) do
    state={phase=phase}; assert(not owner.Ready(2,hint).ok and starts==1)
end
state={phase='released'}; assert(owner.Ready(2,hint).ok and starts==2)
state=nil
api.identity=function()
    assert(not owner.Ready(2,hint).ok,'reserve before yielding identity')
    assert(not owner.Cancel(2,'old')); assert(owner.Cancel(2,'current'))
    return identity
end
assert(not owner.Ready(2,hint).ok and starts==2)
api.identity=function() enabled=false; return identity end
assert(not owner.Ready(2,hint).ok and starts==2); enabled=true
api.identity=function() error('Core unavailable') end
assert(not owner.Ready(2,hint).ok and starts==2)
api.identity=function() return identity end
api.dispatcher.Status=function() error('status unavailable') end
assert(not owner.Ready(2,hint).ok and starts==2)
api.dispatcher.Status=function() return state end
api.dispatcher.Start=function() error('dispatch unavailable') end
assert(not owner.Ready(2,hint).ok)
api.dispatcher.Start=function() starts=starts+1; return {ok=true} end
assert(owner.Ready(2,hint).ok and starts==3,'exception releases readiness reservation only')
print('character_ammunition_activation_spec PASS')
