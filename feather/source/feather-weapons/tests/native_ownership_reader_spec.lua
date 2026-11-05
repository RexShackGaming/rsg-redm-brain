Config={Inventory={requiredContract=4}}
dofile('server/adapters/character_ammunition_inventory.lua')
WeaponDefinitionCatalog={weapons={repeater_carbine={itemName='weapon_repeater_carbine'}}}
local definitions={{id=39,name='weapon_repeater_carbine'}}
local writes=0
local function ref(fn) return setmetatable({__cfx_functionReference='mock'},{__call=function(_,...) return fn(...) end}) end
local api={GetCapabilities=ref(function() return {ok=true,value={contractVersion=4,characterIdentity={uuid=true,mode='uuid'}}} end),
 Items={GetDefinitions=ref(function() return {ok=true,value=definitions} end)},
 Instances={GetInstance=ref(function(id) return {ok=true,value={id=id,inventoryId=8,revision=12,
 definition={id=39,name='weapon_repeater_carbine'},metadata={weaponDefinitionId='repeater_carbine',serialNumber='S'}}} end)},
 GetCharacterInventory=ref(function(cid) return {ok=true,value={id=2,characterId=cid}} end),
 CreateInstance=function() writes=writes+1 end}
local reader=WeaponNativeOwnershipInventory.New(ref(function() return api end))
assert(not reader.IsReady() and reader.ResolveWeaponDefinitionId(39)==nil)
assert(reader.Install() and reader.IsReady() and reader.ResolveWeaponDefinitionId('39')=='repeater_carbine')
assert(reader.GetInstance({},135).value.metadataRevision==12 and reader.GetCharacterInventory({},'Jane').value.id==2)
assert(reader.DestroyInstance==nil and reader.CreateInstance==nil and reader.SetEquippedForCharacter==nil and writes==0)
definitions[#definitions+1]={id=40,name='weapon_repeater_carbine'}
assert(not reader.Install() and not reader.IsReady() and reader.ResolveWeaponDefinitionId(39)==nil,'failed reinstall clears stale index')
definitions={}
assert(not reader.Install(),'missing catalog definition fails startup')
print('Native ownership reader PASS (read-only CFX surface, trusted definition map, missing/duplicate failclosed, no legacy mutation methods)')
