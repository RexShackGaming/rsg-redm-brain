-- Factory-only port of the accepted ammo-free GiveWeaponToPed path, with new
-- ownership barriers. No registration/automatic grant; admission is default-off.
WeaponNativeKnifeOwner={}
local function copy(t)
    if type(t)~='table' then return t end
    local result={}; for k,v in pairs(t) do result[k]=copy(v) end; return result
end
function WeaponNativeKnifeOwner.New(api,definition,identity)
    for _,key in ipairs({'current','present','grant','observe','remove'}) do
        assert(type(api)=='table' and type(api[key])=='function','Local knife adapter required: '..key)
    end
    -- Validate/copy the world identity without granting or manufacturing a row.
    local bound={}
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        local value=type(identity)=='table' and identity[key]
        if type(value)~='string' or #value<1 or #value>128 or value:find('%c') then return nil,'knife_identity_required' end
        bound[key]=value
    end
    local state,record,reason,cleanupEvidence='idle',nil,nil,nil
    local function current()
        local ok,value=pcall(api.current,copy(bound)); return ok and value==true
    end
    local function call(name,...)
        local ok,value=pcall(api[name],...); return ok,value
    end
    local function inspect()
        if not record or not record.entity or type(api.inspect)~='function' then return nil end
        local ok,value=pcall(api.inspect,record.entity,copy(bound))
        return ok and type(value)=='table' and copy(value) or {readFailed=true}
    end
    local function retain(why) state='retained'; reason=why; return nil,why end
    local function exactObservation()
        local ok,entities=call('observe',copy(bound))
        if not ok or type(entities)~='table' or #entities~=1 then return nil end
        for key in pairs(entities) do if key~=1 then return nil end end
        local entity=entities[1]
        if type(entity)~='number' or entity<1 or entity%1~=0 or entity==math.huge then return nil end
        return entity
    end
    local T={}
    function T.Status()
        return {phase=state,reason=reason,identity=copy(bound),itemId=record and record.itemInstanceId,
            itemRevision=record and record.itemRevision,entity=record and record.entity,cleanupEvidence=copy(cleanupEvidence),
            observation=state=='retained' and inspect() or nil,guidOwnershipCaptured=record and record.guidOwnershipCaptured or false}
    end
    function T.Create(row)
        if state~='idle' then return nil,'knife_creation_already_attempted' end
        local projected,why=WeaponNativeKnife.Project(row,definition,bound)
        if not projected then return nil,why end
        if not current() then return nil,'knife_world_changed' end
        state='preflight' -- reserve before even a yielding adapter read
        local checked,present=call('present',copy(bound))
        if not checked or present~=false or not current() then return retain('knife_preexisting_or_unconfirmed') end
        record=projected
        state='creating' -- grant may throw AFTER creating; never assume compensation
        local called,granted=call('grant',copy(bound))
        if not called or granted~=true or not current() then return retain('knife_grant_unconfirmed_no_retry') end
        local entity=exactObservation()
        if not entity or not current() then return retain('knife_created_copy_unresolved_no_retry') end
        record.entity=entity
        if type(api.capture)=='function' then
            local captured,value=call('capture',record,copy(bound))
            if not captured or value~=true or not current() then return retain('melee_guid_capture_unconfirmed') end
            record.guidOwnershipCaptured=true
        end
        state='active'
        return copy(record)
    end
    function T.Release(deathRecovery)
        if state=='released' then return true end
        -- Unknown grants remain held for explicit investigation, not a model wipe.
        if state~='active' or not record or not record.entity then return nil,'knife_exact_cleanup_unavailable' end
        state='releasing' -- block reentrant creation/release while adapters yield
        cleanupEvidence=inspect() -- diagnostics only; never grants cleanup authority
        if not current() then return retain('knife_cleanup_world_changed') end
        local guidUnresolved=false
        if type(api.resolve)=='function' then
            local resolved,entity,why=pcall(api.resolve,record,copy(bound))
            if not resolved or type(entity)~='number' or entity~=record.entity or not current() then
                guidUnresolved=true
                cleanupEvidence=cleanupEvidence or {}
                cleanupEvidence.guidReason=resolved and type(why)=='string' and why or 'guid_resolution_unconfirmed'
                if resolved and why=='guid_copy_not_settled' and type(api.removeCapturedInventory)=='function' then
                    local checked,removed,evidence=pcall(api.removeCapturedInventory,record,copy(bound))
                    if checked and type(evidence)=='table' then cleanupEvidence.inventory=evidence end
                    if checked and removed==true and current() then
                        state='released'; reason='melee_captured_inventory_removed'; return true
                    end
                    -- This adapter may have removed the native entry. Never run
                    -- another removal or manufacture a retry after uncertainty.
                    return retain('melee_inventory_cleanup_unconfirmed')
                end
                -- Positive disappearance still needs the existing death-only proof.
                if deathRecovery~=true then return retain('melee_guid_cleanup_unconfirmed') end
            end
        end
        if guidUnresolved or exactObservation()~=record.entity then
            -- Death may destroy an owned object before doctor cleanup. Only an
            -- explicit recovery can accept positively proven disappearance;
            -- never adopt/remove a replacement or infer absence from enumeration.
            if deathRecovery==true and type(api.absent)=='function' then
                local checked,absent,evidence=pcall(api.absent,record.entity,copy(bound))
                if checked and type(evidence)=='table' then cleanupEvidence=copy(evidence) end
                if checked and absent==true and current() then
                    state='released'; reason='death_owned_copy_already_absent'; return true
                end
            end
            return retain('knife_cleanup_identity_unconfirmed')
        end
        if not current() then return retain('knife_cleanup_world_changed') end
        local called,removed=call('remove',record.entity,copy(bound))
        if not called or removed~=true or not current() then return retain('knife_cleanup_unconfirmed_no_retry') end
        local checked,present=call('present',copy(bound))
        if not checked or present~=false or not current() then return retain('knife_cleanup_presence_unconfirmed') end
        state='released'; return true
    end
    return T
