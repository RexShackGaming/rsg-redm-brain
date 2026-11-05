dofile('tests/native_utility_item_spec.lua')
for _,p in ipairs({'shared/definitions/ammunition.lua','shared/character_ammunition.lua',
 'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/character_ammunition_item.lua','shared/character_ammunition_materialization.lua','shared/character_ammunition_loadout_lease.lua',
 'shared/character_ammunition_runtime.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
local gate,changed,reinforcedGate=1,false,0
GetConvarInt=function(name) return name=='feather_native_utility' and gate or name=='feather_native_lasso_reinforced' and reinforcedGate or 0 end
GetGameTimer=function() return 1 end; AddEventHandler=function() end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='john',sessionId='s'}} end,IsSessionCurrent=function() return true end}
local row={id=200,revision=0,itemName='weapon_lasso',metadata={schemaVersion=2,weaponDefinitionId='utility_lasso',
 serialNumber='L',condition=100,quality=100,flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}
local inventory={GetCharacterFirearmRuntimeSnapshot=function(_,context,limits)
 local pools={}; for id in pairs(limits) do pools[id]=0 end
 local r=copy(row); if changed then r.metadata.serialNumber='different' end
 local secondary=r.metadata.weaponDefinitionId=='utility_lasso_reinforced'
 return {ok=true,value={characterId='john',revision=16,pools=pools,equipment={},utilityEquipment={characterId='john',
 expected={[secondary and 'weapon_utility_secondary' or 'weapon_utility']={itemId=r.id,revision=0}},
 equipment={[secondary and 'utility_secondary' or 'utility']=r}}}}
end}
exports=setmetatable({['feather-inventory']=inventory},{__call=function() end})
dofile('server/services/character_ammunition_runtime.lua')
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local S=WeaponCharacterAmmoService
local opened=S.OpenLoadout(4,WeaponDefinitionCatalog,registry.limits)
assert(opened.ok,opened.error and opened.error.code)
local bundle=opened.value
assert(bundle.utility.row.id==200 and S.IsNativeItemBound(200))
assert(S.ConfirmRestore(4,bundle.runtime).ok)
local recovery=assert(S.ReadRecoveryStatus(4))
assert(recovery.itemRevisions[1].itemId==200 and recovery.ledgerRevision==16)
bundle.utility.row.metadata.serialNumber='caller mutation'
assert(S.ValidateLoadout(4).ok,'bundle mutation cannot change private server lease')
changed=true; assert(not S.ValidateLoadout(4).ok and S.IsNativeItemBound(200),
 'changed lasso freezes validation without dropping its movement hold')
S.Revoke(4,'s'); assert(not S.IsNativeItemBound(200))
gate=0; assert(not S.OpenLoadout(4,WeaponDefinitionCatalog,registry.limits).ok,
 'unsolicited utility snapshot is refused with gate disabled')
dofile('shared/native_lasso_policy.lua')
gate=1; reinforcedGate=1; changed=false; Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true
row.id=201; row.itemName='weapon_lasso_reinforced'; row.metadata.weaponDefinitionId='utility_lasso_reinforced'
local reinforced=assert(S.OpenLoadout(6,WeaponDefinitionCatalog,registry.limits).value)
assert(reinforced.utility.equipmentSlot=='weapon_utility_secondary' and reinforced.utility.row.id==201 and S.IsNativeItemBound(201))
assert(S.ConfirmRestore(6,reinforced.runtime).ok)
reinforcedGate=0
assert(not S.ValidateLoadout(6).ok and S.IsNativeItemBound(201),'gate change cannot silently drop reinforced hold')
print('staged utility server binding PASS: actual loadout/lease/recovery projection, stale content retains hold, disabled gate refusal; mocked Inventory')
