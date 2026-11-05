Config={AmmunitionPools={enabled=false},DevMode=true,NativeAlphaRuntime=true}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_melee_catalog.lua',
 'shared/native_knife.lua','client/character_maintenance_native.lua','client/native_knife_owner.lua'}) do dofile(p) end
local def=WeaponDefinitionCatalog.weapons.melee_hatchet
local row={id=161,revision=0,itemName=def.itemName,metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='H'}))}
local id={characterId='john',sessionId='s',epoch='e'}
local has,entityExists,visible,world,readGuid,readHash,removed,reads,dropWorld,readSuccess,removeSuccess
joaat=function(v) return v==def.nativeWeaponName and 42 or v end
PlayerPedId=function() return 7 end
DoesEntityExist=function(e) return e==7 or (e==70 and entityExists) end
HasPedGotWeapon=function() return has end
GetCurrentPedWeapon=function(_,_,p) return visible and p==6,42 end
GetCurrentPedWeaponEntityIndex=function(_,p) return p==6 and visible and 70 or 0 end
IsEntityDead=function() return false end
GetGameTimer=function() return 0 end
Wait=function() error('hidden inventory path must not spin or select a model') end
GiveWeaponToPed=function() has=true; entityExists=true; visible=true end
RemoveWeaponFromPed=function() error('no model-only removal on hidden copy') end
WeaponCharacterAmmoCreationNative={
 DecodeDiagnosticGuid=function() return {scriptSlotWords=readGuid} end,
 DecodeEquippedChild=function(_,result) if result then return {itemHash=readHash} end end}
Citizen={InvokeNative=function(native,inventory,input,output)
 if native==0x6929E22158E52265 then return true end
 assert(inventory==1)
 if native==0x9700E8EFC4AB9089 then reads=reads+1; return readSuccess end
 if native==0x3E4E811480B3AE79 then
  assert(type(input)=='string' and #input==104 and output==1)
  removed=removed+1; if removeSuccess then has=false end
  if dropWorld then world=false end
  return removeSuccess
 end
 error('unexpected native')
end}
local function run(mode)
 has=false; entityExists=false; visible=false; world=true
 readGuid={1,2,3,4}; readHash=42; removed=0; reads=0; dropWorld=false; readSuccess=true; removeSuccess=true
 local owner=assert(WeaponNativeKnifeOwner.Scoped(7,id,function() return world end,def))
 assert(owner.Create(row) and owner.Status().guidOwnershipCaptured)
 visible=false; entityExists=false
 if mode=='foreign_guid' then readGuid={1,2,3,5} end
 if mode=='wrong_model' then readHash=43 end
 if mode=='live_entity' then entityExists=true end
 if mode=='world_lost' then world=false end
 if mode=='read_failed' then readSuccess=false end
 if mode=='remove_failed' then removeSuccess=false end
 if mode=='post_write_world_lost' then dropWorld=true end
 local ok=owner.Release()
 if mode=='owned_hidden' then
  assert(ok and removed==1 and reads==1 and owner.Status().reason=='melee_captured_inventory_removed')
 else
  assert(not ok and owner.Status().phase=='retained')
  assert(removed==((mode=='remove_failed' or mode=='post_write_world_lost') and 1 or 0))
 end
 local count=removed; owner.Release(); owner.Status(); assert(removed==count,'no retry from retained or released')
end
for _,mode in ipairs({'owned_hidden','foreign_guid','wrong_model','live_entity','world_lost','read_failed',
 'remove_failed','post_write_world_lost'}) do run(mode) end
print('hidden melee captured-inventory cleanup PASS: exact independent GUID+model read, targeted native entry only, no replacement/entity assumption, uncertainty retained')
