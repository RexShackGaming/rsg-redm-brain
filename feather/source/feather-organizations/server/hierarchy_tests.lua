local function Run(name,callback)
    local called,result=xpcall(callback,debug.traceback)
    if not called then print((' [%s] FAIL %s'):format(name,tostring(result))) end
end
local function Id(number) return ('00000000-0000-4000-8000-%012x'):format(number) end
Organizations.RegisterDevCommand('OrganizationsHierarchyContractSmokeTest',function(source)
    if source~=0 then return end
    Run('OrganizationsHierarchyContractSmokeTest',function()
        if not Organizations.AwaitReady(0).ok then print('[OrganizationsHierarchyContractSmokeTest] FAIL not ready');return end
        local request={organizationId=Id(1),parentOrganizationId=Id(2),expectedRevision=1,
            requestId='hierarchy-contract',reasonCode='development.hierarchy'}
        local denied=OrganizationHierarchy.Change(request,'untrusted-smoke-caller','set')
        local self=Organizations.Copy(request);self.parentOrganizationId=self.organizationId
        local cycle=OrganizationHierarchy.ValidateGraph({[Id(1)]=Id(2),[Id(2)]=Id(1)})
        local deep={}
        for index=1,33 do deep[Id(index)]=Id(index+1) end
        local tooDeep=OrganizationHierarchy.ValidateGraph(deep)
        deep[Id(33)]=nil
        local injected=Organizations.Copy(request);injected.sourceResource='feather-admin'
        local stale=Organizations.Copy(request);stale.expectedRevision=1.5
        local remove=Organizations.Copy(request);remove.parentOrganizationId=nil
        local tests={
            {'hierarchy capability',Organizations.GetCapabilities().value.features.hierarchy==1},
            {'valid set request',OrganizationHierarchy.Validate(request,'set').ok},
            {'valid remove request',OrganizationHierarchy.Validate(remove,'remove').ok},
            {'untrusted rejected',not denied.ok and denied.code=='authorization_denied'},
            {'self-parent rejected',not OrganizationHierarchy.Validate(self,'set').ok},
            {'cycle rejected',not cycle.ok and cycle.code=='hierarchy_cycle'},
            {'depth limit rejected',not tooDeep.ok and tooDeep.code=='hierarchy_depth'},
            {'maximum depth accepted',OrganizationHierarchy.ValidateGraph(deep).ok},
            {'empty graph accepted',OrganizationHierarchy.ValidateGraph({}).ok},
            {'identity injection rejected',not OrganizationHierarchy.Validate(injected,'set').ok},
            {'fractional revision rejected',not OrganizationHierarchy.Validate(stale,'set').ok},
            {'missing parent rejected',not OrganizationHierarchy.Validate(remove,'set').ok},
            {'remove extra parent rejected',not OrganizationHierarchy.Validate(request,'remove').ok}
        }
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[OrganizationsHierarchyContractSmokeTest] %-30s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[OrganizationsHierarchyContractSmokeTest] done %d/%d passed (no parent changes)'):format(passed,#tests))
    end)
end,true)

