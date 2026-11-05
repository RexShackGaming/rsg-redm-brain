Config={AmmunitionPools={enabled=false}}
dofile('shared/constants.lua')
dofile('shared/definitions/weapons.lua')
dofile('shared/native_melee_catalog.lua')
dofile('shared/native_knife.lua')
dofile('client/native_knife_owner.lua')
local function copy(t)
 if type(t)~='table' then return t end
 local r={}; for k,v in pairs(t) do r[k]=copy(v) end; return r
end
local ids={'melee_knife','melee_machete','melee_hammer','melee_cleaver','melee_hatchet'}
local slots={'melee','melee_secondary','melee_tertiary','melee_quaternary','melee_quinary'}
local identity={characterId='john',sessionId='session',epoch='epoch'}
local snapshot={characterId='john',equipment={},expected={}}
local entities={}
function joaat(s) return s end
function PlayerPedId() return 10 end
function DoesEntityExist(e) return e==10 or entities[e]~=nil end
function IsEntityDead() return false end
function HasPedGotWeapon(_,model)
 for _,m in pairs(entities) do if m==model then return true end end; return false
end
function GetCurrentPedWeapon(_,_,point)
 local model=entities[100+point]; return model~=nil,model
end
function GetCurrentPedWeaponEntityIndex(_,point) return entities[100+point] and 100+point or 0 end
function GetGameTimer() return 0 end
function Wait() error('unexpected settlement wait') end
for _,name in ipairs({'SetPedAmmo','SetPedAmmoByType','SetAmmoInClip','SetCurrentPedWeapon'}) do
 _G[name]=function() error('forbidden mutation '..name) end
end
local owners={}
for n,id in ipairs(ids) do
 local def=WeaponDefinitionCatalog.weapons[id]
 local profile=assert(WeaponNativeMeleeCatalog.Resolve(def))
 assert(profile.nativeGrantAmount==(n>=4 and 1 or 0))
 local metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='MELEE-'..n}))
 assert(metadata.weaponDefinitionId==id and metadata.ammo==nil and metadata.maintenance==nil)
 local row={id=n,revision=0,itemName=def.itemName,metadata=metadata}
 snapshot.equipment[slots[n]]=row
 snapshot.expected['weapon_'..slots[n]]={itemId=n,revision=0}
 function GiveWeaponToPed(ped,model,amount,...)
  assert(ped==10 and model==profile.nativeWeaponName and amount==profile.nativeGrantAmount)
  entities[100+n]=model
 end
 function RemoveWeaponFromPed(_,model)
  for e,m in pairs(entities) do if m==model then entities[e]=nil end end
 end
 owners[n]=assert(WeaponNativeKnifeOwner.Scoped(10,identity,function() return true end,def))
 assert(owners[n].Create(row))
 local invalid=copy(def); invalid.nativeGrantAmount=9
 assert(not WeaponNativeMeleeCatalog.Resolve(invalid))
 assert(not WeaponNativeKnifeOwner.Scoped(10,identity,function() return true end,invalid))
end
local projected=assert(WeaponNativeMeleeCatalog.Project(snapshot,WeaponDefinitionCatalog,identity))
assert(#projected.items==5)
projected.items[1].row.metadata.flags.disabled=true
assert(not snapshot.equipment.melee.metadata.flags.disabled)
for n,owner in ipairs(owners) do
 assert(owner.Release())
 for remaining=n+1,5 do assert(entities[100+remaining]) end
end
local bad=copy(snapshot); bad.expected.weapon={itemId=1,revision=0}
assert(not WeaponNativeMeleeCatalog.Project(bad,WeaponDefinitionCatalog,identity))
bad=copy(snapshot); bad.expected.weapon_melee.revision=1
assert(not WeaponNativeMeleeCatalog.Project(bad,WeaponDefinitionCatalog,identity))
bad=copy(snapshot); bad.characterId='jane'
assert(not WeaponNativeMeleeCatalog.Project(bad,WeaponDefinitionCatalog,identity))
bad=copy(snapshot); bad.equipment.melee_secondary=copy(bad.equipment.melee)
bad.equipment.melee_secondary.id=2
assert(not WeaponNativeMeleeCatalog.Project(bad,WeaponDefinitionCatalog,identity))
for id,def in pairs(WeaponDefinitionCatalog.weapons) do
 local admitted=false; for _,allowed in ipairs(ids) do if id==allowed then admitted=true end end
 if not admitted then assert(not WeaponNativeMeleeCatalog.Resolve(def)) end
end
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('shared/native_melee_catalog.lua',1,true),'canonical melee policy must be manifest loaded')
assert(not WeaponNativeMeleeCatalog.Enabled(),'manifest loading alone cannot enable melee gameplay')
print('staged five-model melee policy: canonical quantities, isolated entities, snapshot identity/revision/duplicate veto PASS')
