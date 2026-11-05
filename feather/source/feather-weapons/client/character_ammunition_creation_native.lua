-- Explicit creation adapter. Never touches ammo totals, clips or ammo selection.
-- Entitlement/appearance readiness is supplied by the owning lifecycle adapter.
WeaponCharacterAmmoCreationNative={}
function WeaponCharacterAmmoCreationNative.SelectEquippedChild(stock,wide)
    local function readable(item)
        return type(item)=='table' and item.found==true and item.readConfirmed==true
            and item.equippedFlagReadable==true and type(item.equipped)=='boolean'
            and type(item.guid)=='string' and item.guid~=''
    end
    if not readable(stock) or type(wide)~='table' then return nil end
    if wide.found==false then return stock.equipped and stock.guid or nil end
    if not readable(wide) or wide.guid==stock.guid or stock.equipped==wide.equipped then return nil end
    return wide.equipped and wide.guid or stock.guid
end
function WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,result)
    if result~=true and result~=1 then return nil end
    if type(raw)~='string' or #raw<40 then return nil end
    -- shop_gunsmith func1915 consumes equipped output.f_4 as component hash.
    -- Native script fields occupy eight-byte slots, as verified for GUID f_0..3.
    local hash=string.unpack('<I4',raw,33)
    if hash==0 then return nil end
    return {itemHash=hash,itemHashHex=string.format('0x%08X',hash),fieldOffsetBytes=32}
end
function WeaponCharacterAmmoCreationNative.DecodeChildEquippedFlag(raw,result)
    if type(raw)~='string' or #raw<88 then return nil end
    local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,result)
    if not item then return nil end
    -- shop_gunsmith func1176 compares inventory item.f_10 to desired equip BOOL.
    local flag=string.unpack('<I4',raw,81)
    item.equippedField10=flag
    item.equippedFlagReadable=flag==0 or flag==1
    if item.equippedFlagReadable then item.equipped=flag==1 end
    return item
end
function WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
    if type(raw)~='string' or #raw<32 then return nil end
    local prefix=raw:sub(1,32)
    if prefix==string.rep('\0',32) then return nil end
    local packed,slots={},{}
    for index=0,3 do
        packed[index+1]=string.unpack('<I4',raw,1+index*4)
        slots[index+1]=string.unpack('<I4',raw,1+index*8)
    end
    return {raw32=prefix:gsub('.',function(byte) return ('%02x'):format(byte:byte()) end),
        packedWords=packed,scriptSlotWords=slots}
