-- Explicit diagnostic only. No SQL, saved equipment, ammunition or metadata writes.
-- Field layout comes from shop_gunsmith func_2374 / weapon_locker func_102
-- (1491.50). Unknown fields10/11 stay zero; this is NOT permanent-wear support.
WeaponNativePairOptionsProbe={}
local P=WeaponNativePairOptionsProbe
local function yes(v) return v==true or v==1 end
function P.GuidKey(raw)
    if type(raw)~='string' or #raw<32 then return nil end
    local words={}
    for i=0,3 do words[i+1]=string.unpack('<I4',raw,1+i*8) end
    local key=('%08x%08x%08x%08x'):format(table.unpack(words))
    return key~=string.rep('0',32) and key or nil
end
function P.Pack(guid,hash,point,reason)
    if not P.GuidKey(guid) or type(hash)~='number' or hash%1~=0 or hash==0
        or (point~=2 and point~=3) or type(reason)~='number' or reason%1~=0 then return nil end
    local function int(v) return string.pack('<I4I4',v & 0xffffffff,0) end
    local function float(v) return string.pack('<fI4',v,0) end
    return guid:sub(1,32)..int(hash)..int(0)..int(point)..int(reason)
        ..float(0.5)..float(1.0)..int(0)..int(0)..int(1)
end
function P.EnableInventoryRecord(raw,guid,hash)
    if type(raw)~='string' or #raw~=22*8 or not P.GuidKey(guid)
        or P.GuidKey(raw)~=P.GuidKey(guid) or string.unpack('<I4',raw,33)~=(hash & 0xffffffff) then
        return nil,'probe_inventory_record_mismatch'
    end
    local before=string.unpack('<I4',raw,169)
    if before~=0 and before~=1 then return nil,'probe_inventory_flag_unreadable' end
    -- Preserve the independently read native record; only the observed f_21
    -- flag changes, as in weapon_locker func_102. No permanent-wear offset guessed.
    return raw:sub(1,168)..string.pack('<I4I4',1,0),before
end
local function unit(v) return type(v)=='number' and v==v and v>=0 and v<=1 end
function P.WearFields(raw,guid,hash)
    if not P.EnableInventoryRecord(raw,guid,hash) then return nil end
    local values={}
    for field=16,20 do
        local value=string.unpack('<f',raw,field*8+1)
        if not unit(value) then return nil end
        values['field'..field]=value
    end
    return values
end
function P.SetTemporaryPermanent(raw,guid,hash,target)
    local fields=P.WearFields(raw,guid,hash)
    if not fields or not unit(target) then return nil end
    -- Only a newly inserted diagnostic record may reach this helper. Preserve
    -- every other byte, including native field padding and enable flag.
    return raw:sub(1,136)..string.pack('<f',target+0.0)..raw:sub(141)
