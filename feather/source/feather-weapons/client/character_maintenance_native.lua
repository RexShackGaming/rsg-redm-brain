-- Exact owned-record adapter; no model scan, ammo calls or runtime registration.
WeaponCharacterMaintenanceNative={}
-- Itemdatabase discovery only, not attachment installation/entitlement.
WeaponNativeAttachmentSlots={}
-- Dormant lifecycle composition; native factory/creation handoff are separate.
-- Retain partial attempts until exact child cleanup, never claim compensation
-- merely because creation did not reach its normal returned weapon handle.
WeaponNativeAttachmentReconstruction={}
function WeaponNativeAttachmentReconstruction.New(api)
    assert(type(api)=='table' and type(api.current)=='function' and type(api.probe)=='function','Local reconstruction dependencies required')
    local entries={}
    local function same(record,bound)
        for _,field in ipairs({'characterId','sessionId','epoch','serialNumber','nativeWeaponName'}) do
            if type(bound[field])~='string' or bound[field]=='' then return false end
        end
        for _,field in ipairs({'itemInstanceId','itemRevision'}) do
            local v=bound[field]
            if type(v)~='number' or v%1~=0 or v<0 or v==math.huge or (field=='itemInstanceId' and v==0) then return false end
        end
        local called,current=pcall(api.current,bound)
        return record.itemInstanceId==bound.itemInstanceId and record.itemRevision==bound.itemRevision
            and record.serialNumber==bound.serialNumber and record.name==bound.nativeWeaponName
            and called and current==true
    end
    local T={}
    function T.Apply(record,plan)
        if type(record)~='table' or type(plan)~='table' or type(plan.components)~='table' then return nil,'attachment_rebuild_invalid' end
        if entries[record] then return nil,'attachment_rebuild_already_attempted' end
        local bound={itemInstanceId=plan.itemInstanceId,itemRevision=plan.itemRevision,serialNumber=plan.serialNumber,
            nativeWeaponName=plan.nativeWeaponName,characterId=plan.characterId,sessionId=plan.sessionId,epoch=plan.epoch}
        if not same(record,bound) then return nil,'attachment_rebuild_copy_changed' end
        if next(plan.components)==nil then return true end
        local count,components,slots,nativeSlots=0,{},{},{}
        for key in pairs(plan.components) do
            if type(key)~='number' or key%1~=0 or key<1 or key>4 then return nil,'attachment_rebuild_components_invalid' end
            count=count+1
        end
        for index=1,count do
            local c=plan.components[index]
            if type(c)~='table' or type(c.slot)~='string' or slots[c.slot]
                or type(c.nativeSlot)~='number' or c.nativeSlot==0 or c.nativeSlot%1~=0 or nativeSlots[c.nativeSlot] then
                return nil,'attachment_rebuild_duplicate_or_missing_slot'
            end
            local allowed
            if api.validate then
                local ok,value=pcall(api.validate,bound,c)
                allowed=ok and value==true
            else
                allowed=c.definitionId=='carbine_wide_sight' and c.slot=='sight' and c.nativeSlot==468034421
                    and c.nativeComponentName=='COMPONENT_REPEATER_CARBINE_SIGHT_WIDE'
                    and c.stockComponentName=='COMPONENT_REPEATER_CARBINE_SIGHT_NARROW'
                    and bound.nativeWeaponName=='WEAPON_REPEATER_CARBINE'
            end
            if not allowed then return nil,'attachment_rebuild_unproved_component' end
            slots[c.slot]=true
            nativeSlots[c.nativeSlot]=true
            components[index]={definitionId=c.definitionId,slot=c.slot,nativeSlot=c.nativeSlot,
                nativeComponentName=c.nativeComponentName,stockComponentName=c.stockComponentName}
        end
        local entry={bound=bound,children={}}; entries[record]=entry -- reserve BEFORE factory/native work
        for _,component in ipairs(components) do
            local child={}; entry.children[#entry.children+1]=child
            local ok,probe=pcall(api.probe,record,bound,component)
            if not ok or type(probe)~='table' or type(probe.Run)~='function' or type(probe.Pending)~='function' then
                return nil,'attachment_rebuild_factory_unconfirmed_retained'
            end
            child.probe=probe
            if not same(record,bound) then return nil,'attachment_rebuild_copy_changed_retained' end
            local called,result,why=pcall(probe.Run,'install')
            if not called or type(result)~='table' or result.owned~=true or result.uncertain~=false or not same(record,bound) then
                return nil,why or 'attachment_rebuild_install_unconfirmed_retained'
            end
        end
        return true
    end
    function T.Cleanup(record)
        local entry=entries[record]
        if not entry then return true end
        if not same(record,entry.bound) then return nil,'attachment_rebuild_copy_changed_retained' end
        -- Reverse creation order; never forget an earlier child when a later
        -- install fails. Unknown factory outcomes retain the whole ownership.
        for index=#entry.children,1,-1 do
            local probe=entry.children[index].probe
            if not probe then return nil,'attachment_rebuild_factory_unconfirmed_retained' end
            local ok,pending=pcall(probe.Pending)
            if not ok then return nil,'attachment_rebuild_cleanup_unknown_retained' end
            if pending then
                local called,result=pcall(probe.Run,'remove')
                if not called or not result or result.owned~=false or result.uncertain~=false then
                    return nil,'attachment_rebuild_cleanup_failed_retained'
                end
            end
            local checked,remaining=pcall(probe.Pending)
            if not checked or remaining~=false or not same(record,entry.bound) then return nil,'attachment_rebuild_cleanup_failed_retained' end
        end
        entries[record]=nil
        return true
    end
    function T.Pending(record) return entries[record]~=nil end
    function T.AnyPending() return next(entries)~=nil end
    return T
end
-- Inert wrapper until explicitly supplied a trusted projector/native factory.
-- It composes with the existing loadout executor: handles are accepted BEFORE
-- finish applies attachments, so failed child setup has a retained owner.
function WeaponNativeAttachmentReconstruction.Bind(base,project,manager)
    assert(type(base)=='table' and type(project)=='function' and type(manager)=='table','Local attachment creation binding required')
    local bound,plans={},{}
    for key,value in pairs(base) do bound[key]=value end
    bound.createSingle=function(item,ammo,identity)
        if ammo~=0 or base.current(identity)~=true then return nil,'attachment_creation_scope_required' end
        local plan,why=project(item,identity)
        if not plan then return nil,why end
        local private={}
        for key,value in pairs(item) do private[key]=value end
        private.attachments={} -- projection, NOT saved metadata rewrite
        local record,reason=base.createSingle(private,ammo,identity)
        if not record then return nil,reason end
        plans[record]=plan
        return record
    end
    bound.finish=function(records,identity)
        if base.current(identity)~=true or base.finish(records,identity)~=true then return false end
        for _,record in ipairs(records) do
            local plan=plans[record]
            if plan and manager.Apply(record,plan)~=true then return false end
        end
        return base.current(identity)==true and base.finish(records,identity)==true
    end
    bound.remove=function(record)
        if manager.Cleanup(record)~=true then return false end
        local removed=base.remove(record)
        if removed==true then plans[record]=nil end
        return removed
    end
    if base.cleanupSetup then
        bound.cleanupSetup=function(...)
            if manager.AnyPending() then return nil,'attachment_children_cleanup_required' end
            return base.cleanupSetup(...)
        end
    end
    return bound
end
-- One fixed experimental child; never adopts an existing native inventory row.
WeaponNativeAttachmentChild={}
function WeaponNativeAttachmentChild.New(api)
    local owned,uncertain,stock
    local function current() return api.current()==true end
    local function inspect()
        if not current() then return nil,'child_context_changed' end
        local child=api.find()
        local count=api.count()
        local details=api.details and api.details() or nil
        if not current() then return nil,'child_context_changed' end
        return {child=child,owned=owned~=nil,uncertain=uncertain==true,
            preservedStockGuid=stock,
            slotCount=count,slotCountType=type(count),slotCountReadable=type(count)=='number' and count>=0 and count%1==0,
            slotDetails=details,noNativeWrites=true,noSQLWrites=true,noAmmoWrites=true,nativeInventoryOnly=true}
    end
    return {
        Pending=function() return owned~=nil or uncertain==true end,
        Run=function(action)
            if action=='status' then return inspect() end
            if not current() then return nil,'child_context_changed' end
            if uncertain then return nil,'child_unknown_outcome_retained' end
            if action=='install' then
                if owned then return nil,'child_existing_or_unreadable_slot_refused' end
                if api.stock then
                    local baseline=api.stock()
                    if not baseline or api.count()~=1 or api.find() or api.equipped()~=baseline then
                        return nil,'child_exact_stock_only_slot_required'
                    end
                    stock=baseline -- restoration authority only, NEVER removal authority
                elseif api.count()~=0 or api.find() then
                    return nil,'child_existing_or_unreadable_slot_refused'
                end
                if not current() then return nil,'child_context_changed' end
                -- Reserve before mutation. A failed/throwing native may have changed
                -- inventory; never retry it or fabricate cleanup acknowledgement.
                uncertain=true
                local child=api.add()
                if not child then return nil,'child_add_unconfirmed' end
                owned=child; uncertain=false
                if not current() then return nil,'child_context_changed_owned_retained' end
                if api.find()~=owned then return nil,'child_added_identity_mismatch_owned_retained' end
                if stock and (owned==stock or api.count()~=2 or api.stock()~=stock) then
                    return nil,'child_stock_changed_owned_retained'
                end
                if not current() then return nil,'child_context_changed_owned_retained' end
                if api.equip(owned)~=true then return nil,'child_equip_failed_owned_retained' end
                if stock and (not current() or api.equipped()~=owned) then return nil,'child_equip_readback_failed_owned_retained' end
                local out,why=inspect()
                if out then out.noNativeWrites=false end
                return out,why
            elseif action=='remove' then
                if not owned then return nil,'child_not_owned' end
                if api.count()~=(stock and 2 or 1) or api.find()~=owned or not current() then return nil,'child_identity_changed_owned_retained' end
                if stock then
                    local equipped=api.equipped()
                    if api.stock()~=stock or (equipped~=owned and equipped~=stock) or not current() then
                        return nil,'child_stock_changed_owned_retained'
                    end
                    if api.equip(stock)~=true then return nil,'child_stock_restore_failed_owned_retained' end
                    if not current() or api.equipped()~=stock or api.stock()~=stock then
                        return nil,'child_stock_restore_readback_failed_owned_retained'
                    end
                end
                if not current() then return nil,'child_context_changed_owned_retained' end
                if api.remove(owned)~=true then return nil,'child_remove_unconfirmed_owned_retained' end
                if not current() then return nil,'child_context_changed_owned_retained' end
                if api.find()~=nil then return nil,'child_remove_readback_failed_owned_retained' end
                if stock and (api.count()~=1 or api.stock()~=stock or api.equipped()~=stock or not current()) then
                    return nil,'child_final_stock_readback_failed_owned_retained'
                end
                owned=nil
                local out,why=inspect()
                if out then out.noNativeWrites=false end
                return out,why
            end
            return nil,'child_action_required'
        end,
    }
end
function WeaponNativeAttachmentSlots.Catalog(catalog,read)
    if type(catalog)~='table' or type(catalog.weapons)~='table' or type(catalog.attachments)~='table'
        or type(read)~='function' then return nil,'attachment_catalog_required' end
    local candidates={}
    for weaponId,weapon in pairs(catalog.weapons) do
        for slot,ids in pairs(weapon.attachmentSlots or {}) do
            for _,attachmentId in ipairs(ids) do
                local attachment=catalog.attachments[attachmentId]
                if not attachment or attachment.slot~=slot or type(weapon.nativeWeaponName)~='string'
                    or type(attachment.nativeComponentName)~='string' then return nil,'attachment_catalog_invalid' end
                candidates[#candidates+1]={weaponId=weaponId,attachmentId=attachmentId,slot=slot,
                    weaponName=weapon.nativeWeaponName,componentName=attachment.nativeComponentName}
                if #candidates>64 then return nil,'attachment_catalog_limit' end
            end
        end
    end
    table.sort(candidates,function(a,b) return a.weaponId..':'..a.attachmentId<b.weaponId..':'..b.attachmentId end)
    local out={items={},noNativeWrites=true,noSQLWrites=true,noAmmoWrites=true}
    for _,candidate in ipairs(candidates) do
        local called,value,why=pcall(read,candidate.weaponName,candidate.componentName)
        local entry={weaponId=candidate.weaponId,attachmentId=candidate.attachmentId,slot=candidate.slot}
        if called and value then
            entry.category=value.category; entry.compatibleSlots={}
            for _,row in ipairs(value.slots) do
                if row.wideSightCompatible then entry.compatibleSlots[#entry.compatibleSlots+1]=row.slot end
            end
            entry.uniqueCompatibleSlot=#entry.compatibleSlots==1
        else entry.error=called and why or 'attachment_slot_read_failed' end
        out.items[#out.items+1]=entry
    end
    return out -- compatibility discovery alone never authorizes reconstruction
end
function WeaponNativeAttachmentSlots.Read(api)
    if api.current()~=true then return nil,'attachment_slot_context_required' end
    local category=api.category()
    if type(category)~='number' or category==0 or category%1~=0 then return nil,'attachment_category_unavailable' end
    local count=api.count(category)
    if type(count)~='number' or count<0 or count>32 or count%1~=0 then return nil,'attachment_slot_count_invalid' end
    local out={category=category,slots={},noNativeWrites=true,noSQLWrites=true}
    local seen={}
    for index=0,count-1 do
        local slot=api.slot(category,index)
        if type(slot)~='number' or slot==0 or slot%1~=0 or seen[slot] then return nil,'attachment_slot_read_invalid' end
        seen[slot]=true
        local compatible=api.compatible(category,slot)
        if type(compatible)~='boolean' or api.current()~=true then return nil,'attachment_slot_context_changed' end
        out.slots[#out.slots+1]={slot=slot,wideSightCompatible=compatible}
    end
    if api.current()~=true then return nil,'attachment_slot_context_changed' end
    return out
end
-- Independent copy identity. This is not a model scan/adoption policy: only a
-- GUID captured from the exact created entity may authorize its representation.
WeaponNativeGuidIdentity={}
function WeaponNativeGuidIdentity.New(api,observationPoints)
    local bindings=setmetatable({},{__mode='k'})
    local points={0,1,2,3,9,10}
    if observationPoints~=nil then
        assert(type(observationPoints)=='table' and #observationPoints>0 and #observationPoints<=32,'Bounded native identity points required')
        points={}; local seen={}
        for _,point in ipairs(observationPoints) do
            assert(type(point)=='number' and point%1==0 and point>=0 and point<=31 and not seen[point],'Unique native identity points required')
            points[#points+1]=point; seen[point]=true
        end
    end
    local function key(value)
        return type(value)=='string' and #value==32 and value:match('^[0-9a-f]+$')
            and value~=string.rep('0',32)
    end
    local function matches(bound,record,identity)
        return type(identity)=='table' and api.current(identity)==true
            and bound.characterId==identity.characterId and bound.sessionId==identity.sessionId and bound.epoch==identity.epoch
            and record.name==bound.name and record.itemInstanceId==bound.id and record.itemRevision==bound.revision
            and record.serialNumber==bound.serial and record.entity==bound.entity
    end
    local function same(a,b)
        return a and b and a.entity==b.entity and a.hash==b.hash and a.guid==b.guid
    end
    local T={}
    function T.Capture(record,identity)
        if type(record)~='table' or type(record.entity)~='number' or record.entity<=0 or record.entity%1~=0
            or bindings[record] or type(identity)~='table' or api.current(identity)~=true then return false,'guid_capture_context' end
        for _,field in ipairs({'characterId','sessionId','epoch'}) do
            if type(identity[field])~='string' or identity[field]=='' then return false,'guid_capture_context' end
        end
        local value=api.point(record.point)
        if not value or value.entity~=record.entity or value.hash~=api.hash(record.name) or not key(value.guid)
            or api.exists(value.entity)~=true or not same(value,api.point(record.point)) or api.current(identity)~=true then
            return false,'guid_capture_exact_copy_required'
        end
        for _,bound in pairs(bindings) do if bound.guid==value.guid then return false,'guid_duplicate_capture' end end
        bindings[record]={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,
            name=record.name,id=record.itemInstanceId,revision=record.itemRevision,serial=record.serialNumber,
            entity=record.entity,guid=value.guid}
        return true
    end
    function T.Resolve(record,identity,exclusive)
        local bound=bindings[record]
        if not bound or not matches(bound,record,identity) then return nil,'guid_owner_context_changed' end
        local candidate,point,foreign
        for _,where in ipairs(points) do
            local value=api.point(where)
            if value and value.hash==api.hash(bound.name) and type(value.entity)=='number' and value.entity>0 then
                if value.guid==bound.guid then
                    if candidate and candidate.entity~=value.entity then return nil,'guid_ambiguous_objects' end
                    candidate,point=value,where
                else foreign=true end
            end
        end
        if exclusive and foreign then return nil,'guid_foreign_same_model_present' end
        if not candidate or api.exists(candidate.entity)~=true or not same(candidate,api.point(point))
            or not matches(bound,record,identity) then return nil,'guid_copy_not_settled' end
        if candidate.entity~=bound.entity then
            if api.exists(bound.entity)~=false then return nil,'guid_prior_representation_still_exists' end
            if not matches(bound,record,identity) then return nil,'guid_owner_context_changed' end
            -- The exact captured GUID, not the model, authorized this change.
            bound.entity=candidate.entity; record.entity=candidate.entity
        end
        return bound.entity
    end
    function T.Has(record) return bindings[record]~=nil end
    function T.MatchesCaptured(record,identity,guid)
        local bound=bindings[record]
        return bound~=nil and matches(bound,record,identity) and key(guid)~=nil and guid==bound.guid
    end
    return T
end
local fields={'degradation','permanentDegradation','damage','dirt','soot'}
local function unit(v) return type(v)=='number' and v==v and v>=0 and v<=1 end
function WeaponCharacterMaintenanceNative.New(api)
    for _,key in ipairs({'current','resolve','read','write'}) do
        assert(type(api[key])=='function','Local maintenance adapter required: '..key)
    end
    local T={}
    local function object(record,identity)
        if type(record)~='table' or type(record.entity)~='number' or record.entity<1
            or record.entity%1~=0 or record.entity==math.huge or api.current(identity)~=true then return nil end
        local resolved=api.resolve(record,identity)
        if api.current(identity)~=true or type(resolved)~='number' or resolved<=0
            or resolved%1~=0 or resolved==math.huge then return nil end
        return resolved
    end
    function T.Read(record,identity)
        local handle=object(record,identity)
        if not handle then return nil,'maintenance_owned_object_unavailable' end
        local values={}
        for _,key in ipairs(fields) do
            local called,value=pcall(api.read,handle,key)
            if not called or not unit(value) or object(record,identity)~=handle then
                return nil,'maintenance_readback_unavailable'
            end
            values[key]=value
        end
        return values
    end
    function T.Apply(record,identity,maintenance)
        if type(maintenance)~='table' then return false,'invalid_maintenance' end
        local target={}
        for _,key in ipairs(fields) do
            if not unit(maintenance[key]) then return false,'invalid_maintenance' end
            target[key]=maintenance[key]
        end
        target.degradation=math.max(target.permanentDegradation,target.degradation)
        target.damage=math.max(target.permanentDegradation,target.damage)
        local handle=object(record,identity)
        if not handle then return false,'maintenance_owned_object_unavailable' end
        -- Existing adapter has no proven permanent-degradation setter. Do not
        -- silently claim restoration of a nonmatching permanent native value.
        local values,reason=T.Read(record,identity)
        if not values then return false,reason end
        if math.abs(values.permanentDegradation-target.permanentDegradation)>0.0001 then
            return false,'permanent_degradation_restore_not_supported'
        end
        for _,key in ipairs({'degradation','damage','dirt','soot'}) do
            if object(record,identity)~=handle then return false,'maintenance_owner_changed' end
            local called,written=pcall(api.write,handle,key,target[key])
            if not called or written~=true then return false,'maintenance_write_failed' end
            if object(record,identity)~=handle then return false,'maintenance_owner_changed' end
        end
        local checked=T.Read(record,identity)
        if not checked then return false,'maintenance_readback_unavailable' end
        for _,key in ipairs(fields) do
            if math.abs(checked[key]-target[key])>0.0001 then return false,'maintenance_readback_mismatch' end
        end
        return true
    end
    return T
end
local function scoped(ped,current,deadRead,resolveOwned)
    local function yes(v) return v==true or v==1 end
    local getters={degradation=GetWeaponDegradation,permanentDegradation=GetWeaponPermanentDegradation,
        damage=GetWeaponDamage,dirt=GetWeaponDirt,soot=GetWeaponSoot}
    return WeaponCharacterMaintenanceNative.New({
        current=function(identity)
            return current(identity)==true and PlayerPedId()==ped
                and yes(DoesEntityExist(ped)) and yes(IsEntityDead(ped))==deadRead
        end,
        resolve=function(record,identity)
            if type(record.name)~='string' then return nil end
            if resolveOwned and resolveOwned(record,identity)~=record.entity then return nil end
            -- Locate the tracked entity even after draw/holster changes points.
            -- Matching model alone never establishes ownership of a copy.
            for _,point in ipairs({0,1,2,3,9,10}) do
                local present,hash=GetCurrentPedWeapon(ped,true,point,true)
                if yes(present) and hash==joaat(record.name)
                    and GetCurrentPedWeaponEntityIndex(ped,point)==record.entity
                    and yes(DoesEntityExist(record.entity)) then
                    return GetObjectIndexFromEntityIndex(record.entity)
                end
            end
        end,
        read=function(handle,key) return getters[key](handle) end,
        write=function(handle,key,value)
            if deadRead then return false end -- death readback never grants setters
            -- CfxLua preserves integer/float tags when marshalling natives.
            -- JSON and fixtures can produce integer 0/1; all wear setters take float.
            value=value+0.0
            if key=='degradation' then SetWeaponDegradation(handle,value)
            elseif key=='damage' then SetWeaponDamage(handle,value,false)
            elseif key=='dirt' then SetWeaponDirt(handle,value,false)
            elseif key=='soot' then SetWeaponSoot(handle,value,false)
            else return false end
            return true -- void setters require independent readback above
        end,
    })
end
function WeaponCharacterMaintenanceNative.Scoped(ped,current,resolveOwned)
    return scoped(ped,current,false,resolveOwned)
end
-- Read-only death evidence, not creation/repair/recovery authority. Independent
-- Medical-backed context checks surround every native read via the adapter.
function WeaponCharacterMaintenanceNative.DeathReadOnly(ped,identity,readContext)
    local expected={}
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(identity)~='table' or type(identity[key])~='string' or identity[key]=='' then return nil,'invalid_death_identity' end
        expected[key]=identity[key]
    end
    if type(readContext)~='function' then return nil,'missing_death_context' end
    local medicalRevision
    local adapter=scoped(ped,function(check)
        if type(check)~='table' then return false end
        for key,value in pairs(expected) do if check[key]~=value then return false end end
        local called,result=pcall(readContext)
        local value=called and type(result)=='table' and result.ok==true and result.value
        if type(value)~='table' or value.characterId~=expected.characterId or value.sessionId~=expected.sessionId
            or value.ped~=ped or value.lifeState~='dead' or type(value.medicalRevision)~='number'
            or value.medicalRevision<0 or value.medicalRevision%1~=0 or value.medicalRevision==math.huge then return false end
        if medicalRevision and medicalRevision~=value.medicalRevision then return false end
        medicalRevision=value.medicalRevision
        return true
    end,true)
    return {Read=adapter.Read} -- deliberately does not expose Apply/write
end
