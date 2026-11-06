-- Canonical purchase authority belongs to Weapons; no issuance developer flag.
local tickets, sequence = {}, 0
local function Copy(v)
    if type(v) ~= 'table' then return v end
    local out={};for k,x in pairs(v) do out[k]=Copy(x) end;return out
end
local function Equal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Refuse()
    return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID, 'Canonical checkout authority required')
end
local function Current(ticket,order)
    if not ticket or GetGameTimer() >= ticket.deadline or not Equal(ticket.order,order)
        or not IssuanceService.PurchaseAvailable() then return false end
    local c=ticket.context
    if not CoreAdapter.IsSessionCurrent(c.targetSource,c.sessionId,c.characterId)
        or (WeaponNativeEquipmentBindings and WeaponNativeEquipmentBindings.IsStopping(c.targetSource)) then return false end
    local state=WeaponCharacterAmmoDispatcher.Status(c.targetSource)
    return state and state.phase=='active' and not state.busy and state.identity
        and state.identity.characterId==c.characterId and state.identity.sessionId==c.sessionId
        and state.identity.epoch==c.epoch or false
end
exports('GetShopWeaponDefinition',function(itemName)
    if GetInvokingResource()~='feather-shops' then return Refuse() end
    local definition=IssuanceService.PurchaseDefinition(itemName)
    if not definition then return Refuse() end
    return WeaponResult.Ok({definitionId=definition.id,itemName=definition.itemName})
end)
exports('PrepareShopCheckoutWeapon',function(source,order)
    if GetInvokingResource()~='feather-inventory' or type(order)~='table'
        or order.source_resource~='feather-shops' or order.quantity~=1 then return Refuse() end
    local session=CoreAdapter.ResolveSession(source)
    if not session.ok or session.value.characterId~=order.buyer_character_id
        or session.value.accountId~=order.buyer_account_id or session.value.sessionId~=order.buyer_session_id then return Refuse() end
    local state=WeaponCharacterAmmoDispatcher.Status(source)
    if not state or not state.identity then return Refuse() end
    local context={targetSource=source,characterId=session.value.characterId,
        sessionId=session.value.sessionId,epoch=state.identity.epoch}
    local prepared=IssuanceService.PreparePurchase(context,{orderId=order.order_id,
        itemName=order.item_name,currency=order.currency_code,total=order.total_amount})
    if not prepared.ok then return prepared end
    sequence=sequence+1
    local id=order.order_id..':'..GetGameTimer()..':'..sequence
    tickets[id]={order=Copy(order),context=context,spec=Copy(prepared.value),deadline=GetGameTimer()+120000}
    return WeaponResult.Ok({ticket=id,weapon=prepared.value})
end)
exports('IsShopCheckoutWeaponCurrent',function(id,order)
    return GetInvokingResource()=='feather-inventory' and Current(tickets[id],order)==true
end)
exports('StageShopCheckoutProvenance',function(query,id,order,inventoryId,itemId)
    if GetInvokingResource()~='feather-inventory' or not Current(tickets[id],order) then return Refuse() end
    return WeaponProvenanceService.StagePurchase(query,order,tickets[id].spec,inventoryId,itemId)
end)
exports('ReleaseShopCheckoutWeapon',function(id)
    if GetInvokingResource()~='feather-inventory' then return false end
    tickets[id]=nil;return true
end)
CreateThread(function()
    while true do
        Wait(30000)
        for id,ticket in pairs(tickets) do if GetGameTimer()>=ticket.deadline then tickets[id]=nil end end
    end
end)
