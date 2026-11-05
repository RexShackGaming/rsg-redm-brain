-- Inventory-only UI bridge. Server owns options, equipment policy and writes.
local pending,sequence=nil,0
local function failure(code) return {ok=false,error={code=code},message=code} end
local function current()
    if Config.NativeAlphaRuntime~=true or Config.CharacterAmmunitionEnabled~=true
        or Config.CharacterAmmoTransportEnabled~=true then return nil end
    local owner=WeaponCharacterAmmoActiveOwner
    local state=owner and owner.Status()
    local runtime=state and state.bootstrap and state.bootstrap.runtime
    local ammo=runtime and runtime.session and runtime.session.ammo
    local world=WeaponCharacterAmmoWorldContext.Read()
    local value=world and world.ok and world.value
    local baseline=ammo and ammo.baseline
    if not runtime or runtime.phase~='active' or runtime.runtimeBusy or runtime.quiescing or runtime.receiving
        or not ammo or ammo.phase~='active' or ammo.pending or ammo.closing or not baseline or not value
        or value.characterId~=baseline.characterId or value.sessionId~=baseline.sessionId or value.ped~=ammo.ped then return nil end
    return {characterId=baseline.characterId,sessionId=baseline.sessionId,epoch=baseline.epoch}
end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId
    and a.sessionId==b.sessionId and a.epoch==b.epoch end
RegisterNetEvent('feather-weapons:client:native-equipment-result',function(id,scope,result)
    if source~=65535 or not pending or id~=pending.id or not same(scope,pending.scope) or type(result)~='table' then return end
    pending.result=result
end)
local function request(kind,itemId,action,slot,scope,attachmentId)
    if GetInvokingResource()~='feather-inventory' then return failure('equipment_caller_denied') end
    if pending then return failure('equipment_action_in_flight') end
    if type(itemId)~='number' or itemId<1 or itemId%1~=0 or itemId==math.huge then return failure('invalid_equipment_item') end
    local bound=current()
    if not bound then return failure('native_equipment_owner_not_ready') end
    if kind~='options' and not same(scope,bound) then return failure('equipment_panel_expired_reopen') end
    if kind=='attachment-change' and action~='install' and action~='remove' then return failure('invalid_attachment_action') end
    if attachmentId~=nil and (type(attachmentId)~='string' or #attachmentId<1 or #attachmentId>100) then return failure('invalid_attachment_id') end
    sequence=sequence+1
    local reservation={id=('equipment-ui:%s:%s'):format(GetGameTimer(),sequence),scope=bound}
    pending=reservation
    local called,result=pcall(function()
        TriggerServerEvent('feather-weapons:server:native-equipment-ui',reservation.id,kind,
            {itemId=itemId,action=action,slot=slot,scope=bound,attachmentId=attachmentId})
        local started=GetGameTimer()
        while (GetGameTimer()-started)%4294967296<50000 do
            local world=WeaponCharacterAmmoWorldContext.Read()
            local value=world and world.ok and world.value
            if not value or value.characterId~=bound.characterId or value.sessionId~=bound.sessionId then
                return failure('equipment_lifecycle_changed_no_retry')
            end
            if reservation.result then
                local answer=reservation.result
                if answer.ok then
                    local now=current()
                    local expected=kind=='options' and bound or answer.value and answer.value.identity
                    if not same(now,expected) then return failure('equipment_restore_not_settled_no_retry') end
                end
                return answer
            end
            Wait(50)
        end
        return failure('equipment_ack_timeout_no_retry')
    end)
    if pending==reservation then pending=nil end
    return called and result or failure('equipment_request_failed_no_retry')
end
exports('GetNativeEquipmentControls',function(itemId) return request('options',itemId) end)
exports('ChangeNativeEquipment',function(itemId,action,slot,scope) return request('change',itemId,action,slot,scope) end)
exports('ChangeNativeAttachment',function(itemId,action,scope,attachmentId) return request('attachment-change',itemId,action,nil,scope,attachmentId) end)
exports('RepairNativeEquipment',function(itemId,scope) return request('repair-change',itemId,'repair',nil,scope) end)
