Config={}
WeaponDefinitionCatalog={ammunition={}}
exports=function() end
GetGameTimer=function() return 0 end
Wait=function() end
dofile('client/character_ammunition_actions.lua')
local clock=0
local enabled=true
local context={ok=true,value={characterId='jane',sessionId='session',ped=1}}
local baseline={characterId='jane',sessionId='session',epoch='epoch',revision=9,pools={regular=0}}
local ammo={phase='active',baseline=baseline,ped=1,pending=false}
local runtime={phase='active',session={ammo=ammo}}
local owner={Status=function() return {phase='started',bootstrap={runtime=runtime}} end}
local sends=0
local delta
owner.Transfer=function(id,amount)
    sends=sends+1
    delta=amount
    ammo.pending=true
    return true
end
local finish=true
local actions
actions=WeaponCharacterAmmoActions.New({
    enabled=function() return enabled end,owner=function() return owner end,
    context=function() return context end,catalog={regular={label='Regular',itemName='ammo_regular'}},
    weapons={cattleman={itemName='weapon_revolver_cattleman',ammunitionTypes={'regular'}}},
    operation=function(n) return 'ui:'..n end,now=function() return clock end,
    wait=function(ms)
        clock=clock+ms
        assert(not actions.Options().ok)
        assert(not actions.Transfer('regular',1,'load').ok)
        if finish then
            ammo.pending=false
            baseline={characterId='jane',sessionId='session',epoch='epoch',revision=baseline.revision+1,
                pools={regular=baseline.pools.regular+delta}}
            ammo.baseline=baseline
        end
    end,
})
assert(actions.Options().value.options[1].carried==0)
assert(#actions.Options('unknown').value.options==0)
assert(#actions.Options('ammo_regular').value.options==1)
assert(#actions.Options('weapon_revolver_cattleman').value.options==1)
assert(not actions.Transfer('regular',0,'load').ok and sends==0)
assert(not actions.Transfer('regular',1,'unload').ok and sends==0)
local scope={characterId='jane',sessionId='session',epoch='epoch'}
assert(actions.Transfer('regular',1,'load').error.code=='ammunition_panel_expired_reopen' and sends==0)
assert(actions.Transfer('regular',1,'load',{characterId='jane',sessionId='old',epoch='epoch'}).error.code=='ammunition_panel_expired_reopen' and sends==0)
assert(actions.Transfer('regular',1,'load',{characterId='jane',sessionId='session',epoch='old'}).error.code=='ammunition_panel_expired_reopen' and sends==0)
local result=actions.Transfer('regular',1,'load',scope)
assert(result.ok and result.value.revision==10 and result.value.carried==1 and sends==1)
result=actions.Transfer('regular',1,'unload',scope)
assert(result.ok and result.value.revision==11 and result.value.carried==0 and sends==2)
enabled=false
assert(not actions.Options().ok and not actions.Transfer('regular',1,'load').ok and sends==2)
enabled=true; context.value.sessionId='other'
assert(not actions.Transfer('regular',1,'load').ok and sends==2)
context.value.sessionId='session'; finish=false
result=actions.Transfer('regular',1,'load',scope)
assert(not result.ok and result.error.code=='ammunition_transfer_ack_timeout_no_retry' and sends==3)
assert(not actions.Transfer('regular',1,'load').ok and sends==3)
print('character ammunition Inventory actions spec PASS')
