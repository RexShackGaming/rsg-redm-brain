-- Concrete but inert lasso adapter. No events, admission or calls on file load.
WeaponNativeUtilityAdapter={}
function WeaponNativeUtilityAdapter.Scoped(ped,identity,current,sealed,def)
    assert(type(current)=='function' and type(sealed)=='function','Local utility lifecycle required')
    local profile=WeaponNativeUtilityCatalog.Resolve(def)
    if not profile or not WeaponCharacterAmmoCreationNative then return nil,'utility_components_required' end
    local bound={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
    local model=joaat(profile.nativeWeaponName)
    local captured
    local function yes(v) return v==true or v==1 end
    local function valid(check)
        return type(check)=='table' and check.characterId==bound.characterId
            and check.sessionId==bound.sessionId and check.epoch==bound.epoch
            and PlayerPedId()==ped and yes(DoesEntityExist(ped)) and current(check)==true
    end
    local function key(raw)
        local decoded=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)
        if not decoded then return nil end
        local w=decoded.scriptSlotWords
        return ('%08x%08x%08x%08x'):format(w[1],w[2],w[3],w[4])
    end
    local function present()
        local value=HasPedGotWeapon(ped,model,false)
        if value==true or value==1 then return true end
        if value==false or value==0 then return false end
        return nil -- unreadable is not positive absence
    end
    local function read(raw)
        local out=string.rep('\0',104)
        local result=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,raw,out,true)
        return result,out
    end
    local function exact(handle,approval)
        return captured and handle.guid==captured.guid and approval.row.id==captured.itemId
            and approval.row.revision==captured.itemRevision and valid(approval.identity)
    end
    return WeaponNativeUtilityOwner.New({current=valid,
        present=function() return present() end,
        create=function(_,check)
            if not valid(check) or yes(IsEntityDead(ped)) or present()~=false then return false end
            GiveWeaponToPed(ped,model,0,false,true,0,false,0.5,1.0,joaat('ADD_REASON_DEFAULT'),true,0.0,false)
            return valid(check)
        end,
        capture=function(_,approval)
            local started=GetGameTimer()
            for frame=1,120 do
                if not valid(approval.identity) then return nil end
                local selected
                for point=0,31 do
                    local found,hash=GetCurrentPedWeapon(ped,true,point,true)
                    if yes(found) and hash==model then
                        local entity=GetCurrentPedWeaponEntityIndex(ped,point)
                        if type(entity)~='number' or entity<=0 or not yes(DoesEntityExist(entity)) then return nil end
                        local raw=string.rep('\0',104)
                        if not yes(Citizen.InvokeNative(0x6929E22158E52265,ped,point,raw)) then return nil end
                        local guid=key(raw)
                        local result,out=read(raw)
                        local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(out,result)
                        local after,afterHash=GetCurrentPedWeapon(ped,true,point,true)
                        if not guid or not item or item.itemHash~=(model & 0xffffffff) or key(out)~=guid
                            or not yes(after) or afterHash~=model or GetCurrentPedWeaponEntityIndex(ped,point)~=entity
                            or not valid(approval.identity) then return nil end
                        if selected and selected.guid~=guid then return nil end
                        selected={guid=guid,raw=raw,itemId=approval.row.id,itemRevision=approval.row.revision}
                    end
                end
                if selected then captured=selected; return {guid=selected.guid} end
                if (GetGameTimer()-started)%4294967296>=1500 then break end
                Wait(0)
            end
            return nil -- no guessed hierarchy or model-only adoption
        end,
        sealed=function(approval) return valid(approval.identity) and sealed(approval)==true end,
        removeCaptured=function(handle,approval)
            if not exact(handle,approval) then return false end
            local result,out=read(captured.raw)
            local item=WeaponCharacterAmmoCreationNative.DecodeEquippedChild(out,result)
            if not item or item.itemHash~=(model & 0xffffffff) or key(out)~=captured.guid
                or not exact(handle,approval) then return false end
            return yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,captured.raw,1,joaat('REMOVE_REASON_CLIENT_PURGED')))
                and valid(approval.identity)
        end,
        absent=function(handle,approval)
            if not exact(handle,approval) then return false end
            local result=read(captured.raw)
            return (result==false or result==0) and present()==false and valid(approval.identity)
        end,
    },def,bound)
end
