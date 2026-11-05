for _,file in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_client.lua',
    'shared/character_ammunition_materialization.lua','client/character_ammunition_native.lua',
    'client/character_ammunition_controller.lua','client/character_ammunition_loadout.lua',
    'client/character_ammunition_session.lua'}) do dofile(file) end
local identity={characterId='c',sessionId='s',epoch='e'}
local plan={identity=identity,dual=false,sameModel=false,items={{slot='primary',point=2,
    itemInstanceId=1,itemRevision=2,definitionId='gun',nativeWeaponName='WEAPON_PISTOL_M1899',
    preferredAmmoType='regular',copyKey='primary:1:2',creation='native_zero_ammo_grant',attachments={},cosmetics={}}}}
local record={entity=100,itemInstanceId=1,itemRevision=2}
local outcome=false
local adapter={current=function() return true end,prepareDual=function() return true end,
    createSingle=function() return record end,createPair=function() error('unexpected pair') end,
    finish=function() return false end,remove=function() if outcome=='throw' then error('cleanup') end; return outcome end}
for _,failed in ipairs({false,'throw'}) do
    outcome=failed
    local result,why,partial=WeaponCharacterAmmoLoadout.New(adapter).Create(plan)
    assert(not result and why=='holster_verification_failed' and partial.handles[1]==record and not partial.cleanupComplete)
end
outcome=true
local _,_,partial=WeaponCharacterAmmoLoadout.New(adapter).Create(plan)
assert(partial.cleanupComplete and #partial.handles==0,'only explicit true confirms compensation')
outcome=nil
_,_,partial=WeaponCharacterAmmoLoadout.New(adapter).Create(plan)
assert(not partial.cleanupComplete and #partial.handles==1,'nil removal result is unconfirmed')
local tracked,blocked,writes,sends
local api={ped=function() return 10 end,ready=function() return true end,hash=function(v) return v end,
    block=function(v) blocked=v end,read=function() return 0 end,
    write=function() writes=true; error('failed creation cannot restore ammo') end,
    send=function() sends=true; error('failed creation cannot acknowledge activation/release') end,
    creation=function() return adapter end,
    owned=function(creator,records) assert(creator==adapter); tracked=records end}
local registry={names={regular='AMMO_PISTOL'},limits={regular=200},weapons={gun={nativeWeaponName='WEAPON_PISTOL_M1899',family='pistol',compatible={regular=true}}}}
outcome=false
local owner=WeaponCharacterAmmoSession.New(api,registry)
assert(not owner.Begin({creation=plan,runtime={characterId='c',sessionId='s',epoch='e',phase='restoring',revision=1,pools={regular=0}}}))
assert(owner.Status().phase=='frozen' and owner.Status().copies==1 and tracked[1]==record and blocked)
assert(not writes and not sends,'retained failure performs no ammo restore or server acknowledgement')
assert(not owner.Begin({}),'cannot overwrite retained session with another creation attempt')
print('creation failure retention PASS (exact residual handles to session/owner, nil/throw refusal, frozen blocked/no ammo/ack)')
