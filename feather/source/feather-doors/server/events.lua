DoorsEvents = {}
local E=DoorsEvents
E.Names={definition='doors.definition.changed.v1',state='doors.state.changed.v1'}
local kinds={create=true,update=true,state=true,control=true,binding=true,authority=true,retire=true}
function E.Decode(text)
    if type(text)~='string' or #text>2048 then return nil end
    -- Runtime rapidjson can retain JSON metadata despite dkjson-compatible
    -- nil metadata arguments. Copy only bounded decoded data using raw iteration;
    -- never loosen plain-table validation for incoming API requests.
    local ok,value,position,err=pcall(json.decode,text,1,nil,nil,nil)
    if not ok or err~=nil or type(value)~='table' or type(position)~='number'
        or text:sub(position):find('%S') then return nil end
    local seen,nodes={},0
    local function plain(item,depth)
        nodes=nodes+1
        if nodes>256 or depth>8 then error('decoded_json_limits') end
        local kind=type(item)
        if kind=='string' or kind=='boolean' then return item end
        if kind=='number' and item==item and math.abs(item)<math.huge then return item end
        if kind~='table' or seen[item] then error('invalid_decoded_json') end
        seen[item]=true
        local result={}
        for key,child in next,item do
            if type(key)~='string' and type(key)~='number' then error('invalid_json_key') end
            result[key]=plain(child,depth+1)
        end
        seen[item]=nil
        return result
    end
    local copied,result=pcall(plain,value,0)
    return copied and result or nil
end
function E.Validate(payload,name)
    local C=DoorsContract
    return C.Fields(payload,{contract=true,eventId=true,eventType=true,doorId=true,revision=true,
        delegationEpoch=true,sourceResource=true,requestId=true,reasonCode=true,operation=true,status=true,locked=true})
        and payload.contract==1 and C.Uuid(payload.eventId) and C.Uuid(payload.doorId)
        and C.Int(payload.revision,1,C.MaxRevision) and C.Int(payload.delegationEpoch,1,C.MaxRevision)
        and C.Token(payload.sourceResource,100) and C.Token(payload.requestId,128) and C.Token(payload.reasonCode,64)
        and kinds[payload.operation]==true and type(payload.locked)=='boolean'
        and (payload.status=='active' or payload.status=='suspended' or payload.status=='retired')
        and payload.eventType==((payload.operation=='state' or payload.operation=='control') and E.Names.state or E.Names.definition)
        and payload.eventType==name
end
function E.Matches(row,payload)
    return E.Validate(payload,row.event_type) and payload.eventId==row.event_id and payload.doorId==row.door_id
        and payload.sourceResource==row.source_resource and payload.requestId==row.request_id
        and payload.revision==tonumber(row.revision)
end
function E.Record(tx,caller,kind,request,snapshot)
    local name=(kind=='state' or kind=='control') and E.Names.state or E.Names.definition
    local payload={contract=1,eventId=tx.value('SELECT UUID() AS event_id'),eventType=name,
        doorId=snapshot.doorId,revision=snapshot.revision,delegationEpoch=snapshot.delegationEpoch,
        sourceResource=caller,requestId=request.requestId,reasonCode=request.reasonCode,
        operation=kind,status=snapshot.status,locked=snapshot.locked}
    if not E.Validate(payload,name) then error('invalid_event_payload') end
    tx.exec([[INSERT INTO `feather_door_outbox`
        (`event_id`,`door_id`,`source_resource`,`request_id`,`event_type`,`revision`,`payload_json`)
        VALUES (?,?,?,?,?,?,?)]],payload.eventId,payload.doorId,caller,request.requestId,name,payload.revision,json.encode(payload))
