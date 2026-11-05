-- Native-only Inventory guard composition. Explicit installation only; does
-- not register legacy usable handlers or enable either runtime flag.
WeaponCharacterAmmoInventory={}
local function callable(value)
    return type(value)=='function' or type(value)=='table'
        and type(rawget(value,'__cfx_functionReference'))=='string'
end
function WeaponCharacterAmmoInventory.New(getInventory,isBound,administrativePolicy,canUninstall)
    assert(callable(getInventory) and callable(isBound) and callable(administrativePolicy),
        'native_inventory_callbacks_required')
    local phase='dormant'
    local surface
    local T={}
    local function fail(code) phase='failed'; return nil,code end
    local function guard(instance,context)
        if type(instance)~='table' or type(instance.id)~='number'
            or instance.id<1 or instance.id%1~=0 then
            return false,'Unable to verify native item ownership.'
        end
        local ok,bound=pcall(isBound,instance.id,context)
        if not ok or type(bound)~='boolean' then
            return false,'Unable to verify native item ownership.'
        end
        if bound then return false,'Native loadout still owns this item; complete its release first.' end
        return true
    end
    local function movementGuard(instance)
        local permitted,reason=guard(instance)
        if not permitted then return false,reason end
        local checked,equipped=pcall(surface.Equipment.IsInstanceEquipped,instance.id)
        if not checked or type(equipped)~='table' or equipped.ok~=true
            or type(equipped.value)~='boolean' then return false,'Unable to verify equipped state.' end
        if equipped.value then return false,'Unequip this item before moving or removing it.' end
        local called,allowed,why=pcall(administrativePolicy,instance)
        if not called or type(allowed)~='boolean' then return false,'Unable to verify administrative state.' end
        return allowed,why
    end
    function T.Install()
        if phase~='dormant' then return nil,'native_inventory_already_attempted' end
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
            return nil,'character_ammunition_disabled'
        end
        phase='installing'
        local ok,inventory=pcall(getInventory)
        if not ok or type(inventory)~='table' or not callable(inventory.GetCapabilities)
            or type(inventory.Guards)~='table' or type(inventory.Equipment)~='table'
            or not callable(inventory.Equipment.IsInstanceEquipped) then return fail('native_inventory_unavailable') end
        local got,caps=pcall(inventory.GetCapabilities)
        local value=got and type(caps)=='table' and caps.ok==true and caps.value
        if type(value)~='table' or (tonumber(value.contractVersion) or 0)<Config.Inventory.requiredContract
            or type(value.characterIdentity)~='table' or value.characterIdentity.uuid~=true
            or value.characterIdentity.mode~='uuid' then return fail('native_inventory_contract') end
        for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
            if not callable(inventory.Guards[name]) then return fail('native_inventory_guard_missing') end
        end
        surface=inventory
        for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
            if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
                return fail('character_ammunition_disabled')
            end
            local callback=name=='RegisterInstanceChangeGuard' and guard or movementGuard
            local registered,result=pcall(inventory.Guards[name],'feather-weapons',callback)
            if not registered or type(result)~='table' or result.ok~=true then
                return fail('native_inventory_guard_failed')
            end
        end
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
            return fail('character_ammunition_disabled')
        end
        phase='ready'; return true
    end
    function T.Status() return phase end
    function T.Uninstall()
        if phase~='ready' or not surface or not callable(canUninstall) then return nil,'native_inventory_teardown_unavailable' end
        local checked,allowed=pcall(canUninstall)
        if not checked or allowed~=true then return nil,'native_inventory_holds_remain' end
        for _,name in ipairs({'UnregisterMoveGuard','UnregisterDestroyGuard','UnregisterInstanceChangeGuard'}) do
            if not callable(surface.Guards[name]) then return nil,'native_inventory_teardown_missing' end
        end
        for _,name in ipairs({'UnregisterMoveGuard','UnregisterDestroyGuard','UnregisterInstanceChangeGuard'}) do
            local called,value=pcall(surface.Guards[name],'feather-weapons')
            if not called or value==false or type(value)=='table' and value.ok==false then
                return nil,'native_inventory_teardown_failed'
            end
        end
        phase='stopped'; return true
    end
    return T
