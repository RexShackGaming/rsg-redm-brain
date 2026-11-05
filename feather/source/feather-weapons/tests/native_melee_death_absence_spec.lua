Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_melee_catalog.lua',
 'shared/native_knife.lua','client/native_knife_owner.lua','client/native_melee_owner.lua'}) do dofile(p) end
local def=WeaponDefinitionCatalog.weapons.melee_hatchet
local row={id=161,revision=0,itemName=def.itemName,metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='H'}))}
local id={characterId='john',sessionId='s',epoch='e'}
local exists,has,observed,world,removes
joaat=function(v) return v end
PlayerPedId=function() return 7 end
DoesEntityExist=function(entity) if entity==7 then return true end; return exists end
HasPedGotWeapon=function() return has end
GetCurrentPedWeapon=function(_,_,point) return observed and point==4,def.nativeWeaponName end
GetCurrentPedWeaponEntityIndex=function() return 70 end
IsEntityDead=function() return false end
GetGameTimer=function() return 0 end
Wait=function() error('no wait expected') end
GiveWeaponToPed=function() exists=true; has=true; observed=true end
RemoveWeaponFromPed=function() removes=removes+1; exists=false; has=false; observed=false end
local function owner()
 exists=false; has=false; observed=false; world=true; removes=0
 local o=assert(WeaponNativeKnifeOwner.Scoped(7,id,function() return world end,def))
 assert(o.Create(row)); return o
end
local o=owner(); exists=false; has=false; observed=false
assert(o.Release(true) and o.Status().phase=='released' and removes==0)
assert(o.Status().reason=='death_owned_copy_already_absent')
o=owner(); exists=false; has=false; observed=false
assert(not o.Release() and removes==0,'ordinary unequip cannot use death absence proof')
o=owner(); observed=false
assert(not o.Release(true) and removes==0,'original object still exists: no disappearance proof')
o=owner(); exists=false; observed=false
assert(not o.Release(true) and removes==0,'model still in ped: no disappearance proof')
o=owner(); exists=false; has=false; observed=false; world=false
assert(not o.Release(true) and removes==0,'world loss cannot release')
o=owner(); exists=nil; has=false; observed=false
assert(not o.Release(true) and removes==0,'unknown native result is not proof')
local snapshot={characterId='john',equipment={melee=row},expected={weapon_melee={itemId=161,revision=0}}}
local approval=assert(WeaponNativeMeleeCatalog.Project(snapshot,WeaponDefinitionCatalog,id))
local recovery
local group=assert(WeaponNativeMeleeOwner.New(approval,WeaponDefinitionCatalog,id,function()
 local phase='idle'
 return {Create=function() phase='active'; return true end,Release=function(death)
  recovery=death; phase='released'; return true
 end,Status=function() return {phase=phase} end}
end,function() return true end))
assert(group.Create() and group.Release(true) and recovery==true)
print('death-only melee absence proof PASS: original gone + model absent + empty observation + current world; no deletion/adoption, ordinary cleanup unchanged')