end
function E.New(db,publish,ready)
    local api={enabled=false,busy=false,lastCode='idle'}
    function api:Drain()
        if self.busy then return DoorsContract.Err('busy') end
        if not ready() then return DoorsContract.Err('unavailable') end
        self.busy=true
        local ok,result=pcall(function()
            local rows=db.query([[SELECT `event_id`,`event_type`,`door_id`,`source_resource`,`request_id`,`revision`,`payload_json` FROM `feather_door_outbox`
                WHERE `status`='pending' AND `available_at`<=CURRENT_TIMESTAMP ORDER BY `created_at`,`event_id` LIMIT 20]])
            local counts={published=0,retried=0,quarantined=0}
            for _,row in ipairs(rows) do
                if not ready() then return DoorsContract.Err('unavailable') end
                local payload=E.Decode(row.payload_json)
                if not E.Matches(row,payload) then
                    db.exec([[UPDATE `feather_door_outbox` SET `status`='quarantined',`attempts`=LEAST(`attempts`+1,2147483647)
                        WHERE `event_id`=? AND `status`='pending']],row.event_id)
                    counts.quarantined=counts.quarantined+1
                else
                    local called,sent=pcall(publish,row.event_type,payload)
                    -- Core success alone can include failed listeners. Replay the
                    -- stable event ID if any listener raised, including to listeners
                    -- that already succeeded. Consumers must deduplicate.
                    local accepted=called and type(sent)=='table' and sent.ok==true
                        and type(sent.value)=='table' and sent.value.failed==0
                        and DoorsContract.Int(sent.value.delivered,0,64)
                    if not ready() then return DoorsContract.Err('unavailable') end
                    if accepted then
                        db.exec([[UPDATE `feather_door_outbox` SET `status`='published',`published_at`=CURRENT_TIMESTAMP,
                            `attempts`=LEAST(`attempts`+1,2147483647) WHERE `event_id`=? AND `status`='pending']],row.event_id)
                        counts.published=counts.published+1
                    else
                        db.exec([[UPDATE `feather_door_outbox` SET `attempts`=LEAST(`attempts`+1,2147483647),
                            `available_at`=DATE_ADD(CURRENT_TIMESTAMP,INTERVAL 5 SECOND)
                            WHERE `event_id`=? AND `status`='pending']],row.event_id)
                        counts.retried=counts.retried+1
                    end
                end
            end
            return DoorsContract.Ok(counts)
        end)
        self.busy=false
        self.lastCode=not ok and 'database_exception' or (result.ok
            and (result.value.quarantined>0 and 'quarantined' or result.value.retried>0 and 'retry_pending' or 'ok') or result.code)
        return ok and result or DoorsContract.Err('database_exception')
    end
    function api:Status()
        local result={enabled=self.enabled,busy=self.busy,lastCode=self.lastCode,pending=0,published=0,quarantined=0}
        for _,row in ipairs(db.query('SELECT `status`,COUNT(*) AS total FROM `feather_door_outbox` GROUP BY `status`')) do
            if row.status=='pending' or row.status=='published' or row.status=='quarantined' then result[row.status]=tonumber(row.total) end
        end
        return result
    end
    return api
end

