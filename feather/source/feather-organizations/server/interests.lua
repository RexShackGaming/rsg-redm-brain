OrganizationInterests = {}
local Ok,Err=Organizations.Ok,Organizations.Err
local function IsCallable(value)
    return type(value)=='function' or (type(value)=='table' and type(rawget(value,'__cfx_functionReference'))=='string')
end
function OrganizationInterests.CharacterProvider()
    local called,result=pcall(function() return exports['feather-core']:GetProvider('character-profile',nil,1) end)
    if not called or type(result)~='table' or not result.ok or type(result.value)~='table'
        or type(result.value.provider)~='table' or result.value.provider.owner~='feather-character'
        or type(result.value.implementation)~='table' or not IsCallable(result.value.implementation.GetProfile) then
        return Err('dependency_unavailable','Character profile provider Contract 1 is required.')
    end
    local checked,health=pcall(function() return exports['feather-core']:GetProviderHealth('character-profile',result.value.provider.name) end)
    if not checked or type(health)~='table' or not health.ok or type(health.value)~='table' or health.value.state~='ready' then
        return Err('dependency_unavailable','Character profile provider is not ready.')
    end
    return Ok(result.value.implementation)
end
function OrganizationInterests.CharacterSnapshot(result,holderId)
    if type(result)~='table' then return Err('invalid_dependency_result','Character provider returned an invalid result.') end
    if result.ok~=true then
        if result.ok==false and result.code=='not_found' then return Err('holder_not_found','Character holder not found.') end
        return Err('dependency_unavailable','Character holder lookup failed.')
    end
    local value=result.value
    if type(value)~='table' or not Organizations.Uuid(value.characterId) or value.characterId:lower()~=holderId
        or type(value.status)~='string' then return Err('invalid_dependency_result','Character identity does not match requested holder.') end
    if value.status~='active' then return Err('holder_inactive','Character holder is not active.') end
    return Ok({holderType='character',holderId=holderId,status='active'})
end
-- Internal resolver, not a public enumeration API. Future grant/revoke handlers
-- must authorize target ownership first and revalidate within their write flow.
function OrganizationInterests.ResolveHolder(request,resource)
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request)~='table' or not Organizations.Uuid(request.holderId)
        or (request.holderType~='character' and request.holderType~='organization') then
        return Err('invalid_input','Character/organization holder and UUID required.')
    end
    for key in pairs(request) do
        if key~='holderType' and key~='holderId' then return Err('invalid_input','Unexpected holder field.') end
    end
    local holderType,holderId=request.holderType,request.holderId:lower()
    if holderType=='organization' then
        local found=OrganizationIdentity.Get({organizationId=holderId},resource)
        if not found.ok then
            if found.code=='organization_not_found' then return Err('holder_not_found','Organization holder not found.') end
            return found
        end
        if found.value.status~='active' then return Err('holder_inactive','Organization holder must be active.') end
        return Ok({holderType=holderType,holderId=holderId,status=found.value.status})
    end
    local provider=OrganizationInterests.CharacterProvider()
    if not provider.ok then return provider end
    local called,result=pcall(provider.value.GetProfile,holderId)
    if not called then return Err('dependency_unavailable','Character holder lookup failed.') end
    return OrganizationInterests.CharacterSnapshot(result,holderId)
