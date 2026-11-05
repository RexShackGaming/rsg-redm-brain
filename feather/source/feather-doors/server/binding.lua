DoorsBinding = {}
function DoorsBinding.New(db,repository,port,ready)
    local C=DoorsContract
    local api={generation=0}
    local function group(id)
        if not ready() then return nil,'unavailable' end
        local ok,row=pcall(db.one,[[SELECT d.*,COALESCE(b.`mode`,'standalone') AS authority_mode,
            b.`link_id` AS binding_link_id,b.`property_id` AS binding_property_id,
            b.`property_epoch` AS binding_property_epoch,b.`property_status` AS binding_property_status
            FROM `feather_door_groups` d LEFT JOIN `feather_door_bindings` b ON b.`door_id`=d.`door_id`
            WHERE d.`door_id`=?]],id)
        if not ok or not ready() then return nil,'unavailable' end
        if not row then return nil,'not_found' end
        if row.door_id~=id or not C.Int(tonumber(row.revision),1,C.MaxRevision)
            or not C.Int(tonumber(row.delegation_epoch),1,C.MaxRevision)
            or (row.authority_mode~='standalone' and row.authority_mode~='property')
            or not ({active=true,suspended=true,retired=true})[row.status] then return nil,'invalid_persistence' end
        return row
    end
    local function facts(id)
        if not ready() or not port.available() then return nil,'property_unavailable' end
        local ok,result=pcall(port.read,id)
        if not ok or not ready() or not port.available() or type(result)~='table' or result.ok~=true then
            return nil,'property_unavailable'
        end
        local value=result.value
        if not C.Fields(value,{linkId=true,propertyId=true,epoch=true,status=true})
            or not C.Uuid(value.linkId) or not C.Uuid(value.propertyId)
            or not C.Int(value.epoch,1,9007199254740991)
            or not ({active=true,suspended=true,retired=true,unavailable=true})[value.status] then return nil,'property_invalid' end
        return {linkId=value.linkId,propertyId=value.propertyId,epoch=value.epoch,status=value.status}
    end
    local function same(a,b)
        return a and b and a.linkId==b.linkId and a.propertyId==b.propertyId and a.epoch==b.epoch and a.status==b.status
    end
    function api:Drop() self.generation=self.generation+1 end
    function api:Read(id)
        if not C.Uuid(id) then return nil,'invalid_request' end
        local generation=self.generation
        local row,err=group(id)
        if not row then return nil,err end
        if row.authority_mode=='standalone' or row.status=='retired' then return row end
        local source,sourceErr=facts(id)
        if not source then return nil,sourceErr end
        if row.binding_property_id==source.propertyId and tonumber(row.binding_property_epoch)
            and source.epoch<tonumber(row.binding_property_epoch) then return nil,'property_epoch_rollback' end
        if generation~=self.generation then return nil,'property_unavailable' end
        if row.binding_link_id~=source.linkId or row.binding_property_id~=source.propertyId
            or tonumber(row.binding_property_epoch)~=source.epoch or row.binding_property_status~=source.status then
            local result=repository:Mutate('feather-doors','authority',{doorId=id,expectedRevision=tonumber(row.revision),
                requestId='doors.authority:'..id..':'..('%.0f'):format(tonumber(row.revision)),reasonCode='doors.binding.changed'},source)
            if not result.ok then return nil,result.code end
            row,err=group(id)
            if not row then return nil,err end
        end
        local confirmed,confirmErr=facts(id)
        if not confirmed then return nil,confirmErr end
        local current,currentErr=group(id)
        if not current then return nil,currentErr end
        if generation~=self.generation or not same(source,confirmed) or current.authority_mode~='property'
            or tonumber(current.revision)~=tonumber(row.revision)
            or current.binding_link_id~=confirmed.linkId or current.binding_property_id~=confirmed.propertyId
            or tonumber(current.binding_property_epoch)~=confirmed.epoch or current.binding_property_status~=confirmed.status then
            return nil,'target_changed'
        end
        if current.status~='retired' and source.status~='active' then current.effective_status='unavailable' end
        return current
    end
    function api:Set(caller,request)
        local normalized=C.Validate('binding',request)
        if not normalized then return C.Err('invalid_request') end
        local before,err=group(normalized.doorId)
        if not before then return C.Err(err) end
        if before.manager_resource~=caller then return C.Err('not_found') end
        local source
        if normalized.mode=='property' then
            source,err=facts(normalized.doorId)
            if not source then return C.Err(err) end
            if source.status~='active' then return C.Err('property_unavailable') end
        end
        local result=repository:Mutate(caller,'binding',normalized,source)
        if result.ok and source then
            local confirmed=facts(normalized.doorId)
            if not same(source,confirmed) then return C.Err('pending_recovery') end
        end
        return result
    end
    function api:Context(caller,request)
        if not C.Fields(request,{doorId=true}) or not C.Uuid(request.doorId) then return C.Err('invalid_request') end
        local row,err=group(request.doorId:lower())
        if not row then return C.Err(err) end
        if row.manager_resource~=caller then return C.Err('not_found') end
        row,err=self:Read(request.doorId:lower())
        if not row then return C.Err(err) end
        if row.manager_resource~=caller then return C.Err('not_found') end
        return C.Ok({doorId=row.door_id,mode=row.authority_mode,revision=tonumber(row.revision),
            delegationEpoch=tonumber(row.delegation_epoch),status=row.effective_status or row.status,
            linkId=row.binding_link_id,propertyId=row.binding_property_id,propertyEpoch=tonumber(row.binding_property_epoch)})
    end
    return api
end
