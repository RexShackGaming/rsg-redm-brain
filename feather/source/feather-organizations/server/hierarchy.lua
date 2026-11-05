OrganizationHierarchy = {}
local Ok,Err=Organizations.Ok,Organizations.Err
local maximumLinks,maximumDepth=4096,32
local function Editable(status) return status=='pending' or status=='active' or status=='suspended' end
function OrganizationHierarchy.CheckStartup()
    local guard=DB.value('SELECT `id` FROM `feather_organization_hierarchy_guard` WHERE `id`=1')
    if tonumber(guard)~=1 then return Err('invalid_persistence','Hierarchy guard is missing.') end
    return Ok(true)
end
function OrganizationHierarchy.ValidateGraph(parents)
    local count=0
    for child,parent in pairs(parents) do
        count=count+1
        if count>maximumLinks then return Err('hierarchy_limit','Hierarchy exceeds 4096 links.') end
        if not Organizations.Uuid(child) or not Organizations.Uuid(parent) then return Err('invalid_persistence','Invalid hierarchy UUID.') end
        local visited,node,depth={},child,0
        while node do
            if visited[node] then return Err('hierarchy_cycle','Parent links would form a cycle.') end
            visited[node]=true
            node=parents[node]
            if node then depth=depth+1 end
            if depth>maximumDepth then return Err('hierarchy_depth','Hierarchy exceeds 32 parent links.') end
        end
    end
    return Ok(true)
end
function OrganizationHierarchy.Validate(request,operation)
    if type(request)~='table' or (operation~='set' and operation~='remove') then return Err('invalid_input','Hierarchy request required.') end
    local fields={organizationId=true,expectedRevision=true,requestId=true,reasonCode=true}
    if operation=='set' then fields.parentOrganizationId=true end
    for key in pairs(request) do if not fields[key] then return Err('invalid_input','Unexpected hierarchy field.') end end
    if not Organizations.Uuid(request.organizationId)
        or not Organizations.Integer(request.expectedRevision,1,9007199254740990)
        or (operation=='set' and not Organizations.Uuid(request.parentOrganizationId))
        or type(request.requestId)~='string' or #request.requestId>128
        or not request.requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or type(request.reasonCode)~='string' or #request.reasonCode>64
        or not request.reasonCode:match('^[a-z][a-z0-9._:%-]*$') then
        return Err('invalid_input','UUIDs, integer revision, stable request ID and reason required.')
    end
    if operation=='set' and request.organizationId:lower()==request.parentOrganizationId:lower() then
        return Err('hierarchy_cycle','Organization cannot be its own parent.')
    end
    return Ok(table.concat({operation,request.organizationId:lower(),
        operation=='set' and request.parentOrganizationId:lower() or '',tostring(request.expectedRevision),request.reasonCode},'|'))
