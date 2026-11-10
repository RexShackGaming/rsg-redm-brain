-- Explicit, injectable creation boundary. No automatic thread/event/grant loop.
WeaponCharacterAmmoLoadout={}
function WeaponCharacterAmmoLoadout.New(api)
    for _,key in ipairs({'current','prepareDual','createSingle','createPair','remove','finish'}) do
        assert(type(api)=='table' and type(api[key])=='function','Local loadout adapter required: '..key)
    end
    local state='idle'
    local function yes(v) return v==true end
    local function validHandle(v)
        return type(v)=='table' and type(v.entity)=='number' and v.entity>0 and v.entity%1==0 and v.entity<math.huge
    end
    local function create(plan)
        if state~='idle' then return nil,'creation_already_attempted' end
        if type(plan)~='table' or type(plan.items)~='table' or type(plan.identity)~='table' then return nil,'invalid_plan' end
        if not yes(api.current(plan.identity)) then return nil,'stale_materialization' end
        for _,item in ipairs(plan.items) do
            if item.creation~='native_inventory_guid' then return nil,'unsupported_creation' end
        end
        state='creating'
        local owned,entities={},{}
        local function fail(reason)
            -- Only handles created in this attempt; never remove all ped weapons.
            local attempted,retained={},{}
            for i=#owned,1,-1 do
                local handle=owned[i]
                local key=handle.entity or handle
                if not attempted[key] then
                    attempted[key]=true
                    local called,removed=pcall(api.remove,handle)
                    if not called or removed~=true then retained[#retained+1]=handle end
                else
                    -- A duplicate entity does not prove duplicate GUID/resource
                    -- ownership. Do not silently clear a skipped alias record.
                    retained[#retained+1]=handle
                end
            end
            state='failed'
            return nil,reason,{identity=plan.identity,handles=retained,cleanupComplete=#retained==0}
        end
        local function accept(handle,item)
            if not validHandle(handle) then return false end
            -- Track before duplicate check so adapter-created resources can be
            -- compensated even when native entity verification fails.
            owned[#owned+1]=handle
            if entities[handle.entity] then return false end
            entities[handle.entity]=true
            handle.copyKey=item.copyKey; handle.point=item.point
            return true
        end
        if plan.dual then
            local ok,ready=pcall(api.prepareDual,plan.identity)
            if not ok or ready~=true then return fail('offhand_not_ready') end
        end
        local pair={}
        for _,item in ipairs(plan.items) do
            if plan.sameModel==true and (item.point==2 or item.point==3) then pair[#pair+1]=item end
        end
        if #pair>0 then
            if #pair~=2 then return fail('invalid_pair_plan') end
            if not yes(api.current(plan.identity)) then return fail('stale_materialization') end
            local ok,handles,detail,partial=pcall(api.createPair,pair,plan.identity)
            if not ok or type(handles)~='table' then
                -- The native adapter may have created resources before failing.
                -- Preserve even an unidentified pending grant; never acknowledge
                -- cleanup just because normal handle acceptance was not reached.
                if ok and type(partial)=='table' and type(partial.handles)=='table' then
                    for _,handle in ipairs(partial.handles) do owned[#owned+1]=handle end
                end
                return fail('pair_creation_failed: '..tostring(ok and detail or handles))
            end
            local valid=true
            for i=1,2 do if not accept(handles[i],pair[i]) then valid=false end end
            if not valid then return fail('pair_entities_not_distinct') end
        end
        for _,item in ipairs(plan.items) do
            if not (plan.sameModel==true and (item.point==2 or item.point==3)) then
                if not yes(api.current(plan.identity)) then return fail('stale_materialization') end
                -- Zero ammunition is mandatory at this boundary. Ammo restore
                -- is a later, separately authorized controller operation.
                local ok,handle,detail,partial=pcall(api.createSingle,item,0,plan.identity)
                if not ok then return fail('single_creation_failed: adapter_exception: '..tostring(handle)) end
                if not validHandle(handle) then
                    if type(partial)=='table' and type(partial.handles)=='table' then
                        for _,record in ipairs(partial.handles) do owned[#owned+1]=record end
                    end
                    return fail('single_creation_failed: invalid_handle: '..tostring(detail or type(handle)))
                end
                if not accept(handle,item) then return fail('single_creation_failed: duplicate_entity') end
            end
        end
        if not yes(api.current(plan.identity)) then return fail('stale_materialization') end
        local ok,finished=pcall(api.finish,owned,plan.identity)
        if not ok or finished~=true then return fail('holster_verification_failed') end
        state='created'
        return {identity=plan.identity,handles=owned}
    end
    return {Create=create,Status=function() return state end}
end
