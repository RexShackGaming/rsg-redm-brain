Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,NativeAlphaLifecycleWearEnabled=true}
dofile('client/character_ammunition_native_owner.lua')
local create,track
local context={characterId='c',sessionId='s',ped=7,lifeState='dead',medicalRevision=7}
local values={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0.5,soot=0}
local mode
local state={phase='active',session={ammo={phase='active',baseline={epoch='e'},deathClosing=true}}}
WeaponCharacterAmmoWorldContext={ReadDeath=function() return {ok=true,value=context} end}
local owner=assert(WeaponCharacterAmmoNativeOwner.New({ped=function() return 7 end,
 context=function() return {ok=true,value={characterId='c',sessionId='s',ped=7}} end,
 dual=function() error('read cannot create dual setup') end,
 creation=function() return {readDeathMaintenance=function(record,id)
  assert(record.entity==11 and id.epoch=='e')
  if mode=='revision' then context.medicalRevision=8 end
  if mode=='unreadable' then return nil end
  return values
 end} end,
 bootstrap=function(c,t) create,track=c,t; return {Start=function() return true end,
 Status=function() return {runtime=state} end} end,
}))
assert(owner.Start())
local adapter=assert(create(7,{characterId='c',sessionId='s',epoch='e'}))
track(adapter,{{entity=11,itemInstanceId=128,itemRevision=4}})
local report=assert(owner.DeathWear(context))
assert(report.medicalRevision==7 and report.items[1].itemRevision==4 and report.items[1].maintenance.dirt==0.5)
state.phase='sealed'; assert(not owner.DeathWear(context),'no resample after acknowledged seal'); state.phase='active'
mode='unreadable'; assert(not owner.DeathWear(context))
mode='revision'
local before={characterId='c',sessionId='s',ped=7,lifeState='dead',medicalRevision=7}
assert(not owner.DeathWear(before),'batch revision changes refuse complete report')
Config.NativeAlphaLifecycleWearEnabled=false; assert(not owner.DeathWear(context))
print('Death wear owner PASS (exact epoch records, active dead closing read, complete batch revision consistency, sealed/unreadable/gate refusal)')
