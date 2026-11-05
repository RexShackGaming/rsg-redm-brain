Access.Preservation={}
local P,G=Access.Preservation,Access.Grants
local maximum=25
function P.Resolve(request,caller)
    if not Access.OnlyFields(request,{manifestId=true,targetType=true,targetId=true})
        or not Access.Uuid(request.manifestId) or not Access.Key(request.targetType) or not Access.Uuid(request.targetId) then
        return Access.Err('invalid_input','Exact manifest/target required.')
    end
    local definition=Config.Providers.Targets[request.targetType]
    local ready=Access.Ready();if not ready.ok then return ready end
    if not definition or definition.resource~=caller then return Access.Err('authorization_denied','Owning target domain required.')end
    local manifest=DB.one('SELECT * FROM `feather_access_preservation_manifests` WHERE `manifest_id`=?',request.manifestId:lower())
    if not manifest or (manifest.status~='prepared' and manifest.status~='adopted') or manifest.target_type~=request.targetType or manifest.target_id~=request.targetId:lower() then
        return Access.Err('manifest_unavailable','Prepared manifest does not match this target.')
    end
    return Access.Ok({manifestId=manifest.manifest_id,sourceEpoch=tonumber(manifest.source_epoch)})
end
local function Selection(value)
    if type(value)~='table' or getmetatable(value)~=nil then return nil end
    local result,seen,count={},{},0
    for key,item in pairs(value) do
        count=count+1
        if count>maximum or not Access.Integer(key,1,maximum) or not Access.OnlyFields(item,{grantId=true,expectedRevision=true})
            or not Access.Uuid(item.grantId) or not Access.Integer(item.expectedRevision,1,9007199254740990) then return nil end
        local id=item.grantId:lower();if seen[id] then return nil end;seen[id]=true
        result[key]={id,item.expectedRevision}
    end
    if count==0 or #result~=count then return nil end
    for i=1,count do if not result[i] then return nil end end
    table.sort(result,function(a,b)return a[1]<b[1]end)
    return result
end
local common={requestId=true,reasonCode=true,actorSource=true,grants=true}
local function Input(request,extra)
    local fields=Access.Copy(common);for _,key in ipairs(extra)do fields[key]=true end
    if not Access.OnlyFields(request,fields) or not G.Token(request.requestId,128) or not Access.Key(request.reasonCode)
        or not Access.Integer(request.actorSource,1,65535) then return nil end
    return Selection(request.grants)
end
local function Context(targetType,targetId,epoch)
    local context=G.Context(targetType,targetId)
    if not context.ok then return context end
    if context.value.status~='active' or context.value.epoch~=epoch then return Access.Err('epoch_conflict','Target is unavailable or ownership changed.')end
    return context
end
local function Current(context,actor)
    local fresh=Context(context.targetType,context.targetId,context.epoch)
    if not fresh.ok then return fresh end
    if fresh.value.provider.generation~=context.provider.generation then return Access.Err('provider_changed','Target provider changed.')end
    return G.Current(actor)
end
local function Locked(tx,id,targetType,targetId,epoch,revision,now)
    local row=tx.one('SELECT * FROM `feather_access_grants` WHERE `grant_id`=? FOR UPDATE',id)
    if not row or row.target_type~=targetType or row.target_id~=targetId or tonumber(row.target_epoch)~=epoch
        or tonumber(row.revision)~=revision or row.status~='active' or tonumber(row.valid_from)>now or tonumber(row.valid_until)<=now then
        return nil,Access.Err('grant_ineligible','Grant changed, expired, revoked or does not belong to the handoff.')
    end
    return row
end
function P.Prepare(request,caller)
    local grants=Input(request,{'targetType','targetId','expectedEpoch'})
    if not grants or not Access.Key(request.targetType) or not Access.Uuid(request.targetId)
        or not Access.Integer(request.expectedEpoch,1,9007199254740990) then return Access.Err('invalid_input','Exact target epoch and 1–25 grant IDs/revisions required.')end
    request=Access.Copy(request);request.targetId=request.targetId:lower();request.grants=grants
    local begun=G.Begin(request,caller,'Managers');if not begun.ok then return begun end
    local actor=begun.value
    local fingerprint=G.Fingerprint('preservation.prepare',request,actor,{'targetType','targetId','expectedEpoch','grants','reasonCode'})
    local replay=G.Replay(caller,request.requestId,'preservation.prepare',fingerprint);if replay then return replay end
    local context=Context(request.targetType,request.targetId,request.expectedEpoch);if not context.ok then return context end
    local allowed=Access.Providers.Authorize(context.value,actor,'preserve.prepare');if not allowed.ok then return allowed end
    local current=Current(context.value,actor);if not current.ok then return current end
    return G.Mutate(caller,request.requestId,'preservation.prepare',fingerprint,actor,function(tx)
        local clock=G.Clock(tx)
        for _,item in ipairs(grants)do
            local row,denied=Locked(tx,item[1],request.targetType,request.targetId,request.expectedEpoch,item[2],clock.now_ms)
            if not row then return denied end
            if not G.Capability(context.value,row.capability) then return Access.Err('capability_unsupported','Candidate capability no longer supported.')end
        end
        if not G.Fence(actor) then return Access.Err('stale_session','Actor context changed.')end
        tx.exec([[INSERT INTO `feather_access_preservation_manifests`
            (`manifest_id`,`target_type`,`target_id`,`source_epoch`,`candidates_json`,`actor_json`)
            VALUES (?,?,?,?,?,?)]],clock.event_id,request.targetType,request.targetId,request.expectedEpoch,json.encode(grants),json.encode(actor))
        return Access.Ok({manifestId=clock.event_id,targetType=request.targetType,targetId=request.targetId,
            sourceEpoch=request.expectedEpoch,candidates=grants})
    end)
