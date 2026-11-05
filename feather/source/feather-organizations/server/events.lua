OrganizationEvents = {}
local Ok,Err=Organizations.Ok,Organizations.Err
local running=false
local names={
    ['organization.created']='organizations.organization.created.v1',
    ['organization.status_changed']='organizations.organization.status_changed.v1',
    ['organization.identity_changed']='organizations.organization.identity_changed.v1',
    ['organization.parent_changed']='organizations.organization.parent_changed.v1',
    ['organization.interest_granted']='organizations.organization.interest_granted.v1',
    ['organization.interest_revoked']='organizations.organization.interest_revoked.v1'
}
function OrganizationEvents.Record(tx,organizationId,eventType,resource,requestId,reason,revision,details)
    local rows=tx.query('SELECT UUID() AS id') or {}
    local eventId=rows[1] and rows[1].id
    if not Organizations.Uuid(eventId) or not names[eventType] then error('Invalid organization event identity/type.') end
    local payload={eventId=eventId,organizationId=organizationId,revision=revision,
        sourceResource=resource,requestId=requestId,reasonCode=reason}
    for _,field in ipairs({'status','previousStatus','organizationType','parentOrganizationId','previousParentOrganizationId','interestId','interestType','interestStatus'}) do
        if details and details[field]~=nil then payload[field]=details[field] end
    end
    tx.exec([[INSERT INTO `feather_organization_events`
        (`event_id`,`organization_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`)
        VALUES (?,?,?,?,?,?,?)]], eventId,organizationId,eventType,resource,requestId,reason,revision)
    tx.exec([[INSERT INTO `feather_organization_outbox` (`event_id`,`event_type`,`payload_json`) VALUES (?,?,?)]], eventId,names[eventType],json.encode(payload))
end
local function Deliver()
    local rows=DB.query([[SELECT `event_id`,`event_type`,`payload_json`
        FROM `feather_organization_outbox` WHERE `status`='pending' AND `available_at`<=CURRENT_TIMESTAMP
        ORDER BY `created_at`,`event_id` LIMIT ?]], Config.Outbox.batchSize) or {}
    for _,row in ipairs(rows) do
        if not running then return end
        local decoded,payload=pcall(json.decode,row.payload_json)
        local called,published=false,nil
        if decoded and type(payload)=='table' and payload.eventId==row.event_id then
            called,published=pcall(function() return exports['feather-core']:PublishEvent(row.event_type,payload) end)
        end
        if called and type(published)=='table' and published.ok then
            DB.exec([[UPDATE `feather_organization_outbox` SET `status`='published',
                `published_at`=CURRENT_TIMESTAMP,`attempts`=`attempts`+1 WHERE `event_id`=? AND `status`='pending']], row.event_id)
        else
            DB.exec([[UPDATE `feather_organization_outbox` SET `attempts`=`attempts`+1,
                `available_at`=DATE_ADD(CURRENT_TIMESTAMP,INTERVAL ? SECOND) WHERE `event_id`=? AND `status`='pending']], Config.Outbox.retryDelaySeconds,row.event_id)
            print(('[feather-organizations] event=outbox.failed id=%s code=%s'):format(row.event_id,
                type(published)=='table' and tostring(published.code) or 'publication_unavailable'))
        end
    end
end
function OrganizationEvents.Start()
    if running then return Err('conflict','Organizations publisher is already running.') end
    for _,name in pairs(names) do
        local declared=exports['feather-core']:DeclareEvent(name,{contract=1,maxPayloadBytes=4096,maxDepth=3,maxNodes=32})
        if type(declared)~='table' or not declared.ok then return Err('dependency_unavailable','Could not declare organization event.',{eventType=name}) end
    end
    running=true
    CreateThread(function()
        while running do
            local called,reason=pcall(Deliver)
            if not called then print('[feather-organizations] event=outbox.error ' .. tostring(reason)) end
            Wait(Config.Outbox.pollIntervalMs)
        end
    end)
    return Ok(true)
end
function OrganizationEvents.Stop() running=false end
function OrganizationEvents.State()
    local rows=DB.query('SELECT `status`,COUNT(*) AS total FROM `feather_organization_outbox` GROUP BY `status`') or {}
    local state={running=running,pending=0,published=0}
    for _,row in ipairs(rows) do state[row.status]=tonumber(row.total) end
    return Ok(state)
end
function OrganizationEvents.ValidateHistory(request)
    if type(request)~='table' or not Organizations.Uuid(request.organizationId) then return Err('invalid_input','Organization UUID required.') end
    for key in pairs(request) do
        if key~='organizationId' and key~='limit' and key~='cursor' then return Err('invalid_input','Unexpected history field.') end
    end
    local limit=request.limit
    if limit==nil then limit=20 end
    if not Organizations.Integer(limit,1,50) or (request.cursor~=nil and not Organizations.Uuid(request.cursor)) then
        return Err('invalid_input','Integer history limit 1–50 and valid event UUID cursor required.')
    end
    return Ok({organizationId=request.organizationId:lower(),limit=limit,cursor=request.cursor and request.cursor:lower()})
end
function OrganizationEvents.History(request,resource)
    if Config.Access.trustedAuditors[resource or '']~=true then return Err('authorization_denied','Caller is not a trusted auditor.') end
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid=OrganizationEvents.ValidateHistory(request)
    if not valid.ok then return valid end
    local options=valid.value
    local owner=DB.one('SELECT `created_by_resource` FROM `feather_organizations` WHERE `organization_id`=?', options.organizationId)
    if not owner then return Err('organization_not_found','Organization not found.') end
    if owner.created_by_resource~=resource and Config.Access.privilegedAuditors[resource]~=true then
        return Err('authorization_denied','Caller cannot inspect this organization history.')
    end
    local sql=[[SELECT `event_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`,
        UNIX_TIMESTAMP(`created_at`)*1000 AS created_at_ms FROM `feather_organization_events` WHERE `organization_id`=?]]
    local params={options.organizationId}
    if options.cursor then
        local cursor=DB.one([[SELECT DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_organization_events` WHERE `event_id`=? AND `organization_id`=?]], options.cursor,options.organizationId)
        if not cursor then return Err('invalid_cursor','History cursor does not belong to this organization.') end
        sql=sql .. ' AND (`created_at`<? OR (`created_at`=? AND `event_id`<?))'
        params[#params+1]=cursor.cursor_time;params[#params+1]=cursor.cursor_time;params[#params+1]=options.cursor
    end
    sql=sql .. ' ORDER BY `created_at` DESC,`event_id` DESC LIMIT ?';params[#params+1]=options.limit+1
    local rows=DB.query(sql, table.unpack(params)) or {}
    local items={}
    for index=1,math.min(#rows,options.limit) do
        local row=rows[index]
        items[#items+1]={eventId=row.event_id,eventType=row.event_type,organizationId=options.organizationId,
            sourceResource=row.source_resource,requestId=row.request_id,reasonCode=row.reason_code,
            revision=tonumber(row.revision),createdAt=tonumber(row.created_at_ms)}
    end
    local nextCursor
    if #rows>options.limit then nextCursor=items[#items].eventId end
    return Ok({items=items,nextCursor=nextCursor})
end
exports('InspectOrganizationHistory',function(request)
    local called,result=xpcall(function() return OrganizationEvents.History(request,GetInvokingResource()) end,debug.traceback)
    if not called then
        print('[feather-organizations] history API failure: ' .. tostring(result))
        return Err('internal_error','Organization history read failed.')
    end
    return result
end)
