Config={}
dofile('shared/definitions/ammunition.lua')
dofile('shared/definitions/attachments.lua')
dofile('shared/definitions/weapons.lua')
dofile('client/character_maintenance_native.lua')
local calls=0
local result=assert(WeaponNativeAttachmentSlots.Catalog(WeaponDefinitionCatalog,function(weapon,component)
 assert(weapon:match('^WEAPON_') and component:match('^COMPONENT_'))
 calls=calls+1
 return {category=123,slots={{slot=10,wideSightCompatible=false},{slot=11,wideSightCompatible=true}}}
end))
assert(calls>1 and #result.items==calls and result.noNativeWrites and result.noSQLWrites and result.noAmmoWrites)
local previous=''
for _,row in ipairs(result.items) do
 local key=row.weaponId..':'..row.attachmentId
 assert(previous<key and row.uniqueCompatibleSlot and row.compatibleSlots[1]==11); previous=key
end
local catalog={weapons={a={nativeWeaponName='WEAPON_A',attachmentSlots={sight={'sight'}}}},
 attachments={sight={slot='sight',nativeComponentName='COMPONENT_A'}}}
result=assert(WeaponNativeAttachmentSlots.Catalog(catalog,function() return nil,'not_available' end))
assert(result.items[1].error=='not_available' and not result.items[1].uniqueCompatibleSlot)
result=assert(WeaponNativeAttachmentSlots.Catalog(catalog,function()
 return {category=1,slots={{slot=10,wideSightCompatible=true},{slot=11,wideSightCompatible=true}}}
end))
assert(not result.items[1].uniqueCompatibleSlot,'ambiguous discovery never selects a slot')
catalog.attachments.sight=nil
assert(not WeaponNativeAttachmentSlots.Catalog(catalog,function() error('invalid catalog must not reach natives') end))
catalog.attachments.sight={slot='sight',nativeComponentName='COMPONENT_A'}
catalog.weapons.a.attachmentSlots.sight={}
for i=1,65 do catalog.weapons.a.attachmentSlots.sight[i]='sight' end
assert(not WeaponNativeAttachmentSlots.Catalog(catalog,function() error('oversized batch must not reach natives') end))
-- Actual startup command: known catalog names only; invalid arguments and dev
-- off never reach natives. Native mock allows ONLY read-category operations.
Config.DevMode=true; Config.NativeAlphaRuntime=true
local commands,observed,reads={},nil,0
CreateThread=function() end
RegisterCommand=function(name,fn) commands[name]=fn end
json={encode=function(value) observed=value; return 'diagnostic' end}
joaat=function(name) assert(type(name)=='string'); return name end
Citizen={InvokeNative=function(hash,name)
 assert(hash==0xFE90ABBCBFDC13B2 and name:match('^WEAPON_'),'discovery must not invoke write native')
 reads=reads+1; return false -- unsupported model error is isolated per entry
end}
dofile('client/character_ammunition_startup.lua')
commands.weaponNativeComponentSlotStatus(0,{'catalog'})
assert(observed and #observed.items==calls and reads==calls)
commands.weaponNativeComponentSlotStatus(0,{'WEAPON_INJECTED'})
assert(reads==calls)
Config.DevMode=false; commands.weaponNativeComponentSlotStatus(0,{'catalog'}); assert(reads==calls)
print('Catalog slot discovery PASS (trusted definitions, bounded sorted batch, failure isolation, ambiguity diagnostic only)')
