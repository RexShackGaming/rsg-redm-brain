Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_melee_catalog.lua',
 'shared/native_knife.lua','client/character_maintenance_native.lua','client/native_knife_owner.lua'}) do dofile(p) end
local def=WeaponDefinitionCatalog.weapons.melee_hatchet
local row={id=161,revision=0,itemName=def.itemName,metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='H'}))}
local identity={characterId='john',sessionId='s',epoch='e'}
-- Actual owner + existing GUID resolver, with a mutable native representation.
local function run(mode)
 local present,active,removed=false,true,0
 local objects={[50]=true}; local points={[6]={entity=50,hash=def.nativeWeaponName,guid=string.rep('a',32)}}
 local where={}; for p=0,31 do where[#where+1]=p end
 local resolver=WeaponNativeGuidIdentity.New({current=function() return active end,hash=function(v) return v end,
 exists=function(e) return objects[e]==true end,point=function(p)
  local v=points[p]; if not v then return end; return {entity=v.entity,hash=v.hash,guid=v.guid}
 end},where)
 local owner=assert(WeaponNativeKnifeOwner.New({current=function() return active end,present=function() return present end,
 grant=function() present=true; return true end,observe=function()
  local seen,out={},{}; for _,v in pairs(points) do if not seen[v.entity] then out[#out+1]=v.entity; seen[v.entity]=true end end; return out
 end,capture=function(r,id) r.name=def.nativeWeaponName; r.point=6; return resolver.Capture(r,id) end,
 resolve=function(r,id) return resolver.Resolve(r,id,true) end,
 remove=function(e) assert(e==51); removed=removed+1; present=false; return true end},def,identity))
 assert(owner.Create(row))
 objects[50]=mode=='old_live'; objects[51]=true
 points[6]={entity=51,hash=def.nativeWeaponName,guid=string.rep(mode=='foreign' and 'b' or 'a',32)}
 if mode=='ambiguous' then objects[52]=true; points[5]={entity=52,hash=def.nativeWeaponName,guid=string.rep('a',32)} end
 if mode=='world_lost' then active=false end
 local ok=owner.Release()
 if mode=='same_guid' then assert(ok and removed==1 and owner.Status().entity==51)
 else assert(not ok and removed==0 and owner.Status().entity==50) end
end
for _,mode in ipairs({'same_guid','foreign','old_live','ambiguous','world_lost'}) do run(mode) end
print('melee GUID representation change PASS: captured identity at point6, exact GUID-only rematerialization; foreign/live-old/ambiguous/world-loss veto')
