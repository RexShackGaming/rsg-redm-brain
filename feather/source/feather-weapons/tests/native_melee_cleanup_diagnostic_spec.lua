Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_melee_catalog.lua',
 'shared/native_knife.lua','client/native_knife_owner.lua'}) do dofile(p) end
local def=WeaponDefinitionCatalog.weapons.melee_hatchet
local row={id=161,revision=0,itemName=def.itemName,metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='H'}))}
local id={characterId='john',sessionId='s',epoch='e'}
local has,hand,exists,removes=false,70,true,0
joaat=function(v) return v end
PlayerPedId=function() return 7 end
DoesEntityExist=function(entity) return entity==7 or (exists and (entity==70 or entity==71)) end
HasPedGotWeapon=function() return has end
GetCurrentPedWeapon=function(_,_,point) return has and point==4,def.nativeWeaponName end
GetCurrentPedWeaponEntityIndex=function() return hand end
IsEntityDead=function() return false end
GetGameTimer=function() return 0 end
Wait=function() error('no wait') end
GiveWeaponToPed=function() has=true end
RemoveWeaponFromPed=function() removes=removes+1 end
local owner=assert(WeaponNativeKnifeOwner.Scoped(7,id,function() return true end,def))
assert(owner.Create(row)); hand=71
assert(not owner.Release() and removes==0)
local s=owner.Status()
assert(s.reason=='knife_cleanup_identity_unconfirmed' and s.entity==70)
assert(s.cleanupEvidence.points[1].entity==71 and not s.cleanupEvidence.points[1].tracked)
assert(s.cleanupEvidence.trackedExists and s.cleanupEvidence.modelPresent and s.cleanupEvidence.current)
s.cleanupEvidence.points[1].entity=900
assert(owner.Status().cleanupEvidence.points[1].entity==71,'private diagnostic copy')
hand=0
s=owner.Status(); assert(s.observation.points[1].entity==0 and not s.observation.points[1].exists)
assert(s.cleanupEvidence.points[1].entity==71,'failure evidence does not change with later observations')
exists=false; has=false
s=owner.Status(); assert(not s.observation.trackedExists and not s.observation.modelPresent and #s.observation.points==0)
assert(not owner.Release() and removes==0,'read-only diagnostics never release or adopt a replacement')
print('normal melee cleanup diagnostics PASS: captured failure versus fresh read-only observation, exact replacement veto, no retry/write/adoption')