end
-- Construction is inert. The eventual startup owner explicitly calls Install.
-- Narrow read-only surface for postcommit ownership observation. Never install
-- the legacy mutation/usable-item provider merely to obtain these reads.
WeaponNativeOwnershipInventory={}
function WeaponNativeOwnershipInventory.New(getInventory)
    local surface,index
    local T={}
    function T.Install()
        surface,index=nil,nil
        local ok,api=pcall(getInventory)
        if not ok or type(api)~='table' or not callable(api.GetCapabilities)
            or type(api.Items)~='table' or not callable(api.Items.GetDefinitions)
            or type(api.Instances)~='table' or not callable(api.Instances.GetInstance)
            or not callable(api.GetCharacterInventory) then return nil,'native_ownership_reader_unavailable' end
        local caps=api.GetCapabilities()
        local value=caps and caps.ok and caps.value
        if type(value)~='table' or (tonumber(value.contractVersion) or 0)<Config.Inventory.requiredContract
            or type(value.characterIdentity)~='table' or value.characterIdentity.uuid~=true
            or value.characterIdentity.mode~='uuid' then return nil,'native_ownership_reader_contract' end
        local listed=api.Items.GetDefinitions()
        if not listed or not listed.ok or type(listed.value)~='table' then return nil,'native_ownership_definitions_unavailable' end
        local byName,byId={},{}
        for id,definition in pairs(WeaponDefinitionCatalog.weapons) do byName[definition.itemName]=id end
        local found={}
        for _,definition in pairs(listed.value) do
            local weapon=byName[definition.name]
            local id=tonumber(definition.id)
            if weapon then
                if not id or id<1 or id%1~=0 or id==math.huge or found[weapon] or byId[id] then
                    return nil,'native_ownership_definition_ambiguous'
                end
                byId[id]=weapon; found[weapon]=true
            end
        end
        for _,weapon in pairs(byName) do if not found[weapon] then return nil,'native_ownership_definition_missing' end end
        surface,index=api,byId
        return true
    end
    function T.ResolveWeaponDefinitionId(id) return index and index[tonumber(id)] end
    function T.GetInstance(context,id)
        if not surface then return {ok=false,error={code='native_ownership_reader_not_ready'}} end
        local result=surface.Instances.GetInstance(id)
        if not result or not result.ok then return result end
        local item=result.value
        if type(item)~='table' or tonumber(item.id)~=tonumber(id) or type(item.metadata)~='table'
            or type(item.revision)~='number' or item.revision<0 or item.revision%1~=0 or item.revision==math.huge
            or not item.definition or index[tonumber(item.definition.id)]~=item.metadata.weaponDefinitionId then
            return {ok=false,error={code='native_ownership_item_mismatch'}}
        end
        return {ok=true,value={id=item.id,inventoryId=item.inventoryId,metadata=item.metadata,
            metadataRevision=item.revision,definitionId=item.definition.id,itemName=item.definition.name}}
    end
    function T.GetCharacterInventory(context,characterId)
        if not surface then return {ok=false,error={code='native_ownership_reader_not_ready'}} end
        return surface.GetCharacterInventory(characterId)
    end
    function T.IsReady() return surface~=nil end
    return T
end
WeaponNativeOwnershipReader=WeaponNativeOwnershipInventory.New(function()
    assert(GetResourceState('feather-inventory')=='started','inventory_not_started')
    return exports['feather-inventory'].initiate()
end)
WeaponCharacterAmmoInventoryProvider=WeaponCharacterAmmoInventory.New(function()
    assert(GetResourceState('feather-inventory')=='started','inventory_not_started')
    return exports['feather-inventory'].initiate()
end,function(id,context)
    return WeaponCharacterAmmoService.IsNativeItemBound(id)
        and not WeaponCharacterAmmoService.IsDeathWearWriteAuthorized(id,context)
        and not WeaponCharacterAmmoService.IsDeathEquipmentWriteAuthorized(id,context)
end,function(instance)
    local name=type(instance.definition)=='table' and instance.definition.name
    for _,definition in pairs(WeaponDefinitionCatalog.weapons) do
        if definition.itemName==name then
            return WeaponOwnershipService.EvaluateAdministrativeHold(instance.metadata)
        end
    end
    return true
end,function()
    return WeaponCharacterAmmoService.CanReleaseInventoryGuards()==true
end)
if type(AddEventHandler)=='function' then AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() or WeaponCharacterAmmoInventoryProvider.Status()~='ready' then return end
    local called,removed,why=pcall(WeaponCharacterAmmoInventoryProvider.Uninstall)
    print('[feather-weapons] native Inventory guard teardown '..(called and removed==true and 'PASS' or ('REFUSED '..tostring(why or removed))))
end) end
