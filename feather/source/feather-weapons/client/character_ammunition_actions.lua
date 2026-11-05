-- Inventory UI bridge only: existing server transfer/restore protocol owns all
-- economic/native authority. Never retry an ambiguous committed mutation.
WeaponCharacterAmmoActions={}
function WeaponCharacterAmmoActions.New(api)
    local busy,sequence=false,0
    local T={}
    local function failure(code)
        return {ok=false,error={code=code},message=code}
    end
    local function state()
        if api.enabled()~=true then return nil,'native_ammunition_disabled' end
        local owner=api.owner()
        if not owner then return nil,'native_owner_not_started' end
        local status=owner.Status()
        local runtime=status.bootstrap and status.bootstrap.runtime
        local ammo=runtime and runtime.session and runtime.session.ammo
        if status.phase~='started' or not runtime or runtime.phase~='active'
            or runtime.quiescing or runtime.runtimeBusy or runtime.receiving or runtime.fault
            or not ammo or ammo.phase~='active' or ammo.closing or ammo.deathClosing
            or ammo.pending then return nil,'native_ammunition_not_settled' end
        local context=api.context()
        local value=type(context)=='table' and context.ok==true and context.value
        local baseline=ammo.baseline
        if type(value)~='table' or type(baseline)~='table' or value.ped~=ammo.ped
            or value.characterId~=baseline.characterId or value.sessionId~=baseline.sessionId then
            return nil,'native_ammunition_world_changed'
        end
        return {owner=owner,baseline=baseline,ped=ammo.ped}
    end
    function T.Options(itemName)
        if busy then return failure('ammunition_action_in_flight') end
        local ready,why=state()
        if not ready then return failure(why) end
        local compatible
        if itemName~=nil then
            compatible={}
            for id,definition in pairs(api.catalog) do
                if definition.itemName==itemName then compatible[id]=true end
            end
            for _,definition in pairs(api.weapons or {}) do
                if definition.itemName==itemName then
                    for _,id in ipairs(definition.ammunitionTypes or {}) do compatible[id]=true end
                end
            end
        end
        local options={}
        for id,total in pairs(ready.baseline.pools) do
            local definition=api.catalog[id]
            if definition and (not compatible or compatible[id]) then options[#options+1]={id=id,label=definition.label or id,
                itemName=definition.itemName,carried=total} end
        end
        table.sort(options,function(a,b) return a.id<b.id end)
        return {ok=true,value={options=options,revision=ready.baseline.revision,
            characterId=ready.baseline.characterId,sessionId=ready.baseline.sessionId,epoch=ready.baseline.epoch}}
    end
    function T.Transfer(id,quantity,direction,scope)
        if busy then return failure('ammunition_action_in_flight') end
        if type(id)~='string' or not api.catalog[id] or type(quantity)~='number'
            or quantity%1~=0 or quantity<1 or quantity>1000
            or (direction~='load' and direction~='unload') then return failure('invalid_ammunition_action') end
        local ready,why=state()
        if not ready then return failure(why) end
        if type(scope)~='table' or scope.characterId~=ready.baseline.characterId
            or scope.sessionId~=ready.baseline.sessionId or scope.epoch~=ready.baseline.epoch then
            return failure('ammunition_panel_expired_reopen')
        end
        local expectedScope={characterId=scope.characterId,sessionId=scope.sessionId,epoch=scope.epoch}
        if ready.baseline.pools[id]==nil then return failure('unsupported_ammunition') end
        local amount=direction=='load' and quantity or -quantity
        local expected=ready.baseline.pools[id]+amount
        if expected<0 then return failure('insufficient_carried_ammunition') end
        busy=true -- reserve across transport and restore acknowledgement waits
        sequence=sequence+1
        local operationId=api.operation(sequence,ready.baseline)
        local called,result,reason=pcall(function()
            local accepted,refusal=ready.owner.Transfer(id,amount,operationId,expectedScope)
            if not accepted then return failure(refusal or 'ammunition_transfer_refused') end
            local started=api.now()
            while (api.now()-started)%4294967296<25000 do
                if api.enabled()~=true or api.owner()~=ready.owner then
                    return failure('ammunition_transfer_interrupted_no_retry')
                end
                local status=ready.owner.Status()
                local runtime=status.bootstrap and status.bootstrap.runtime
                if not runtime or runtime.phase=='frozen' or runtime.phase=='suspended'
                    or runtime.phase=='sealed' or runtime.phase=='closed' then
                    return failure(runtime and runtime.reason or 'ammunition_transfer_interrupted_no_retry')
                end
                local settled=state()
                if settled then
                    local baseline=settled.baseline
                    if baseline.epoch~=ready.baseline.epoch or settled.ped~=ready.ped then
                        return failure('ammunition_transfer_lifecycle_changed_no_retry')
                    end
                    if baseline.revision==ready.baseline.revision+1 and baseline.pools[id]==expected then
                        return {ok=true,value={revision=baseline.revision,carried=expected,direction=direction,quantity=quantity}}
                    end
                end
                api.wait(50)
            end
            return failure('ammunition_transfer_ack_timeout_no_retry')
        end)
        busy=false
        if not called then return failure('ammunition_action_failed_no_retry') end
        return result or failure(reason or 'ammunition_action_failed_no_retry')
    end
    return T
end

local actions=WeaponCharacterAmmoActions.New({
    enabled=function() return Config.CharacterAmmunitionEnabled==true
        and Config.CharacterAmmoTransportEnabled==true and Config.NativeAlphaRuntime==true end,
    owner=function() return WeaponCharacterAmmoActiveOwner end,
    context=function() return WeaponCharacterAmmoWorldContext.Read() end,
    catalog=WeaponDefinitionCatalog.ammunition,weapons=WeaponDefinitionCatalog.weapons,now=GetGameTimer,wait=Wait,
    operation=function(sequence,baseline) return ('ui:%s:%s:%s'):format(baseline.sessionId,GetGameTimer(),sequence) end,
})
exports('GetNativeAmmunitionControls',function(itemName)
    if GetInvokingResource()~='feather-inventory' then return {ok=false,error={code='ammunition_caller_denied'}} end
    return actions.Options(itemName)
end)
exports('TransferNativeAmmunition',function(id,quantity,direction,scope)
    if GetInvokingResource()~='feather-inventory' then return {ok=false,error={code='ammunition_caller_denied'}} end
    return actions.Transfer(id,quantity,direction,scope)
end)
