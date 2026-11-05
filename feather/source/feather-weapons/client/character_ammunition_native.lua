-- Dormant native pool boundary. Clip/type selection is deliberately absent.
WeaponCharacterAmmoNative={}
function WeaponCharacterAmmoNative.New(names,limits,api)
    api=api or {ped=PlayerPedId,hash=joaat,read=GetPedAmmoByType,write=SetPedAmmoByType,
        remove=function(ped,hash,count) Citizen.InvokeNative(0xB6CFEC32E3742779,ped,hash,count,0xA07362E6) end}
    local hashes,seen,caps={},{},{}
    if type(names)~='table' or type(limits)~='table' or next(limits)==nil then return nil,'invalid_mapping' end
    for id,cap in pairs(limits) do
        if type(names[id])~='string' or not names[id]:match('^AMMO_[A-Z0-9_]+$')
            or type(cap)~='number' or cap<0 or cap%1~=0 or cap==math.huge then return nil,'invalid_mapping' end
        local hash=api.hash(names[id])
        if hash==nil or seen[hash] then return nil,'native_alias' end
        seen[hash]=true; hashes[id]=hash; caps[id]=cap
    end
    for id in pairs(names) do if caps[id]==nil then return nil,'unknown_mapping' end end
    local N={}
    function N.Read(ped,ready)
        if ready~=true or ped~=api.ped() then return nil,'ped_not_ready' end
        local pools={}
        for id,hash in pairs(hashes) do
            local ok,value=pcall(api.read,ped,hash)
            if not ok then return nil,'native_read_failed' end
            pools[id]=value
        end
        if ped~=api.ped() then return nil,'ped_changed' end
        -- Every mapped pool, including zero/unselected types, is required.
        for id in pairs(caps) do if pools[id]==nil then return nil,'incomplete_observation' end end
        return WeaponCharacterAmmunition.Validate(pools,caps)
    end
    function N.Restore(value,ped,ready)
        if ready~=true or ped~=api.ped() then return nil,'ped_not_ready' end
        if type(value)~='table' or value.phase~='restoring' then return nil,'restore_not_authorized' end
        local pools,reason=WeaponCharacterAmmunition.Validate(value.pools,caps)
        if not pools then return nil,reason end
        for id in pairs(caps) do if value.pools[id]==nil then return nil,'incomplete_baseline' end end
        for id,hash in pairs(hashes) do
            if ped~=api.ped() then return nil,'ped_changed' end
            local readOk,current=pcall(api.read,ped,hash)
            if not readOk or type(current)~='number' or current<0 or current%1~=0 or current==math.huge then
                return nil,'native_read_failed'
            end
            if ped~=api.ped() then return nil,'ped_changed' end
            -- RedM's absolute setter may leave an existing larger pool unchanged.
            -- Remove only the excess at this authorized boundary; never touch clips.
            local ok
            if current>pools[id] then
                if type(api.remove)~='function' then return nil,'native_remove_unavailable' end
                ok=pcall(api.remove,ped,hash,current-pools[id])
            else ok=pcall(api.write,ped,hash,pools[id]) end
            if not ok then return nil,'native_write_failed' end
        end
        local actual
        actual,reason=N.Read(ped,true)
        if not actual then return nil,reason end
        for id,count in pairs(pools) do if actual[id]~=count then return nil,'restore_mismatch' end end
        return actual
    end
    return N
end
