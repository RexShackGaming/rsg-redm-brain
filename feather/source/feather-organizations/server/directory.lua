OrganizationDirectory = {}
local Ok, Err = Organizations.Ok, Organizations.Err
local statuses = { pending=true,active=true,suspended=true,dissolving=true,dissolved=true }
local function Key(value, maximum)
    return type(value)=='string' and #value<=maximum and value:match('^[a-z][a-z0-9_]*$')~=nil
end
local function Name(value, maximum)
    return type(value)=='string' and #value>0 and #value<=maximum
        and not value:find('%c') and value:find('%S')~=nil
end
function OrganizationDirectory.ValidateList(request)
    if type(request)~='table' then return Err('invalid_input','Directory request required.') end
    local fields={limit=true,cursor=true,status=true,organizationType=true,parentOrganizationId=true}
    for key in pairs(request) do
        if not fields[key] then return Err('invalid_input','Unexpected directory field.') end
    end
    local limit=request.limit
    if limit==nil then limit=20 end
    if not Organizations.Integer(limit,1,50)
        or (request.cursor~=nil and not Key(request.cursor,64))
        or (request.status~=nil and (type(request.status)~='string' or not statuses[request.status]))
        or (request.organizationType~=nil and not Key(request.organizationType,48)) then
        return Err('invalid_input','Integer limit 1–50 and valid cursor/type/status required.')
    end
    if request.parentOrganizationId~=nil and not Organizations.Uuid(request.parentOrganizationId) then
        return Err('invalid_input','Valid parent organization UUID required.')
    end
    return Ok({limit=limit,cursor=request.cursor,status=request.status,organizationType=request.organizationType,
        parentOrganizationId=request.parentOrganizationId and request.parentOrganizationId:lower()})
