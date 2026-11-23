Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,AmmunitionPools={enabled=false}}
GetConvar=function(n,d) return n=='feather_throwable_quantities' and '1' or d end
GetConvarInt=function(n,d) return (n=='feather_throwable_quantities' or n=='feather_throwing_knife_quantities'
 or arg and arg[2]=='poison-fixture' and n=='feather_poison_knives') and 1 or d end
for _,p in ipairs({'shared/throwable_mode.lua','shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','client/character_ammunition_native.lua',
 'client/native_throwable_pickup_permissions.lua','client/throwable_quantity_owner.lua','client/native_throwable_adapter.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local identity={characterId='jane',sessionId='s',epoch='e'}
local native,entries,permissions={},{},{}
for _,name in pairs(registry.names) do native[name]=0 end
local lastModel,grants,removed,writes=42,0,0,0
joaat=function(n) return n=='WEAPON_THROWN_TOMAHAWK' and 42 or n=='WEAPON_THROWN_THROWING_KNIVES' and 43 or n end
PlayerPedId=function() return 7 end;DoesEntityExist=function() return true end
HasPedGotWeapon=function(_,model) return entries[model]==true end
GetPedAmmoByType=function(_,ammo) return native[ammo] end
SetPedAmmoByType=function() writes=writes+1;error('carrier cannot restore ammunition') end
IsEntityDead=function() return false end
GetCurrentPedWeapon=function() return false,0 end;GetCurrentPedWeaponEntityIndex=function() return 0 end
GiveWeaponToPed=function(_,model,n) assert(n==0 and not entries[model]);grants=grants+1;entries[model]=true end
SetLocalPlayerPermittedToCollectPickupsWithModel=function(model,allowed) permissions[model]=allowed end
dofile('client/character_maintenance_native.lua')
WeaponCharacterAmmoCreationNative={DecodeDiagnosticGuid=function() return {scriptSlotWords={lastModel,2,3,4}} end,
 DecodeEquippedChild=function(_,result) return result and {itemHash=lastModel} or nil end}
Citizen={InvokeNative=function(hash,a,b,c,d)
 if hash==0xF70825EB340E7D15 then assert(a==43);return 10043 end
 if hash==0x886DFD3E185C8A89 then
  if c==42 or c==43 then lastModel=c;return entries[c]==true and d=='SLOTID_WEAPON_0' end
  return true
 end
 if hash==0x9700E8EFC4AB9089 then return entries[lastModel]==true end
 if hash==0x3E4E811480B3AE79 then assert(entries[lastModel]);entries[lastModel]=nil;removed=removed+1;return true end
 if hash==0xB6CFEC32E3742779 then assert(a==7 and c==native[b]);native[b]=native[b]-c;return end
 error('unexpected native '..tostring(hash))
end}
local baseline={contract=3,kind='throwable_quantity',characterId='jane',identity=identity,revision=1,pools={}}
for id in pairs(registry.limits) do baseline.pools[id]=0 end
baseline.pools.ammo_tomahawk_regular=3;baseline.pools.ammo_throwing_knives_regular=2
local sealed
local root=assert(WeaponNativeThrowableAdapter.Scoped(7,identity,function() return true end,function() return sealed end,WeaponDefinitionCatalog,registry))
if arg and arg[2]=='poison-fixture' then
 return {root=root,baseline=baseline,native=native,entries=entries,permissions=permissions,copy=copy,
  seal=function(v) sealed=v end,counters=function() return grants,removed,writes end}
end
assert(grants==0 and writes==0,'factories cannot grant a carrier before activation')
assert(root.Create(baseline) and grants==2)
assert(native.AMMO_TOMAHAWK==0 and native.AMMO_THROWING_KNIVES==0,'both carriers are zero-ammo')
native.AMMO_TOMAHAWK=3;native.AMMO_THROWING_KNIVES=2 -- modeled parent restore, not adapter grant
assert(root.Observe(baseline))
assert(permissions.w_melee_tomahawk01==false and permissions[10043]==true)
native.AMMO_THROWING_KNIVES=0;entries[43]=nil
local spent=copy(baseline);spent.revision=2;spent.pools.ammo_throwing_knives_regular=0
assert(root.Observe(spent) and native.AMMO_TOMAHAWK==3)
native.AMMO_THROWING_KNIVES=1
local collected=copy(spent);collected.revision=3;collected.pools.ammo_throwing_knives_regular=1
assert(root.AcceptNativePickup(collected) and native.AMMO_THROWING_KNIVES==1 and native.AMMO_TOMAHAWK==3)
assert(grants==3 and writes==0,'only the missing knife carrier is recreated with zero ammo')
local full=copy(collected);full.revision=4;full.pools.ammo_throwing_knives_regular=8
assert(root.PrepareRestore(full));native.AMMO_THROWING_KNIVES=8
assert(permissions[10043]==false and root.Observe(full))
sealed=copy(full);sealed.phase='sealed'
assert(root.Release() and root.Status().phase=='released' and root.Status().knives.phase=='released')
assert(native.AMMO_TOMAHAWK==0 and native.AMMO_THROWING_KNIVES==0 and removed==2 and writes==0)
assert(permissions.w_melee_tomahawk01==true and permissions[10043]==true,'both owned model policies restored independently')
assert(root.Release() and removed==2,'release cannot repeat native removal')
print('PASS concrete dual quantity carriers: separate GUIDs/permissions, zero-ammo materialization, knife throw/rebind without Tomahawk mutation, eight-unit suppression and sealed aggregate cleanup')