local concurrencyRunning=false
Organizations.RegisterDevCommand('OrganizationsHierarchyConcurrencyTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    if concurrencyRunning then print('[OrganizationsHierarchyConcurrencyTest] FAIL already running');return end
    local base=args[1]
    if #args~=1 or type(base)~='string' or #base>100 or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        print('[OrganizationsHierarchyConcurrencyTest] FAIL use <stable requestId>');return
    end
    concurrencyRunning=true
    CreateThread(function()
        local called,reason=xpcall(function()
            local owner,ids=GetCurrentResourceName(),{}
            print('[OrganizationsHierarchyConcurrencyTest] started')
            for index=1,2 do
                local created=OrganizationIdentity.Create({requestId=base .. ':create:' .. index,organizationType='business',
                    organizationKey='org_hierarchy_race_' .. index,legalName='Organization Hierarchy Race Company ' .. index,
                    displayName='Organization Hierarchy Race ' .. index,reasonCode='development.hierarchy_race'},owner)
                if not created.ok then print('[OrganizationsHierarchyConcurrencyTest] FAIL create code=' .. created.code);return end
                ids[index]=created.value.organizationId
            end
            local requests={
                {organizationId=ids[1],parentOrganizationId=ids[2],expectedRevision=1,requestId=base .. ':a',reasonCode='development.hierarchy_race'},
                {organizationId=ids[2],parentOrganizationId=ids[1],expectedRevision=1,requestId=base .. ':b',reasonCode='development.hierarchy_race'}
            }
            local outcomes,finished={},0
            for index=1,2 do
                local slot=index
                CreateThread(function()
                    local ok,result=xpcall(function() return OrganizationHierarchy.Change(requests[slot],owner,'set') end,debug.traceback)
                    outcomes[slot]=ok and result or Organizations.Err('internal_error','Hierarchy contender failed.')
                    finished=finished+1
                    print(('[OrganizationsHierarchyConcurrencyTest] contender=%d ok=%s code=%s'):format(
                        slot,tostring(outcomes[slot].ok),tostring(outcomes[slot].code)))
                end)
            end
            local started=GetGameTimer()
            while finished<2 and GetGameTimer()-started<30000 do Wait(50) end
            if finished<2 then print('[OrganizationsHierarchyConcurrencyTest] FAIL timeout; retain IDs and inspect state before retry');return end
            local committed,cycles,winner=0,0,nil
            for index=1,2 do
                if outcomes[index].ok then committed=committed+1;winner=index
                elseif outcomes[index].code=='hierarchy_cycle' then cycles=cycles+1 end
            end
            local replay=winner and OrganizationHierarchy.Change(requests[winner],owner,'set')
            local first=OrganizationIdentity.Get({organizationId=ids[1]},owner)
            local second=OrganizationIdentity.Get({organizationId=ids[2]},owner)
            local states={first,second}
            local consistent=winner and first.ok and second.ok
                and states[winner].value.revision==2 and states[winner].value.parentOrganizationId==ids[3-winner]
                and states[3-winner].value.revision==1 and states[3-winner].value.parentOrganizationId==nil
                and first.value.status=='pending' and second.value.status=='pending'
            local counts=DB.one([[SELECT
                (SELECT COUNT(*) FROM `feather_organization_parents` WHERE `organization_id` IN (?,?)) AS links,
                (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id` IN (?,?)) AS events,
                (SELECT COUNT(*) FROM `feather_organization_hierarchy_receipts`
                    WHERE `source_resource`=? AND `request_id` IN (?,?)) AS receipts]], ids[1],ids[2],ids[1],ids[2],owner,requests[1].requestId,requests[2].requestId)
            local good=committed==1 and cycles==1 and consistent and replay and replay.ok and replay.value.replayed==true
                and counts and tonumber(counts.links)==1 and tonumber(counts.events)==3 and tonumber(counts.receipts)==1
            print(('[OrganizationsHierarchyConcurrencyTest] %s committed=%d cycleRejected=%d winner=%s consistent=%s links=%s events=%s receipts=%s winnerReplayed=%s'):format(
                good and 'PASS' or 'FAIL',committed,cycles,tostring(winner),tostring(consistent),
                tostring(counts and counts.links),tostring(counts and counts.events),tostring(counts and counts.receipts),
                tostring(replay and replay.ok and replay.value.replayed)))
        end,debug.traceback)
        concurrencyRunning=false
        if not called then print('[OrganizationsHierarchyConcurrencyTest] FAIL ' .. tostring(reason)) end
    end)
end,true)

Organizations.RegisterDevCommand('OrganizationsHierarchyLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    Run('OrganizationsHierarchyLiveTest',function()
        local base=args[1]
        if #args~=1 or type(base)~='string' or #base>100 or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
            print('[OrganizationsHierarchyLiveTest] FAIL use <stable requestId>');return
        end
        local owner,ids=GetCurrentResourceName(),{}
        for index=1,3 do
            local created=OrganizationIdentity.Create({requestId=base .. ':create:' .. index,organizationType='business',
                organizationKey='org_hierarchy_test_' .. index,legalName='Organization Hierarchy Test Company ' .. index,
                displayName='Organization Hierarchy Test ' .. index,reasonCode='development.hierarchy_test'},owner)
            if not created.ok then print('[OrganizationsHierarchyLiveTest] FAIL create code=' .. created.code);return end
            ids[index]=created.value.organizationId
        end
        local function Request(child,parent,revision,suffix)
            return {organizationId=ids[child],parentOrganizationId=parent and ids[parent],expectedRevision=revision,
                requestId=base .. ':' .. suffix,reasonCode='development.hierarchy_test'}
        end
        local first=Request(2,1,1,'set_b')
        local second=Request(3,2,1,'set_c')
        local b=OrganizationHierarchy.Change(first,owner,'set')
        local c=OrganizationHierarchy.Change(second,owner,'set')
        if not b.ok or not c.ok then print('[OrganizationsHierarchyLiveTest] FAIL set code=' .. tostring(not b.ok and b.code or c.code));return end
        -- Current C link may have been removed on a previous run; recreate no
        -- state on replay. B -> A still makes A -> B an unambiguous cycle.
        local cycle=OrganizationHierarchy.Change(Request(1,2,1,'cycle'),owner,'set')
        local stale=OrganizationHierarchy.Change(Request(2,3,1,'stale'),owner,'set')
        local altered=Organizations.Copy(first);altered.parentOrganizationId=ids[3]
        local mismatch=OrganizationHierarchy.Change(altered,owner,'set')
        local removed=OrganizationHierarchy.Change(Request(3,nil,2,'remove_c'),owner,'remove')
        local replay=OrganizationHierarchy.Change(second,owner,'set')
        local children=OrganizationHierarchy.Children({organizationId=ids[1],limit=1},owner)
        local readA=OrganizationIdentity.Get({organizationId=ids[1]},owner)
        local readB=OrganizationIdentity.Get({organizationId=ids[2]},owner)
        local readC=OrganizationIdentity.Get({organizationId=ids[3]},owner)
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id` IN (?,?,?)) AS events,
            (SELECT COUNT(*) FROM `feather_organization_hierarchy_receipts`
                WHERE `source_resource`=? AND `request_id` IN (?,?)) AS rejected_receipts]], ids[1],ids[2],ids[3],owner,base .. ':cycle',base .. ':stale')
        local good=not cycle.ok and cycle.code=='hierarchy_cycle' and not stale.ok and stale.code=='revision_conflict'
            and not mismatch.ok and mismatch.code=='idempotency_conflict' and removed.ok and removed.value.revision==3
            and replay.ok and replay.value.replayed==true and replay.value.parentOrganizationId==ids[2]
            and readA.ok and readA.value.revision==1 and readA.value.parentOrganizationId==nil
            and readB.ok and readB.value.revision==2 and readB.value.parentOrganizationId==ids[1]
            and readC.ok and readC.value.revision==3 and readC.value.parentOrganizationId==nil
            and readA.value.status=='pending' and readB.value.status=='pending' and readC.value.status=='pending'
            and children.ok and #children.value.items==1 and children.value.items[1].organizationId==ids[2]
            and counts and tonumber(counts.events)==6 and tonumber(counts.rejected_receipts)==0
        print(('[OrganizationsHierarchyLiveTest] %s root=%s firstReplayed=%s cycleRejected=%s staleRejected=%s mismatchRejected=%s removed=%s oldReceiptReplayed=%s events=%s rolledBack=%s'):format(
            good and 'PASS' or 'FAIL',ids[1],tostring(b.value.replayed),tostring(not cycle.ok and cycle.code=='hierarchy_cycle'),
            tostring(not stale.ok and stale.code=='revision_conflict'),tostring(not mismatch.ok and mismatch.code=='idempotency_conflict'),
            tostring(removed.ok),tostring(replay.ok and replay.value.replayed),tostring(counts and counts.events),
            tostring(counts and tonumber(counts.rejected_receipts)==0)))
    end)
end,true)