end
-- Injectable orchestration exercises failure retention independently of natives.
function P.New(api)
    local attempted,busy=false,false
    local records,setup={},false
    local last={phase='idle',probeVersion=5,activationOrder='primary_then_offhand',expectedPermanent=api.expectedWear,
        noSQLWrites=true,noSavedEquipmentWrites=true,noAmmoWrites=true}
    local function cleanup()
        if not api.current() then return false,'probe_cleanup_context_changed' end
        local remaining={}
        for i=#records,1,-1 do
            local ok,removed=pcall(api.remove,records[i])
            if not ok or removed~=true then remaining[#remaining+1]=records[i] end
        end
        records=remaining
        if #records==0 and setup then
            local ok,removed=pcall(api.cleanupSetup)
            if ok and removed==true then setup=false end
        end
        if #records~=0 or setup then return false,'probe_native_resources_retained' end
        local ok,verified,why=pcall(api.verifyCleanup)
        return ok and verified==true,not ok and 'probe_cleanup_readback_failed' or why
    end
    local T={}
    function T.Status() return last end
    function T.Run()
        if attempted or busy or not api.current() then return nil,'probe_not_idle_or_current' end
        local permitted,why=api.preflight()
        if permitted~=true then return nil,why end
        attempted,busy,setup=true,true,true -- reserve before any setup/native mutation
        last.phase='running'
        local allAccepted=true
        local ok,failure=pcall(function()
            assert(api.prepare()==true,'probe_dual_setup_failed')
            for index=1,2 do
                assert(api.current(),'probe_context_changed')
                local record={point=index==1 and 2 or 3,pending=true,
                    expectedPermanent=api.expectedWear and api.expectedWear[index]}
                records[#records+1]=record -- unknown inserts remain owned and block retry
                assert(api.insert(record)==true,'probe_insert_failed')
                assert(record.guid and P.GuidKey(record.guid),'probe_guid_unreadable')
                record.pending=false
                if index==1 then assert(api.move(record)==true,'probe_move_failed') end
            end
            assert(P.GuidKey(records[1].guid)~=P.GuidKey(records[2].guid),'probe_duplicate_insert_guid')
            -- Unlike the established GUID path, inserting inventory records
            -- here has not yet created a ped primary. Establish it before the
            -- options call for offhand, which must not be activated alone.
            for _,index in ipairs({1,2}) do
                assert(api.current(),'probe_context_changed')
                local activated,detail=api.activate(records[index])
                last.activationCalls=last.activationCalls or {}
                last.activationCalls[#last.activationCalls+1]=detail or {point=records[index].point}
                if activated~=true then
                    allAccepted=false
                    -- Diagnostic observation only: a false return can still
                    -- accompany a populated output GUID. Do not retry this
                    -- copy. Observe both distinct, already-owned GUIDs once;
                    -- never turn a return mismatch into production acceptance.
                    assert(type(detail)=='table' and detail.callCompleted==true
                        and detail.guid and detail.outputGuid==detail.guid
                        and api.current(),'probe_options_activation_failed')
                end
            end
            local observed,why,evidence=api.verify(records)
            last.verification=evidence
            assert(observed,why)
            last.observed=observed
            if api.expectedWear then
                for index=1,2 do
                    local value=observed[index] and observed[index].permanentDegradation
                    assert(unit(value) and math.abs(value-api.expectedWear[index])<=0.0001,'probe_per_copy_permanent_mismatch')
                end
            end
        end)
        last.activation=ok and (allAccepted and 'verified' or 'verified_readback_return_mismatch') or 'failed'
        last.allNativeAccepted=allAccepted
        if not ok then last.reason=tostring(failure) end
        local cleaned,cleanupWhy=cleanup()
        last.cleanupComplete=cleaned
        last.cleanupReason=cleanupWhy
        last.retained=#records
        last.phase=ok and cleaned and allAccepted and (api.expectedWear and 'passed_permanent_pair' or 'passed_guid_activation') or 'review_required'
        busy=false
        return last
    end
    function T.Cleanup()
        if busy then return nil,'probe_busy' end
        last.cleanupComplete,last.cleanupReason=cleanup(); last.retained=#records
        return last
    end
    return T
end

local probe,calibration,inspection
RegisterCommand('weaponNativePairOptionsProbe',function(_,args)
    local action=args and args[1] or 'status'
    if action=='status' then return print('[WeaponNativePairOptionsProbe] '..json.encode(probe and probe.Status() or {phase='idle'})) end
    if action=='cleanup' then
        return print('[WeaponNativePairOptionsProbe] '..json.encode(probe and probe.Cleanup() or {phase='idle'}))
    end
    if action=='inspect-wear' and #args==1 and GetConvarInt('feather_native_pair_options_probe',0)==1 then
        calibration=nil
        local function inspect()
            local owner=WeaponCharacterAmmoActiveOwner
            local status=owner and owner.Status()
            local runtime=status and status.bootstrap and status.bootstrap.runtime
            assert(status and status.ownedCopies==1 and runtime and runtime.phase=='active'
                and not runtime.runtimeBusy and not runtime.quiescing and not runtime.receiving,'inspect_one_settled_firearm_required')
            local read=WeaponCharacterAmmoWorldContext.Read()
            local context=read and read.ok and read.value
            assert(context,'inspect_world_required')
            local maintenance=owner.MaintenanceStatus()
            local item=maintenance and maintenance.items and #maintenance.items==1 and maintenance.items[1]
            assert(item and item.maintenance and unit(item.maintenance.permanentDegradation)
                and item.maintenance.permanentDegradation>0,'inspect_nonzero_saved_permanent_required')
            local ped=context.ped
            local hash=joaat(item.name)
            local observed
            for _,point in ipairs({0,1,2,3,9,10}) do
                local present,model=GetCurrentPedWeapon(ped,true,point,true)
                local entity=GetCurrentPedWeaponEntityIndex(ped,point)
                if yes(present) and model==hash and type(entity)=='number' and entity>0 then
                    assert(not observed,'inspect_ambiguous_copy')
                    local guid=string.rep('\0',104)
                    assert(yes(Citizen.InvokeNative(0x6929E22158E52265,ped,point,guid)) and P.GuidKey(guid),'inspect_guid_unreadable')
                    local full=string.rep('\0',8*9)..string.pack('<I4I4',joaat('SLOTID_NONE') & 0xffffffff,0)..string.rep('\0',8*12)
                    assert(yes(Citizen.InvokeNative(0x025A1B1FB03FBF61,1,guid,full,22,1)),'inspect_full_record_unreadable')
                    local fields=P.WearFields(full,guid,hash)
                    assert(fields,'inspect_native_fields_invalid')
                    local object=GetObjectIndexFromEntityIndex(entity)
                    assert(type(object)=='number' and object>0,'inspect_object_unavailable')
                    local permanent=GetWeaponPermanentDegradation(object)
                    assert(unit(permanent) and permanent>0,'inspect_native_permanent_unavailable')
                    assert(math.abs(permanent-item.maintenance.permanentDegradation)<=0.0001,'inspect_saved_native_permanent_mismatch')
                    assert(math.abs(fields.field17-permanent)<=0.0001,'inspect_field17_native_mismatch')
                    local afterGuid=string.rep('\0',104)
                    assert(yes(Citizen.InvokeNative(0x6929E22158E52265,ped,point,afterGuid))
                        and P.GuidKey(afterGuid)==P.GuidKey(guid) and GetCurrentPedWeaponEntityIndex(ped,point)==entity,'inspect_copy_changed')
                    observed={itemId=item.itemInstanceId,point=point,guid=P.GuidKey(guid),nativePermanent=permanent,fields=fields}
                end
            end
            assert(observed,'inspect_owned_copy_not_found')
            local after=owner.Status()
            local afterRuntime=after.bootstrap and after.bootstrap.runtime
            local world=WeaponCharacterAmmoWorldContext.Read()
            local c=world and world.ok and world.value
            assert(after.ownedCopies==1 and afterRuntime and afterRuntime.phase=='active' and afterRuntime.epoch==runtime.epoch
                and c and c.characterId==context.characterId and c.sessionId==context.sessionId and c.ped==ped,'inspect_context_changed')
            calibration={characterId=context.characterId,sessionId=context.sessionId,ped=ped,itemId=observed.itemId}
            return observed
        end
        local ok,value=pcall(inspect)
        inspection={probeVersion=5,phase=ok and 'verified_field17' or 'review_required',readOnly=true,
            noSQLWrites=true,noNativeWrites=true,noSavedEquipmentWrites=true,observed=ok and value or nil,
            reason=not ok and tostring(value) or nil}
        return print('[WeaponNativePairOptionsProbe] '..json.encode(inspection))
    end
    local wearMode=action=='run' and #args==2 and args[2]=='wear'
    if action~='run' or (not wearMode and #args~=1) or GetConvarInt('feather_native_pair_options_probe',0)~=1 then
        return print('[WeaponNativePairOptionsProbe] REFUSED explicit run opt-in required')
    end
    if probe then return print('[WeaponNativePairOptionsProbe] REFUSED already attempted; retain status') end
    local owner=WeaponCharacterAmmoActiveOwner
    local status=owner and owner.Status()
    local runtime=status and status.bootstrap and status.bootstrap.runtime
    if not status or status.ownedCopies~=0 or status.cleanupComplete~=true or not runtime or runtime.phase~='closed' then
        return print('[WeaponNativePairOptionsProbe] REFUSED prepare-stop must finish first; zero native owners required')
    end
    local read=WeaponCharacterAmmoWorldContext.Read()
    if not read or not read.ok then return print('[WeaponNativePairOptionsProbe] REFUSED world unavailable') end
    local bound=read.value
    local ped=bound.ped
    if wearMode and (not calibration or calibration.characterId~=bound.characterId
        or calibration.sessionId~=bound.sessionId or calibration.ped~=ped) then
        return print('[WeaponNativePairOptionsProbe] REFUSED verified inspect-wear required in this same player session')
    end
    local hash=joaat('WEAPON_REVOLVER_CATTLEMAN')
    local parent
    local ammoBefore
    local function ammoSnapshot()
        local values={}
        for id,definition in pairs(WeaponDefinitionCatalog.ammunition) do
            local value=GetPedAmmoByType(ped,joaat(definition.nativeAmmoName))
            assert(type(value)=='number' and value>=0 and value%1==0,'probe_ammo_read_unavailable')
            values[id]=value
        end
        return values
    end
    local function current()
        local s=owner.Status()
        local r=s.bootstrap and s.bootstrap.runtime
        local read=WeaponCharacterAmmoWorldContext.Read()
        local c=read and read.ok and read.value
        return s.ownedCopies==0 and s.cleanupComplete==true and r and r.phase=='closed'
            and c and c.characterId==bound.characterId and c.sessionId==bound.sessionId and c.ped==ped
            and PlayerPedId()==ped
    end
    local dual=WeaponCharacterAmmoDualNative.New(ped,current)
    local function buffer() return string.rep('\0',104) end
    local function resolve(parent,name,slot)
        local out=buffer()
        return yes(Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,joaat(name),slot,out)) and out or nil
    end
    probe=P.New({current=current,expectedWear=wearMode and {0.1,0.25} or nil,
        preflight=function()
            if yes(HasPedGotWeapon(ped,hash,false)) then return nil,'preexisting_cattleman_refused' end
            ammoBefore=ammoSnapshot()
            local character=resolve(nil,'CHARACTER',0xA1212100)
            parent=character and resolve(character,'CARRIED_WEAPONS',joaat('SLOTID_CARRIED_WEAPONS'))
            return parent~=nil,'carried_inventory_unavailable'
        end,
        prepare=function() return dual.Ensure() end,
        cleanupSetup=function() return dual.Cleanup() end,
        verifyCleanup=function()
            if not current() then return false,'probe_cleanup_context_changed' end
            if yes(HasPedGotWeapon(ped,hash,false)) then return false,'probe_native_model_remains' end
            local after=ammoSnapshot()
            for id,value in pairs(ammoBefore) do if after[id]~=value then return false,'probe_ammo_changed:'..id end end
            return true
        end,
        insert=function(record)
            local raw=buffer()
            if not yes(Citizen.InvokeNative(0xCB5D11F9508A928D,1,raw,parent,hash,joaat('SLOTID_WEAPON_0'),1,joaat('ADD_REASON_DEFAULT'))) then return false end
            record.guid=raw
            -- Locker/options activation operates on the inventory record; it
            -- does not first activate through InventoryEquipItemWithGuid.
            return current()
        end,
        move=function(record)
            local moved=buffer()
            if not yes(Citizen.InvokeNative(0xDCCAA7C3BFD88862,1,record.guid,parent,joaat('SLOTID_WEAPON_1'),1,moved)) then return false end
            record.guid=moved
            return current() and P.GuidKey(moved)~=nil
        end,
        activate=function(record)
            local detail={point=record.point,guid=P.GuidKey(record.guid),stage='read_inventory_record'}
            local function fullRecord()
                local raw=string.rep('\0',8*9)..string.pack('<I4I4',joaat('SLOTID_NONE') & 0xffffffff,0)..string.rep('\0',8*12)
                local returned=Citizen.InvokeNative(0x025A1B1FB03FBF61,1,record.guid,raw,22,1)
                if not yes(returned) or not current() then return nil end
                return raw
            end
            local full=fullRecord()
            if not full then return false,detail end
            local enabled,prior=P.EnableInventoryRecord(full,record.guid,hash)
            detail.priorFlag=prior
            if not enabled then detail.reason=prior; return false,detail end
            if record.expectedPermanent~=nil then
                detail.stage='prepare_temporary_permanent'
                detail.expectedPermanent=record.expectedPermanent
                enabled=P.SetTemporaryPermanent(enabled,record.guid,hash,record.expectedPermanent)
                if not enabled then return false,detail end
            end
            if prior==0 or record.expectedPermanent~=nil then
                detail.stage='enable_inventory_record'
                local updated=Citizen.InvokeNative(0xD80A8854DB5CFBA5,1,record.guid,enabled,22)
                detail.updateReturnType=type(updated); detail.updateReturn=tostring(updated)
                if not yes(updated) or not current() then return false,detail end
            end
            detail.stage='verify_inventory_record'
            local checked=fullRecord()
            local verified,flag
            if checked then verified,flag=P.EnableInventoryRecord(checked,record.guid,hash) end
            if not verified or flag~=1 then return false,detail end
            if record.expectedPermanent~=nil then
                local fields=P.WearFields(checked,record.guid,hash)
                detail.inventoryPermanent=fields and fields.field17
                if not fields or math.abs(fields.field17-record.expectedPermanent)>0.0001 then return false,detail end
            end
            local input=assert(P.Pack(record.guid,hash,record.point,joaat('ADD_REASON_DEFAULT')))
            local output=string.rep('\0',8*24)
            detail.stage='activate_options'
            local returned=Citizen.InvokeNative(0xBE7E42B07FD317AC,ped,input,output)
            detail.callCompleted=true
            detail.nativeReturnType=type(returned); detail.nativeReturn=tostring(returned)
            detail.outputGuid=P.GuidKey(output)
            detail.nativeAccepted=yes(returned)
            return yes(returned) and current(),detail
        end,
        verify=function(records)
            Citizen.InvokeNative(0x94A3C1B804D291EC,ped,true,true,true,true)
            SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
            local latest
            for frame=1,120 do
                if not current() then return nil,'probe_context_changed' end
                local observed,entities,allValid={},{},true
                latest={}
                for index,record in ipairs(records) do
                    local present,model=GetCurrentPedWeapon(ped,true,record.point,true)
                    local entity=GetCurrentPedWeaponEntityIndex(ped,record.point)
                    local raw=buffer()
                    local readable=yes(present) and model==hash and type(entity)=='number' and entity>0
                        and yes(Citizen.InvokeNative(0x6929E22158E52265,ped,record.point,raw))
                    local actual=readable and P.GuidKey(raw) or nil
                    latest[index]={point=record.point,expectedGuid=P.GuidKey(record.guid),actualGuid=actual,
                        entity=entity,weaponHash=model,present=yes(present)}
                    local valid=actual==P.GuidKey(record.guid) and type(entity)=='number' and entity>0 and not entities[entity]
                    if valid then
                        entities[entity]=true
                        local object=GetObjectIndexFromEntityIndex(entity)
                        local wear=type(object)=='number' and object>0 and GetWeaponPermanentDegradation(object) or nil
                        if type(wear)=='number' and wear==wear and wear>=0 and wear<=1 then
                            observed[index]={point=record.point,guid=actual,entity=entity,permanentDegradation=wear}
                        else valid=false end
                    end
                    if not valid then allValid=false end
                end
                if allValid and #observed==2 and current() then return observed,nil,latest end
                Wait(0)
            end
            return nil,'probe_distinct_guid_points_not_verified',latest
        end,
        remove=function(record)
            if record.pending or not P.GuidKey(record.guid) or not current() then return false end
            return yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,record.guid,1,joaat('REMOVE_REASON_DEFAULT')))
        end})
    CreateThread(function()
        local result,why=probe.Run()
        print('[WeaponNativePairOptionsProbe] '..(result and json.encode(result) or 'REFUSED '..tostring(why)))
    end)
end,false)
