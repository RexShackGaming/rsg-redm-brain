Config={DevMode=false,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
for _,path in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/validation.lua','shared/character_ammunition_item.lua'}) do dofile(path) end
WeaponResult={Ok=function(v) return {ok=true,value=v} end,
 Error=function(c,m) return {ok=false,error={code=c,message=m}} end}
WeaponErrors={AUTHORIZATION_INVALID='denied',ITEM_INVALID='invalid'}
local current,stopping,epoch=true,false,'epoch'
CoreAdapter={NormalizeCharacterId=function(v) return type(v)=='string' and v or nil end,
 IsSessionCurrent=function() return current end}
WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity={characterId='buyer',sessionId='session',epoch=epoch}} end}
WeaponCharacterAmmoInventoryProvider={Status=function() return 'ready' end}
WeaponProvenanceService={IsReady=function() return true end}
WeaponNativeEquipmentBindings={IsStopping=function() return stopping end}
WeaponCharacterAmmoPolicy={Build=function() return {weapons={revolver_cattleman={}}} end}
GetResourceState=function() return 'stopped' end
GetConvarInt=function() return 0 end
exports=function() end
DefinitionRegistry={ValidateAttachmentSet=function() return WeaponResult.Ok(true) end}
dofile('server/services/metadata.lua')
dofile('server/services/issuance.lua')
local context={characterId='buyer',targetSource=3,sessionId='session',epoch='epoch'}
local request={orderId='00000000-0000-4000-8000-000000000001',itemName='weapon_revolver_cattleman',currency='dollars',total=12500}
assert(IssuanceService.PurchaseAvailable() and not IssuanceService.NativeAvailable(),
 'normal purchase metadata does not unlock developer grants')
local first=IssuanceService.PreparePurchase(context,request)
assert(first.ok and first.value.metadata.condition==100 and first.value.metadata.quality==100)
assert(first.value.metadata.provenance.reference==request.orderId and first.value.metadata.provenance.type=='purchase')
assert(first.value.metadata.ammo.ownership=='character' and first.value.metadata.ammo.clip==nil)
local second=IssuanceService.PreparePurchase(context,request)
assert(second.ok and second.value.fingerprint==first.value.fingerprint and second.value.metadata.serialNumber~=first.value.metadata.serialNumber,
 'receipt payload identity excludes generated serial/time; outcome must be committed once by coordinator')
stopping=true;assert(not IssuanceService.PreparePurchase(context,request).ok);stopping=false
current=false;assert(not IssuanceService.PreparePurchase(context,request).ok);current=true
epoch='other';assert(not IssuanceService.PreparePurchase(context,request).ok);epoch='epoch'
request.itemName='weapon_unknown';assert(not IssuanceService.PreparePurchase(context,request).ok)
request.itemName='weapon_revolver_cattleman';request.total=-1;assert(not IssuanceService.PreparePurchase(context,request).ok)
request.total=12500;request.ammo={clip=6};assert(not IssuanceService.PreparePurchase(context,request).ok)
print('Normal purchase metadata PASS (DevMode=false, admitted pristine/serial/provenance data, identity binding, no grants or payment)')

-- The owning provenance service stages its event on the supplied transaction.
local ddl, inserts, savedFact, failedInsert = 0, 0
DB={exec=function() ddl=ddl+1 end,insert=function() error('standalone insert forbidden in checkout') end}
json={encode=function(value) savedFact=value;return 'fact' end}
dofile('server/services/provenance.lua')
assert(WeaponProvenanceService.Start().ok and ddl==1)
local order={order_id=first.value.requestId,source_resource='feather-shops',quantity=1,
 item_name=first.value.itemName,buyer_character_id='buyer'}
local function query(sql,p)
 assert(sql:find('INSERT INTO `feather_weapon_events`',1,true) and p.n==15)
 assert(p[1]==101 and p[2]==first.value.metadata.serialNumber and p[3]==first.value.definitionId)
 assert(p[4]=='issuance' and p[5]=='purchase' and p[6]=='buyer' and p[7]==nil and p[8]=='buyer')
 assert(p[9]==nil and p[10]==2 and p[12]=='feather-shops' and p[13]==order.order_id)
 inserts=inserts+1
 if failedInsert then error('SQL failure') end
 return {insertId=88}
end
local staged=WeaponProvenanceService.StagePurchase(query,order,first.value,2,101)
assert(staged.ok and staged.value.eventId==88 and inserts==1)
assert(savedFact.operation=='purchase' and savedFact.toInventoryId==2)
order.buyer_character_id='other'
assert(not WeaponProvenanceService.StagePurchase(query,order,first.value,2,101).ok and inserts==1)
order.buyer_character_id='buyer';order.quantity=2
assert(not WeaponProvenanceService.StagePurchase(query,order,first.value,2,101).ok and inserts==1)
order.quantity=1;failedInsert=true
assert(not WeaponProvenanceService.StagePurchase(query,order,first.value,2,101).ok and inserts==2)
failedInsert=false
local cfx=setmetatable({__cfx_functionReference='checkout-query'},{__call=function(_,...) return query(...) end})
assert(WeaponProvenanceService.StagePurchase(cfx,order,first.value,2,101).ok and inserts==3)
print('Purchase provenance participant PASS (one SQL call, same-connection callback, NULL binding, buyer/order scope, SQL failure, CFX methods)')