end
function WeaponNativeKnifeOwner.Scoped(ped,identity,current,definition)
    assert(type(current)=='function','Local knife lifecycle required')
    definition=definition or WeaponDefinitionCatalog.weapons.melee_knife
    local profile=WeaponNativeMeleeCatalog and WeaponNativeMeleeCatalog.Resolve(definition)
    if not profile then
        if WeaponNativeMeleeCatalog or type(definition)~='table' or definition.id~='melee_knife' then
            return nil,'unsupported_native_melee_definition'
        end
        profile={nativeWeaponName='WEAPON_MELEE_KNIFE',nativeGrantAmount=0}
    end
    local model,grantAmount=profile.nativeWeaponName,profile.nativeGrantAmount
    local function yes(v) return v==true or v==1 end
    local function valid(check)
        return PlayerPedId()==ped and yes(DoesEntityExist(ped)) and current(check)==true
    end
    local function present()
        return yes(HasPedGotWeapon(ped,joaat(model),false))
    end
    local settling=false
    local function scan()
        local entities,seen={},{}
        -- Enumeration is read-only. Default grant point0 is the prior accepted
        -- wheel behavior, NOT a claim that a holstered knife occupies point0.
        for point=0,31 do
            local found,hash=GetCurrentPedWeapon(ped,true,point,true)
            if yes(found) and hash==joaat(model) then
                local entity=GetCurrentPedWeaponEntityIndex(ped,point)
                if type(entity)~='number' or entity<=0 or not yes(DoesEntityExist(entity)) then return {} end
                if not seen[entity] then entities[#entities+1]=entity; seen[entity]=true end
            end
        end
        return entities
    end
    local function observe(check)
        if not settling then return scan() end
        settling=false
        local started=GetGameTimer()
        for frame=1,120 do
            if not valid(check) then return {} end
            local entities=scan()
            if #entities>0 then return entities end
            if (GetGameTimer()-started)%4294967296>=1500 then break end
            Wait(0)
        end
        return {} -- unresolved creation is retained; never model-wide rollback
    end
    local guidIdentity
    local capturedInventory=setmetatable({},{__mode='k'})
    if Config.NativeAlphaRuntime==true then
        if not WeaponNativeGuidIdentity or not WeaponCharacterAmmoCreationNative or not Citizen then
            return nil,'melee_guid_components_unavailable'
        end
        local points={}; for point=0,31 do points[#points+1]=point end
        guidIdentity=WeaponNativeGuidIdentity.New({current=valid,hash=joaat,
            exists=function(entity) return yes(DoesEntityExist(entity)) end,
            point=function(point)
                if not valid(identity) then return nil end
                local found,hash=GetCurrentPedWeapon(ped,true,point,true)
                local entity=GetCurrentPedWeaponEntityIndex(ped,point)
                if not yes(found) or hash~=joaat(model) or type(entity)~='number' or entity<=0 then return nil end
                local raw=string.rep('\0',104)
                local result=Citizen.InvokeNative(0x6929E22158E52265,ped,point,raw)
                if not yes(result) then return nil end
                local guid=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
                if not guid then return nil end
                local w=guid.scriptSlotWords
                local key=('%08x%08x%08x%08x'):format(w[1],w[2],w[3],w[4])
                local after,afterHash=GetCurrentPedWeapon(ped,true,point,true)
                if not valid(identity) or not yes(after) or afterHash~=hash
                    or GetCurrentPedWeaponEntityIndex(ped,point)~=entity then return nil end
                return {entity=entity,hash=hash,guid=key}
            end},points)
    end
    local api={current=valid,present=present,observe=observe,
        inspect=function(entity,check)
            local points={}
            for point=0,31 do
                local found,hash=GetCurrentPedWeapon(ped,true,point,true)
                if yes(found) and hash==joaat(model) then
                    local value=GetCurrentPedWeaponEntityIndex(ped,point)
                    points[#points+1]={point=point,entity=value,tracked=value==entity,
                        exists=type(value)=='number' and value>0 and yes(DoesEntityExist(value)) or false}
                end
            end
            return {current=valid(check),trackedExists=DoesEntityExist(entity),
                modelPresent=HasPedGotWeapon(ped,joaat(model),false),points=points}
        end,
        absent=function(entity,check)
            -- All independent reads must agree in the same current world.
            if not valid(check) then return false,{current=false} end
            local exists=DoesEntityExist(entity)
            local modelPresent=HasPedGotWeapon(ped,joaat(model),false)
            local observed=#scan()
            local sameWorld=valid(check)
            return exists==false and modelPresent==false and observed==0 and sameWorld,
                {current=sameWorld,trackedExists=exists,modelPresent=modelPresent,observedCount=observed}
        end,
        grant=function(check)
            if not valid(check) or yes(IsEntityDead(ped)) then return false end
            -- Reuse accepted ammo-free grant arguments only: no SetPedAmmo,
            -- selected-type/clip writes, maintenance setters or offhand changes.
            settling=true
            GiveWeaponToPed(ped,joaat(model),grantAmount,false,true,0,false,
                0.5,1.0,joaat('ADD_REASON_DEFAULT'),true,0.0,false)
            return true
        end,
        remove=function(entity,check)
            local found=scan()
            if not valid(check) or #found~=1 or found[1]~=entity then return false end
            -- Match the previously accepted melee removal path. DEFAULT was
            -- used for entitlement inventory items, not owned weapon purging.
            RemoveWeaponFromPed(ped,joaat(model),true,joaat('REMOVE_REASON_CLIENT_PURGED'))
            return not present()
        end,
    }
    if guidIdentity then
        api.capture=function(record,check)
            record.name=model
            for point=0,31 do
                local found,hash=GetCurrentPedWeapon(ped,true,point,true)
                if yes(found) and hash==joaat(model) and GetCurrentPedWeaponEntityIndex(ped,point)==record.entity then
                    record.point=point
                    local ok,why=guidIdentity.Capture(record,check)
                    if not ok then return false,why end
                    -- Re-read the original point, binding only the GUID that
                    -- was independently captured for this exact owned entity.
                    local raw=string.rep('\0',104)
                    if not yes(Citizen.InvokeNative(0x6929E22158E52265,ped,point,raw)) then return false end
                    local guid=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
                    if not guid then return false end
                    local w=guid.scriptSlotWords
                    local key=('%08x%08x%08x%08x'):format(w[1],w[2],w[3],w[4])
                    if not guidIdentity.MatchesCaptured(record,check,key) or not valid(check)
                        or GetCurrentPedWeaponEntityIndex(ped,point)~=record.entity then return false end
                    capturedInventory[record]={guid=key,raw=raw}
                    return true
                end
            end
            return false
        end
        api.resolve=function(record,check) return guidIdentity.Resolve(record,check,true) end
        api.removeCapturedInventory=function(record,check)
            local captured=capturedInventory[record]
            if not captured or not guidIdentity.Has(record) or not valid(check)
                or DoesEntityExist(record.entity)~=false or #scan()~=0 then return false,{preflight=false} end
            -- InventoryGetInventoryItem reads a captured GUID even when its
            -- world representation is hidden. Same verified layout as the
            -- existing native child/attachment inventory reader.
            local raw=string.rep('\0',104)
            local result=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,captured.raw,raw,true)
            local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,result)
            local guid=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
            if not item or not guid then return false,{readConfirmed=false} end
            local w=guid.scriptSlotWords
            local key=('%08x%08x%08x%08x'):format(w[1],w[2],w[3],w[4])
            local matched=key==captured.guid and item.itemHash==(joaat(model) & 0xffffffff)
            if not matched or not valid(check) or DoesEntityExist(record.entity)~=false or #scan()~=0 then
                return false,{readConfirmed=true,guidAndModelMatched=matched}
            end
            local removed=Citizen.InvokeNative(0x3E4E811480B3AE79,1,captured.raw,1,joaat('REMOVE_REASON_CLIENT_PURGED'))
            local absent=not present() and #scan()==0 and DoesEntityExist(record.entity)==false
            return yes(removed) and absent and valid(check),
                {readConfirmed=true,guidAndModelMatched=true,removeAcknowledged=yes(removed),modelAbsent=absent}
        end
    end
    return WeaponNativeKnifeOwner.New(api,definition,identity)
end
