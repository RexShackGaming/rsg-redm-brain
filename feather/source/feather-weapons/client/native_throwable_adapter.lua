-- Concrete but inert port: no registration, activation, grants or loops on load.
WeaponNativeThrowableAdapter={}
function WeaponNativeThrowableAdapter.Scoped(ped,identity,current,sealed,catalog,registry)
    assert(type(current)=='function' and type(sealed)=='function','Local parent throwable lifecycle required')
    if type(identity)~='table' then return nil,'throwable_identity_required' end
    identity={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
    local profile,why=WeaponNativeThrowablePolicy.Resolve(catalog)
    if not profile then return nil,why end
    if not WeaponNativeGuidIdentity or not WeaponCharacterAmmoCreationNative or not WeaponCharacterAmmoNative
        or type(registry)~='table' or type(registry.names)~='table' or type(registry.limits)~='table'
        or registry.names.ammo_tomahawk_regular~='AMMO_TOMAHAWK'
        or registry.limits.ammo_tomahawk_regular~=1 then return nil,'throwable_native_components_required' end
    local def=profile.definition
    local function yes(v) return v==true or v==1 end
    local function valid(check)
        return PlayerPedId()==ped and yes(DoesEntityExist(ped)) and type(check)=='table'
            and check.characterId==identity.characterId and check.sessionId==identity.sessionId and check.epoch==identity.epoch
            and current({characterId=check.characterId,sessionId=check.sessionId,epoch=check.epoch})==true
    end
    local model,ammo=joaat(def.nativeWeaponName),joaat(profile.ammunition.nativeAmmoName)
    local function quantity() return GetPedAmmoByType(ped,ammo) end
    local function present() return yes(HasPedGotWeapon(ped,model,false)) end
    local function key(raw)
        local decoded=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
        if not decoded then return nil end
        local w=decoded.scriptSlotWords
        return ('%08x%08x%08x%08x'):format(w[1],w[2],w[3],w[4])
    end
    local points={}; for point=0,31 do points[#points+1]=point end
    local function pointRead(point)
        if not valid(identity) then return nil end
        local found,hash=GetCurrentPedWeapon(ped,true,point,true)
        local entity=GetCurrentPedWeaponEntityIndex(ped,point)
        if not yes(found) or hash~=model or type(entity)~='number' or entity<=0 then return nil end
        local raw=string.rep('\0',104)
        if not yes(Citizen.InvokeNative(0x6929E22158E52265,ped,point,raw)) then return nil end
        local guid=key(raw)
        local after,afterHash=GetCurrentPedWeapon(ped,true,point,true)
        if not guid or not valid(identity) or not yes(after) or afterHash~=hash
            or GetCurrentPedWeaponEntityIndex(ped,point)~=entity then return nil end
        return {entity=entity,hash=hash,guid=guid,raw=raw,point=point}
    end
    local resolver=WeaponNativeGuidIdentity.New({current=valid,hash=joaat,point=pointRead,
        exists=function(entity) return yes(DoesEntityExist(entity)) end},points)
    local owned,buffer
    -- Throwables may be inventory-present without an attach-point entity.
    -- Resolve only the original carried-inventory hierarchy and two weapon
    -- slots; independently read back exact GUID/model before accepting it.
    local function inventoryGuid()
        local function resolve(parent,item,slot)
            local raw=string.rep('\0',104)
            local found=Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,item,slot,raw)
            if not valid(identity) then return nil,'throwable_creation_context_changed' end
            if found==false or found==0 then return false end
            if not yes(found) or not key(raw) then return nil,'throwable_inventory_guid_unreadable' end
            return raw
        end
        local character,why=resolve(nil,joaat('CHARACTER'),0xA1212100)
        if not character then return nil,why or 'throwable_inventory_parent_unavailable' end
        local parent; parent,why=resolve(character,joaat('CARRIED_WEAPONS'),joaat('SLOTID_CARRIED_WEAPONS'))
        if not parent then return nil,why or 'throwable_inventory_parent_unavailable' end
        local selected
        for slot=0,1 do
            local raw; raw,why=resolve(parent,model,joaat(('SLOTID_WEAPON_%d'):format(slot)))
            if raw==nil then return nil,why end
            if raw then
                if selected then return nil,'throwable_inventory_guid_ambiguous' end
                local read=string.rep('\0',104)
                local result=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,raw,read,true)
                local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(read,result)
                if not item or item.itemHash~=(model & 0xffffffff) or key(read)~=key(raw) or not valid(identity) then
                    return nil,'throwable_inventory_guid_readback_failed'
                end
                selected={raw=raw,guid=key(raw)}
            end
        end
        return selected or false
    end
    local native=WeaponCharacterAmmoNative.New(registry.names,registry.limits)
    if not native then return nil,'throwable_ammo_adapter_required' end
    local function exact(handle,check)
        return owned and handle.guid==owned.guid and handle.itemId==owned.itemInstanceId
            and handle.itemRevision==owned.itemRevision and valid(check)
    end
    local function anyVisible()
        for _,point in ipairs(points) do
            local found,hash=GetCurrentPedWeapon(ped,true,point,true)
            if yes(found) and hash==model then return true end
        end
        return false
    end
    return WeaponNativeThrowableOwner.New({current=valid,sealed=sealed,present=present,quantity=quantity,
        pickupEnabled=function()
            return Config.DevMode==true and type(GetConvarInt)=='function'
                and GetConvarInt('feather_native_throwable_pickup',0)==1 and WeaponNativeThrowablePolicy.Enabled()==true
        end,
        rebindPickup=function(handle,check)
            -- Acknowledged ledger recovery authorizes only a read-only capture
            -- of the unique exact model in this ped's carried inventory.
            -- No world object adoption, inventory removal or ammo setter here.
            if not exact(handle,check) or quantity()~=1 then return nil end
            local captured=inventoryGuid()
            if not captured or not valid(check) or not present() or quantity()~=1 then return nil end
            owned.guid=captured.guid; buffer=captured.raw
            return {entity=0,inventoryOnly=true,guid=captured.guid,itemId=owned.itemInstanceId,itemRevision=owned.itemRevision}
        end,
        createFunded=function(approval)
            local function failed(reason)
                local qok,q=pcall(quantity)
                local pok,p=pcall(present)
                print(('[WeaponNativeThrowableCreation] REFUSED reason=%s item=%s quantity=%s present=%s; no retry'):format(
                    reason,tostring(approval.row.id),qok and tostring(q) or 'unreadable',pok and tostring(p) or 'unreadable'))
                return nil,reason
            end
            if owned or not valid(approval.identity) or yes(IsEntityDead(ped)) or approval.fundedQuantity~=1 then return failed('throwable_creation_context_changed') end
            local before=native.Read(ped,true)
            if not before or (before.ammo_tomahawk_regular~=0 and before.ammo_tomahawk_regular~=approval.fundedQuantity)
                or present() then return failed('throwable_creation_preflight_failed') end
            local prior,priorWhy=inventoryGuid()
            if prior~=false then return failed(priorWhy or 'throwable_preexisting_inventory_guid') end
            if not valid(approval.identity) or quantity()~=before.ammo_tomahawk_regular or present()
                or yes(IsEntityDead(ped)) then return failed('throwable_creation_preflight_changed') end
            -- Same zero-quantity construction as the accepted throwable path.
            -- Only this approved character balance may be restored afterward.
            owned={name=def.nativeWeaponName,itemInstanceId=approval.row.id,itemRevision=approval.row.revision,
                serialNumber=approval.row.metadata.serialNumber}
            GiveWeaponToPed(ped,model,0,false,true,0,false,0.5,1.0,joaat('ADD_REASON_DEFAULT'),true,0.0,false)
            if not valid(approval.identity) then return failed('throwable_creation_context_changed') end
            -- Re-equipping an already funded character belt often starts at1.
            -- Give only the zero-ammo carrier; do not redundantly grant/reset
            -- a pool which already agrees with the authoritative ledger.
            local carried=quantity()
            if carried==0 then SetPedAmmoByType(ped,ammo,1)
            elseif carried~=1 then return failed('throwable_creation_pool_changed') end
            local after=native.Read(ped,true)
            if not after or after.ammo_tomahawk_regular~=1 then return failed('throwable_funded_pool_readback_failed') end
            for id,value in pairs(before) do if id~='ammo_tomahawk_regular' and after[id]~=value then return failed('throwable_foreign_pool_changed') end end
            local captured,captureWhy=inventoryGuid()
            if captured==nil then return failed(captureWhy) end
            if captured then
                owned.guid=captured.guid; buffer=captured.raw
                return {entity=0,inventoryOnly=true,guid=owned.guid,itemId=owned.itemInstanceId,itemRevision=owned.itemRevision}
            end
            local started=GetGameTimer()
            for frame=1,120 do
                if not valid(approval.identity) then return failed('throwable_creation_context_changed') end
                local candidate
                for _,point in ipairs(points) do
                    local value=pointRead(point)
                    if value then
                        if candidate and candidate.entity~=value.entity then return failed('throwable_creation_multiple_entities') end
                        candidate=value
                    end
                end
                if candidate then
                    owned.entity=candidate.entity; owned.point=candidate.point
                    if not resolver.Capture(owned,approval.identity) then return failed('throwable_creation_guid_capture_failed') end
                    if not resolver.MatchesCaptured(owned,approval.identity,candidate.guid) then return failed('throwable_creation_guid_changed') end
                    owned.guid=candidate.guid; buffer=candidate.raw
                    return {entity=owned.entity,guid=owned.guid,itemId=owned.itemInstanceId,itemRevision=owned.itemRevision}
                end
                if (GetGameTimer()-started)%4294967296>=1500 then return failed('throwable_creation_entity_guid_not_observed') end
                Wait(0)
            end
            return failed('throwable_creation_entity_guid_not_observed')
        end,
        removeOwned=function(handle,check)
            local function failed(reason)
                print(('[WeaponNativeThrowableCleanup] REFUSED reason=%s quantity=%s present=%s; no retry'):format(
                    reason,tostring(quantity()),tostring(present())))
                return false,reason
            end
            if not exact(handle,check) or quantity()~=1 then return failed('throwable_cleanup_preflight_failed') end
            -- Captured GUID is authority even if the representation is hidden.
            local raw=string.rep('\0',104)
            local result=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,buffer,raw,true)
            local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,result)
            if not item or item.itemHash~=(model & 0xffffffff) or key(raw)~=owned.guid
                or not valid(check) or quantity()~=1 then return failed('throwable_cleanup_guid_readback_failed') end
            local removed=Citizen.InvokeNative(0x3E4E811480B3AE79,1,buffer,1,joaat('REMOVE_REASON_CLIENT_PURGED'))
            if not yes(removed) then return failed('throwable_cleanup_remove_not_acknowledged') end
            if not valid(check) or present() or anyVisible() then return failed('throwable_cleanup_model_not_absent') end
            local absent=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,buffer,string.rep('\0',104),true)
            if absent~=false and absent~=0 then return failed('throwable_cleanup_guid_not_absent') end
            -- Native inventory removal and character ammo pools are separate.
            -- Under the already-sealed parent, retire only this approved pool
            -- after exact GUID/model absence; this is not economic consumption.
            local before=native.Read(ped,true)
            if not before or not valid(check) then return failed('throwable_cleanup_pool_unreadable') end
            if before.ammo_tomahawk_regular==1 then
                -- Same reduction primitive as WeaponCharacterAmmoNative.Restore:
                -- RedM's absolute setter need not reduce an existing pool.
                Citizen.InvokeNative(0xB6CFEC32E3742779,ped,ammo,1,0xA07362E6)
            end
            local after=native.Read(ped,true)
            if not after or after.ammo_tomahawk_regular~=0 or not valid(check) or present() or anyVisible() then
                return failed('throwable_cleanup_pool_reset_unconfirmed')
            end
            for id,n in pairs(before) do
                if id~='ammo_tomahawk_regular' and after[id]~=n then return failed('throwable_cleanup_foreign_pool_changed') end
            end
            return true
        end,
        releaseSpent=function(handle,check)
            local function failed(reason)
                print(('[WeaponNativeThrowableCleanup] REFUSED reason=%s quantity=%s present=%s; no retry'):format(
                    reason,tostring(quantity()),tostring(present())))
                return false,reason
            end
            if not exact(handle,check) or quantity()~=0 then return failed('throwable_spent_preflight_failed') end
            local before=native.Read(ped,true)
            if not before or before.ammo_tomahawk_regular~=0 then return failed('throwable_spent_pool_unconfirmed') end
            local raw=string.rep('\0',104)
            local found=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,buffer,raw,true)
            if yes(found) then
                local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,found)
                local carried=inventoryGuid()
                -- Only remove an empty entry still in this ped's carried
                -- inventory with the original captured GUID. Never operate on
                -- the thrown world entity or adopt a replacement/pickup GUID.
                if not item or item.itemHash~=(model & 0xffffffff) or key(raw)~=owned.guid
                    or not carried or carried.guid~=owned.guid or not valid(check) or quantity()~=0 then
                    return failed('throwable_spent_carried_guid_unconfirmed')
                end
                if not yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,buffer,1,joaat('REMOVE_REASON_CLIENT_PURGED'))) then
                    return failed('throwable_spent_remove_not_acknowledged')
                end
                found=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,buffer,string.rep('\0',104),true)
            end
            if (found~=false and found~=0) or not valid(check) or present() or anyVisible() then
                return failed('throwable_spent_absence_unconfirmed')
            end
            local after=native.Read(ped,true)
            if not after or not valid(check) then return failed('throwable_spent_pool_unconfirmed') end
            for id,n in pairs(before) do
                if after[id]~=n then return failed('throwable_spent_pool_changed') end
            end
            return true
        end,
    },catalog,identity,registry.limits)
end
