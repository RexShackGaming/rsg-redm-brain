vector3=function(x,y,z) return {x=x,y=y,z=z} end
dofile('config.lua')
GetConvarInt=function(_,default) return default end
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua',
 'shared/character_ammunition_materialization.lua','shared/native_guid_acceptance.lua'}) do dofile(file) end
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local cases=assert(WeaponGuidAcceptance.Matrix(WeaponDefinitionCatalog,registry))
registry.weapons.throwable_tomahawk={nativeWeaponName='WEAPON_THROWN_TOMAHAWK',family='throwable'}
assert(#WeaponGuidAcceptance.Matrix(WeaponDefinitionCatalog,registry)==#cases,'optional non-firearm registry entries do not enter firearm matrix')
registry.weapons.throwable_tomahawk=nil
local ids,coverage={},{}
for _,case in ipairs(cases) do
 assert(not ids[case.id]);ids[case.id]=true
 local plan=assert(WeaponGuidAcceptance.Plan(case,WeaponDefinitionCatalog,registry,{characterId='any-player',sessionId='s',epoch='e'}))
 assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,plan.identity))
 for _,item in ipairs(plan.items) do
  coverage[item.definitionId..':'..item.point..':'..case.profile]=true
  assert(item.itemInstanceId>=800000001 and item.itemInstanceId<=800000004)
  assert(item.ammo==nil and item.loaded==nil and item.reserve==nil)
 end
end
local count=0
for id,w in pairs(registry.weapons) do
 count=count+1
 local side=WeaponDefinitionCatalog.weapons[id].slot=='sidearm'
 for _,point in ipairs(side and {2,3} or {9,10}) do
  for _,profile in ipairs({'clean','customized'}) do assert(coverage[id..':'..point..':'..profile]) end
 end
end
local calls=0
local report=WeaponGuidAcceptance.Run({case=function(case)
 calls=calls+1
 if calls==2 then return {ok=false,cleanupComplete=false,reason='unconfirmed_insert',retained=1} end
 return {ok=true,cleanupComplete=true}
end},cases)
assert(calls==2 and report.passed==1 and report.phase=='review_required' and report.failedCase==cases[2].id
 and not report.cleanupComplete and report.automaticRetries==0,'stop first failure, retain uncertainty, never auto-replay')
report=WeaponGuidAcceptance.Run({case=function() error('native exception') end},cases)
assert(report.phase=='review_required' and not report.cleanupComplete and report.reason=='case_exception_retained')
report=WeaponGuidAcceptance.Run({case=function() return {ok=true,cleanupComplete=true} end},cases)
assert(report.phase=='complete' and report.passed==#cases and report.visual=='pending')
print(('GUID matrix/runner PASS (%s firearms, %s cases, all valid positions and ordered pairwise profiles, stop/retention)'):format(count,#cases))