-- Console-only recovery of the four known, already-retired acceptance facts.
-- Never rewrites payloads, event IDs, receipts, groups or attempt counters.
function E.RecoverFixture(db)
    local caller='feather-doors-outbox-tests'
    local ids={'doors-outbox-v1.create','doors-outbox-v1.update','doors-outbox-v1.state','doors-outbox-v1.retire'}
    local result
    local committed=db.transaction(function(tx)
        result={requeued=0,unchanged=0}
        local rows=tx.query([[SELECT o.*,r.`result_json` AS receipt_result_json FROM `feather_door_outbox` o
            JOIN `feather_door_operations` r ON r.`source_resource`=o.`source_resource` AND r.`request_id`=o.`request_id`
            WHERE o.`source_resource`=? AND o.`request_id` IN (?,?,?,?) FOR UPDATE]],caller,table.unpack(ids))
        if #rows~=4 then result=nil; return false end
        local requeue={}
        for _,row in ipairs(rows) do
            local payload=E.Decode(row.payload_json)
            local receipt=E.Decode(row.receipt_result_json)
            local snapshot=receipt and receipt.ok==true and receipt.value
            if not E.Matches(row,payload) or row.source_resource~=caller or type(snapshot)~='table'
                or snapshot.doorId~=payload.doorId or snapshot.revision~=payload.revision
                or snapshot.delegationEpoch~=payload.delegationEpoch or snapshot.status~=payload.status
                or snapshot.locked~=payload.locked then result=nil; return false end
            if row.status=='quarantined' then
                requeue[#requeue+1]=row.event_id
            elseif row.status=='pending' or row.status=='published' then result.unchanged=result.unchanged+1
            else result=nil; return false end
        end
        for _,eventId in ipairs(requeue) do
            tx.exec([[UPDATE `feather_door_outbox` SET `status`='pending',`available_at`=CURRENT_TIMESTAMP
                WHERE `event_id`=? AND `status`='quarantined']],eventId)
            result.requeued=result.requeued+1
        end
        return true
    end)
    return committed and result and DoorsContract.Ok(result) or DoorsContract.Err('fixture_recovery_refused')
end

function E.DiagnoseFixture(db)
    local rows=db.query([[SELECT o.*,r.`result_json` AS receipt_result_json FROM `feather_door_outbox` o
        JOIN `feather_door_operations` r ON r.`source_resource`=o.`source_resource` AND r.`request_id`=o.`request_id`
        WHERE o.`source_resource`=? AND o.`request_id` IN (?,?,?,?) ORDER BY o.`request_id`]],
        'feather-doors-outbox-tests','doors-outbox-v1.create','doors-outbox-v1.update','doors-outbox-v1.state','doors-outbox-v1.retire')
    local results={decoderVersion=tostring(json.version or json._VERSION or 'unknown'),rows={}}
    for _,row in ipairs(rows) do
        local ok,payload,position,err=pcall(json.decode,row.payload_json,1,nil,nil,nil)
        local normalized=E.Decode(row.payload_json)
        local p=ok and type(payload)=='table' and payload or {}
        local receipt=E.Decode(row.receipt_result_json)
        local snapshot=receipt and type(receipt.value)=='table' and receipt.value or {}
        local fields={}
        for _,key in ipairs({'contract','eventId','eventType','doorId','revision','delegationEpoch','sourceResource','requestId','reasonCode','operation','status','locked'}) do
            fields[key]=type(p[key])
        end
        results.rows[#results.rows+1]={requestId=row.request_id,status=row.status,
            storageType=type(row.payload_json),bytes=type(row.payload_json)=='string' and #row.payload_json or false,
            decodeOk=ok,decodedType=type(payload),positionType=type(position),position=type(position)=='number' and position or false,
            decodeError=type(err)=='string' and err:sub(1,100) or false,metadata=type(getmetatable(p)),
            normalizedType=type(normalized),fieldTypes=fields,validPayload=E.Validate(p,row.event_type)==true,
            normalizedValidPayload=E.Validate(normalized,row.event_type)==true,normalizedMatches=E.Matches(row,normalized)==true,
            matches={eventId=p.eventId==row.event_id,doorId=p.doorId==row.door_id,source=p.sourceResource==row.source_resource,
                request=p.requestId==row.request_id,revision=p.revision==tonumber(row.revision),eventType=p.eventType==row.event_type},
            receiptNormalized=type(receipt),receiptOk=type(receipt)=='table' and receipt.ok==true,
            receiptMatches={doorId=snapshot.doorId==p.doorId,revision=snapshot.revision==p.revision,
                epoch=snapshot.delegationEpoch==p.delegationEpoch,status=snapshot.status==p.status,locked=snapshot.locked==p.locked}}
    end
    return DoorsContract.Ok(results)
end