end
function OrganizationHierarchy.Change(request,resource,operation)
    if Config.Access.trustedMutators[resource or '']~=true then return Err('authorization_denied','Caller is not a trusted hierarchy mutator.') end
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid=OrganizationHierarchy.Validate(request,operation)
    if not valid.ok then return valid end
    request=Organizations.Copy(request);request.organizationId=request.organizationId:lower()
    local parent=operation=='set' and request.parentOrganizationId:lower() or nil
    if Config.Authorization.enabled then
        local decision=exports['feather-core']:Authorize(Config.Authorization.hierarchyAction,{
            correlationId=request.requestId,subject={resource=resource,organizationId=request.organizationId,
                parentOrganizationId=parent,operation=operation}})
        if type(decision)~='table' or not decision.ok or type(decision.value)~='table' or decision.value.allowed~=true then
            return Err('authorization_denied','Hierarchy policy denied.')
        end
    end
    local current=Organizations.CheckRead(resource)
    if not current.ok then return current end
    local result
    local called,committed=pcall(DB.transaction, function(tx)
        local executed,outcome=xpcall(function()
            -- All graph writers take this row first; opposing links cannot both
            -- validate against an old snapshot and create a concurrent cycle.
            local guard=tx.query('SELECT `id` FROM `feather_organization_hierarchy_guard` WHERE `id`=1 FOR UPDATE') or {}
            if not guard[1] then return Err('invalid_persistence','Hierarchy guard is missing.') end
            tx.exec([[INSERT IGNORE INTO `feather_organization_hierarchy_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]], resource,request.requestId,valid.value)
            local receipts=tx.query([[SELECT `request_fingerprint`,`result_json` FROM `feather_organization_hierarchy_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], resource,request.requestId) or {}
            local receipt=receipts[1]
            if not receipt then return Err('internal_error','Could not reserve hierarchy receipt.') end
            if receipt.request_fingerprint~=valid.value then return Err('idempotency_conflict','Request ID belongs to another hierarchy payload.') end
            local rows=tx.query([[SELECT `organization_id`,`status`,`revision`,`created_by_resource` FROM `feather_organizations`
                WHERE `organization_id`=? OR `organization_id`=? ORDER BY `organization_id` FOR UPDATE]], request.organizationId,parent or request.organizationId) or {}
            local child,parentRow
            for _,row in ipairs(rows) do
                if row.organization_id==request.organizationId then child=row end
                if row.organization_id==parent then parentRow=row end
            end
            if not child then return Err('organization_not_found','Child organization not found.') end
            if child.created_by_resource~=resource and Config.Access.privilegedMutators[resource]~=true then
                return Err('authorization_denied','Caller does not own this hierarchy child.')
            end
            if receipt.result_json then
                local decoded,value=pcall(json.decode,receipt.result_json)
                if not decoded or type(value)~='table' or value.organizationId~=request.organizationId
                    or value.parentOrganizationId~=parent or value.revision~=request.expectedRevision+1
                    or (value.previousParentOrganizationId~=nil and not Organizations.Uuid(value.previousParentOrganizationId)) then
                    return Err('invalid_persistence','Stored hierarchy receipt is invalid.')
                end
                value.replayed=true;return Ok(value)
            end
            if parent and not parentRow then return Err('organization_not_found','Parent organization not found.') end
            if parentRow and parentRow.created_by_resource~=resource and Config.Access.privilegedMutators[resource]~=true then
                return Err('authorization_denied','Caller does not own the proposed parent.')
            end
            local events=tx.query([[SELECT `event_id` FROM `feather_organization_events`
                WHERE `source_resource`=? AND `request_id`=?]], resource,request.requestId) or {}
            if #events>0 then return Err('idempotency_conflict','Request ID belongs to another organization operation.') end
            if tonumber(child.revision)~=request.expectedRevision then return Err('revision_conflict','Child revision changed.') end
            if not Editable(child.status) or (parentRow and not Editable(parentRow.status)) then
                return Err('organization_inactive','Dissolving/dissolved organizations cannot receive new hierarchy changes.')
            end
            local links=tx.query('SELECT `organization_id`,`parent_organization_id` FROM `feather_organization_parents` LIMIT 4097') or {}
            if #links>maximumLinks then return Err('hierarchy_limit','Hierarchy exceeds supported link limit.') end
            local parents={}
            for _,link in ipairs(links) do parents[link.organization_id]=link.parent_organization_id end
            local previous=parents[request.organizationId]
            if previous==parent then return Err('no_change','Parent link is unchanged.') end
            parents[request.organizationId]=parent
            local graph=OrganizationHierarchy.ValidateGraph(parents)
            if not graph.ok then return graph end
            if parent then
                tx.exec([[INSERT INTO `feather_organization_parents` (`organization_id`,`parent_organization_id`) VALUES (?,?)
                    ON DUPLICATE KEY UPDATE `parent_organization_id`=VALUES(`parent_organization_id`)]], request.organizationId,parent)
            else tx.exec('DELETE FROM `feather_organization_parents` WHERE `organization_id`=?', request.organizationId) end
            tx.exec('UPDATE `feather_organizations` SET `revision`=`revision`+1 WHERE `organization_id`=? AND `revision`=?', request.organizationId,request.expectedRevision)
            OrganizationEvents.Record(tx,request.organizationId,'organization.parent_changed',resource,
                request.requestId,request.reasonCode,request.expectedRevision+1,
                {parentOrganizationId=parent,previousParentOrganizationId=previous})
            local value={organizationId=request.organizationId,parentOrganizationId=parent,
                previousParentOrganizationId=previous,revision=request.expectedRevision+1,replayed=false}
            tx.exec([[UPDATE `feather_organization_hierarchy_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]], json.encode(value),resource,request.requestId)
            return Ok(value)
        end,debug.traceback)
        if not executed then
            print('[feather-organizations] hierarchy transaction failed: ' .. tostring(outcome))
            result=Err('internal_error','Hierarchy transaction failed.');return false
        end
        result=outcome;return outcome.ok==true
    end)
    if not called or (result and result.ok and committed~=true) then return Err('transaction_failed','Hierarchy commit not confirmed. Retry the same request ID.') end
    return result or Err('transaction_failed','Hierarchy change did not complete. Retry the same request ID.')
end
function OrganizationHierarchy.Children(request,resource)
    if type(request)~='table' or not Organizations.Uuid(request.organizationId) then return Err('invalid_input','Parent UUID required.') end
    for key in pairs(request) do
        if key~='organizationId' and key~='limit' and key~='cursor' then return Err('invalid_input','Unexpected children query field.') end
    end
    local found=OrganizationIdentity.Get({organizationId=request.organizationId},resource)
    if not found.ok then return found end
    return OrganizationDirectory.List({parentOrganizationId=request.organizationId,limit=request.limit,cursor=request.cursor},resource)
end
local function Boundary(callback,request,operation)
    local called,result=xpcall(function() return callback(request,GetInvokingResource(),operation) end,debug.traceback)
    if not called then
        print('[feather-organizations] hierarchy API failure: ' .. tostring(result))
        return Err('internal_error','Hierarchy operation failed.')
    end
    return result
end
exports('SetParentOrganization',function(request) return Boundary(OrganizationHierarchy.Change,request,'set') end)
exports('RemoveParentOrganization',function(request) return Boundary(OrganizationHierarchy.Change,request,'remove') end)
exports('ListOrganizationChildren',function(request) return Boundary(OrganizationHierarchy.Children,request) end)