end
local catalog={
    {key='founder',label='Founder',holderTypes={'character'}},
    {key='owner',label='Owner',holderTypes={'character','organization'}},
    {key='controlling_organization',label='Controlling Organization',holderTypes={'organization'}}
}
function OrganizationInterests.Types(resource)
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    return Ok(Organizations.Copy(catalog))
end
-- Pure internal validation only: neither UUID shape nor this catalog proves a
-- holder exists. Durable holder resolution is required before any future write.
function OrganizationInterests.ValidateGrant(request)
    if type(request)~='table' then return Err('invalid_input','Interest request required.') end
    local fields={organizationId=true,expectedRevision=true,requestId=true,reasonCode=true,
        interestType=true,holderType=true,holderId=true}
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input','Unexpected interest field.') end
    end
    if not Organizations.Uuid(request.organizationId) or not Organizations.Uuid(request.holderId)
        or not Organizations.Integer(request.expectedRevision,1,9007199254740990)
        or type(request.requestId)~='string' or #request.requestId>128
        or not request.requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or type(request.reasonCode)~='string' or #request.reasonCode>64
        or not request.reasonCode:match('^[a-z][a-z0-9._:%-]*$') then
        return Err('invalid_input','UUIDs, integer revision, stable request ID and bounded reason required.')
    end
    local permitted=false
    for _,definition in ipairs(catalog) do
        if definition.key==request.interestType then
            for _,holderType in ipairs(definition.holderTypes) do
                if holderType==request.holderType then permitted=true end
            end
        end
    end
    if not permitted then return Err('invalid_input','Interest and holder types are incompatible.') end
    if request.holderType=='organization' and request.organizationId:lower()==request.holderId:lower() then
        return Err('invalid_input','Organization cannot hold its own controlling interest.')
    end
    local parts={request.organizationId:lower(),tostring(request.expectedRevision),request.interestType,
        request.holderType,request.holderId:lower(),request.reasonCode}
    for index,value in ipairs(parts) do parts[index]=tostring(#value)..':'..value end
    return Ok(table.concat(parts))
end
exports('ListOrganizationInterestTypes',function()
    local called,result=xpcall(function() return OrganizationInterests.Types(GetInvokingResource()) end,debug.traceback)
    if not called then return Err('internal_error','Interest catalog read failed.') end
    return result
end)

function OrganizationInterests.EvaluatePolicy(evaluate,action,context)
    if not IsCallable(evaluate) then return Err('authorization_denied','Interest policy evaluator unavailable.') end
    local called,decision=pcall(evaluate,action,Organizations.Copy(context))
    if not called or type(decision)~='table' or decision.ok~=true
        or type(decision.value)~='table' or decision.value.allowed~=true then
        return Err('authorization_denied','Interest policy denied or unavailable.')
    end
    return Ok(true)
end
function OrganizationInterests.Change(request,resource,operation)
    if Config.Access.trustedMutators[resource or '']~=true then return Err('authorization_denied','Caller is not a trusted interest mutator.') end
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    if operation~='grant' and operation~='revoke' then return Err('invalid_input','Interest operation required.') end
    local valid=OrganizationInterests.ValidateGrant(request)
    if not valid.ok then return valid end
    request=Organizations.Copy(request)
    request.organizationId=request.organizationId:lower();request.holderId=request.holderId:lower()
    local fingerprint=operation..':'..valid.value
    if Config.Authorization.enabled then
        local decision=OrganizationInterests.EvaluatePolicy(function(action,context)
            return exports['feather-core']:Authorize(action,context)
        end,Config.Authorization.interestAction,{correlationId=request.requestId,
            subject={resource=resource,organizationId=request.organizationId,operation='interest_'..operation}})
        if not decision.ok then return decision end
    end
    local result
    local called,committed=pcall(DB.transaction, function(tx)
        local executed,outcome=xpcall(function()
            -- Same ordering as hierarchy writers: guard, receipt, then sorted
            -- organization rows. Holder/target lifecycle checks share row locks.
            local guard=tx.query('SELECT `id` FROM `feather_organization_hierarchy_guard` WHERE `id`=1 FOR UPDATE') or {}
            if not guard[1] then return Err('invalid_persistence','Organization graph guard missing.') end
            tx.exec([[INSERT IGNORE INTO `feather_organization_interest_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]], resource,request.requestId,fingerprint)
            local receipts=tx.query([[SELECT `request_fingerprint`,`result_json` FROM `feather_organization_interest_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], resource,request.requestId) or {}
            local receipt=receipts[1]
            if not receipt then return Err('internal_error','Could not reserve interest receipt.') end
            if receipt.request_fingerprint~=fingerprint then return Err('idempotency_conflict','Request ID is bound to another interest operation.') end
            local nodes=tx.query([[SELECT `organization_id`,`created_by_resource`,`status`,`revision` FROM `feather_organizations`
                WHERE `organization_id` IN (?,?) ORDER BY `organization_id` FOR UPDATE]], request.organizationId,request.holderType=='organization' and request.holderId or request.organizationId) or {}
            local target,holder
            for _,row in ipairs(nodes) do
                if row.organization_id==request.organizationId then target=row end
                if row.organization_id==request.holderId then holder=row end
            end
            if not target then return Err('organization_not_found','Target organization not found.') end
            if target.created_by_resource~=resource and Config.Access.privilegedMutators[resource]~=true then
                return Err('authorization_denied','Caller does not own the target organization.')
            end
            local status=operation=='grant' and 'active' or 'revoked'
            if receipt.result_json then
                local decoded,value=pcall(json.decode,receipt.result_json)
                if not decoded or type(value)~='table' or not Organizations.Uuid(value.interestId)
                    or value.organizationId~=request.organizationId or value.holderId~=request.holderId
                    or value.holderType~=request.holderType or value.interestType~=request.interestType
                    or value.status~=status or value.revision~=request.expectedRevision+1 then
                    return Err('invalid_persistence','Stored interest receipt is invalid.')
                end
                value.replayed=true;return Ok(value)
            end
            local events=tx.query('SELECT `event_id` FROM `feather_organization_events` WHERE `source_resource`=? AND `request_id`=?', resource,request.requestId) or {}
            if #events>0 then return Err('idempotency_conflict','Request ID belongs to another organization operation.') end
            if tonumber(target.revision)~=request.expectedRevision then return Err('revision_conflict','Organization revision changed.') end
            if target.status=='dissolved' or (operation=='grant' and target.status~='pending' and target.status~='active' and target.status~='suspended') then
                return Err('organization_inactive','Target lifecycle blocks this interest operation.')
            end
            if operation=='grant' then
                if request.holderType=='organization' then
                    if not holder then return Err('holder_not_found','Organization holder not found.') end
                    if holder.status~='active' then return Err('holder_inactive','Organization holder must be active.') end
                else
                    local resolved=OrganizationInterests.ResolveHolder({holderType=request.holderType,holderId=request.holderId},resource)
                    if not resolved.ok then return resolved end
                end
            end
            local interests=tx.query([[SELECT `interest_id`,`status` FROM `feather_organization_interests`
                WHERE `organization_id`=? AND `interest_type`=? AND `holder_type`=? AND `holder_id`=? FOR UPDATE]], request.organizationId,request.interestType,request.holderType,request.holderId) or {}
            local interest=interests[1]
            if operation=='revoke' and not interest then return Err('interest_not_found','Interest not found.') end
            if interest and interest.status==status then return Err('no_change','Interest is already in the requested state.') end
            local id=interest and interest.interest_id
            if not id then
                local ids=tx.query('SELECT UUID() AS id') or {};id=ids[1] and ids[1].id
                if not Organizations.Uuid(id) then return Err('invalid_persistence','Interest UUID unavailable.') end
                tx.exec([[INSERT INTO `feather_organization_interests`
                    (`interest_id`,`organization_id`,`interest_type`,`holder_type`,`holder_id`,`status`,`revision`)
                    VALUES (?,?,?,?,?,?,?)]], id,request.organizationId,request.interestType,request.holderType,request.holderId,status,request.expectedRevision+1)
            else
                tx.exec('UPDATE `feather_organization_interests` SET `status`=?,`revision`=? WHERE `interest_id`=?', status,request.expectedRevision+1,id)
            end
            tx.exec('UPDATE `feather_organizations` SET `revision`=`revision`+1 WHERE `organization_id`=? AND `revision`=?', request.organizationId,request.expectedRevision)
            OrganizationEvents.Record(tx,request.organizationId,'organization.interest_'..(operation=='grant' and 'granted' or 'revoked'),
                resource,request.requestId,request.reasonCode,request.expectedRevision+1,{interestId=id,interestType=request.interestType,interestStatus=status})
            local value={interestId=id,organizationId=request.organizationId,holderType=request.holderType,holderId=request.holderId,
                interestType=request.interestType,status=status,revision=request.expectedRevision+1,replayed=false}
            tx.exec('UPDATE `feather_organization_interest_receipts` SET `result_json`=? WHERE `source_resource`=? AND `request_id`=?', json.encode(value),resource,request.requestId)
            return Ok(value)
        end,debug.traceback)
        if not executed then print('[feather-organizations] interest transaction failed: '..tostring(outcome));result=Err('internal_error','Interest transaction failed.');return false end
        result=outcome;return outcome.ok==true
    end)
    if not called or (result and result.ok and committed~=true) then return Err('transaction_failed','Interest commit not confirmed. Retry the same request ID.') end
    return result or Err('transaction_failed','Interest transaction did not complete.')
end
local function InterestBoundary(request,operation)
    local called,result=xpcall(function() return OrganizationInterests.Change(request,GetInvokingResource(),operation) end,debug.traceback)
    if not called then return Err('internal_error','Interest operation failed.') end
    return result
end
exports('GrantOrganizationInterest',function(request) return InterestBoundary(request,'grant') end)
exports('RevokeOrganizationInterest',function(request) return InterestBoundary(request,'revoke') end)

Organizations.RegisterDevCommand('OrganizationsInterestPolicyContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local tests={}
        local function Check(label,good) tests[#tests+1]={label,good==true} end
        local context={correlationId='policy-contract-001',subject={resource=GetCurrentResourceName(),
            organizationId='00000000-0000-0000-0000-000000000001',operation='interest_grant'}}
        local function Gate(evaluate) return OrganizationInterests.EvaluatePolicy(evaluate,Config.Authorization.interestAction,context) end
        local allowed=Gate(function(action,request)
            Check('action and attribution',action==Config.Authorization.interestAction
                and request.correlationId==context.correlationId and request.subject.resource==context.subject.resource
                and request.subject.organizationId==context.subject.organizationId and request.subject.operation=='interest_grant'
                and request.source==nil and request.subject.characterId==nil)
            request.subject.resource='tampered'
            return Ok({allowed=true})
        end)
        Check('explicit allow accepted',allowed.ok)
        Check('context isolated',context.subject.resource==GetCurrentResourceName())
        for _,case in ipairs({
            {'explicit deny',function() return Ok({allowed=false}) end},
            {'unavailable provider',function() return Err('provider_unavailable','Unavailable') end},
            {'malformed envelope',function() return true end},
            {'missing allowed',function() return Ok({}) end},
            {'truthy allowed',function() return Ok({allowed='true'}) end},
            {'failed envelope allow',function() return {ok=false,value={allowed=true}} end},
            {'provider exception',function() error('controlled contract exception') end}
        }) do
            local denied=Gate(case[2]);Check(case[1]..' rejected',not denied.ok and denied.code=='authorization_denied')
        end
        local absent=Gate({})
        Check('noncallable rejected',not absent.ok and absent.code=='authorization_denied')
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[OrganizationsInterestPolicyContractSmokeTest] %-31s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsInterestPolicyContractSmokeTest] done %d/%d passed (isolated decision gate; no providers replaced or writes)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[OrganizationsInterestPolicyContractSmokeTest] FAIL '..tostring(reason)) end
end,true)

function OrganizationInterests.ValidateList(request)
    if type(request)~='table' or not Organizations.Uuid(request.organizationId) then return Err('invalid_input','Organization UUID required.') end
    for field in pairs(request) do
        if field~='organizationId' and field~='limit' and field~='cursor' and field~='status' then return Err('invalid_input','Unexpected interest list field.') end
    end
    local limit=request.limit
    if limit==nil then limit=20 end
    if not Organizations.Integer(limit,1,50) or (request.cursor~=nil and not Organizations.Uuid(request.cursor))
        or (request.status~=nil and request.status~='active' and request.status~='revoked') then
        return Err('invalid_input','Integer limit 1–50, interest UUID cursor and active/revoked status required.')
    end
    return Ok({organizationId=request.organizationId:lower(),limit=limit,
        cursor=request.cursor and request.cursor:lower(),status=request.status})
end
function OrganizationInterests.List(request,resource)
    if Config.Access.trustedAuditors[resource or '']~=true then return Err('authorization_denied','Caller is not a trusted interest reader.') end
    local allowed=Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid=OrganizationInterests.ValidateList(request)
    if not valid.ok then return valid end
    local options=valid.value
    local owner=DB.one('SELECT `created_by_resource` FROM `feather_organizations` WHERE `organization_id`=?', options.organizationId)
    if not owner then return Err('organization_not_found','Organization not found.') end
    if owner.created_by_resource~=resource and Config.Access.privilegedAuditors[resource]~=true then
        return Err('authorization_denied','Caller cannot inspect these controlling interests.')
    end
    local sql=[[SELECT `interest_id`,`interest_type`,`holder_type`,`holder_id`,`status`,`revision`
        FROM `feather_organization_interests` WHERE `organization_id`=?]]
    local params={options.organizationId}
    if options.cursor then
        local cursor=DB.one('SELECT `status` FROM `feather_organization_interests` WHERE `interest_id`=? AND `organization_id`=?', options.cursor,options.organizationId)
        if not cursor or (options.status and cursor.status~=options.status) then return Err('invalid_cursor','Cursor does not belong to this organization/filter.') end
        sql=sql..' AND `interest_id`>?';params[#params+1]=options.cursor
    end
    if options.status then sql=sql..' AND `status`=?';params[#params+1]=options.status end
    sql=sql..' ORDER BY `interest_id` LIMIT ?';params[#params+1]=options.limit+1
    local rows=DB.query(sql, table.unpack(params)) or {}
    local items={}
    for index=1,math.min(#rows,options.limit) do
        local row=rows[index]
        if not Organizations.Uuid(row.interest_id) or not Organizations.Uuid(row.holder_id)
            or not Organizations.Integer(tonumber(row.revision),1,9007199254740991)
            or (row.status~='active' and row.status~='revoked') then return Err('invalid_persistence','Invalid persisted controlling interest.') end
        local tuple={organizationId=options.organizationId,expectedRevision=1,requestId='list-validation',reasonCode='list.validation',
            interestType=row.interest_type,holderType=row.holder_type,holderId=row.holder_id}
        if not OrganizationInterests.ValidateGrant(tuple).ok then return Err('invalid_persistence','Invalid persisted interest holder/type.') end
        items[#items+1]={interestId=row.interest_id,organizationId=options.organizationId,interestType=row.interest_type,
            holderType=row.holder_type,holderId=row.holder_id,status=row.status,revision=tonumber(row.revision)}
    end
    return Ok({items=items,nextCursor=#rows>options.limit and items[#items].interestId or nil})
end
exports('ListOrganizationInterests',function(request)
    local called,result=xpcall(function() return OrganizationInterests.List(request,GetInvokingResource()) end,debug.traceback)
    if not called then return Err('internal_error','Interest list failed.') end
    return result
end)

Organizations.RegisterDevCommand('OrganizationsInterestReadContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local tests={}
        local function Check(label,good) tests[#tests+1]={label,good==true} end
        local id='00000000-0000-0000-0000-000000000001'
        local default=OrganizationInterests.ValidateList({organizationId=id})
        Check('bounded default',default.ok and default.value.limit==20)
        Check('maximum accepted',OrganizationInterests.ValidateList({organizationId=id,limit=50}).ok)
        for _,limit in ipairs({0,1.5,51,'2'}) do
            Check('limit rejected '..tostring(limit),not OrganizationInterests.ValidateList({organizationId=id,limit=limit}).ok)
        end
        Check('bad cursor rejected',not OrganizationInterests.ValidateList({organizationId=id,cursor='bad'}).ok)
        Check('bad status rejected',not OrganizationInterests.ValidateList({organizationId=id,status='pending'}).ok)
        Check('identity injection rejected',not OrganizationInterests.ValidateList({organizationId=id,sourceResource=GetCurrentResourceName()}).ok)
        Check('holder enumeration rejected',not OrganizationInterests.ValidateList({organizationId=id,holderId=id}).ok)
        local denied=OrganizationInterests.List({organizationId=id},'untrusted-smoke-caller')
        Check('untrusted read rejected',not denied.ok and denied.code=='authorization_denied')
        Check('private reads capability',Organizations.GetCapabilities().value.features.interestReads==1)
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[OrganizationsInterestReadContractSmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsInterestReadContractSmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[OrganizationsInterestReadContractSmokeTest] FAIL '..tostring(reason)) end
end,true)

local interestLiveRunning=false
Organizations.RegisterDevCommand('OrganizationsServicePolicyLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestLiveRunning then print('[OrganizationsServicePolicyLiveTest] FAIL already running');return end
    interestLiveRunning=true
    local called,reason=xpcall(function()
        assert(#args==2 and #args[1]<=100 and Organizations.Uuid(args[2]),'Use <stable requestId> <character UUID>')
        assert(Organizations.AwaitReady(0).ok and Config.Authorization.enabled==true,'Ready Organizations with authorization enabled required')
        local owner=GetCurrentResourceName()
        local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
        local provider=Require(exports['feather-core']:GetProvider('policy',nil,1)).provider
        assert(provider.owner=='feather-admin' and provider.capabilities.servicePrincipals==1,'Installed Admin service policy required')
        local created=Require(OrganizationIdentity.Create({requestId=args[1]..':create',organizationType='business',
            organizationKey='org_service_policy_test',legalName='Organization Service Policy Test Company',
            displayName='Service Policy Test',reasonCode='development.service_policy'},owner))
        local grant={organizationId=created.organizationId,expectedRevision=1,interestType='owner',holderType='character',
            holderId=args[2]:lower(),requestId=args[1]..':grant',reasonCode='development.service_policy'}
        local granted=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local revoke=Organizations.Copy(grant);revoke.expectedRevision=2;revoke.requestId=args[1]..':revoke'
        local revoked=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        local replay=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local revokeReplay=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        assert(granted.interestId==revoked.interestId and replay.interestId==granted.interestId
            and replay.replayed and replay.revision==2 and revokeReplay.replayed and revokeReplay.status=='revoked','Stable receipts failed')
        local current=Require(OrganizationIdentity.Get({organizationId=created.organizationId},owner))
        local page=Require(OrganizationInterests.List({organizationId=created.organizationId},owner))
        assert(current.revision==3 and #page.items==1 and page.items[1].interestId==granted.interestId
            and page.items[1].status=='revoked' and page.items[1].revision==3,'Service mutation state inconsistent')
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE organization_id=?) AS events,
            (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id=?) AS outbox,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id IN (?,?)) AS receipts]], created.organizationId,created.organizationId,owner,grant.requestId,revoke.requestId)
        assert(tonumber(counts.events)==3 and tonumber(counts.outbox)==3 and tonumber(counts.receipts)==2,'Service mutation counts inconsistent')
        local after=Require(exports['feather-core']:GetProvider('policy',nil,1)).provider
        assert(Config.Authorization.enabled==true and after.name==provider.name and after.owner==provider.owner,'Production policy configuration changed')
        print(('[OrganizationsServicePolicyLiveTest] PASS id=%s interestId=%s provider=feather-admin authorizationEnabled=true revision=3 state=revoked events=3 outbox=3 receipts=2 originalReceipts=true policyUnchanged=true firstReplayed=%s'):format(
            created.organizationId,granted.interestId,tostring(granted.replayed)))
    end,debug.traceback)
    interestLiveRunning=false
    if not called then print('[OrganizationsServicePolicyLiveTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsInterestPolicyLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestLiveRunning then print('[OrganizationsInterestPolicyLiveTest] FAIL interest test already running');return end
    interestLiveRunning=true
    local previousEnabled=Config.Authorization.enabled
    local registered=false
    local providerName='organizations-policy-acceptance'
    local called,reason=xpcall(function()
        assert(#args==2 and #args[1]<=100 and Organizations.Uuid(args[2]),'Use <stable requestId> <character UUID>')
        assert(#GetPlayers()==0,'Run on an empty development server: this temporarily enables authorization')
        assert(previousEnabled==false,'This acceptance harness requires development authorization initially disabled')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        assert(Config.Access.privilegedMutators[owner]~=true,'Main resource must not have privileged override for this test')
        local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
        local providers=Require(exports['feather-core']:GetProviders())
        for _,provider in ipairs(providers) do assert(provider.kind~='policy','Existing policy provider detected; refusing to alter policy registry') end
        local foreign=Require(OrganizationIdentity.Find({organizationKey='org_interest_fixture'},owner))
        local created=Require(OrganizationIdentity.Create({requestId=args[1]..':create',organizationType='business',
            organizationKey='org_interest_policy_test',legalName='Organization Interest Policy Test Company',
            displayName='Interest Policy Test',reasonCode='development.interest_policy'},owner))
        local mode='allow'
        local seen=0
        local registration=exports['feather-core']:RegisterPolicyProvider(providerName,{Evaluate=function(action,context)
            if action~=Config.Authorization.interestAction or context.caller~=owner or context.source~=0 or context.system~=true
                or context.subject.resource~=owner or context.correlationId:sub(1,#args[1]+1)~=args[1]..':'
                or (context.subject.organizationId~=created.organizationId and context.subject.organizationId~=foreign.organizationId)
                or (context.subject.operation~='interest_grant' and context.subject.operation~='interest_revoke') then
                return Ok({allowed=false})
            end
            seen=seen+1
            if mode=='deny' then return Ok({allowed=false}) end
            if mode=='malformed' then return true end
            if mode=='exception' then error('controlled development policy exception') end
            return Ok({allowed=true})
        end},{contract=1,default=true,capabilities={actions=1}})
        Require(registration);registered=true
        Config.Authorization.enabled=true
        local request={organizationId=created.organizationId,expectedRevision=1,interestType='owner',holderType='character',
            holderId=args[2]:lower(),requestId=args[1]..':grant',reasonCode='development.interest_policy'}
        local granted=Require(OrganizationInterests.Change(request,owner,'grant'))
        for _,failureMode in ipairs({'deny','malformed','exception'}) do
            mode=failureMode
            local blocked=Organizations.Copy(request);blocked.expectedRevision=2;blocked.requestId=args[1]..':'..failureMode
            local denied=OrganizationInterests.Change(blocked,owner,'revoke')
            assert(not denied.ok and denied.code=='authorization_denied',failureMode..' policy did not fail closed')
        end
        mode='allow'
        local foreignRequest=Organizations.Copy(request);foreignRequest.organizationId=foreign.organizationId
        foreignRequest.expectedRevision=foreign.revision;foreignRequest.requestId=args[1]..':foreign'
        local deniedForeign=OrganizationInterests.Change(foreignRequest,owner,'grant')
        assert(not deniedForeign.ok and deniedForeign.code=='authorization_denied','Policy allow bypassed creator ownership')
        assert(seen>=5,'Real Core policy provider did not observe all requests')
        Require(exports['feather-core']:UnregisterProvider('policy',providerName));registered=false
        local unavailable=Organizations.Copy(request);unavailable.expectedRevision=2;unavailable.requestId=args[1]..':unavailable'
        local deniedUnavailable=OrganizationInterests.Change(unavailable,owner,'revoke')
        assert(not deniedUnavailable.ok and deniedUnavailable.code=='authorization_denied','Unavailable policy did not fail closed')
        local current=Require(OrganizationIdentity.Get({organizationId=created.organizationId},owner))
        local afterForeign=Require(OrganizationIdentity.Get({organizationId=foreign.organizationId},owner))
        local page=Require(OrganizationInterests.List({organizationId=created.organizationId},owner))
        assert(current.revision==2 and #page.items==1 and page.items[1].status=='active' and page.items[1].interestId==granted.interestId
            and afterForeign.revision==foreign.revision,'Rejected policy requests changed state')
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE organization_id=?) AS events,
            (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id=?) AS outbox,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id IN (?,?,?,?,?)) AS rejected]], created.organizationId,created.organizationId,owner,args[1]..':deny',args[1]..':malformed',args[1]..':exception',args[1]..':foreign',args[1]..':unavailable')
        assert(tonumber(counts.events)==2 and tonumber(counts.outbox)==2 and tonumber(counts.rejected)==0,'Policy rejection persisted partial records')
        print(('[OrganizationsInterestPolicyLiveTest] checks passed id=%s revision=2 realCoreProvider=true allow=true deny=true malformed=true exception=true unavailable=true ownershipEnforced=true events=2 outbox=2 firstReplayed=%s'):format(
            created.organizationId,tostring(granted.replayed)))
    end,debug.traceback)
    Config.Authorization.enabled=previousEnabled
    local cleanup=true
    if registered then
        local removed,result=pcall(function() return exports['feather-core']:UnregisterProvider('policy',providerName) end)
        cleanup=removed and type(result)=='table' and result.ok==true
    end
    interestLiveRunning=false
    if not called then print('[OrganizationsInterestPolicyLiveTest] FAIL '..tostring(reason)) end
    if not cleanup then print('[OrganizationsInterestPolicyLiveTest] FAIL provider cleanup failed; restart feather-organizations before continuing')
    elseif called then print('[OrganizationsInterestPolicyLiveTest] PASS authorizationRestored=true temporaryProviderRemoved=true') end
end,true)

Organizations.RegisterDevCommand('OrganizationsInterestHolderLifecycleTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestLiveRunning then print('[OrganizationsInterestHolderLifecycleTest] FAIL already running');return end
    interestLiveRunning=true
    local called,reason=xpcall(function()
        assert(#args==1 and #args[1]<=100,'Use <stable requestId>')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
        local function Create(suffix)
            return Require(OrganizationIdentity.Create({requestId=args[1]..':create_'..suffix,organizationType='business',
                organizationKey='org_interest_holder_'..suffix,legalName='Organization Interest Holder '..suffix,
                displayName='Interest Holder '..suffix,reasonCode='development.interest_holder_lifecycle'},owner))
        end
        local target,holder=Create('target'),Create('controller')
        local function Transition(revision,status,suffix)
            return Require(OrganizationLifecycle.Change({organizationId=holder.organizationId,expectedRevision=revision,status=status,
                requestId=args[1]..':'..suffix,reasonCode='development.interest_holder_lifecycle'},owner))
        end
        Transition(1,'active','activate')
        local grant={organizationId=target.organizationId,expectedRevision=1,interestType='controlling_organization',
            holderType='organization',holderId=holder.organizationId,requestId=args[1]..':grant',reasonCode='development.interest_holder_lifecycle'}
        local granted=Require(OrganizationInterests.Change(grant,owner,'grant'))
        Transition(2,'suspended','suspend')
        local before=Require(OrganizationIdentity.Get({organizationId=holder.organizationId},owner))
        if before.status=='suspended' then
            local blocked=Organizations.Copy(grant);blocked.expectedRevision=2;blocked.interestType='owner';blocked.requestId=args[1]..':blocked'
            local denied=OrganizationInterests.Change(blocked,owner,'grant')
            assert(not denied.ok and denied.code=='holder_inactive','Suspended holder grant accepted')
            local read=Require(OrganizationInterests.List({organizationId=target.organizationId,status='active'},owner))
            assert(#read.items==1 and read.items[1].interestId==granted.interestId,'Inactive holder interest not readable')
        else
            assert(before.status=='active' and before.revision==4,'Unexpected holder replay state')
        end
        local revoke=Organizations.Copy(grant);revoke.expectedRevision=2;revoke.requestId=args[1]..':revoke'
        local revoked=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        assert(revoked.interestId==granted.interestId and revoked.status=='revoked','Inactive holder cleanup failed')
        Transition(3,'active','resume')
        local regrant=Organizations.Copy(grant);regrant.expectedRevision=3;regrant.requestId=args[1]..':regrant'
        local restored=Require(OrganizationInterests.Change(regrant,owner,'grant'))
        local replay=Require(OrganizationInterests.Change(grant,owner,'grant'))
        assert(restored.interestId==granted.interestId and replay.replayed and replay.revision==2,'Stable identity/original receipt failed')
        local targetState=Require(OrganizationIdentity.Get({organizationId=target.organizationId},owner))
        local holderState=Require(OrganizationIdentity.Get({organizationId=holder.organizationId},owner))
        local final=Require(OrganizationInterests.List({organizationId=target.organizationId},owner))
        assert(targetState.revision==4 and targetState.status=='pending' and holderState.revision==4 and holderState.status=='active'
            and #final.items==1 and final.items[1].interestId==granted.interestId and final.items[1].status=='active'
            and final.items[1].revision==4,'Final holder/target state inconsistent')
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE organization_id IN (?,?)) AS events,
            (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id IN (?,?)) AS outbox,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id=?) AS rejected]], target.organizationId,holder.organizationId,target.organizationId,holder.organizationId,owner,args[1]..':blocked')
        assert(tonumber(counts.events)==8 and tonumber(counts.outbox)==8 and tonumber(counts.rejected)==0,'Holder lifecycle counts inconsistent')
        print(('[OrganizationsInterestHolderLifecycleTest] PASS target=%s holder=%s targetRevision=4 holderRevision=4 inactiveGrantBlocked=true inactiveReadable=true cleanupAllowed=true resumedGrant=true stableIdentity=true events=8 outbox=8 rolledBack=true firstReplayed=%s'):format(
            target.organizationId,holder.organizationId,tostring(granted.replayed)))
    end,debug.traceback)
    interestLiveRunning=false
    if not called then print('[OrganizationsInterestHolderLifecycleTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsInterestLifecycleTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestLiveRunning then print('[OrganizationsInterestLifecycleTest] FAIL already running');return end
    interestLiveRunning=true
    local called,reason=xpcall(function()
        assert(#args==2 and #args[1]<=100 and Organizations.Uuid(args[2]),'Use <stable requestId> <character UUID>')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
        local created=Require(OrganizationIdentity.Create({requestId=args[1]..':create',organizationType='business',
            organizationKey='org_interest_lifecycle_test',legalName='Organization Interest Lifecycle Test Company',
            displayName='Interest Lifecycle Test',reasonCode='development.interest_lifecycle'},owner))
        local id=created.organizationId
        local grant={organizationId=id,expectedRevision=1,requestId=args[1]..':grant',reasonCode='development.interest_lifecycle',
            interestType='owner',holderType='character',holderId=args[2]:lower()}
        local granted=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local function Transition(revision,status)
            return Require(OrganizationLifecycle.Change({organizationId=id,expectedRevision=revision,status=status,
                requestId=args[1]..':'..status,reasonCode='development.interest_lifecycle'},owner))
        end
        Transition(2,'dissolving')
        local before=Require(OrganizationIdentity.Get({organizationId=id},owner))
        local function Blocked(revision,suffix,operation)
            local request=Organizations.Copy(grant);request.expectedRevision=revision;request.requestId=args[1]..':'..suffix
            local denied=OrganizationInterests.Change(request,owner,operation)
            assert(not denied.ok and denied.code=='organization_inactive','Lifecycle '..operation..' not blocked')
        end
        if before.status=='dissolving' then Blocked(3,'blocked_grant','grant')
        else assert(before.status=='dissolved' and before.revision==5,'Unexpected replay lifecycle') end
        local revoke=Organizations.Copy(grant);revoke.expectedRevision=3;revoke.requestId=args[1]..':revoke'
        local revoked=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        assert(revoked.status=='revoked' and revoked.interestId==granted.interestId,'Cleanup identity inconsistent')
        Transition(4,'dissolved')
        Blocked(5,'terminal_grant','grant');Blocked(5,'terminal_revoke','revoke')
        local oldGrant=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local oldRevoke=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        assert(oldGrant.replayed and oldGrant.status=='active' and oldGrant.revision==2
            and oldRevoke.replayed and oldRevoke.status=='revoked' and oldRevoke.revision==4,'Original receipts changed')
        local current=Require(OrganizationIdentity.Get({organizationId=id},owner))
        local revokedPage=Require(OrganizationInterests.List({organizationId=id,status='revoked',limit=1},owner))
        local active=Require(OrganizationInterests.List({organizationId=id,status='active'},owner))
        local history=Require(OrganizationEvents.History({organizationId=id},owner))
        assert(current.status=='dissolved' and current.revision==5 and #revokedPage.items==1 and not revokedPage.nextCursor
            and revokedPage.items[1].interestId==granted.interestId and revokedPage.items[1].revision==4
            and #active.items==0 and #history.items==5,'Terminal state/read inconsistent')
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id=?) AS outbox,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id IN (?,?)) AS receipts,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id IN (?,?,?)) AS rejected]], id,owner,grant.requestId,revoke.requestId,owner,args[1]..':blocked_grant',args[1]..':terminal_grant',args[1]..':terminal_revoke')
        assert(tonumber(counts.outbox)==5 and tonumber(counts.receipts)==2 and tonumber(counts.rejected)==0,'Atomic counts invalid')
        print(('[OrganizationsInterestLifecycleTest] PASS id=%s state=dissolved revision=5 grantBlocked=true cleanupAllowed=true terminalBlocked=true originalReceipts=true historyReadable=true events=5 outbox=5 rolledBack=true firstReplayed=%s'):format(id,tostring(granted.replayed)))
    end,debug.traceback)
    interestLiveRunning=false
    if not called then print('[OrganizationsInterestLifecycleTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsInterestReadLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestLiveRunning then print('[OrganizationsInterestReadLiveTest] FAIL test already running');return end
    interestLiveRunning=true
    local called,reason=xpcall(function()
        assert(#args==2 and #args[1]<=100 and Organizations.Uuid(args[2]),'Use <stable requestId> <character UUID>')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        local function Require(result)
            assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value
        end
        local holder=Require(OrganizationIdentity.Find({organizationKey='org_event_test_child'},owner))
        local created=Require(OrganizationIdentity.Create({requestId=args[1]..':create',organizationType='business',
            organizationKey='org_interest_read_test',legalName='Organization Interest Read Test Company',displayName='Interest Read Test',
            reasonCode='development.interest_read'},owner))
        local id=created.organizationId
        local requests={
            {interestType='owner',holderType='character',holderId=args[2]:lower()},
            {interestType='founder',holderType='character',holderId=args[2]:lower()},
            {interestType='controlling_organization',holderType='organization',holderId=holder.organizationId}
        }
        local granted={}
        for index,request in ipairs(requests) do
            request.organizationId=id;request.expectedRevision=index;request.requestId=args[1]..':grant'..index
            request.reasonCode='development.interest_read'
            granted[index]=Require(OrganizationInterests.Change(request,owner,'grant'))
        end
        local revoke=Organizations.Copy(requests[1]);revoke.expectedRevision=4;revoke.requestId=args[1]..':revoke'
        local revoked=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        assert(revoked.interestId==granted[1].interestId,'Revocation identity changed')
        local cursor,seen,items=nil,{},{}
        for page=1,3 do
            local result=Require(OrganizationInterests.List({organizationId=id,limit=1,cursor=cursor},owner))
            assert(#result.items==1,'Expected one item per page')
            local item=result.items[1]
            assert(not seen[item.interestId] and (not cursor or item.interestId>cursor),'Pagination duplicated/reordered an item')
            seen[item.interestId]=true;items[item.interestId]=Organizations.Copy(item)
            for field in pairs(item) do
                assert(field=='interestId' or field=='organizationId' or field=='interestType' or field=='holderType'
                    or field=='holderId' or field=='status' or field=='revision','Unexpected private field')
            end
            item.holderId='tampered'
            cursor=result.nextCursor
            assert((page<3 and cursor~=nil) or (page==3 and cursor==nil),'Pagination boundary invalid')
        end
        for index,grant in ipairs(granted) do
            local item=items[grant.interestId]
            assert(item and item.organizationId==id and item.holderId==requests[index].holderId
                and item.holderType==requests[index].holderType and item.interestType==requests[index].interestType
                and item.status==(index==1 and 'revoked' or 'active')
                and item.revision==(index==1 and 5 or index+1),'Persisted interest projection inconsistent')
        end
        local active=Require(OrganizationInterests.List({organizationId=id,status='active',limit=1},owner))
        assert(#active.items==1 and active.nextCursor,'Active first page invalid')
        local nextActive=Require(OrganizationInterests.List({organizationId=id,status='active',limit=1,cursor=active.nextCursor},owner))
        assert(#nextActive.items==1 and not nextActive.nextCursor and nextActive.items[1].interestId~=active.items[1].interestId,'Active second page invalid')
        local revokedPage=Require(OrganizationInterests.List({organizationId=id,status='revoked',limit=1},owner))
        assert(#revokedPage.items==1 and revokedPage.items[1].interestId==revoked.interestId and not revokedPage.nextCursor,'Revoked filter invalid')
        local filterMismatch=OrganizationInterests.List({organizationId=id,status='active',cursor=revoked.interestId},owner)
        assert(not filterMismatch.ok and filterMismatch.code=='invalid_cursor','Filter-mismatched cursor accepted')
        local foreign=OrganizationInterests.List({organizationId=holder.organizationId,cursor=revoked.interestId},owner)
        assert(not foreign.ok and foreign.code=='invalid_cursor','Foreign organization cursor accepted')
        local reread=Require(OrganizationInterests.List({organizationId=id,limit=50},owner))
        assert(#reread.items==3 and not reread.nextCursor,'Full page invalid')
        for _,item in ipairs(reread.items) do assert(item.holderId==items[item.interestId].holderId,'Caller mutation changed stored data') end
        local current=Require(OrganizationIdentity.Get({organizationId=id},owner))
        assert(current.revision==5 and current.status=='pending','Shared organization revision inconsistent')
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE organization_id=?) AS events,
            (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id=?) AS outbox,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id IN (?,?,?,?)) AS receipts]], id,id,owner,requests[1].requestId,requests[2].requestId,requests[3].requestId,revoke.requestId)
        assert(tonumber(counts.events)==5 and tonumber(counts.outbox)==5 and tonumber(counts.receipts)==4,'Replay record counts changed')
        print(('[OrganizationsInterestReadLiveTest] PASS id=%s revision=5 interests=3 active=2 revoked=1 paginated=true isolated=true cursorBoundaries=true organizationHolder=true events=5 outbox=5 firstReplayed=%s'):format(id,tostring(granted[1].replayed)))
    end,debug.traceback)
    interestLiveRunning=false
    if not called then print('[OrganizationsInterestReadLiveTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsInterestLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestLiveRunning then print('[OrganizationsInterestLiveTest] FAIL test already running');return end
    interestLiveRunning=true
    local called,reason=xpcall(function()
        assert(#args==2 and type(args[1])=='string' and #args[1]<=100 and Organizations.Uuid(args[2]),
            'Use <stable requestId, maximum 100 bytes> <character UUID>')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        local function Require(result)
            assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value
        end
        local created=Require(OrganizationIdentity.Create({requestId=args[1]..':create',organizationType='business',
            organizationKey='org_interest_test',legalName='Organization Interest Test Company',displayName='Interest Test',
            reasonCode='development.interest_test'},owner))
        local id=created.organizationId
        local grant={organizationId=id,expectedRevision=1,requestId=args[1]..':grant',reasonCode='development.interest_test',
            interestType='owner',holderType='character',holderId=args[2]:lower()}
        local first=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local revoke=Organizations.Copy(grant);revoke.expectedRevision=2;revoke.requestId=args[1]..':revoke'
        local revoked=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        local regrant=Organizations.Copy(grant);regrant.expectedRevision=3;regrant.requestId=args[1]..':regrant'
        local restored=Require(OrganizationInterests.Change(regrant,owner,'grant'))
        local replay=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local revokeReplay=Require(OrganizationInterests.Change(revoke,owner,'revoke'))
        assert(first.interestId==revoked.interestId and first.interestId==restored.interestId,'Interest UUID changed')
        assert(replay.replayed and replay.revision==2 and revokeReplay.replayed and revokeReplay.status=='revoked','Original receipts did not replay')
        local stale=Organizations.Copy(grant);stale.requestId=args[1]..':stale'
        local staleResult=OrganizationInterests.Change(stale,owner,'grant')
        assert(not staleResult.ok and staleResult.code=='revision_conflict','Stale change accepted')
        local unchanged=Organizations.Copy(grant);unchanged.expectedRevision=4;unchanged.requestId=args[1]..':noop'
        local noChange=OrganizationInterests.Change(unchanged,owner,'grant')
        assert(not noChange.ok and noChange.code=='no_change','Duplicate active grant accepted')
        local mismatch=Organizations.Copy(grant);mismatch.interestType='founder'
        local mismatchResult=OrganizationInterests.Change(mismatch,owner,'grant')
        assert(not mismatchResult.ok and mismatchResult.code=='idempotency_conflict','Payload mismatch accepted')
        local missing=Organizations.Copy(grant);missing.expectedRevision=4;missing.requestId=args[1]..':missing'
        missing.holderId='00000000-0000-0000-0000-000000000000'
        local missingResult=OrganizationInterests.Change(missing,owner,'grant')
        assert(not missingResult.ok and missingResult.code=='holder_not_found','Missing holder accepted')
        local after=Require(OrganizationIdentity.Get({organizationId=id},owner))
        assert(after.revision==4 and after.status=='pending','Replay/rejection altered organization')
        local row=DB.one('SELECT `interest_id`,`status`,`revision` FROM `feather_organization_interests` WHERE `organization_id`=?', id)
        assert(row and row.interest_id==first.interestId and row.status=='active' and tonumber(row.revision)==4,'Interest persistence inconsistent')
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_interests` WHERE `organization_id`=?) AS interests,
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id`=?) AS events,
            (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id=?) AS outbox,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id IN (?,?,?)) AS receipts,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id IN (?,?,?)) AS rejected_receipts]], id,id,id,owner,grant.requestId,revoke.requestId,regrant.requestId,owner,stale.requestId,unchanged.requestId,missing.requestId)
        assert(tonumber(counts.interests)==1 and tonumber(counts.events)==4 and tonumber(counts.outbox)==4
            and tonumber(counts.receipts)==3 and tonumber(counts.rejected_receipts)==0,'Atomic record counts invalid')
        local rows=DB.query([[SELECT o.payload_json FROM `feather_organization_outbox` o
            JOIN `feather_organization_events` e ON e.event_id=o.event_id
            WHERE e.organization_id=? AND e.event_type IN ('organization.interest_granted','organization.interest_revoked')]], id) or {}
        assert(#rows==3,'Interest events missing')
        for _,event in ipairs(rows) do
            local payload=json.decode(event.payload_json)
            assert(payload.interestId==first.interestId and payload.holderId==nil and payload.holderType==nil
                and payload.legalName==nil and payload.displayName==nil,'Event identity/privacy invalid')
        end
        print(('[OrganizationsInterestLiveTest] PASS id=%s interestId=%s revision=4 state=active firstReplayed=%s originalReceipts=true stableIdentity=true staleRejected=true mismatchRejected=true missingRejected=true events=4 outbox=4 rolledBack=true privateFieldsExcluded=true'):format(
            id,first.interestId,tostring(first.replayed)))
    end,debug.traceback)
    interestLiveRunning=false
    if not called then print('[OrganizationsInterestLiveTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsInterestContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        local tests={}
        local function Check(label,good) tests[#tests+1]={label,good==true} end
        local definitions=OrganizationInterests.Types(owner)
        Check('bounded type catalog',definitions.ok and #definitions.value==3)
        definitions.value[1].key='tampered'
        Check('catalog isolated',OrganizationInterests.Types(owner).value[1].key=='founder')
        local denied=OrganizationInterests.Types('untrusted-smoke-caller')
        Check('untrusted catalog rejected',not denied.ok and denied.code=='authorization_denied')
        local request={organizationId='00000000-0000-0000-0000-000000000001',
            holderId='00000000-0000-0000-0000-000000000002',holderType='character',interestType='owner',
            expectedRevision=1,requestId='interest-contract-001',reasonCode='development.interest_test'}
        Check('valid character owner',OrganizationInterests.ValidateGrant(request).ok)
        local organizational=Organizations.Copy(request);organizational.holderType='organization';organizational.interestType='controlling_organization'
        Check('valid organization control',OrganizationInterests.ValidateGrant(organizational).ok)
        for _,case in ipairs({{'interestType','employee'},{'holderType','player'},{'holderId','bad'},
            {'expectedRevision',1.5},{'requestId','bad id'},{'sourceResource',owner},{'shares',50}}) do
            local invalid=Organizations.Copy(request);invalid[case[1]]=case[2]
            Check('rejected '..case[1],not OrganizationInterests.ValidateGrant(invalid).ok)
        end
        local founder=Organizations.Copy(organizational);founder.interestType='founder'
        Check('founder holder constrained',not OrganizationInterests.ValidateGrant(founder).ok)
        local self=Organizations.Copy(organizational);self.holderId=self.organizationId
        Check('self control rejected',not OrganizationInterests.ValidateGrant(self).ok)
        local changed=Organizations.Copy(request);changed.holderId='00000000-0000-0000-0000-000000000003'
        Check('holder payload binding',OrganizationInterests.ValidateGrant(request).value~=OrganizationInterests.ValidateGrant(changed).value)
        Check('writes available',Organizations.GetCapabilities().value.features.controllingInterests==1)
        local deniedGrant=OrganizationInterests.Change(request,'untrusted-smoke-caller','grant')
        Check('untrusted grant rejected',not deniedGrant.ok and deniedGrant.code=='authorization_denied')
        local deniedRevoke=OrganizationInterests.Change(request,'untrusted-smoke-caller','revoke')
        Check('untrusted revoke rejected',not deniedRevoke.ok and deniedRevoke.code=='authorization_denied')
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[OrganizationsInterestContractSmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsInterestContractSmokeTest] done %d/%d passed (no interests created)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[OrganizationsInterestContractSmokeTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsHolderContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local tests={}
        local function Check(label,good) tests[#tests+1]={label,good==true} end
        local id='00000000-0000-0000-0000-000000000001'
        Check('character provider ready',OrganizationInterests.CharacterProvider().ok)
        Check('Cfx reference callable',IsCallable({__cfx_functionReference='test'}))
        Check('plain table not callable',not IsCallable({}))
        local valid=OrganizationInterests.CharacterSnapshot(Ok({characterId=id,status='active',firstName='Private',accountId='Private'}),id)
        Check('private fields excluded',valid.ok and valid.value.firstName==nil and valid.value.accountId==nil)
        local missing=OrganizationInterests.CharacterSnapshot(Err('not_found','Missing'),id)
        Check('missing holder rejected',not missing.ok and missing.code=='holder_not_found')
        local inactive=OrganizationInterests.CharacterSnapshot(Ok({characterId=id,status='deleted'}),id)
        Check('inactive holder rejected',not inactive.ok and inactive.code=='holder_inactive')
        Check('wrong identity rejected',not OrganizationInterests.CharacterSnapshot(Ok({characterId='00000000-0000-0000-0000-000000000002',status='active'}),id).ok)
        Check('bad result rejected',not OrganizationInterests.CharacterSnapshot(true,id).ok)
        Check('invalid UUID rejected',not OrganizationInterests.ResolveHolder({holderType='character',holderId='bad'},GetCurrentResourceName()).ok)
        local denied=OrganizationInterests.ResolveHolder({holderType='character',holderId=id},'untrusted-smoke-caller')
        Check('untrusted lookup rejected',not denied.ok and denied.code=='authorization_denied')
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[OrganizationsHolderContractSmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsHolderContractSmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[OrganizationsHolderContractSmokeTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsHolderLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    local called,reason=xpcall(function()
        assert(#args==2,'Use character|organization <holder UUID>; no player source required')
        local result=OrganizationInterests.ResolveHolder({holderType=args[1],holderId=args[2]},GetCurrentResourceName())
        assert(result.ok,tostring(result.code)..': '..tostring(result.message))
        assert(result.value.holderId==args[2]:lower() and result.value.holderType==args[1],'Holder identity mismatch')
        for field in pairs(result.value) do assert(field=='holderId' or field=='holderType' or field=='status','Unexpected private field') end
        print(('[OrganizationsHolderLiveTest] PASS type=%s id=%s active=true privateFieldsExcluded=true sessionNotRequired=true (read-only)'):format(result.value.holderType,result.value.holderId))
    end,debug.traceback)
    if not called then print('[OrganizationsHolderLiveTest] FAIL '..tostring(reason)) end
end,true)