end
function OrganizationDirectory.List(request,resource)
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid=OrganizationDirectory.ValidateList(request)
    if not valid.ok then return valid end
    local options=valid.value
    local sql=OrganizationIdentity.SelectSql .. ' WHERE o.`organization_key`>?'
    local params={options.cursor or ''}
    if options.status then sql=sql .. ' AND o.`status`=?';params[#params+1]=options.status end
    if options.organizationType then sql=sql .. ' AND t.`type_key`=?';params[#params+1]=options.organizationType end
    if options.parentOrganizationId then sql=sql .. ' AND p.`parent_organization_id`=?';params[#params+1]=options.parentOrganizationId end
    sql=sql .. ' ORDER BY o.`organization_key` ASC LIMIT ?';params[#params+1]=options.limit+1
    local rows=DB.query(sql, table.unpack(params)) or {}
    local items={}
    for index=1,math.min(#rows,options.limit) do
        local snapshot=OrganizationIdentity.Snapshot(rows[index])
        if not snapshot.ok then return snapshot end
        items[#items+1]=snapshot.value
    end
    local nextCursor
    if #rows>options.limit then nextCursor=items[#items].organizationKey end
    return Ok({items=items,nextCursor=nextCursor})
end
function OrganizationDirectory.ValidateUpdate(request)
    if type(request)~='table' then return Err('invalid_input','Identity update required.') end
    local fields={organizationId=true,expectedRevision=true,requestId=true,reasonCode=true,legalName=true,displayName=true}
    for key in pairs(request) do
        if not fields[key] then return Err('invalid_input','Unexpected identity update field.') end
    end
    if not Organizations.Uuid(request.organizationId)
        or not Organizations.Integer(request.expectedRevision,1,9007199254740990)
        or type(request.requestId)~='string' or #request.requestId>128
        or not request.requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or type(request.reasonCode)~='string' or #request.reasonCode>64
        or not request.reasonCode:match('^[a-z][a-z0-9._:%-]*$')
        or not Name(request.legalName,160) or not Name(request.displayName,100) then
        return Err('invalid_input','UUID, integer revision, stable request ID, reason and bounded names required.')
    end
    local parts={request.organizationId:lower(),tostring(request.expectedRevision),request.reasonCode,request.legalName,request.displayName}
    for index,value in ipairs(parts) do parts[index]=tostring(#value) .. ':' .. value end
    return Ok(table.concat(parts))
end
function OrganizationDirectory.Update(request,resource)
    if Config.Access.trustedMutators[resource or '']~=true then return Err('authorization_denied','Caller is not a trusted identity mutator.') end
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid=OrganizationDirectory.ValidateUpdate(request)
    if not valid.ok then return valid end
    request=Organizations.Copy(request);request.organizationId=request.organizationId:lower()
    if Config.Authorization.enabled then
        local decision=exports['feather-core']:Authorize(Config.Authorization.updateAction,{
            correlationId=request.requestId,subject={resource=resource,organizationId=request.organizationId,operation='identity_update'}})
        if type(decision)~='table' or not decision.ok or type(decision.value)~='table' or decision.value.allowed~=true then
            return Err('authorization_denied','Identity update policy denied.')
        end
    end
    local current=Organizations.CheckRead(resource)
    if not current.ok then return current end
    local result
    local called,committed=pcall(DB.transaction, function(tx)
        local executed,outcome=xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_organization_identity_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]], resource,request.requestId,valid.value)
            local receipts=tx.query([[SELECT `request_fingerprint`,`result_json` FROM `feather_organization_identity_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], resource,request.requestId) or {}
            local receipt=receipts[1]
            if not receipt then return Err('internal_error','Could not reserve identity receipt.') end
            if receipt.request_fingerprint~=valid.value then return Err('idempotency_conflict','Request ID is bound to another identity update.') end
            local rows=tx.query(OrganizationIdentity.SelectSql .. ' WHERE o.`organization_id`=? FOR UPDATE', request.organizationId) or {}
            local row=rows[1]
            if not row then return Err('organization_not_found','Organization not found.') end
            if row.created_by_resource~=resource and Config.Access.privilegedMutators[resource]~=true then
                return Err('authorization_denied','Caller does not own this organization identity.')
            end
            if receipt.result_json then
                local decoded,value=pcall(json.decode,receipt.result_json)
                if not decoded or type(value)~='table' or value.organizationId~=request.organizationId
                    or value.legalName~=request.legalName or value.displayName~=request.displayName
                    or value.revision~=request.expectedRevision+1 or not Organizations.Uuid(value.organizationTypeId)
                    or not Key(value.organizationKey,64) or not statuses[value.status] then
                    return Err('invalid_persistence','Stored identity update receipt is invalid.')
                end
                value.replayed=true;return Ok(value)
            end
            local events=tx.query([[SELECT `event_id` FROM `feather_organization_events`
                WHERE `source_resource`=? AND `request_id`=?]], resource,request.requestId) or {}
            if #events>0 then return Err('idempotency_conflict','Request ID belongs to another organization operation.') end
            local snapshot=OrganizationIdentity.Snapshot(row)
            if not snapshot.ok then return snapshot end
            if snapshot.value.revision~=request.expectedRevision then return Err('revision_conflict','Organization revision changed.') end
            if row.status~='pending' and row.status~='active' and row.status~='suspended' then
                return Err('organization_inactive','Dissolving or dissolved identity cannot be edited.')
            end
            if row.legal_name==request.legalName and row.display_name==request.displayName then return Err('no_change','Names are unchanged.') end
            tx.exec([[UPDATE `feather_organizations` SET `legal_name`=?,`display_name`=?,`revision`=`revision`+1
                WHERE `organization_id`=? AND `revision`=?]], request.legalName,request.displayName,request.organizationId,request.expectedRevision)
            OrganizationEvents.Record(tx,request.organizationId,'organization.identity_changed',resource,
                request.requestId,request.reasonCode,request.expectedRevision+1)
            local value=snapshot.value
            value.legalName,value.displayName=request.legalName,request.displayName
            value.revision,value.replayed=request.expectedRevision+1,false
            tx.exec([[UPDATE `feather_organization_identity_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]], json.encode(value),resource,request.requestId)
            return Ok(value)
        end,debug.traceback)
        if not executed then
            print('[feather-organizations] identity transaction failed: ' .. tostring(outcome))
            result=Err('internal_error','Identity transaction failed.');return false
        end
        result=outcome;return outcome.ok==true
    end)
    if not called or (result and result.ok and committed~=true) then return Err('transaction_failed','Identity commit not confirmed. Retry the same request ID.') end
    return result or Err('transaction_failed','Identity update did not complete. Retry the same request ID.')
end
local function Boundary(operation,request)
    local called,result=xpcall(function() return operation(request,GetInvokingResource()) end,debug.traceback)
    if not called then
        print('[feather-organizations] directory API failure: ' .. tostring(result))
        return Err('internal_error','Organization directory operation failed.')
    end
    return result
end
exports('ListOrganizations',function(request) return Boundary(OrganizationDirectory.List,request) end)
exports('UpdateOrganizationIdentity',function(request) return Boundary(OrganizationDirectory.Update,request) end)
