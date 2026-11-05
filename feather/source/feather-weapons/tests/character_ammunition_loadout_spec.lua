dofile('client/character_ammunition_loadout.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
local function plan(pair)
    return {identity=identity,dual=true,items={
        {copyKey='primary:1:2',point=2,creation=pair and 'inventory_guid_pair' or 'native_zero_ammo_grant'},
        {copyKey='offhand:2:2',point=3,creation=pair and 'inventory_guid_pair' or 'native_zero_ammo_grant'}}}
end
local removed,grants={},0
local api={current=function() return true end,prepareDual=function() return true end,
    createSingle=function(item,ammo) assert(ammo==0); grants=grants+1; return {entity=100+grants} end,
    createPair=function() return {{entity=201},{entity=202}} end,
    remove=function(handle) removed[#removed+1]=handle.entity end,finish=function() return true end}
local controller=WeaponCharacterAmmoLoadout.New(api)
local result=assert(controller.Create(plan(false)))
assert(#result.handles==2 and grants==2 and #removed==0 and controller.Status()=='created')
assert(not controller.Create(plan(false)))
controller=WeaponCharacterAmmoLoadout.New(api); assert(controller.Create(plan(true)))
api.createPair=function() return {{entity=201},{entity=201}} end
controller=WeaponCharacterAmmoLoadout.New(api); assert(not controller.Create(plan(true)))
assert(controller.Status()=='failed' and #removed==1)
api.createPair=function() return {{entity=201},{entity=202}} end
api.finish=function() return false end
controller=WeaponCharacterAmmoLoadout.New(api); assert(not controller.Create(plan(true)))
assert(#removed==3)
api.current=function() return false end
controller=WeaponCharacterAmmoLoadout.New(api); assert(not controller.Create(plan(false)))
assert(controller.Status()=='idle' and grants==2)
api.current=function() return true end
api.finish=function() return true end
local empty=assert(WeaponCharacterAmmoLoadout.New(api).Create({identity=identity,items={},dual=false}))
assert(#empty.handles==0,'unequipped character rebuild must support zero copies')
api.createSingle=function() return nil,'single_creation_precondition: preexisting_weapon' end
local _,reason=WeaponCharacterAmmoLoadout.New(api).Create(plan(false))
assert(reason=='single_creation_failed: invalid_handle: single_creation_precondition: preexisting_weapon')
api.createSingle=function() error('native diagnostic sentinel') end
_,reason=WeaponCharacterAmmoLoadout.New(api).Create(plan(false))
assert(reason:find('adapter_exception',1,true) and reason:find('native diagnostic sentinel',1,true))
api.createSingle=function() return {entity=321} end
_,reason=WeaponCharacterAmmoLoadout.New(api).Create(plan(false))
assert(reason=='single_creation_failed: duplicate_entity')
print('character_ammunition_loadout_spec PASS (zero-ammo creation, distinct entities, stale/repeat refusal, owned-handle compensation, creation diagnostics)')
