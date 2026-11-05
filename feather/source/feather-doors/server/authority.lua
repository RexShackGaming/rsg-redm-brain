-- Advisory management preflight only. Never a reusable grant or door-use permit.
DoorsAuthority = {}
function DoorsAuthority.New(binding,port,ready)
    local C=DoorsContract
    local api={generation=0,fences={}}
    function api:Drop() self.generation=self.generation+1 end
    function api:Bump(source)
        if C.Int(source,1,65535) then self.fences[source]=(self.fences[source] or 0)+1 end
    end
    local function invoke(fn,...)
        local ok,result=pcall(fn,...)
        if not ok or type(result)~='table' or result.ok~=true or type(result.value)~='table' then return nil end
        return result.value
    end
    local function session(source)
        local actor=invoke(port.session,source)
        if not actor or not C.Uuid(actor.accountId) or not C.Uuid(actor.characterId) or not C.Uuid(actor.sessionId)
            or not C.Int(actor.generation,1,9007199254740991) then return nil end
        return {accountId=actor.accountId:lower(),characterId=actor.characterId:lower(),
            sessionId=actor.sessionId:lower(),generation=actor.generation}
    end
    local function sameActor(a,b)
        return a and b and a.accountId==b.accountId and a.characterId==b.characterId
            and a.sessionId==b.sessionId and a.generation==b.generation
    end
    local function sameTarget(a,b)
        return a and b and a.door_id==b.door_id and a.manager_resource==b.manager_resource
            and tonumber(a.revision)==tonumber(b.revision) and tonumber(a.delegation_epoch)==tonumber(b.delegation_epoch)
            and a.status==b.status and a.effective_status==b.effective_status and a.authority_mode==b.authority_mode
            and a.binding_link_id==b.binding_link_id and a.binding_property_id==b.binding_property_id
            and tonumber(a.binding_property_epoch)==tonumber(b.binding_property_epoch)
    end
    function api:Check(caller,request)
        if not C.Fields(request,{doorId=true,actorSource=true,operation=true,capability=true,path=true})
            or not C.Uuid(request.doorId) or not C.Int(request.actorSource,1,65535)
            or not ({grant=true,revoke=true,list=true})[request.operation]
            or not ({property=true,staff=true})[request.path]
            or (request.operation=='list' and request.capability~=nil)
            or (request.operation~='list' and request.capability~='door.lock' and request.capability~='door.unlock') then
            return C.Err('invalid_request')
        end
        if not ready() then return C.Err('unavailable') end
        local generation=self.generation
        local fence=self.fences[request.actorSource] or 0
        local actor=session(request.actorSource)
        if not actor then return C.Err('actor_unavailable') end
        local id=request.doorId:lower()
        local before,err=binding:Read(id)
        if not before then return C.Err(err) end
        if before.manager_resource~=caller then return C.Err('not_found') end
        local function active(row) return row.status=='active' and (not row.effective_status or row.effective_status=='active') end
        if not active(before) then return C.Ok({allowed=false,code='target_unavailable'}) end
        local allowed=false
        if request.path=='property' then
            if before.authority_mode=='property' and C.Uuid(before.binding_property_id) then
                local interest=invoke(port.interest,{propertyId=before.binding_property_id,holderType='character',
                    holderId=actor.characterId,interestType='owner'})
                if not interest then return C.Err('property_unavailable') end
                if interest.propertyId~=before.binding_property_id or type(interest.matched)~='boolean' then return C.Err('property_invalid') end
                allowed=interest.matched and interest.propertyStatus=='active'
            end
        else
            local decision=invoke(port.policy,'doors.grant.manage',{source=request.actorSource,
                subject={doorId=id,operation=request.operation,capability=request.capability}})
            if not decision or type(decision.allowed)~='boolean' then return C.Err('policy_unavailable') end
            allowed=decision.allowed
        end
        local after,readErr=binding:Read(id)
        if not after then return C.Err(readErr) end
        if not ready() or generation~=self.generation then return C.Err('unavailable') end
        if not sameTarget(before,after) then return C.Err('target_changed') end
        local current=session(request.actorSource)
        local final,finalErr=binding:Read(id)
        if not final then return C.Err(finalErr) end
        if not sameTarget(after,final) then return C.Err('target_changed') end
        if not sameActor(actor,current) or fence~=(self.fences[request.actorSource] or 0) or generation~=self.generation
            or not ready() then return C.Err('stale_session') end
        return C.Ok({allowed=allowed==true,code=allowed and 'allowed' or 'authority_denied',path=request.path,
            doorId=id,epoch=tonumber(after.delegation_epoch),advisory=true})
    end
    return api
end
