-- Explicit, ped/lifecycle-bound offhand setup. No ammo or Feather inventory.
-- Fixed fallback appearance only: caller must own the appearance lifecycle.
WeaponCharacterAmmoDualNative={}
function WeaponCharacterAmmoDualNative.New(ped,current)
    assert(type(current)=='function','Local lifecycle callback required')
    local owned,prior,prepared={},nil,false
    local function yes(v) return v==true or v==1 end
    local function ready()
        local ok,value=pcall(current)
        return ok and value==true and PlayerPedId()==ped and yes(DoesEntityExist(ped)) and not yes(IsEntityDead(ped))
    end
    local function guid(parent,item,slot)
        local out=string.rep('\0',104)
        return yes(Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,joaat(item),slot,out)) and out or nil
    end
    local function refresh()
        Citizen.InvokeNative(0xCC8CA3E88256E58F,ped,false,true,true,true,false)
        Citizen.InvokeNative(0xAAB86462966168CE,ped,true)
    end
    local T={}
    function T.Cleanup()
        if not ready() then return nil,'dual_lifecycle_changed' end
        local remaining={}
        for index=#owned,1,-1 do
            local record=owned[index]
            local ok=pcall(function()
                if record.clothing then Citizen.InvokeNative(0x0D7FFA1B2F69ED82,ped,record.hash,0,0) end
                assert(yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,record.guid,1,joaat('REMOVE_REASON_DEFAULT'))),'guid_remove_failed')
            end)
            if not ok then remaining[#remaining+1]=record end
        end
        owned=remaining
        if #owned>0 then return nil,'dual_cleanup_failed' end
        local ok=pcall(function()
            if prior~=nil then
                SetAllowDualWield(ped,prior)
                assert(yes(GetAllowDualWield(ped))==prior,'dual_permission_restore_failed')
            end
            refresh()
        end)
        if not ok then return nil,'dual_cleanup_failed' end
        prior,prepared=nil,false
        return true
    end
    function T.Ensure()
        if not ready() then return nil,'dual_lifecycle_changed' end
        if prepared then return true end
        if #owned>0 or prior~=nil then return nil,'dual_cleanup_required' end
        local model=GetEntityModel(ped)
        local clothing=model==joaat('mp_male') and 'CLOTHING_ITEM_M_OFFHAND_000_TINT_004'
            or model==joaat('mp_female') and 'CLOTHING_ITEM_F_OFFHAND_000_TINT_004'
        if not clothing then return nil,'unsupported_dual_model' end
        prior=yes(GetAllowDualWield(ped))
        local ok,reason=pcall(function()
            local character=guid(nil,'CHARACTER',0xA1212100)
            local wardrobe=character and guid(character,'WARDROBE',0x3DABBFA7)
            assert(wardrobe,'dual_wardrobe_unavailable')
            for _,entry in ipairs({{name=clothing,slot=0xF20B6B4A,clothing=true},
                {name='UPGRADE_OFFHAND_HOLSTER',slot=0x39E57B01}}) do
                local hash=joaat(entry.name)
                local rawCount=Citizen.InvokeNative(0xE787F05DFC977BDE,1,hash,false,Citizen.ResultAsInteger())
                local existing=tonumber(rawCount)
                assert(existing and existing>=0,('invalid_entitlement_readback item=%s type=%s value=%s')
                    :format(entry.name,type(rawCount),tostring(rawCount)))
                if existing==0 then
                    local out=string.rep('\0',104)
                    assert(yes(Citizen.InvokeNative(0xCB5D11F9508A928D,1,out,wardrobe,hash,entry.slot,1,joaat('ADD_REASON_DEFAULT'))),'dual_insert_failed')
                    owned[#owned+1]={guid=out,hash=hash,clothing=entry.clothing}
                    assert(yes(Citizen.InvokeNative(0x734311E2852760D0,1,out,true)),'dual_equip_failed')
                end
                if entry.clothing then
                    Citizen.InvokeNative(0xD3A7B003ED343FD9,ped,hash,false,false,false)
                    Citizen.InvokeNative(0xD3A7B003ED343FD9,ped,hash,false,true,false)
                    refresh()
                end
            end
            SetAllowDualWield(ped,true)
            assert(yes(GetAllowDualWield(ped)),'dual_permission_failed')
        end)
        if not ok then
            local cleaned=T.Cleanup()
            return nil,cleaned and tostring(reason) or 'dual_compensation_failed'
        end
        prepared=true; return true
    end
    function T.Status() return {prepared=prepared,ownedCount=#owned,permissionCaptured=prior~=nil} end
    return T
end