end
function P.Adopt(request,caller)
    local grants=Input(request,{'manifestId','transferResource','transferRequestId'})
    if not grants or not Access.Uuid(request.manifestId) or not G.Token(request.transferResource,100)
        or not G.Token(request.transferRequestId,128) then return Access.Err('invalid_input','Manifest, committed transfer proof and selected grant IDs/revisions required.')end
    request=Access.Copy(request);request.manifestId=request.manifestId:lower();request.grants=grants
    local begun=G.Begin(request,caller,'Managers');if not begun.ok then return begun end
    local actor=begun.value
    local fingerprint=G.Fingerprint('preservation.adopt',request,actor,{'manifestId','transferResource','transferRequestId','grants','reasonCode'})
    local replay=G.Replay(caller,request.requestId,'preservation.adopt',fingerprint);if replay then return replay end
    local manifest=DB.one('SELECT * FROM `feather_access_preservation_manifests` WHERE `manifest_id`=?',request.manifestId)
    if not manifest or manifest.status~='prepared' then return Access.Err('manifest_unavailable','Manifest missing or already adopted.')end
    local decoded,candidates=pcall(json.decode,manifest.candidates_json)
    if not decoded or type(candidates)~='table' then return Access.Err('invalid_persistence','Invalid preservation manifest.')end
    local eligible={};for _,item in ipairs(candidates)do eligible[item[1]]=item[2]end
    for _,item in ipairs(grants)do if eligible[item[1]]~=item[2]then return Access.Err('grant_ineligible','Selection not in original manifest.')end end
    local sourceEpoch=tonumber(manifest.source_epoch)
    local context=Context(manifest.target_type,manifest.target_id,sourceEpoch+1);if not context.ok then return context end
    local proof=Access.Providers.TransferProof(context.value,actor,request,manifest);if not proof.ok then return proof end
    local current=Current(context.value,actor);if not current.ok then return current end
    return G.Mutate(caller,request.requestId,'preservation.adopt',fingerprint,actor,function(tx)
        local locked=tx.one('SELECT * FROM `feather_access_preservation_manifests` WHERE `manifest_id`=? FOR UPDATE',request.manifestId)
        if not locked or locked.status~='prepared' then return Access.Err('manifest_unavailable','Manifest already consumed.')end
        local adopted={}
        for _,item in ipairs(grants)do
            local clock=G.Clock(tx)
            local row,denied=Locked(tx,item[1],manifest.target_type,manifest.target_id,sourceEpoch,item[2],clock.now_ms)
            if not row then return denied end
            if not G.Capability(context.value,row.capability)then return Access.Err('capability_unsupported','Candidate capability no longer supported.')end
            tx.exec('UPDATE `feather_access_grants` SET `target_epoch`=?,`revision`=`revision`+1 WHERE `grant_id`=?',sourceEpoch+1,item[1])
            row.target_epoch,row.revision=sourceEpoch+1,item[2]+1
            local snapshot=G.Snapshot(row);adopted[#adopted+1]=snapshot
            local factRequest=Access.Copy(request)
            factRequest._preservation={manifestId=request.manifestId,sourceEpoch=sourceEpoch,
                transferResource=request.transferResource,transferRequestId=request.transferRequestId}
            G.Record(tx,clock.event_id,'access.grant.preserved.v1',snapshot,actor,factRequest)
        end
        local finalClock=G.Clock(tx)
        for _,grant in ipairs(adopted)do
            if grant.validUntil<=finalClock.now_ms then return Access.Err('grant_ineligible','Grant expired before adoption commit.')end
        end
        if not G.Fence(actor) then return Access.Err('stale_session','Actor context changed.')end
        tx.exec("UPDATE `feather_access_preservation_manifests` SET `status`='adopted' WHERE `manifest_id`=?",request.manifestId)
        return Access.Ok({manifestId=request.manifestId,adopted=adopted})
    end)
end
