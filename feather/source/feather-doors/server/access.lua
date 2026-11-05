-- Target facts only. This slice cannot grant access or authorize a player action.
DoorsAccess = {}
function DoorsAccess.New(db,port,ready,binding)
    local C=DoorsContract
    local api={registered=false,generation=0,lastCode='not_registered'}
    local function available() return ready() and port.available() end
    local function call(name,request)
        if not available() then return C.Err('provider_unavailable') end
        local ok,result=pcall(port.call,name,request)
        return ok and type(result)=='table' and type(result.ok)=='boolean' and result or C.Err('provider_unavailable')
    end
    local function read(id)
        if not available() then return nil,'provider_unavailable' end
        local called,row,readErr
        if binding then called,row,readErr=pcall(binding.Read,binding,id)
        else called,row=pcall(db.one,[[SELECT `door_id`,`manager_resource`,`status`,`revision`,`delegation_epoch`
            FROM `feather_door_groups` WHERE `door_id`=?]],id) end
        if not called then return nil,'provider_unavailable' end
        if not available() then return nil,'provider_unavailable' end
        if not row then return nil,readErr or 'not_found' end
        if row.door_id~=id or not C.Int(tonumber(row.revision),1,C.MaxRevision)
            or not C.Int(tonumber(row.delegation_epoch),1,C.MaxRevision)
            or (row.status~='active' and row.status~='suspended' and row.status~='retired') then
            return nil,'invalid_persistence'
        end
        if row.effective_status then row.status=row.effective_status end
        return row
    end
    function api:Drop()
        self.registered=false; self.generation=self.generation+1; self.lastCode='not_registered'
    end
    function api:Resolve(request)
        if not C.Fields(request,{targetType=true,targetId=true}) or request.targetType~='doors.group'
            or not C.Uuid(request.targetId) then return C.Err('invalid_request') end
        if not self.registered or not available() then return C.Err('provider_unavailable') end
        local generation=self.generation
        local row,err=read(request.targetId:lower())
        if not row then return C.Err(err) end
        if generation~=self.generation or not self.registered then return C.Err('provider_unavailable') end
        return C.Ok({targetType='doors.group',targetId=row.door_id,epoch=tonumber(row.delegation_epoch),
            status=row.status,capabilities={'door.lock','door.unlock'}})
    end
    function api:Register()
        if self.registered then return C.Err('already_registered') end
        local generation=self.generation
        local awaited=call('AwaitReady',30000)
        if awaited.ok~=true then self.lastCode=awaited.code or 'provider_unavailable'; return awaited end
        local capabilities=call('GetCapabilities')
        if capabilities.ok~=true or type(capabilities.value)~='table' or capabilities.value.contract~=1 then
            self.lastCode='contract_unavailable'; return C.Err(self.lastCode)
        end
        local result=call('RegisterTargetProvider',{targetType='doors.group',contract=1,
            resolve=function(request) return self:Resolve(request) end,
            -- Resource ownership is not authority over character-owned grants.
            authorize=function() return C.Ok({allowed=false}) end})
        if generation~=self.generation or not available() then result=C.Err('provider_unavailable') end
        self.registered=result.ok==true; self.lastCode=self.registered and 'registered' or result.code or 'provider_unavailable'
        return result
    end
    function api:Unregister()
        self:Drop()
        local result=call('UnregisterTargetProvider',{targetType='doors.group'})
        self.lastCode=result.ok==true and 'not_registered' or result.code or 'provider_unavailable'
        return result
    end
    function api:Context(caller,request)
        if not C.Fields(request,{doorId=true}) or not C.Uuid(request.doorId) then return C.Err('invalid_request') end
        if not self.registered then return C.Err('provider_unavailable') end
        local generation=self.generation
        local id=request.doorId:lower()
        local before,err=read(id)
        if not before then return C.Err(err) end
        if before.manager_resource~=caller then return C.Err('not_found') end
        local result=call('ResolveTargetContext',{targetType='doors.group',targetId=id})
        if result.ok~=true then return result end
        local after,readErr=read(id)
        if not after then return C.Err(readErr) end
        if not self.registered or self.generation~=generation then return C.Err('provider_unavailable') end
        if after.manager_resource~=caller or tonumber(after.revision)~=tonumber(before.revision)
            or tonumber(after.delegation_epoch)~=tonumber(before.delegation_epoch)
            or after.status~=before.status then return C.Err('target_changed') end
        local value=result.value
        if type(value)~='table' or value.targetType~='doors.group' or value.targetId~=id
            or value.epoch~=tonumber(after.delegation_epoch) or value.status~=after.status
            or type(value.provider)~='table' or value.provider.resource~='feather-doors' or value.provider.contract~=1
            or not C.Int(value.provider.generation,1,9007199254740991)
            or type(value.capabilities)~='table' or #value.capabilities~=2
            or not ((value.capabilities[1]=='door.lock' and value.capabilities[2]=='door.unlock')
                or (value.capabilities[2]=='door.lock' and value.capabilities[1]=='door.unlock')) then
            return C.Err('provider_invalid')
        end
        return result
    end
    return api
end