end
function WeaponCharacterAmmoCreationNative.New(ped,current,prepareDual,applyMaintenance,guidIdentity,savedAttachments)
    assert(type(current)=='function' and type(prepareDual)=='function','Local lifecycle callbacks required')
    local function yes(v) return v==true or v==1 end
    local function buffer() return string.rep('\0',104) end
    local function resolve(parent,item,slot)
        local out=buffer()
        return yes(Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,joaat(item),slot,out)) and out or nil
    end
    local function ready(identity)
        local ok,valid=pcall(current,identity)
        return ok and valid==true and PlayerPedId()==ped
            and yes(DoesEntityExist(ped)) and not yes(IsEntityDead(ped))
    end
    local function entity(point,name)
        local present,hash=GetCurrentPedWeapon(ped,true,point,true)
        local handle=GetCurrentPedWeaponEntityIndex(ped,point)
        return yes(present) and hash==joaat(name) and type(handle)=='number' and handle>0 and handle or nil
    end
    local function settle(records,identity)
        -- Native inventory activation/holstering can finish on later frames.
        -- Validate the identity on every yield; never accept an unbounded wait.
        local started=GetGameTimer()
        for frame=1,120 do
            if not ready(identity) then return false,'creation_identity_changed' end
            local complete,seen=true,{}
            for _,record in ipairs(records) do
                record.entity=entity(record.point,record.name)
                if not record.entity or seen[record.entity] then complete=false end
                if record.entity then seen[record.entity]=true end
            end
            if complete then return true end
            if GetGameTimer()-started>=1500 then break end
            Wait(0)
        end
        return false,'holster_entities_not_settled'
    end
    local function remove(record)
        if record.guid then
            return yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,record.guid,1,joaat('REMOVE_REASON_DEFAULT')))
        end
        if guidIdentity and guidIdentity.Has(record) then
            if not guidIdentity.Resolve(record,record.guidIdentity,true) then return false end
        end
        -- Single creation refused preexisting ownership; do not remove a later
        -- replacement model/entity that no longer belongs to this attempt.
        if yes(DoesEntityExist(ped)) then
            for _,point in ipairs({0,1,2,3,9,10}) do
                if entity(point,record.name)==record.entity then
                    RemoveWeaponFromPed(ped,joaat(record.name))
                    return not yes(HasPedGotWeapon(ped,joaat(record.name),false))
                end
            end
        end
        return false
    end
    local function clean(records)
        for i=#records,1,-1 do pcall(remove,records[i]) end
    end
    local function empty(item)
        return type(item)=='table' and type(item.nativeWeaponName)=='string'
            and type(item.attachments)=='table' and next(item.attachments)==nil
            and type(item.cosmetics)=='table' and next(item.cosmetics)==nil
            and not yes(HasPedGotWeapon(ped,joaat(item.nativeWeaponName),false))
    end
    local function single(item,ammo,identity)
        if ammo~=0 then return nil,'single_creation_precondition: nonzero_ammo' end
        if not ready(identity) then return nil,'single_creation_precondition: lifecycle_not_ready' end
        if not empty(item) then
            local existing=type(item)=='table' and type(item.nativeWeaponName)=='string'
                and yes(HasPedGotWeapon(ped,joaat(item.nativeWeaponName),false))
            return nil,'single_creation_precondition: '..(existing and 'preexisting_weapon' or 'unsupported_item_state')
        end
        local mappedModel=item.nativeWeaponName=='WEAPON_REPEATER_CARBINE' or (WeaponNativeAttachmentMappings
            and WeaponNativeAttachmentMappings.CaptureModel(item.nativeWeaponName)==true)
        local capturedCarbine=guidIdentity and ((savedAttachments==true and mappedModel)
            or (savedAttachments~=true and item.itemInstanceId==135))
        if capturedCarbine then
            if not mappedModel or type(item.itemInstanceId)~='number' or item.itemInstanceId<1
                or item.itemInstanceId%1~=0 or item.itemInstanceId==math.huge or type(item.itemRevision)~='number'
                or item.itemRevision<0 or item.itemRevision%1~=0 or item.itemRevision==math.huge
                or type(item.serialNumber)~='string' or item.serialNumber=='' then return nil,'guid_owned_carbine_identity_required' end
            if savedAttachments~=true and (item.itemRevision~=0 or item.serialNumber~='FW-ALPHA-MIXED-JANE-V1-repeater_carbine') then
                return nil,'guid_owned_fixture_scope_required'
            end
        end
        if not ({[2]=true,[3]=true,[9]=true,[10]=true})[item.point] then
            return nil,'single_creation_precondition: unsupported_point'
        end
        local permanent=item.maintenance and item.maintenance.permanentDegradation or 0
        if type(permanent)~='number' or permanent~=permanent or permanent<0 or permanent>1 then
            return nil,'single_creation_precondition: invalid_permanent_degradation'
        end
        if permanent>0 and (type(GetWeaponPermanentDegradation)~='function'
            or type(GetObjectIndexFromEntityIndex)~='function') then
            return nil,'single_creation_precondition: permanent_readback_unavailable'
        end
        local record={name=item.nativeWeaponName,point=item.point,itemInstanceId=item.itemInstanceId,itemRevision=item.itemRevision,
            serialNumber=item.serialNumber}
        local ok,failure=pcall(function()
            GiveWeaponToPed(ped,joaat(item.nativeWeaponName),0,false,true,item.point,false,
                0.5,1.0,joaat('ADD_REASON_DEFAULT'),true,permanent,false)
            local settled,reason=settle({record},identity)
            assert(settled,reason)
            if capturedCarbine then
                local captured,why=guidIdentity.Capture(record,identity)
                assert(captured,why)
                record.guidIdentity={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
            end
            if permanent>0 then
                local object=GetObjectIndexFromEntityIndex(record.entity)
                assert(type(object)=='number' and object>0,'permanent_object_unavailable')
                local read=GetWeaponPermanentDegradation(object)
                assert(type(read)=='number' and read==read and math.abs(read-permanent)<=0.0001,
                    'permanent_creation_readback_mismatch')
                assert(ready(identity) and entity(record.point,record.name)==record.entity,'permanent_creation_owner_changed')
            end
            if applyMaintenance then
                local applied,reason=applyMaintenance(record,identity,item.maintenance)
                assert(applied==true,reason or 'maintenance_creation_restore_failed')
                assert(ready(identity),'maintenance_creation_owner_changed')
            end
        end)
        if not ok or not record.entity then
            -- Preserve the existing compensation policy; report the swallowed
            -- native/settlement error instead of masking it at the caller.
            RemoveWeaponFromPed(ped,joaat(item.nativeWeaponName))
            return nil,'single_creation_or_settlement_failed: '..tostring(failure or 'missing_entity')
        end
        return record
    end
    local function pair(items,identity)
        if not ready(identity) or #items~=2 or items[1].point~=2 or items[2].point~=3
            or items[1].nativeWeaponName~=items[2].nativeWeaponName
            or not empty(items[1]) or not empty(items[2]) then return nil,'pair_creation_precondition' end
        for _,item in ipairs(items) do
            local permanent=item.maintenance and item.maintenance.permanentDegradation or 0
            if permanent~=0 then return nil,'pair_permanent_degradation_restore_not_supported' end
        end
        local character=resolve(nil,'CHARACTER',0xA1212100)
        local parent=character and resolve(character,'CARRIED_WEAPONS',joaat('SLOTID_CARRIED_WEAPONS'))
        if not parent then return nil,'carried_weapon_inventory_unavailable' end
        local owned={}
        local ok,reason=pcall(function()
            for index=1,2 do
                local out=buffer()
                assert(yes(Citizen.InvokeNative(0xCB5D11F9508A928D,1,out,parent,joaat(items[index].nativeWeaponName),
                    joaat('SLOTID_WEAPON_0'),1,joaat('ADD_REASON_DEFAULT'))),'copy insert failed')
                local record={guid=out,slot=0,name=items[index].nativeWeaponName,point=items[index].point,
                    itemInstanceId=items[index].itemInstanceId,itemRevision=items[index].itemRevision,serialNumber=items[index].serialNumber}
                owned[#owned+1]=record
                assert(yes(Citizen.InvokeNative(0x734311E2852760D0,1,out,true)),'copy equip failed')
                Citizen.InvokeNative(0x12FB95FE3D579238,ped,out,true,0,false,false)
                if index==1 then
                    local moved=buffer()
                    assert(yes(Citizen.InvokeNative(0xDCCAA7C3BFD88862,1,out,parent,joaat('SLOTID_WEAPON_1'),1,moved)),'copy move failed')
                    record.guid,record.slot=moved,1
                end
            end
            for _,index in ipairs({2,1}) do
                local record=owned[index]
                Citizen.InvokeNative(0x12FB95FE3D579238,ped,record.guid,true,record.slot,false,false)
            end
            Citizen.InvokeNative(0x94A3C1B804D291EC,ped,true,true,true,true)
            -- The original proof completes GUID activation by selecting unarmed.
            -- Request that transition BEFORE waiting for carried points2/3;
            -- otherwise the copies can remain at hand points0/1 throughout.
            SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
            local settled,failure=settle(owned,identity)
            assert(settled,failure)
            if applyMaintenance then
                for index,record in ipairs(owned) do
                    local applied,reason=applyMaintenance(record,identity,items[index].maintenance)
                    assert(applied==true,reason or 'maintenance_pair_restore_failed')
                    assert(ready(identity),'maintenance_pair_owner_changed')
                end
            end
        end)
        if not ok then clean(owned); return nil,tostring(reason) end
        return owned
    end
    return {current=ready,prepareDual=function(identity) return ready(identity) and prepareDual(ped)==true end,
        createSingle=single,createPair=pair,remove=remove,finish=function(records,identity)
            if not ready(identity) then return false end
            SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
            for _,record in ipairs(records) do
                if entity(record.point,record.name)~=record.entity then return false end
            end
            return true
        end}
end

-- Lifecycle-bound factory only. Never assumes entitlement/appearance ownership;
-- caller supplies both preparation and cleanup for the same scoped setup.
function WeaponCharacterAmmoCreationNative.Scoped(ped,identity,prepareDual,cleanupDual)
    if type(identity)~='table' or type(identity.characterId)~='string'
        or type(identity.sessionId)~='string' or type(identity.epoch)~='string'
        or identity.characterId=='' or identity.sessionId=='' or identity.epoch==''
        or type(prepareDual)~='function' or type(cleanupDual)~='function' then
        return nil,'invalid_scoped_creation'
    end
    local expected={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
    local function current(check)
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true
            or type(check)~='table' then return false end
        for key,value in pairs(expected) do if check[key]~=value then return false end end
        local context=WeaponCharacterAmmoWorldContext
        if type(context)~='table' then return false end
        local called,result=pcall(context.Read)
        local value=called and type(result)=='table' and result.ok==true and result.value
        return type(value)=='table' and value.characterId==expected.characterId
            and value.sessionId==expected.sessionId and value.ped==ped and PlayerPedId()==ped
    end
    if not current(expected) then return nil,'scoped_creation_world_not_ready' end
    if type(WeaponCharacterMaintenanceNative)~='table'
        or type(WeaponCharacterMaintenanceNative.Scoped)~='function' then
        return nil,'scoped_maintenance_adapter_unavailable'
    end
    local guidIdentity
    local savedAttachments=Config.NativeAlphaRuntime==true
        and WeaponNativeEnrollment.Allows(Config,expected.characterId) and type(GetConvarInt)=='function'
        and GetConvarInt('feather_native_saved_attachments',0)==1
    if Config.NativeAlphaRuntime==true and WeaponNativeEnrollment.Allows(Config,expected.characterId)
        and type(GetConvarInt)=='function' and GetConvarInt('feather_native_guid_ownership',0)==1 then
        guidIdentity=WeaponNativeGuidIdentity.New({current=current,hash=joaat,
            exists=function(handle) local value=DoesEntityExist(handle); return value==true or value==1 end,
            point=function(point)
                if not current(expected) then return nil end
                local present,hash=GetCurrentPedWeapon(ped,true,point,true)
                local handle=GetCurrentPedWeaponEntityIndex(ped,point)
                if (present~=true and present~=1) or type(handle)~='number' or handle<=0 then return nil end
                local raw=string.rep('\0',104)
                local value=Citizen.InvokeNative(0x6929E22158E52265,ped,point,raw)
                if value~=true and value~=1 then return nil end
                local guid=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
                if not guid then return nil end
                local words=guid.scriptSlotWords
                local key=('%08x%08x%08x%08x'):format(words[1],words[2],words[3],words[4])
                local after,afterHash=GetCurrentPedWeapon(ped,true,point,true)
                if not current(expected) or (after~=true and after~=1) or hash~=afterHash
                    or GetCurrentPedWeaponEntityIndex(ped,point)~=handle then return nil end
                return {entity=handle,hash=hash,guid=key}
            end})
    end
    local function resolveOwned(record,identity)
        if guidIdentity and guidIdentity.Has(record) then return guidIdentity.Resolve(record,identity) end
        return record.entity
    end
    local maintenance=WeaponCharacterMaintenanceNative.Scoped(ped,current,resolveOwned)
    local adapter=WeaponCharacterAmmoCreationNative.New(ped,current,prepareDual,function(record,check,values)
        return maintenance.Apply(record,check,values)
    end,guidIdentity,savedAttachments)
    adapter.readMaintenance=function(record,check) return maintenance.Read(record,check) end
    local diagnosticGuids=setmetatable({},{__mode='k'})
    local guidProbeUsed=setmetatable({},{__mode='k'})
    local childProbes=setmetatable({},{__mode='k'})
    local originalRemove=adapter.remove
    adapter.remove=function(record,...)
        for _,probe in pairs(childProbes[record] or {}) do
            if probe.Pending() then return nil,'native_child_cleanup_required' end
        end
        return originalRemove(record,...)
    end
    local function pointGuid(point)
        local raw=string.rep('\0',104) -- same bounded native struct buffer as GUID creation
        local ok,value=pcall(Citizen.InvokeNative,0x6929E22158E52265,ped,point,raw)
        if not ok or (value~=true and value~=1) then return nil end
        -- Both layouts are diagnostic until actual buffer packing is confirmed.
        return WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
    end
    adapter.inspectTrackedEntity=function(record,check)
        if not current(check) then return nil,'diagnostic_context_changed' end
        resolveOwned(record,check) -- optional independently captured GUID authority
        local points={}
        for _,point in ipairs({0,1,2,3,9,10}) do
            local present,hash=GetCurrentPedWeapon(ped,true,point,true)
            local handle=GetCurrentPedWeaponEntityIndex(ped,point)
            local guid=pointGuid(point)
            local sight
            if record.name=='WEAPON_REPEATER_CARBINE' and hash==joaat(record.name) and type(handle)=='number' and handle>0 then
                local read,value=pcall(function()
                    local object=GetObjectIndexFromEntityIndex(handle)
                    if type(object)~='number' or object<=0 then return nil end
                    local v=Citizen.InvokeNative(0x76A18844E743BF91,object,joaat('COMPONENT_REPEATER_CARBINE_SIGHT_WIDE'))
                    return v==true or v==1
                end)
                if read then sight=value end
            end
            if not current(check) then return nil,'diagnostic_context_changed' end
            if guid and (present==true or present==1) and hash==joaat(record.name) and handle==record.entity
                and not diagnosticGuids[record] then diagnosticGuids[record]=guid.raw32 end
            points[#points+1]={point=point,present=present==true or present==1,
                expectedModel=hash==joaat(record.name),entity=handle,tracked=handle==record.entity,guid=guid,wideSightPresent=sight,
                guidMatchesDiagnosticBaseline=guid and diagnosticGuids[record] and guid.raw32==diagnosticGuids[record] or false}
        end
        local called,values,why=pcall(maintenance.Read,record,check)
        local childState,childError,childStates=nil,nil,{}
        for slot,probe in pairs(childProbes[record] or {}) do
            local read,value,reason=pcall(probe.Run,'status')
            if read and value then childStates[slot]=value; childState=childState or value
            else childError=tostring(reason or value) end
        end
        if not current(check) then return nil,'diagnostic_context_changed' end
        local exists=DoesEntityExist(record.entity)
        return {itemInstanceId=record.itemInstanceId,itemRevision=record.itemRevision,name=record.name,
            guidOwnershipCaptured=guidIdentity and guidIdentity.Has(record) or false,
            trackedEntity=record.entity,trackedExists=exists==true or exists==1,points=points,
            diagnosticGuidBaseline=diagnosticGuids[record],guidDiagnosticOnly=not (guidIdentity and guidIdentity.Has(record)),
            nativeAttachmentChild=childState,nativeAttachmentChildren=childStates,nativeAttachmentError=childError,
            maintenance=called and values or nil,maintenanceError=not values and tostring(why or values) or nil}
    end
    local function runChild(record,check,guard,action,descriptor)
        if not guidIdentity or not guidIdentity.Has(record) then return nil,'child_captured_copy_guid_required' end
        local function yes(v) return v==true or v==1 end
        -- Manual legacy proof has its fixed descriptor; saved reconstruction
        -- supplies a registry-validated private descriptor through the manager.
        descriptor=descriptor or {nativeComponentName='COMPONENT_REPEATER_CARBINE_SIGHT_WIDE',
            nativeSlot=468034421,stockComponentName='COMPONENT_REPEATER_CARBINE_SIGHT_NARROW'}
        local component=joaat(descriptor.nativeComponentName)
        local slot=descriptor.nativeSlot
        local stockComponent=descriptor.stockComponentName and joaat(descriptor.stockComponentName) or nil
        local probes=childProbes[record]
        if not probes then probes={}; childProbes[record]=probes end
        local function exactParent()
            if not current(check) or not guard() or not resolveOwned(record,check) then return nil end
            for _,point in ipairs({0,1,2,3,9,10}) do
                local present,hash=GetCurrentPedWeapon(ped,true,point,true)
                if yes(present) and hash==joaat(record.name) and GetCurrentPedWeaponEntityIndex(ped,point)==record.entity then
                    local raw=string.rep('\0',104)
                    if yes(Citizen.InvokeNative(0x6929E22158E52265,ped,point,raw)) and current(check) and guard() then return raw end
                end
            end
        end
        local function key(raw)
            return string.format('%08x%08x%08x%08x',string.unpack('<I4',raw,1),string.unpack('<I4',raw,9),
                string.unpack('<I4',raw,17),(string.unpack('<I4',raw,25)))
        end
        if not probes[slot] then
            -- Status must initialize read-only after a fresh adapter/restart;
            -- only removal requires a previously owned child in this copy.
            if action~='install' and action~='status' then return nil,'child_no_probe_this_copy' end
            local parent=exactParent()
            if not parent then return nil,'child_exact_parent_required' end
            local parentKey=key(parent)
            local buffers={}
            local function lookup(item)
                local raw=string.rep('\0',104)
                if not yes(Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,item,slot,raw)) then return nil end
                local id=key(raw)
                if id==string.rep('0',32) or id==parentKey then return nil end
                return id,raw
            end
            local function valid()
                local now=exactParent()
                return now~=nil and key(now)==parentKey
            end
            local function childRead(itemHash)
                local id,input=lookup(itemHash)
                if not id then return {found=false} end
                local raw=string.rep('\0',104)
                local result=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,input,raw,true)
                local item=WeaponCharacterAmmoCreationNative.DecodeChildEquippedFlag(raw,result)
                if not item or key(raw)~=id or item.itemHash~=(itemHash & 0xffffffff) then
                    return {found=true,guid=id,readConfirmed=false}
                end
                item.guid=id; item.found=true; item.readConfirmed=true
                return item
            end
            if not stockComponent then
                -- Fresh single-child slot only. The slot query is a candidate,
                -- not authority: independently read its exact GUID/hash/f10.
                local count=Citizen.InvokeNative(0x033EE4B89F3AC545,1,parent,slot,Citizen.ResultAsInteger())
                if count~=1 or not valid() then return nil,'child_unique_stock_required' end
                local raw=string.rep('\0',104)
                local result=Citizen.InvokeNative(0xBE012571B25F5ACA,1,parent,slot,0,raw,Citizen.ResultAsInteger())
                local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,result)
                if not item or item.itemHash==(component & 0xffffffff) then return nil,'child_stock_candidate_invalid' end
                local verified=childRead(item.itemHash)
                if not verified.readConfirmed or verified.equipped~=true or verified.guid~=key(raw)
                    or not valid() or Citizen.InvokeNative(0x033EE4B89F3AC545,1,parent,slot,Citizen.ResultAsInteger())~=1 then
                    return nil,'child_stock_readback_unconfirmed'
                end
                stockComponent=item.itemHash
            end
            probes[slot]=WeaponNativeAttachmentChild.New({
                current=valid,
                stock=function()
                    local id,raw=lookup(stockComponent)
                    if id then buffers[id]=raw end
                    return id
                end,
                equipped=function()
                    -- LIVE: slot query can return stock even when stock.f10=0
                    -- and wide.f10=1. Only exact child flags select authority.
                    local stock,wide=childRead(stockComponent),childRead(component)
                    if not valid() then return nil end
                    return WeaponCharacterAmmoCreationNative.SelectEquippedChild(stock,wide)
                end,
                count=function() return Citizen.InvokeNative(0x033EE4B89F3AC545,1,parent,slot,Citizen.ResultAsInteger()) end,
                details=function()
                    local raw=string.rep('\0',104)
                    local result=Citizen.InvokeNative(0xBE012571B25F5ACA,1,parent,slot,0,raw,Citizen.ResultAsInteger())
                    local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,result)
                    if item then item.isWideSight=item.itemHash==(component & 0xffffffff) end
                    local stock,wide=childRead(stockComponent),childRead(component)
                    return {slot=slot,parentGuid=parentKey,equippedReadResult=result,
                        stockChild=stock,wideChild=wide,
                        verifiedEquippedChildGuid=WeaponCharacterAmmoCreationNative.SelectEquippedChild(stock,wide),
                        equippedItem=item,
                        equippedGuidDiagnostic=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)}
                end,
                find=function()
                    return (lookup(component))
                end,
                add=function()
                    local raw=string.rep('\0',104)
                    if not yes(Citizen.InvokeNative(0xCB5D11F9508A928D,1,raw,parent,component,slot,1,joaat('ADD_REASON_DEFAULT'))) then return nil end
                    local id=key(raw)
                    if id==string.rep('0',32) or id==parentKey or buffers[id] then return nil end
                    buffers[id]=raw; return id
                end,
                equip=function(id) return buffers[id]~=nil and yes(Citizen.InvokeNative(0x734311E2852760D0,1,buffers[id],true)) end,
                remove=function(id) return buffers[id]~=nil and yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,buffers[id],1,joaat('REMOVE_REASON_DEFAULT'))) end,
            })
        end
        return probes[slot].Run(action)
    end
    adapter.probeInventoryComponent=function(record,check,guard,action)
        if savedAttachments or record.itemInstanceId~=135 or record.itemRevision~=0 or record.name~='WEAPON_REPEATER_CARBINE'
            or record.serialNumber~='FW-ALPHA-MIXED-JANE-V1-repeater_carbine' then return nil,'manual_child_probe_fixture_scope_required' end
        return runChild(record,check,guard,action)
    end
    adapter.probeGuidComponent=function(record,check,guard)
        if guidProbeUsed[record] then return nil,'guid_probe_already_used_this_copy' end
        if record.itemInstanceId~=135 or record.itemRevision~=0 or record.name~='WEAPON_REPEATER_CARBINE'
            or record.serialNumber~='FW-ALPHA-MIXED-JANE-V1-repeater_carbine' then return nil,'guid_probe_fixture_required' end
        local component=joaat('COMPONENT_REPEATER_CARBINE_SIGHT_WIDE')
        local function exact()
            if not current(check) or guard()~=true then return nil end
            for _,point in ipairs({0,1,2,3,9,10}) do
                local present,hash=GetCurrentPedWeapon(ped,true,point,true)
                if (present==true or present==1) and hash==joaat(record.name)
                    and GetCurrentPedWeaponEntityIndex(ped,point)==record.entity then
                    local guid=pointGuid(point)
                    if not current(check) or not guid then return nil end
                    return guid
                end
            end
        end
        local before=exact()
        if not before then return nil,'guid_probe_exact_owner_required' end
        local model=Citizen.InvokeNative(0x59DE03442B6C9598,component)
        if type(model)~='number' or model==0 then return nil,'guid_probe_model_missing' end
        RequestModel(model,false)
        local loaded=false
        for _=1,100 do
            if not exact() then break end
            local value=HasModelLoaded(model)
            if value==true or value==1 then loaded=true; break end
            Wait(0)
        end
        local final=exact()
        if not loaded or not final or final.raw32~=before.raw32 then
            SetModelAsNoLongerNeeded(model); return nil,'guid_probe_owner_changed'
        end
        -- Diagnostic baseline only; NEVER use it to adopt the later replacement.
        diagnosticGuids[record]=before.raw32
        guidProbeUsed[record]=true
        local called,why=pcall(Citizen.InvokeNative,0x74C9090FDD1BB48E,record.entity,component,joaat(record.name),false)
        SetModelAsNoLongerNeeded(model)
        if not called then return nil,tostring(why) end
        return {itemInstanceId=135,trackedEntityBefore=record.entity,guidBefore=before,
            nativeCallCompleted=true,componentPresenceNotYetVerified=true,noSQLWrites=true,noAmmoWrites=true,noRebinding=true}
    end
    local deathReader=type(WeaponCharacterMaintenanceNative.DeathReadOnly)=='function' and WeaponCharacterMaintenanceNative.DeathReadOnly(ped,expected,function()
        return WeaponCharacterAmmoWorldContext.ReadDeath()
    end)
    adapter.readDeathMaintenance=function(record,check)
        if not deathReader then return nil,'death_maintenance_adapter_unavailable' end
        return deathReader.Read(record,check)
    end
    adapter.cleanupSetup=function()
        if not current(expected) then return nil,'scoped_cleanup_world_changed' end
        return cleanupDual()
    end
    if savedAttachments then
        if not guidIdentity then return nil,'saved_attachment_guid_ownership_required' end
        local manager=WeaponNativeAttachmentReconstruction.New({current=current,
            validate=function(bound,component)
                local attachment=WeaponDefinitionCatalog.attachments[component.definitionId]
                for _,weapon in pairs(WeaponDefinitionCatalog.weapons) do
                    if weapon.nativeWeaponName==bound.nativeWeaponName then
                        local mapping=WeaponNativeAttachmentMappings.Resolve(weapon,attachment,true)
                        return mapping~=nil and mapping.slot==component.slot and mapping.nativeSlot==component.nativeSlot
                            and mapping.nativeComponentName==component.nativeComponentName
                            and mapping.stockComponentName==component.stockComponentName
                    end
                end
                return false
            end,
            probe=function(record,check,component)
                local function guard() return current(check) end
                local read,why=runChild(record,check,guard,'status',component)
                assert(read,why)
                return {Run=function(action) return runChild(record,check,guard,action,component) end,
                    Pending=function() return childProbes[record][component.nativeSlot].Pending() end}
            end})
        adapter=WeaponNativeAttachmentReconstruction.Bind(adapter,function(item,check)
            return WeaponNativeAttachmentProjection.Build(item,WeaponDefinitionCatalog,check)
        end,manager)
    end
    return adapter
end
