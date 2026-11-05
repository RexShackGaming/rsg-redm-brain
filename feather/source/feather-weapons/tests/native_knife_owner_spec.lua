Config={AmmunitionPools={enabled=false}}
for _,path in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_knife.lua','client/native_knife_owner.lua'}) do dofile(path) end
local def=WeaponDefinitionCatalog.weapons.melee_knife
local row={id=901,revision=0,itemName='weapon_melee_knife',metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='FW-KNIFE'}))}
local identity={characterId='john',sessionId='s',epoch='e'}
local function setup(change)
 local exists,world,entities,grants,removes=false,true,{50},0,0
 local owner
 local api={current=function() return world end,present=function() return exists end,
  observe=function() return entities end,grant=function() grants=grants+1; exists=true; return true end,
  remove=function(entity) assert(entity==50); removes=removes+1; exists=false; return true end}
 local control={world=function(v) world=v end,entities=function(v) entities=v end,exists=function(v) exists=v end,
  counts=function() return grants,removes end}
 owner=assert(WeaponNativeKnifeOwner.New(api,def,identity))
 if change then change(api,control,owner) end
 return owner,control
end
local owner,c=setup()
assert(owner.Status().phase=='idle' and c.counts()==0)
local record=assert(owner.Create(row)); assert(record.entity==50 and owner.Status().itemId==901)
record.identity.epoch='foreign'; assert(owner.Status().identity.epoch=='e')
assert(not owner.Create(row)); assert(owner.Release() and owner.Release())
local grants,removes=c.counts(); assert(grants==1 and removes==1)
for _,mutation in ipairs({
 function(api,c) c.exists(true) end,
 function(api,c) c.world(false) end,
 function(api,c) api.present=function() error('read failed') end end,
 function(api,c) api.grant=function() error('unknown grant outcome') end end,
 function(api,c) c.entities({}) end,
 function(api,c) c.entities({50,51}) end,
 function(api,c) c.entities({[1]=50,foreign=51}) end,
 function(api,c) c.entities({0/0}) end,
}) do
 local o,control=setup(mutation)
 assert(not o.Create(row)); assert(not o.Release()); local _,removed=control.counts(); assert(removed==0)
end
for _,mutation in ipairs({function(control) control.entities({51}) end,
 function(control) control.entities({50,51}) end,function(control) control.world(false) end}) do
 local o,control=setup(); assert(o.Create(row)); mutation(control)
 assert(not o.Release() and o.Status().phase=='retained'); local _,removed=control.counts(); assert(removed==0)
end
local o=setup(function(api,_,pending)
 api.grant=function() assert(not pending.Create(row) and not pending.Release()); return false end
end)
assert(not o.Create(row)); assert(not o.Create(row) and o.Status().phase=='retained')
local wrong={id=row.id,revision=0,itemName='weapon_melee_machete',metadata=row.metadata}
local untouched,control=setup(); assert(not untouched.Create(wrong) and control.counts()==0)
print('native knife owner PASS (inert accepted grant port, exact copy, reserved exceptions, foreign/replacement cleanup veto, no retry/adoption)')
local has,point,object,issued,deleted=false,4,70,0,0
GetGameTimer=function() return 100 end
Wait=function() error('immediate settled mock must not wait') end
joaat=function(name) return name end
PlayerPedId=function() return 7 end
DoesEntityExist=function(entity) return entity==7 or entity==70 or entity==71 end
IsEntityDead=function() return false end
HasPedGotWeapon=function(_,name) assert(name=='WEAPON_MELEE_KNIFE'); return has end
GetCurrentPedWeapon=function(_,_,p) return has and p==point,'WEAPON_MELEE_KNIFE' end
GetCurrentPedWeaponEntityIndex=function(_,p) return p==point and object or 0 end
GiveWeaponToPed=function(ped,name,quantity,equip,hidden,attach)
 assert(ped==7 and name=='WEAPON_MELEE_KNIFE' and quantity==0 and equip==false and hidden==true and attach==0)
 has=true; issued=issued+1
end
RemoveWeaponFromPed=function(ped,name,all,reason)
 assert(ped==7 and name=='WEAPON_MELEE_KNIFE' and all==true and reason=='REMOVE_REASON_CLIENT_PURGED')
 has=false; deleted=deleted+1
end
for _,name in ipairs({'SetPedAmmo','SetPedAmmoByType','SetAmmoInClip','SetWeaponDegradation','SetCurrentPedWeapon'}) do
 _G[name]=function() error('forbidden firearm/global state mutation '..name) end
end
local scoped=assert(WeaponNativeKnifeOwner.Scoped(7,identity,function() return true end))
assert(scoped.Create(row).entity==70 and issued==1)
point=0 -- moving the exact object to the hand does not change ownership
assert(scoped.Release() and deleted==1)
local replacement=assert(WeaponNativeKnifeOwner.Scoped(7,identity,function() return true end))
point=4; assert(replacement.Create(row)); object=71
assert(not replacement.Release() and deleted==1,'same-model replacement never adopted or wiped')
local f=assert(io.open('fxmanifest.lua','r')); local manifest=f:read('*a'); f:close()
assert(manifest:find('client/native_knife_owner.lua',1,true),'concrete companion factory must be available to native owner')
print('concrete knife native-call port PASS under mocks (no ammo/maintenance/select writes, draw movement and replacement refusal)')
has=false; object=70
local frames=0
GetGameTimer=function() return frames*16 end
Wait=function() frames=frames+1 end
GetCurrentPedWeapon=function(_,_,p) return has and frames>=2 and p==4,'WEAPON_MELEE_KNIFE' end
local delayed=assert(WeaponNativeKnifeOwner.Scoped(7,identity,function() return true end))
assert(delayed.Create(row).entity==70 and frames==2,'bounded settlement follows existing frame-wait pattern')
assert(delayed.Release())
has=false; frames=0
GetCurrentPedWeapon=function() return false,0 end
local missing=assert(WeaponNativeKnifeOwner.Scoped(7,identity,function() return true end))
assert(not missing.Create(row) and missing.Status().phase=='retained' and frames<=120)
assert(not missing.Release(),'timeout never authorizes broad cleanup')
has=false; frames=0
local changed=assert(WeaponNativeKnifeOwner.Scoped(7,identity,function() return frames==0 end))
assert(not changed.Create(row) and frames==1,'session checked at each settlement yield')
print('knife bounded settlement PASS (delayed object, deadline/no model wipe, context invalidation)')
