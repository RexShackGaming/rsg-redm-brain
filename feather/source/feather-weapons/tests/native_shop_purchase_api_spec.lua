-- Real canonical metadata/provenance services with modeled engine authority.
dofile('tests/native_purchase_metadata_spec.lua')
local registered,caller,clock={},'untrusted',1000
exports=function(name,fn) registered[name]=fn end
GetInvokingResource=function() return caller end
GetGameTimer=function() return clock end
CreateThread=function() end
local character,session,epoch='buyer','session','epoch'
CoreAdapter.ResolveSession=function() return WeaponResult.Ok({characterId=character,accountId='account',sessionId=session}) end
CoreAdapter.IsSessionCurrent=function(source,sid,cid) return source==3 and sid==session and cid==character end
WeaponCharacterAmmoDispatcher.Status=function() return {phase='active',identity={characterId=character,sessionId=session,epoch=epoch}} end
dofile('server/services/shop_purchases.lua')
local originalResourceState=GetResourceState
GetResourceState=function() return 'missing' end
assert(IssuanceService.PurchaseAvailable(),'normal checkout does not require an installed developer proof resource')
GetResourceState=function() return 'started' end
assert(not IssuanceService.PurchaseAvailable(),'an active competing proof host remains refused')
GetResourceState=originalResourceState
local order={order_id='00000000-0000-4000-8000-000000000001',source_resource='feather-shops',
    buyer_character_id='buyer',buyer_account_id='account',buyer_session_id='session',quantity=1,
    item_name='weapon_revolver_cattleman',currency_code='dollars',total_amount=12500}
assert(not registered.GetShopWeaponDefinition(order.item_name).ok)
assert(not registered.PrepareShopCheckoutWeapon(3,order).ok)
caller='feather-shops';assert(registered.GetShopWeaponDefinition(order.item_name).ok)
assert(not registered.PrepareShopCheckoutWeapon(3,order).ok)
caller='feather-inventory'
local prepared=registered.PrepareShopCheckoutWeapon(3,order);assert(prepared.ok)
local ticket,serial=prepared.value.ticket,prepared.value.weapon.metadata.serialNumber
assert(registered.IsShopCheckoutWeaponCurrent(ticket,order))
prepared.value.weapon.metadata.serialNumber='forged-returned-copy'
local writes=0
local query=setmetatable({__cfx_functionReference='transaction-query'},{__call=function(_,sql,p)
    writes=writes+1;assert(p[2]==serial and p[2]~='forged-returned-copy')
    return {insertId=1}
end})
assert(registered.StageShopCheckoutProvenance(query,ticket,order,2,101).ok and writes==1)
caller='untrusted';assert(not registered.ReleaseShopCheckoutWeapon(ticket))
assert(not registered.StageShopCheckoutProvenance(query,ticket,order,2,101).ok and writes==1)
caller='feather-inventory'
order.total_amount=1
assert(not registered.IsShopCheckoutWeaponCurrent(ticket,order))
assert(not registered.StageShopCheckoutProvenance(query,ticket,order,2,101).ok and writes==1)
order.total_amount=12500
epoch='replacement';assert(not registered.IsShopCheckoutWeaponCurrent(ticket,order));epoch='epoch'
session='replacement';assert(not registered.IsShopCheckoutWeaponCurrent(ticket,order));session='session'
clock=122000;assert(not registered.IsShopCheckoutWeaponCurrent(ticket,order))
assert(registered.ReleaseShopCheckoutWeapon(ticket))
assert(not registered.IsShopCheckoutWeaponCurrent(ticket,order))
character='other';assert(not registered.PrepareShopCheckoutWeapon(3,order).ok)
assert(not IssuanceService.NativeAvailable(),'normal checkout does not enable developer grants')
print('Native shop API PASS (caller-bound ticket, canonical copy, order/session/epoch, expiry, release, CFX query; no developer grants)')
