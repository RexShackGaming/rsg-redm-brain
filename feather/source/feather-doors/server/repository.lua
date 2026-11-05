DoorsRepository = {}
function DoorsRepository.New(db,allowed,controlled)
    local C=DoorsContract
    local api={}
    local function snapshot(tx,row)
        if not row then return nil end
        local result={doorId=row.door_id,key=row.door_key,label=row.label,status=row.status,
            locked=tonumber(row.locked)==1,revision=tonumber(row.revision),delegationEpoch=tonumber(row.delegation_epoch),
            startupPolicy=row.startup_policy,leaves={}}
        for _,leaf in ipairs(tx.query('SELECT * FROM `feather_door_leaves` WHERE `door_id`=? ORDER BY `ordinal`',row.door_id)) do
            result.leaves[#result.leaves+1]={hash=tonumber(leaf.door_hash),model=tonumber(leaf.model_hash),
                x=tonumber(leaf.x),y=tonumber(leaf.y),z=tonumber(leaf.z)}
        end
        if not C.Uuid(result.doorId) or not C.Int(result.revision,1,C.MaxRevision)
            or not C.Int(result.delegationEpoch,1,C.MaxRevision)
            or (tonumber(row.locked)~=0 and tonumber(row.locked)~=1)
            or (result.status~='active' and result.status~='suspended' and result.status~='retired')
            or not C.Validate('create',{requestId='snapshot',reasonCode='snapshot',key=result.key,label=result.label,
                locked=result.locked,startupPolicy=result.startupPolicy,leaves=result.leaves}) then error('invalid_persistence') end
        return result
    end
    local function controlSnapshot(tx,row)
        local value=snapshot(tx,row)
        return {doorId=value.doorId,key=value.key,status=value.status,locked=value.locked,
            revision=value.revision,delegationEpoch=value.delegationEpoch}
    end
    local function transact(caller,callback,controlKey)
        local function permitted()
            if controlKey~=nil then return controlled~=nil and controlled(caller,controlKey)==true end
            return allowed(caller)
        end
        local result
        local ok,committed=pcall(db.transaction,function(tx)
            -- DB may retry a callback after confirmed deadlock rollback.
            result=nil
            if not permitted() then result=C.Err('unavailable'); return false end
            result=callback(tx)
            if not permitted() then result=C.Err('unavailable'); return false end
            return true
        end)
        if not ok then
            if type(committed)=='table' and committed.rollbackConfirmed==true and committed.driverCode==1062 then
                return C.Err('definition_conflict')
            end
            if type(committed)=='table' and committed.rollbackConfirmed==true then return C.Err('persistence_failed') end
            return C.Err('pending_recovery')
        end
        return result or C.Err(committed and 'invalid_persistence' or 'unavailable')
    end
    function api:Mutate(caller,kind,request,authoritySource)
        if kind=='authority' and caller~='feather-doors' then return C.Err('forbidden') end
        local normalized=C.Validate(kind,request)
        if not normalized then return C.Err('invalid_request') end
        local canonical=C.Canonical({kind=kind,request=normalized,source=kind=='authority' and authoritySource or nil})
        return transact(caller,function(tx)
            -- Unique receipt key serializes concurrent retries before group locks.
            tx.exec([[INSERT INTO `feather_door_operations` (`source_resource`,`request_id`,`request_json`)
                VALUES (?,?,?) ON DUPLICATE KEY UPDATE `request_id`=`request_id`]],caller,normalized.requestId,canonical)
            local receipt=tx.one([[SELECT `request_json`,`result_json` FROM `feather_door_operations`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]],caller,normalized.requestId)
            if not receipt then error('receipt_missing') end
            if receipt.request_json~=canonical then return C.Err('request_conflict') end
            if receipt.result_json then return json.decode(receipt.result_json) end
            local result,row
            if kind=='create' then
                local id=tx.value('SELECT UUID()')
                if not C.Uuid(id) then error('invalid_generated_uuid') end
                tx.exec([[INSERT INTO `feather_door_groups`
                    (`door_id`,`door_key`,`label`,`manager_resource`,`locked`,`startup_policy`) VALUES (?,?,?,?,?,?)]],
                    id,normalized.key,normalized.label,caller,normalized.locked and 1 or 0,normalized.startupPolicy)
                for ordinal,leaf in ipairs(normalized.leaves) do
                    tx.exec([[INSERT INTO `feather_door_leaves`
                        (`door_hash`,`door_id`,`model_hash`,`x`,`y`,`z`,`ordinal`) VALUES (?,?,?,?,?,?,?)]],
                        leaf.hash,id,leaf.model,leaf.x,leaf.y,leaf.z,ordinal)
                end
                row=tx.one('SELECT * FROM `feather_door_groups` WHERE `door_id`=? FOR UPDATE',id)
            else
                if kind=='control' then
                    row=tx.one('SELECT * FROM `feather_door_groups` WHERE `door_key`=? FOR UPDATE',normalized.key)
                elseif kind=='authority' then
                    row=tx.one('SELECT * FROM `feather_door_groups` WHERE `door_id`=? FOR UPDATE',normalized.doorId)
                    local binding=tx.one('SELECT * FROM `feather_door_bindings` WHERE `door_id`=?',normalized.doorId)
                    if not binding or binding.mode~='property' then result=C.Err('target_changed') end
                else
                    row=tx.one('SELECT * FROM `feather_door_groups` WHERE `door_id`=? AND `manager_resource`=? FOR UPDATE',normalized.doorId,caller)
                end
                if result then -- Preserve a terminal authority-mode rejection in its receipt.
                elseif not row then result=C.Err('not_found')
                elseif tonumber(row.revision)~=normalized.expectedRevision then result=C.Err('revision_conflict')
                elseif row.status=='retired' then result=C.Err('retired')
                elseif (kind=='state' or kind=='control') and row.status~='active' then result=C.Err('suspended')
                elseif tonumber(row.revision)>=C.MaxRevision then result=C.Err('revision_exhausted')
                else
                    local status=kind=='retire' and 'retired' or normalized.status or row.status
                    local locked=(kind=='state' or kind=='control') and (normalized.locked and 1 or 0) or tonumber(row.locked)
                    local epoch=tonumber(row.delegation_epoch)
                    if status~=row.status or kind=='binding' or kind=='authority' then epoch=epoch+1 end
                    if epoch>C.MaxRevision then result=C.Err('revision_exhausted') else
                        tx.exec([[UPDATE `feather_door_groups` SET `label`=?,`status`=?,`locked`=?,`startup_policy`=?,
                            `revision`=`revision`+1,`delegation_epoch`=? WHERE `door_id`=? AND `revision`=?]],
                            normalized.label or row.label,status,locked,normalized.startupPolicy or row.startup_policy,
                            epoch,row.door_id,normalized.expectedRevision)
                        row=tx.one('SELECT * FROM `feather_door_groups` WHERE `door_id`=? FOR UPDATE',row.door_id)
                        if kind=='binding' or kind=='authority' then
                            local mode=kind=='authority' and 'property' or normalized.mode
                            local source=mode=='property' and authoritySource or {}
                            if mode=='property' and (type(source)~='table' or not C.Uuid(source.linkId) or not C.Uuid(source.propertyId)
                                or not C.Int(source.epoch,1,9007199254740991)
                                or not ({active=true,suspended=true,retired=true,unavailable=true})[source.status]) then error('invalid_binding_source') end
                            tx.exec([[INSERT INTO `feather_door_bindings` (`door_id`,`mode`,`link_id`,`property_id`,`property_epoch`,`property_status`)
                                VALUES (?,?,?,?,?,?) ON DUPLICATE KEY UPDATE `mode`=VALUES(`mode`),`link_id`=VALUES(`link_id`),
                                `property_id`=VALUES(`property_id`),`property_epoch`=VALUES(`property_epoch`),`property_status`=VALUES(`property_status`)]],
                                row.door_id,mode,source.linkId,source.propertyId,source.epoch,source.status)
                        end
                    end
                end
            end
            if not result and not row then error('group_missing_after_write') end
            result=result or C.Ok(kind=='control' and controlSnapshot(tx,row) or snapshot(tx,row))
            if kind=='control' then result.controlKey=normalized.key end
            if result.ok then DoorsEvents.Record(tx,caller,kind,normalized,result.value) end
            tx.exec([[UPDATE `feather_door_operations` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]],json.encode(result),caller,normalized.requestId)
            return result
        end,kind=='control' and normalized.key or nil)
    end
    function api:Get(caller,request,byKey)
        if not C.Fields(request,byKey and {key=true} or {doorId=true}) then return C.Err('invalid_request') end
        if byKey and not C.Token(request.key,100) or not byKey and not C.Uuid(request.doorId) then return C.Err('invalid_request') end
        return transact(caller,function(tx)
            local sql=byKey and 'SELECT * FROM `feather_door_groups` WHERE `door_key`=? AND `manager_resource`=? FOR UPDATE'
                or 'SELECT * FROM `feather_door_groups` WHERE `door_id`=? AND `manager_resource`=? FOR UPDATE'
            local row=tx.one(sql,byKey and request.key or request.doorId:lower(),caller)
            return row and C.Ok(snapshot(tx,row)) or C.Err('not_found')
        end)
    end
    function api:Find(caller,request)
        if not C.Fields(request,{requestId=true}) or not C.Token(request.requestId,128) then return C.Err('invalid_request') end
        return transact(caller,function(tx)
            local row=tx.one([[SELECT `result_json` FROM `feather_door_operations`
                WHERE `source_resource`=? AND `request_id`=?]],caller,request.requestId)
            if not row then return C.Err('not_found') end
            return row.result_json and C.Ok({result=json.decode(row.result_json)}) or C.Err('pending_recovery')
        end)
    end
    function api:List(caller,request)
        if not C.Fields(request,{limit=true,after=true}) or not C.Int(request.limit==nil and 20 or request.limit,1,50)
            or request.after~=nil and not C.Uuid(request.after) then return C.Err('invalid_request') end
        return transact(caller,function(tx)
            local limit=request.limit or 20
            local rows=tx.query([[SELECT `door_id`,`door_key`,`label`,`status`,`locked`,`revision` FROM `feather_door_groups`
                WHERE `manager_resource`=? AND `door_id`>? ORDER BY `door_id` LIMIT ?]],caller,(request.after or ''):lower(),limit+1)
            local values={}
            for index=1,math.min(limit,#rows) do
                local row=rows[index]
                values[#values+1]={doorId=row.door_id,key=row.door_key,label=row.label,status=row.status,
                    locked=tonumber(row.locked)==1,revision=tonumber(row.revision)}
            end
            return C.Ok({groups=values,nextCursor=#rows>limit and values[#values].doorId or false})
        end)
    end
    function api:Event(caller,request)
        if not C.Fields(request,{requestId=true}) or not C.Token(request.requestId,128) then return C.Err('invalid_request') end
        return transact(caller,function(tx)
            local row=tx.one([[SELECT `event_id`,`event_type`,`door_id`,`source_resource`,`request_id`,`revision`,`payload_json`,`status`,`attempts` FROM `feather_door_outbox`
                WHERE `source_resource`=? AND `request_id`=?]],caller,request.requestId)
            if not row then return C.Err('not_found') end
            local payload=DoorsEvents.Decode(row.payload_json)
            if not DoorsEvents.Matches(row,payload) then return C.Err('invalid_persistence') end
            return C.Ok({eventId=row.event_id,eventType=row.event_type,payload=payload,status=row.status,attempts=tonumber(row.attempts)})
        end)
    end
    function api:ControlGet(caller,request)
        if not C.Fields(request,{key=true}) or not C.Token(request.key,100) then return C.Err('invalid_request') end
        return transact(caller,function(tx)
            local row=tx.one('SELECT * FROM `feather_door_groups` WHERE `door_key`=? FOR UPDATE',request.key)
            return row and C.Ok(controlSnapshot(tx,row)) or C.Err('not_found')
        end,request.key)
    end
    function api:ControlFind(caller,request)
        if not C.Fields(request,{key=true,requestId=true}) or not C.Token(request.key,100)
            or not C.Token(request.requestId,128) then return C.Err('invalid_request') end
        return transact(caller,function(tx)
            local row=tx.one([[SELECT `result_json` FROM `feather_door_operations`
                WHERE `source_resource`=? AND `request_id`=?]],caller,request.requestId)
            if not row then return C.Err('not_found') end
            if not row.result_json then return C.Err('pending_recovery') end
            local value=DoorsEvents.Decode(row.result_json)
            if not value then return C.Err('invalid_persistence') end
            if value.controlKey~=request.key then return C.Err('not_found') end
            return C.Ok({result=value})
        end,request.key)
    end
    return api
end
