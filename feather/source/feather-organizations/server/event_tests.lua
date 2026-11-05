Organizations.RegisterDevCommand('OrganizationsEventContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        if not Organizations.AwaitReady(0).ok then print('[OrganizationsEventContractSmokeTest] FAIL service not ready');return end
        local tests={}
        local function Check(label,passed) tests[#tests+1]={label,passed==true} end
        local features=Organizations.GetCapabilities().value.features
        Check('publication capability',features.eventPublication==1)
        Check('history capability',features.auditHistory==1)
        Check('publisher running',OrganizationEvents.State().value.running)
        local id='00000000-0000-0000-0000-000000000000'
        Check('valid history request',OrganizationEvents.ValidateHistory({organizationId=id,limit=20}).ok)
        local denied=OrganizationEvents.History({organizationId=id},'untrusted-smoke-caller')
        Check('untrusted audit rejected',not denied.ok and denied.code=='authorization_denied')
        for _,limit in ipairs({0,1.5,51,'2'}) do
            Check('limit rejected '..tostring(limit),not OrganizationEvents.ValidateHistory({organizationId=id,limit=limit}).ok)
        end
        Check('bad cursor rejected',not OrganizationEvents.ValidateHistory({organizationId=id,cursor='bad'}).ok)
        Check('identity injection rejected',not OrganizationEvents.ValidateHistory({organizationId=id,sourceResource=GetCurrentResourceName()}).ok)
        local invalid=tonumber(DB.value([[SELECT COUNT(*) FROM `feather_organization_outbox` o
            LEFT JOIN `feather_organization_events` e ON e.event_id=o.event_id
            WHERE e.event_id IS NULL OR o.status NOT IN ('pending','published')
                OR (o.status='published' AND o.published_at IS NULL)]]))
        Check('outbox records valid',invalid==0)
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[OrganizationsEventContractSmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsEventContractSmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[OrganizationsEventContractSmokeTest] FAIL '..tostring(reason)) end
end,true)

local eventLiveRunning=false
Organizations.RegisterDevCommand('OrganizationsEventRecoveryTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if eventLiveRunning then print('[OrganizationsEventRecoveryTest] FAIL another event test is running');return end
    eventLiveRunning=true
    local called,reason=xpcall(function()
        assert(#args==2 and (args[2]=='prepare' or args[2]=='retry'),'Use <stable requestId> prepare|retry')
        local request={requestId=args[1],organizationType='business',organizationKey='org_event_recovery_test',
            legalName='Organization Event Recovery Test Company',displayName='Event Recovery Test',
            reasonCode='development.event_recovery'}
        assert(OrganizationIdentity.Validate(request).ok,'Invalid request ID')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        if args[2]=='prepare' then
            -- Stop before creating the new event; the worker checks running after
            -- its pending-row query as well. This uses existing lifecycle cleanup,
            -- not a production fault injection API or persistent pause setting.
            OrganizationEvents.Stop()
        else
            assert(OrganizationEvents.State().value.running,'Restart feather-organizations before retry')
            local found=OrganizationIdentity.Find({organizationKey=request.organizationKey},owner)
            assert(found.ok,'Prepare must create the test entity first')
            local receipt=DB.value([[SELECT COUNT(*) FROM `feather_organization_creation_receipts`
                WHERE `source_resource`=? AND `request_id`=? AND `result_json` IS NOT NULL]], owner,args[1])
            assert(tonumber(receipt)==1,'Original committed receipt required before retry')
        end
        local created=OrganizationIdentity.Create(request,owner)
        assert(created.ok,tostring(created.code)..': '..tostring(created.message))
        local id=created.value.organizationId
        local function Read()
            return DB.query([[SELECT e.event_id,o.status,o.attempts,o.published_at FROM `feather_organization_events` e
                LEFT JOIN `feather_organization_outbox` o ON o.event_id=e.event_id
                WHERE e.organization_id=? AND e.source_resource=? AND e.request_id=?]], id,owner,args[1]) or {}
        end
        local rows=Read()
        assert(#rows==1,'Expected one audit/outbox event')
        if args[2]=='prepare' then
            assert(rows[1].status=='pending' and tonumber(rows[1].attempts)==0,'Fresh unpublished event required; retain the original request ID')
            print(('[OrganizationsEventRecoveryTest] PASS prepared id=%s eventId=%s pending=true; restart feather-organizations then retry same request ID'):format(id,rows[1].event_id))
            return
        end
        assert(created.value.replayed==true,'Creation did not replay')
        local originalEventId=rows[1].event_id
        local deadline=GetGameTimer()+10000
        while rows[1].status~='published' and GetGameTimer()<deadline do Wait(50);rows=Read();assert(#rows==1,'Event count changed') end
        assert(rows[1].status=='published' and rows[1].published_at~=nil,'Publication recovery timed out')
        assert(rows[1].event_id==originalEventId,'Event identity changed')
        local count=tonumber(DB.value('SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id`=?', id))
        assert(count==1,'Replay added an audit record')
        print(('[OrganizationsEventRecoveryTest] PASS id=%s eventId=%s replayed=true published=true events=1 stableIdentity=true'):format(id,originalEventId))
    end,debug.traceback)
    eventLiveRunning=false
    if not called then print('[OrganizationsEventRecoveryTest] FAIL '..tostring(reason)..'; restart feather-organizations if prepare paused publication') end
end,true)

Organizations.RegisterDevCommand('OrganizationsEventLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if eventLiveRunning then print('[OrganizationsEventLiveTest] FAIL test already running');return end
    eventLiveRunning=true
    local tokens,observed={},{}
    local called,reason=xpcall(function()
        assert(#args==1 and #args[1]<=110,'Use <stable requestId, maximum 110 bytes>')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        for _,kind in ipairs({'created','status_changed','identity_changed','parent_changed'}) do
            local subscribed=exports['feather-core']:SubscribeEvent('organizations.organization.'..kind..'.v1',function(payload)
                if payload.sourceResource==owner and payload.requestId:sub(1,#args[1]+1)==args[1]..':' then
                    observed[payload.eventId]=Organizations.Copy(payload)
                end
            end)
            assert(subscribed.ok,'Subscription failed')
            tokens[#tokens+1]=subscribed.value.token
        end
        local function Require(result)
            assert(result.ok,tostring(result.code)..': '..tostring(result.message))
            return result.value
        end
        local function Create(suffix)
            return Require(OrganizationIdentity.Create({requestId=args[1]..':'..suffix,
                organizationType='business',organizationKey='org_event_test_'..suffix,
                legalName='Organization Event Test '..suffix,displayName='Event Test '..suffix,
                reasonCode='development.event_test'},owner))
        end
        local parent,child=Create('parent'),Create('child')
        local id=child.organizationId
        Require(OrganizationLifecycle.Change({organizationId=id,expectedRevision=1,status='active',
            requestId=args[1]..':activate',reasonCode='development.event_test'},owner))
        Require(OrganizationDirectory.Update({organizationId=id,expectedRevision=2,
            legalName='Organization Event Test Renamed',displayName='Event Test Renamed',
            requestId=args[1]..':rename',reasonCode='development.event_test'},owner))
        local link={organizationId=id,parentOrganizationId=parent.organizationId,expectedRevision=3,
            requestId=args[1]..':link',reasonCode='development.event_test'}
        Require(OrganizationHierarchy.Change(link,owner,'set'))
        assert(Require(OrganizationHierarchy.Change(link,owner,'set')).replayed==true,'Replay failed')
        local first=Require(OrganizationEvents.History({organizationId=id,limit=2},owner))
        assert(#first.items==2 and first.nextCursor,'First history page invalid')
        local second=Require(OrganizationEvents.History({organizationId=id,limit=2,cursor=first.nextCursor},owner))
        assert(#second.items==2 and not second.nextCursor,'Second history page invalid')
        local seen={}
        for _,page in ipairs({first,second}) do
            for _,event in ipairs(page.items) do
                assert(not seen[event.eventId],'Duplicate history event')
                seen[event.eventId]=true
            end
        end
        local cursorDenied=OrganizationEvents.History({organizationId=parent.organizationId,cursor=first.nextCursor},owner)
        assert(not cursorDenied.ok and cursorDenied.code=='invalid_cursor','Foreign cursor accepted')
        local deadline=GetGameTimer()+10000
        local rows
        repeat
            rows=DB.query([[SELECT o.event_id,o.status FROM `feather_organization_outbox` o
                JOIN `feather_organization_events` e ON e.event_id=o.event_id
                WHERE e.organization_id IN (?,?)]], id,parent.organizationId) or {}
            local published=0
            for _,row in ipairs(rows) do if row.status=='published' then published=published+1 end end
            if published==5 then break end
            Wait(50)
        until GetGameTimer()>=deadline
        assert(#rows==5,'Expected exactly five outbox records')
        for _,row in ipairs(rows) do
            assert(row.status=='published','Publication timed out')
            if not child.replayed then
                local payload=observed[row.event_id]
                assert(payload and payload.eventId==row.event_id,'Broker delivery not observed')
                assert(payload.legalName==nil and payload.displayName==nil,'Names leaked in event')
            end
        end
        print(('[OrganizationsEventLiveTest] PASS id=%s events=5 history=4 paginated=true foreignCursorRejected=true replayNoExtra=true published=true brokerObserved=%s'):format(
            id,child.replayed and 'previously_published' or 'true'))
    end,debug.traceback)
    for _,token in ipairs(tokens) do
        pcall(function() exports['feather-core']:UnsubscribeEvent(token) end)
    end
    eventLiveRunning=false
    if not called then print('[OrganizationsEventLiveTest] FAIL '..tostring(reason)) end
end,true)
