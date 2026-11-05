local running = false
Organizations.RegisterDevCommand('OrganizationsConcurrencyTest', function(source,args)
    if source ~= 0 or not Config.DevMode then return end
    if running then print('[OrganizationsConcurrencyTest] FAIL test already running'); return end
    local base = args[1]
    if #args ~= 1 or type(base) ~= 'string' or #base > 100
        or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[OrganizationsConcurrencyTest] FAIL use <stable requestId up to 100 characters>'); return
    end
    running = true
    CreateThread(function()
        local called, errorMessage = xpcall(function()
            local owner = GetCurrentResourceName()
            print('[OrganizationsConcurrencyTest] started')
            local created = OrganizationIdentity.Create({ requestId=base .. ':create',organizationType='business',
                organizationKey='org_concurrency_test',legalName='Organization Concurrency Test Company',
                displayName='Organization Concurrency Test',reasonCode='development.concurrency_test' },owner)
            if not created.ok then print('[OrganizationsConcurrencyTest] FAIL create code=' .. created.code); return end
            local id = created.value.organizationId
            local requests = {
                { organizationId=id,expectedRevision=1,status='active',requestId=base .. ':a',reasonCode='development.concurrency_test' },
                { organizationId=id,expectedRevision=1,status='dissolving',requestId=base .. ':b',reasonCode='development.concurrency_test' }
            }
            local outcomes, finished = {}, 0
            -- Do not await promises or use # on an asynchronously populated array.
            -- Each completion advances an explicit counter, with a bounded watchdog.
            for index=1,2 do
                local slot = index
                CreateThread(function()
                    local ok,result = xpcall(function() return OrganizationLifecycle.Change(requests[slot],owner) end,debug.traceback)
                    outcomes[slot] = ok and result or Organizations.Err('internal_error','Concurrency child failed.')
                    finished = finished+1
                    print(('[OrganizationsConcurrencyTest] contender=%d ok=%s code=%s'):format(
                        slot,tostring(outcomes[slot].ok),tostring(outcomes[slot].code)))
                end)
            end
            local started = GetGameTimer()
            while finished < 2 and GetGameTimer()-started < 30000 do Wait(50) end
            if finished < 2 then
                print('[OrganizationsConcurrencyTest] FAIL timed out; retain request ID and inspect state before retrying'); return
            end
            local success,stale,winner,loser = 0,0,nil,nil
            for index=1,2 do
                if outcomes[index].ok then success=success+1;winner=index
                elseif outcomes[index].code=='revision_conflict' then stale=stale+1;loser=index end
            end
            local replay = winner and OrganizationLifecycle.Change(requests[winner],owner)
            local current = OrganizationIdentity.Get({organizationId=id},owner)
            local counts = DB.one([[SELECT
                (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id`=?) AS events,
                (SELECT COUNT(*) FROM `feather_organization_lifecycle_receipts`
                    WHERE `source_resource`=? AND `request_id` IN (?,?)) AS receipts]], id,owner,requests[1].requestId,requests[2].requestId)
            local good = success==1 and stale==1 and replay and replay.ok and replay.value.replayed==true
                and current.ok and current.value.revision==2 and current.value.status==requests[winner].status
                and counts and tonumber(counts.events)==2 and tonumber(counts.receipts)==1
            print(('[OrganizationsConcurrencyTest] %s id=%s committed=%d stale=%d revision=%s events=%s receipts=%s winnerReplayed=%s'):format(
                good and 'PASS' or 'FAIL',id,success,stale,tostring(current.ok and current.value.revision),
                tostring(counts and counts.events),tostring(counts and counts.receipts),tostring(replay and replay.ok and replay.value.replayed)))
        end,debug.traceback)
        running=false
        if not called then print('[OrganizationsConcurrencyTest] FAIL ' .. tostring(errorMessage)) end
    end)
end,true)

local identityRunning=false
Organizations.RegisterDevCommand('OrganizationsIdentityLifecycleConcurrencyTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if identityRunning then print('[OrganizationsIdentityLifecycleConcurrencyTest] FAIL already running');return end
    local base=args[1]
    if #args~=1 or type(base)~='string' or #base>100 or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[OrganizationsIdentityLifecycleConcurrencyTest] FAIL use <stable requestId>');return
    end
    identityRunning=true
    CreateThread(function()
        local called,reason=xpcall(function()
            local name='OrganizationsIdentityLifecycleConcurrencyTest'
            local owner=GetCurrentResourceName()
            print('[' .. name .. '] started')
            local created=OrganizationIdentity.Create({requestId=base .. ':create',organizationType='business',
                organizationKey='org_identity_lifecycle_race',legalName='Organization Identity Lifecycle Race Company',
                displayName='Organization Identity Lifecycle Race',reasonCode='development.identity_lifecycle_race'},owner)
            if not created.ok then print('[' .. name .. '] FAIL create code=' .. created.code);return end
            local id=created.value.organizationId
            local edit={organizationId=id,expectedRevision=1,requestId=base .. ':edit',
                legalName='Renamed Identity Lifecycle Race Company',displayName='Renamed Identity Lifecycle Race',
                reasonCode='development.identity_lifecycle_race'}
            local change={organizationId=id,expectedRevision=1,requestId=base .. ':dissolve',status='dissolving',
                reasonCode='development.identity_lifecycle_race'}
            local operations={
                function() return OrganizationDirectory.Update(edit,owner) end,
                function() return OrganizationLifecycle.Change(change,owner) end
            }
            local outcomes,finished={},0
            for index=1,2 do
                local slot=index
                CreateThread(function()
                    local ok,result=xpcall(operations[slot],debug.traceback)
                    outcomes[slot]=ok and result or Organizations.Err('internal_error','Race child failed.')
                    finished=finished+1
                    print(('[%s] contender=%s ok=%s code=%s'):format(name,slot==1 and 'identity' or 'lifecycle',
                        tostring(outcomes[slot].ok),tostring(outcomes[slot].code)))
                end)
            end
            local started=GetGameTimer()
            while finished<2 and GetGameTimer()-started<30000 do Wait(50) end
            if finished<2 then print('[' .. name .. '] FAIL timeout; retain IDs and inspect state before retrying');return end
            local successes,stale,winner=0,0,nil
            for index=1,2 do
                if outcomes[index].ok then successes=successes+1;winner=index
                elseif outcomes[index].code=='revision_conflict' then stale=stale+1 end
            end
            local replay=winner and operations[winner]()
            local current=OrganizationIdentity.Get({organizationId=id},owner)
            local counts=DB.one([[SELECT
                (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id`=?) AS events,
                (SELECT COUNT(*) FROM `feather_organization_identity_receipts`
                    WHERE `source_resource`=? AND `request_id`=?) AS edits,
                (SELECT COUNT(*) FROM `feather_organization_lifecycle_receipts`
                    WHERE `source_resource`=? AND `request_id`=?) AS lifecycle]], id,owner,edit.requestId,owner,change.requestId)
            local consistent=current.ok and (
                (winner==1 and current.value.status=='pending' and current.value.legalName==edit.legalName
                    and current.value.displayName==edit.displayName)
                or (winner==2 and current.value.status=='dissolving' and current.value.legalName==created.value.legalName
                    and current.value.displayName==created.value.displayName))
            local receipts=counts and tonumber(counts.edits)+tonumber(counts.lifecycle)
            local good=successes==1 and stale==1 and consistent and current.value.revision==2
                and current.value.organizationKey==created.value.organizationKey
                and current.value.organizationTypeId==created.value.organizationTypeId
                and replay and replay.ok and replay.value.replayed==true and replay.value.revision==2
                and counts and tonumber(counts.events)==2 and receipts==1
                and tonumber(counts.edits)==(winner==1 and 1 or 0)
                and tonumber(counts.lifecycle)==(winner==2 and 1 or 0)
            print(('[%s] %s id=%s committed=%d stale=%d winner=%s revision=%s consistent=%s events=%s receipts=%s winnerReplayed=%s'):format(
                name,good and 'PASS' or 'FAIL',id,successes,stale,winner==1 and 'identity' or winner==2 and 'lifecycle' or 'none',
                tostring(current.ok and current.value.revision),tostring(consistent),tostring(counts and counts.events),
                tostring(receipts),tostring(replay and replay.ok and replay.value.replayed)))
        end,debug.traceback)
        identityRunning=false
        if not called then print('[OrganizationsIdentityLifecycleConcurrencyTest] FAIL ' .. tostring(reason)) end
    end)
end,true)
local interestRunning=false
Organizations.RegisterDevCommand('OrganizationsInterestConcurrencyTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestRunning then print('[OrganizationsInterestConcurrencyTest] FAIL already running');return end
    if #args~=2 or #args[1]>100 or not args[1]:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') or not Organizations.Uuid(args[2]) then
        print('[OrganizationsInterestConcurrencyTest] FAIL use <stable requestId> <character UUID>');return
    end
    interestRunning=true
    CreateThread(function()
        local called,reason=xpcall(function()
            local name='OrganizationsInterestConcurrencyTest'
            local owner=GetCurrentResourceName()
            local function Require(result)
                assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value
            end
            assert(Organizations.AwaitReady(0).ok,'Service not ready')
            print('['..name..'] started')
            local created=Require(OrganizationIdentity.Create({requestId=args[1]..':create',organizationType='business',
                organizationKey='org_interest_race',legalName='Organization Interest Race Company',displayName='Interest Race',
                reasonCode='development.interest_race'},owner))
            local id=created.organizationId
            local requests={}
            for index,kind in ipairs({'owner','founder'}) do
                requests[index]={organizationId=id,expectedRevision=1,requestId=args[1]..':'..kind,
                    interestType=kind,holderType='character',holderId=args[2]:lower(),reasonCode='development.interest_race'}
            end
            local outcomes,finished={},0
            for index=1,2 do
                local slot=index
                CreateThread(function()
                    local ok,result=xpcall(function() return OrganizationInterests.Change(requests[slot],owner,'grant') end,debug.traceback)
                    outcomes[slot]=ok and result or Organizations.Err('internal_error','Interest contender failed.')
                    finished=finished+1
                    print(('[%s] contender=%d ok=%s code=%s'):format(name,slot,tostring(outcomes[slot].ok),tostring(outcomes[slot].code)))
                end)
            end
            local started=GetGameTimer()
            while finished<2 and GetGameTimer()-started<30000 do Wait(50) end
            assert(finished==2,'Timeout; retain original IDs and inspect state before retrying. Database work is not cancelled.')
            local committed,stale,winner=0,0,nil
            for index=1,2 do
                if outcomes[index].ok then committed=committed+1;winner=index
                elseif outcomes[index].code=='revision_conflict' then stale=stale+1 end
            end
            assert(committed==1 and stale==1,'Expected exactly one commit and one revision conflict')
            local replay=Require(OrganizationInterests.Change(requests[winner],owner,'grant'))
            assert(replay.replayed and replay.interestId==outcomes[winner].value.interestId,'Winner receipt did not replay')
            local current=Require(OrganizationIdentity.Get({organizationId=id},owner))
            assert(current.revision==2 and current.status=='pending','Organization state inconsistent')
            local interests=DB.query('SELECT * FROM `feather_organization_interests` WHERE `organization_id`=?', id) or {}
            assert(#interests==1 and interests[1].interest_id==replay.interestId and interests[1].interest_type==requests[winner].interestType
                and interests[1].holder_id==args[2]:lower() and interests[1].status=='active' and tonumber(interests[1].revision)==2,
                'Interest state is not winner-only')
            local events=DB.query('SELECT `event_id`,`request_id`,`revision` FROM `feather_organization_events` WHERE `organization_id`=?', id) or {}
            assert(#events==2,'Expected creation and one grant audit event')
            local grantEvent
            for _,event in ipairs(events) do
                if event.request_id==requests[winner].requestId then grantEvent=event end
            end
            assert(grantEvent and tonumber(grantEvent.revision)==2,'Winner audit missing')
            local receipts=DB.query([[SELECT `request_id` FROM `feather_organization_interest_receipts`
                WHERE `source_resource`=? AND `request_id` IN (?,?)]], owner,requests[1].requestId,requests[2].requestId) or {}
            assert(#receipts==1 and receipts[1].request_id==requests[winner].requestId,'Loser receipt persisted')
            local outbox=DB.query([[SELECT o.event_id,o.payload_json FROM `feather_organization_outbox` o
                JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id=?]], id) or {}
            assert(#outbox==2,'Outbox count inconsistent')
            local payload
            for _,row in ipairs(outbox) do if row.event_id==grantEvent.event_id then payload=json.decode(row.payload_json) end end
            assert(payload and payload.interestId==replay.interestId and payload.holderId==nil,'Grant outbox identity/privacy invalid')
            print(('[%s] PASS id=%s committed=1 stale=1 winner=%s revision=2 interests=1 events=2 outbox=2 receipts=1 winnerReplayed=true consistent=true'):format(
                name,id,requests[winner].interestType))
        end,debug.traceback)
        interestRunning=false
        if not called then print('[OrganizationsInterestConcurrencyTest] FAIL '..tostring(reason)) end
    end)
end,true)
local interestLifecycleRunning=false
Organizations.RegisterDevCommand('OrganizationsInterestLifecycleConcurrencyTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if interestLifecycleRunning then print('[OrganizationsInterestLifecycleConcurrencyTest] FAIL already running');return end
    if #args~=2 or #args[1]>100 or not args[1]:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') or not Organizations.Uuid(args[2]) then
        print('[OrganizationsInterestLifecycleConcurrencyTest] FAIL use <stable requestId> <character UUID>');return
    end
    interestLifecycleRunning=true
    CreateThread(function()
        local called,reason=xpcall(function()
            local name='OrganizationsInterestLifecycleConcurrencyTest'
            local owner=GetCurrentResourceName()
            local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
            assert(Organizations.AwaitReady(0).ok,'Service not ready')
            print('['..name..'] started')
            local created=Require(OrganizationIdentity.Create({requestId=args[1]..':create',organizationType='business',
                organizationKey='org_interest_lifecycle_race',legalName='Organization Interest Lifecycle Race Company',
                displayName='Interest Lifecycle Race',reasonCode='development.interest_lifecycle_race'},owner))
            local id=created.organizationId
            local grant={organizationId=id,expectedRevision=1,requestId=args[1]..':grant',interestType='owner',
                holderType='character',holderId=args[2]:lower(),reasonCode='development.interest_lifecycle_race'}
            local dissolve={organizationId=id,expectedRevision=1,requestId=args[1]..':dissolve',status='dissolving',
                reasonCode='development.interest_lifecycle_race'}
            local operations={function() return OrganizationInterests.Change(grant,owner,'grant') end,
                function() return OrganizationLifecycle.Change(dissolve,owner) end}
            local outcomes,finished={},0
            for index=1,2 do
                local slot=index
                CreateThread(function()
                    local ok,result=xpcall(operations[slot],debug.traceback)
                    outcomes[slot]=ok and result or Organizations.Err('internal_error','Mixed contender failed.')
                    finished=finished+1
                    print(('[%s] contender=%s ok=%s code=%s'):format(name,slot==1 and 'interest' or 'lifecycle',
                        tostring(outcomes[slot].ok),tostring(outcomes[slot].code)))
                end)
            end
            local started=GetGameTimer()
            while finished<2 and GetGameTimer()-started<30000 do Wait(50) end
            assert(finished==2,'Timeout; retain original IDs and inspect state. Database work is not cancelled.')
            local committed,stale,winner=0,0,nil
            for index=1,2 do
                if outcomes[index].ok then committed=committed+1;winner=index
                elseif outcomes[index].code=='revision_conflict' then stale=stale+1 end
            end
            assert(committed==1 and stale==1,'Expected one commit and one revision conflict')
            local replay=Require(operations[winner]())
            assert(replay.replayed and replay.revision==2,'Winner receipt did not replay')
            local current=Require(OrganizationIdentity.Get({organizationId=id},owner))
            assert(current.revision==2 and current.status==(winner==1 and 'pending' or 'dissolving'),'Lifecycle state inconsistent')
            local interests=Require(OrganizationInterests.List({organizationId=id},owner)).items
            assert(#interests==(winner==1 and 1 or 0),'Interest records do not match winner')
            if winner==1 then
                assert(interests[1].interestId==replay.interestId and interests[1].holderId==grant.holderId
                    and interests[1].status=='active' and interests[1].revision==2,'Winner interest inconsistent')
            end
            local counts=DB.one([[SELECT
                (SELECT COUNT(*) FROM `feather_organization_events` WHERE organization_id=?) AS events,
                (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id=?) AS outbox,
                (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id=?) AS grants,
                (SELECT COUNT(*) FROM `feather_organization_lifecycle_receipts` WHERE source_resource=? AND request_id=?) AS changes]], id,id,owner,grant.requestId,owner,dissolve.requestId)
            assert(tonumber(counts.events)==2 and tonumber(counts.outbox)==2
                and tonumber(counts.grants)==(winner==1 and 1 or 0) and tonumber(counts.changes)==(winner==2 and 1 or 0),'Mixed atomic counts invalid')
            local audit=DB.one('SELECT `event_type`,`revision` FROM `feather_organization_events` WHERE source_resource=? AND request_id=?', owner,winner==1 and grant.requestId or dissolve.requestId)
            assert(audit and audit.event_type==(winner==1 and 'organization.interest_granted' or 'organization.status_changed')
                and tonumber(audit.revision)==2,'Winner audit inconsistent')
            print(('[%s] PASS id=%s committed=1 stale=1 winner=%s revision=2 state=%s interests=%d events=2 outbox=2 receipts=1 winnerReplayed=true consistent=true'):format(
                name,id,winner==1 and 'interest' or 'lifecycle',current.status,#interests))
        end,debug.traceback)
        interestLifecycleRunning=false
        if not called then print('[OrganizationsInterestLifecycleConcurrencyTest] FAIL '..tostring(reason)) end
    end)
end,true)
local holderRaceRunning=false
Organizations.RegisterDevCommand('OrganizationsHolderGrantOrderingTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if holderRaceRunning then print('[OrganizationsHolderGrantOrderingTest] FAIL holder test already running');return end
    holderRaceRunning=true
    local called,reason=xpcall(function()
        assert(#args==1 and #args[1]<=100,'Use <stable requestId>')
        assert(Organizations.AwaitReady(0).ok,'Service not ready')
        local owner=GetCurrentResourceName()
        local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
        local function Create(suffix)
            return Require(OrganizationIdentity.Create({requestId=args[1]..':create_'..suffix,organizationType='business',
                organizationKey='org_holder_grant_order_'..suffix,legalName='Organization Holder Grant Ordering '..suffix,
                displayName='Holder Grant Ordering '..suffix,reasonCode='development.holder_grant_order'},owner))
        end
        local target,holder=Create('target'),Create('holder')
        Require(OrganizationLifecycle.Change({organizationId=holder.organizationId,expectedRevision=1,status='active',
            requestId=args[1]..':activate',reasonCode='development.holder_grant_order'},owner))
        local grant={organizationId=target.organizationId,expectedRevision=1,interestType='controlling_organization',
            holderType='organization',holderId=holder.organizationId,requestId=args[1]..':grant',reasonCode='development.holder_grant_order'}
        -- Intentional ordering, not a probabilistic race or production fault hook:
        -- suspension is issued only after the grant transaction has committed.
        local granted=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local suspend={organizationId=holder.organizationId,expectedRevision=2,status='suspended',
            requestId=args[1]..':suspend',reasonCode='development.holder_grant_order'}
        Require(OrganizationLifecycle.Change(suspend,owner))
        local replay=Require(OrganizationInterests.Change(grant,owner,'grant'))
        local suspendReplay=Require(OrganizationLifecycle.Change(suspend,owner))
        assert(replay.replayed and replay.interestId==granted.interestId and replay.revision==2
            and suspendReplay.replayed and suspendReplay.revision==3,'Committed receipts did not replay')
        local fresh=Organizations.Copy(grant);fresh.expectedRevision=2;fresh.interestType='owner';fresh.requestId=args[1]..':blocked'
        local denied=OrganizationInterests.Change(fresh,owner,'grant')
        assert(not denied.ok and denied.code=='holder_inactive','Fresh grant accepted after suspension')
        local targetState=Require(OrganizationIdentity.Get({organizationId=target.organizationId},owner))
        local holderState=Require(OrganizationIdentity.Get({organizationId=holder.organizationId},owner))
        local page=Require(OrganizationInterests.List({organizationId=target.organizationId,status='active'},owner))
        assert(targetState.status=='pending' and targetState.revision==2 and holderState.status=='suspended' and holderState.revision==3
            and #page.items==1 and page.items[1].interestId==granted.interestId
            and page.items[1].holderId==holder.organizationId and page.items[1].revision==2,'Grant-first state inconsistent')
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE organization_id IN (?,?)) AS events,
            (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id IN (?,?)) AS outbox,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id=?) AS grants,
            (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id=?) AS rejected]], target.organizationId,holder.organizationId,target.organizationId,holder.organizationId,owner,grant.requestId,owner,fresh.requestId)
        assert(tonumber(counts.events)==5 and tonumber(counts.outbox)==5 and tonumber(counts.grants)==1 and tonumber(counts.rejected)==0,'Grant-first record counts inconsistent')
        print(('[OrganizationsHolderGrantOrderingTest] PASS target=%s holder=%s ordering=grant_then_suspend holderRevision=3 targetRevision=2 interests=1 events=5 outbox=5 originalReceipt=true freshGrantBlocked=true noImplicitRevocation=true firstReplayed=%s'):format(
            target.organizationId,holder.organizationId,tostring(granted.replayed)))
    end,debug.traceback)
    holderRaceRunning=false
    if not called then print('[OrganizationsHolderGrantOrderingTest] FAIL '..tostring(reason)) end
end,true)

Organizations.RegisterDevCommand('OrganizationsHolderGrantConcurrencyTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if holderRaceRunning then print('[OrganizationsHolderGrantConcurrencyTest] FAIL already running');return end
    if #args~=1 or #args[1]>100 or not args[1]:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[OrganizationsHolderGrantConcurrencyTest] FAIL use <stable requestId>');return
    end
    holderRaceRunning=true
    CreateThread(function()
        local called,reason=xpcall(function()
            local name='OrganizationsHolderGrantConcurrencyTest'
            local owner=GetCurrentResourceName()
            local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
            assert(Organizations.AwaitReady(0).ok,'Service not ready')
            print('['..name..'] started')
            local function Create(suffix)
                return Require(OrganizationIdentity.Create({requestId=args[1]..':create_'..suffix,organizationType='business',
                    organizationKey='org_holder_grant_race_'..suffix,legalName='Organization Holder Grant Race '..suffix,
                    displayName='Holder Grant Race '..suffix,reasonCode='development.holder_grant_race'},owner))
            end
            local target,holder=Create('target'),Create('holder')
            Require(OrganizationLifecycle.Change({organizationId=holder.organizationId,expectedRevision=1,status='active',
                requestId=args[1]..':activate',reasonCode='development.holder_grant_race'},owner))
            local grant={organizationId=target.organizationId,expectedRevision=1,interestType='controlling_organization',
                holderType='organization',holderId=holder.organizationId,requestId=args[1]..':grant',reasonCode='development.holder_grant_race'}
            local suspend={organizationId=holder.organizationId,expectedRevision=2,status='suspended',
                requestId=args[1]..':suspend',reasonCode='development.holder_grant_race'}
            local operations={function() return OrganizationInterests.Change(grant,owner,'grant') end,
                function() return OrganizationLifecycle.Change(suspend,owner) end}
            local outcomes,finished={},0
            for index=1,2 do
                local slot=index
                CreateThread(function()
                    local ok,result=xpcall(operations[slot],debug.traceback)
                    outcomes[slot]=ok and result or Organizations.Err('internal_error','Holder race child failed.')
                    finished=finished+1
                    print(('[%s] contender=%s ok=%s code=%s'):format(name,slot==1 and 'grant' or 'suspend',
                        tostring(outcomes[slot].ok),tostring(outcomes[slot].code)))
                end)
            end
            local started=GetGameTimer()
            while finished<2 and GetGameTimer()-started<30000 do Wait(50) end
            assert(finished==2,'Timeout; retain request ID and inspect state. Database work is not cancelled.')
            local suspension=Require(outcomes[2])
            local granted=outcomes[1].ok==true
            assert(granted or outcomes[1].code=='holder_inactive','Unexpected grant outcome')
            local grantReplay=operations[1]()
            local suspendReplay=Require(operations[2]())
            assert(suspendReplay.replayed and suspendReplay.revision==3 and suspension.revision==3,'Suspension replay inconsistent')
            if granted then
                assert(grantReplay.ok and grantReplay.value.replayed and grantReplay.value.interestId==outcomes[1].value.interestId,
                    'Committed grant did not replay after suspension')
            else
                assert(not grantReplay.ok and grantReplay.code=='holder_inactive','Suspended holder retry accepted')
            end
            local holderState=Require(OrganizationIdentity.Get({organizationId=holder.organizationId},owner))
            local targetState=Require(OrganizationIdentity.Get({organizationId=target.organizationId},owner))
            local interests=Require(OrganizationInterests.List({organizationId=target.organizationId},owner)).items
            assert(holderState.status=='suspended' and holderState.revision==3 and targetState.status=='pending'
                and targetState.revision==(granted and 2 or 1) and #interests==(granted and 1 or 0),'Holder/target state inconsistent')
            if granted then
                assert(interests[1].interestId==grantReplay.value.interestId and interests[1].holderId==holder.organizationId
                    and interests[1].status=='active','Previously committed interest changed implicitly')
            end
            local counts=DB.one([[SELECT
                (SELECT COUNT(*) FROM `feather_organization_events` WHERE organization_id IN (?,?)) AS events,
                (SELECT COUNT(*) FROM `feather_organization_outbox` o JOIN `feather_organization_events` e ON e.event_id=o.event_id WHERE e.organization_id IN (?,?)) AS outbox,
                (SELECT COUNT(*) FROM `feather_organization_interest_receipts` WHERE source_resource=? AND request_id=?) AS grants,
                (SELECT COUNT(*) FROM `feather_organization_lifecycle_receipts` WHERE source_resource=? AND request_id=?) AS suspensions]], target.organizationId,holder.organizationId,target.organizationId,holder.organizationId,owner,grant.requestId,owner,suspend.requestId)
            local expected=granted and 5 or 4
            assert(tonumber(counts.events)==expected and tonumber(counts.outbox)==expected
                and tonumber(counts.grants)==(granted and 1 or 0) and tonumber(counts.suspensions)==1,'Race atomic counts inconsistent')
            print(('[%s] PASS target=%s holder=%s grant=%s holderState=suspended holderRevision=3 targetRevision=%d interests=%d events=%d outbox=%d replayConsistent=true noImplicitRevocation=true'):format(
                name,target.organizationId,holder.organizationId,granted and 'committed_before_suspend' or 'holder_inactive',
                targetState.revision,#interests,expected,expected))
        end,debug.traceback)
        holderRaceRunning=false
        if not called then print('[OrganizationsHolderGrantConcurrencyTest] FAIL '..tostring(reason)) end
    end)
end,true)
