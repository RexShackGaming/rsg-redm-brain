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
function WeaponCharacterAmmoCreationNative.GuidKey(raw)
    local decoded=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
    local words=decoded and decoded.scriptSlotWords
    return words and ('%08x%08x%08x%08x'):format(words[1],words[2],words[3],words[4]) or nil
end
-- Live-verified weapon_locker/options ABI. Never write guessed options fields.
function WeaponCharacterAmmoCreationNative.GuidOptions(guid,hash,point,reason)
    local key=WeaponCharacterAmmoCreationNative.GuidKey(guid)
    if not key or key==string.rep('0',32) or not ({[2]=true,[3]=true,[9]=true,[10]=true})[point] then return nil end
    local function int(v) return string.pack('<I4I4',v & 0xffffffff,0) end
    return guid:sub(1,32)..int(hash)..int(0)..int(point)..int(reason)
        ..string.pack('<fI4fI4',0.5,0,1.0,0)..int(0)..int(0)..int(1)
end
-- Hand-point wrapper retained for diagnostic ABI comparison; production uses GuidOptions.
function WeaponCharacterAmmoCreationNative.PairOptions(guid,hash,point,reason)
    if point~=2 and point~=3 then return nil end
    return WeaponCharacterAmmoCreationNative.GuidOptions(guid,hash,point,reason)
end
function WeaponCharacterAmmoCreationNative.PairRecord(raw,guid,hash,permanent)
    local key=WeaponCharacterAmmoCreationNative.GuidKey(guid)
    if type(raw)~='string' or #raw~=176 or not key or key==string.rep('0',32)
        or WeaponCharacterAmmoCreationNative.GuidKey(raw)~=key
        or string.unpack('<I4',raw,33)~=(hash & 0xffffffff)
        or type(permanent)~='number' or permanent~=permanent or permanent<0 or permanent>1 then return nil end
    local flag=string.unpack('<I4',raw,169)
    local old=string.unpack('<f',raw,137)
    if (flag~=0 and flag~=1) or old~=old or old<0 or old>1 then return nil end
    -- Only our just-created GUID entry: preserve unrelated fields and padding.
    return raw:sub(1,136)..string.pack('<f',permanent+0.0)..raw:sub(141,168)..string.pack('<I4I4',1,0)
end
function WeaponCharacterAmmoCreationNative.New(ped,current,prepareDual,applyMaintenance,guidIdentity,inventory)
    assert(type(current)=='function' and type(prepareDual)=='function','Local lifecycle callbacks required')
    local attempts,owned,creationFailure={},{},nil
    local function yes(v) return v==true or v==1 end
    local function buffer() return inventory and inventory.buffer and inventory.buffer() or string.rep('\0',104) end
    inventory=inventory or {
        read=function(record)
            local raw=string.rep('\0',72)..string.pack('<I4I4',joaat('SLOTID_NONE') & 0xffffffff,0)..string.rep('\0',96)
            return yes(Citizen.InvokeNative(0x025A1B1FB03FBF61,1,record.guid,raw,22,1)) and raw or nil
        end,
        update=function(record,raw) return yes(Citizen.InvokeNative(0xD80A8854DB5CFBA5,1,record.guid,raw,22)) end,
        pointGuid=function(point)
            local raw=string.rep('\0',104)
            if not yes(Citizen.InvokeNative(0x6929E22158E52265,ped,point,raw)) then return nil end
            return WeaponCharacterAmmoCreationNative.GuidKey(raw)
        end,
        activate=function(record)
            local input=WeaponCharacterAmmoCreationNative.GuidOptions(record.guid,joaat(record.name),record.point,joaat('ADD_REASON_DEFAULT'))
            if not input then return false end
            local output=string.rep('\0',192)
            record.guidActivationEvidence={point=record.point,expectedGuid=WeaponCharacterAmmoCreationNative.GuidKey(record.guid),callCompleted=false}
            local returned=Citizen.InvokeNative(0xBE7E42B07FD317AC,ped,input,output)
            record.guidActivationEvidence.callCompleted=true
            record.guidActivationEvidence.nativeReturn=tostring(returned):sub(1,80)
            record.guidActivationEvidence.outputGuid=WeaponCharacterAmmoCreationNative.GuidKey(output)
            return yes(returned) and WeaponCharacterAmmoCreationNative.GuidKey(output)==WeaponCharacterAmmoCreationNative.GuidKey(record.guid)
        end,
    }
    local function ready(identity)
        local ok,value=pcall(current,identity)
        return ok and value==true and PlayerPedId()==ped and yes(DoesEntityExist(ped)) and not yes(IsEntityDead(ped))
    end
    local function entity(point,name)
        local present,hash=GetCurrentPedWeapon(ped,true,point,true)
        local handle=GetCurrentPedWeaponEntityIndex(ped,point)
        return yes(present) and hash==joaat(name) and type(handle)=='number' and handle>0 and handle or nil
    end
    local function settle(records,identity)
        local started=GetGameTimer()
        for frame=1,120 do
            if not ready(identity) then return false,'creation_identity_changed' end
            local complete,seen=true,{}
            for _,record in ipairs(records) do
                local handle=entity(record.point,record.name)
                if not handle or seen[handle] or inventory.pointGuid(record.point)~=WeaponCharacterAmmoCreationNative.GuidKey(record.guid) then complete=false end
                if handle then seen[handle]=true;record.entity=handle end
            end
            if complete then return true end
            if (GetGameTimer()-started)%4294967296>=1500 then break end
            Wait(0)
        end
        return false,'guid_entities_not_settled'
    end
    local function remove(record)
        local key=owned[record]
        if not key or record.pairGrantPending or WeaponCharacterAmmoCreationNative.GuidKey(record.guid)~=key then return false end
        -- Exact issued GUID only. Never delete by weapon model, including when
        -- a different copy of the same model has appeared on the ped.
        local removed=yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,record.guid,1,joaat('REMOVE_REASON_DEFAULT')))
        if removed then owned[record]=nil end
        return removed
    end
    local function clean(records)
        local retained={};creationFailure={}
        for _,record in ipairs(records) do
            creationFailure[#creationFailure+1]={point=record.point,name=record.name,entity=record.entity,
                guid=record.guid and WeaponCharacterAmmoCreationNative.GuidKey(record.guid),grantPending=record.pairGrantPending==true,
                activation=record.guidActivationEvidence}
        end
        for i=#records,1,-1 do
            local ok,result=pcall(remove,records[i]);if not ok or result~=true then retained[#retained+1]=records[i] end
        end
        return {handles=retained,cleanupComplete=#retained==0}
    end
    local function valid(item)
        local function integer(n) return type(n)=='number' and n==n and n>=0 and n%1==0 and n<math.huge end
        return type(item)=='table' and type(item.nativeWeaponName)=='string' and item.nativeWeaponName:match('^WEAPON_[A-Z0-9_]+$')
            and ({[2]=true,[3]=true,[9]=true,[10]=true})[item.point] and integer(item.itemInstanceId) and item.itemInstanceId>0
            and integer(item.itemRevision) and type(item.serialNumber)=='string' and #item.serialNumber>0
            and type(item.attachments)=='table' and next(item.attachments)==nil and type(item.cosmetics)=='table' and next(item.cosmetics)==nil
            and type(item.maintenance)=='table' and type(item.maintenance.permanentDegradation)=='number'
            and item.maintenance.permanentDegradation>=0 and item.maintenance.permanentDegradation<=1
    end
    local function resolve(parent,name,slot)
        local out=buffer()
        return yes(Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,joaat(name),slot,out)) and out or nil
    end
    local function insert(item,parent,records,separate)
        local record={guid=buffer(),pairGrantPending=true,name=item.nativeWeaponName,point=item.point,
            itemInstanceId=item.itemInstanceId,itemRevision=item.itemRevision,serialNumber=item.serialNumber}
        attempts[#attempts+1]=record;records[#records+1]=record
        assert(yes(Citizen.InvokeNative(0xCB5D11F9508A928D,1,record.guid,parent,joaat(record.name),joaat('SLOTID_WEAPON_0'),1,joaat('ADD_REASON_DEFAULT'))),'guid_insert_unconfirmed')
        local key=WeaponCharacterAmmoCreationNative.GuidKey(record.guid);assert(key,'guid_insert_identity_unreadable')
        record.pairGrantPending=nil;owned[record]=key
        if separate then
            local moved=buffer();record.pairGrantPending=true
            assert(yes(Citizen.InvokeNative(0xDCCAA7C3BFD88862,1,record.guid,parent,joaat('SLOTID_WEAPON_1'),1,moved)),'guid_move_unconfirmed')
            local nextKey=WeaponCharacterAmmoCreationNative.GuidKey(moved);assert(nextKey,'guid_move_identity_unreadable')
            record.guid=moved;owned[record]=nextKey;record.pairGrantPending=nil
        end
        return record
    end
    local function activate(record,identity,target)
        assert(ready(identity),'guid_creation_identity_changed')
        local updated=WeaponCharacterAmmoCreationNative.PairRecord(inventory.read(record),record.guid,joaat(record.name),target)
        assert(updated,'guid_inventory_record_invalid')
        assert(inventory.update(record,updated)==true and ready(identity),'guid_inventory_update_failed')
        local read=inventory.read(record)
        assert(WeaponCharacterAmmoCreationNative.PairRecord(read,record.guid,joaat(record.name),target)
            and string.unpack('<I4',read,169)==1 and math.abs(string.unpack('<f',read,137)-target)<=0.0001,'guid_inventory_readback_mismatch')
        local accepted=inventory.activate(record);local detail=record.guidActivationEvidence or {}
        assert(accepted==true and ready(identity),('guid_options_activation_failed point=%s return=%s expected=%s output=%s')
            :format(record.point,tostring(detail.nativeReturn),tostring(detail.expectedGuid),tostring(detail.outputGuid)))
    end
    local function create(items,identity)
        if not ready(identity) then return nil,'guid_creation_lifecycle_not_ready' end
        if not guidIdentity or type(GetWeaponPermanentDegradation)~='function' or type(GetObjectIndexFromEntityIndex)~='function' then
            return nil,'guid_creation_readback_required'
        end
        for _,item in ipairs(items) do
            if not valid(item) then return nil,'guid_creation_identity_or_state_invalid' end
            if yes(HasPedGotWeapon(ped,joaat(item.nativeWeaponName),false)) then return nil,'guid_creation_preexisting_weapon' end
        end
        local records={}
        local ok,why=pcall(function()
            local character=resolve(nil,'CHARACTER',0xA1212100)
            local parent=character and resolve(character,'CARRIED_WEAPONS',joaat('SLOTID_CARRIED_WEAPONS'))
            assert(parent,'carried_weapon_inventory_unavailable')
            for index,item in ipairs(items) do
                assert(ready(identity),'guid_creation_identity_changed')
                insert(item,parent,records,#items==2 and index==1)
            end
            local guids={}
            for index,record in ipairs(records) do
                local key=WeaponCharacterAmmoCreationNative.GuidKey(record.guid)
                assert(not guids[key],'duplicate_inserted_guid');guids[key]=true
                activate(record,identity,items[index].maintenance.permanentDegradation)
                SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
                local settled,reason=settle({record},identity);assert(settled,reason)
            end
            Citizen.InvokeNative(0x94A3C1B804D291EC,ped,true,true,true,true)
            SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
            local settled,reason=settle(records,identity);assert(settled,reason)
            for index,record in ipairs(records) do
                local captured,reason=guidIdentity.Capture(record,identity);assert(captured,reason)
                record.guidIdentity={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
                assert(guidIdentity.MatchesCaptured(record,identity,WeaponCharacterAmmoCreationNative.GuidKey(record.guid)),'guid_created_identity_mismatch')
                local object=GetObjectIndexFromEntityIndex(record.entity)
                assert(type(object)=='number' and object>0,'guid_permanent_object_unavailable')
                local value=GetWeaponPermanentDegradation(object)
                assert(type(value)=='number' and value==value and math.abs(value-items[index].maintenance.permanentDegradation)<=0.0001,'guid_permanent_readback_mismatch')
                if applyMaintenance then local applied,reason=applyMaintenance(record,identity,items[index].maintenance);assert(applied==true,reason) end
            end
        end)
        if not ok then return nil,tostring(why),clean(records) end
        return records
    end
    return {current=ready,prepareDual=function(identity) return ready(identity) and prepareDual(ped)==true end,
        createSingle=function(item,ammo,identity)
            if ammo~=0 then return nil,'guid_creation_nonzero_ammo' end
            local records,reason,partial=create({item},identity)
            return records and records[1] or nil,reason,partial
        end,
        createPair=function(items,identity)
            if type(items)~='table' or #items~=2 or items[1].point~=2 or items[2].point~=3
                or items[1].nativeWeaponName~=items[2].nativeWeaponName then return nil,'guid_pair_layout_invalid' end
            return create(items,identity)
        end,remove=remove,creationFailureEvidence=function() return creationFailure end,
        creationAttemptHandles=function() return attempts end,
        finish=function(records,identity)
            if not ready(identity) then return false end
            SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
            for _,record in ipairs(records) do
                if entity(record.point,record.name)~=record.entity or inventory.pointGuid(record.point)~=owned[record] then return false end
            end
            return true
        end}
end

-- Lifecycle-bound factory only. Never assumes entitlement/appearance ownership;
-- caller supplies both preparation and cleanup for the same scoped setup.
function WeaponCharacterAmmoCreationNative.Scoped(ped,identity,prepareDual,cleanupDual,validationGuard)
    if type(identity)~='table' or type(identity.characterId)~='string'
        or type(identity.sessionId)~='string' or type(identity.epoch)~='string'
        or identity.characterId=='' or identity.sessionId=='' or identity.epoch==''
        or type(prepareDual)~='function' or type(cleanupDual)~='function' then
        return nil,'invalid_scoped_creation'
    end
    local expected={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
    local function current(check)
        if validationGuard and validationGuard()~=true then return false end
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
        and GetConvarInt('feather_native_saved_attachments',1)==1
    if Config.NativeAlphaRuntime==true and WeaponNativeEnrollment.Allows(Config,expected.characterId)
        and type(GetConvarInt)=='function' and GetConvarInt('feather_native_guid_ownership',1)==1 then
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
    if not guidIdentity then return nil,'guid_ownership_required' end
    local function resolveOwned(record,identity)
        if guidIdentity and guidIdentity.Has(record) then return guidIdentity.Resolve(record,identity) end
        return record.entity
    end
    local maintenance=WeaponCharacterMaintenanceNative.Scoped(ped,current,resolveOwned)
    local adapter=WeaponCharacterAmmoCreationNative.New(ped,current,prepareDual,function(record,check,values)
        return maintenance.Apply(record,check,values)
    end,guidIdentity)
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
