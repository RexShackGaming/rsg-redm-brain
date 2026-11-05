local function Run(name,callback)
    local called,result=xpcall(callback,debug.traceback)
    if not called then print((' [%s] FAIL %s'):format(name,tostring(result))) end
end
local function Report(name,tests,note)
    local passed=0
    for _,test in ipairs(tests) do
        if test[2] then passed=passed+1 end
        print(('[%s] %-28s %s'):format(name,test[1],test[2] and 'PASS' or 'FAIL'))
    end
    print(('[%s] done %d/%d passed (%s)'):format(name,passed,#tests,note))
end
Organizations.RegisterDevCommand('OrganizationsDirectoryContractSmokeTest',function(source)
    if source~=0 then return end
    Run('OrganizationsDirectoryContractSmokeTest',function()
        local owner=GetCurrentResourceName()
        if not Organizations.AwaitReady(0).ok then print('[OrganizationsDirectoryContractSmokeTest] FAIL not ready');return end
        local page=OrganizationDirectory.List({limit=1},owner)
        local denied=OrganizationDirectory.List({},'untrusted-smoke-caller')
        local tests={
            {'directory capability',Organizations.GetCapabilities().value.features.directory==1},
            {'bounded page',page.ok and #page.value.items<=1},
            {'untrusted rejected',not denied.ok and denied.code=='authorization_denied'}
        }
        for _,test in ipairs({ {'zero limit',{limit=0}}, {'fractional limit',{limit=1.5}},
            {'oversized limit',{limit=51}}, {'string limit',{limit='2'}},
            {'bad cursor',{cursor='bad cursor'}}, {'unknown status',{status='unknown'}},
            {'identity injection',{sourceResource=owner}} }) do
            tests[#tests+1]={test[1] .. ' rejected',not OrganizationDirectory.ValidateList(test[2]).ok}
        end
        local active=OrganizationDirectory.List({status='active',limit=50},owner)
        local correctStatus=active.ok
        for _,item in ipairs(active.ok and active.value.items or {}) do correctStatus=correctStatus and item.status=='active' end
        tests[#tests+1]={'status filter',correctStatus}
        local business=OrganizationDirectory.List({organizationType='business',limit=50},owner)
        local correctType=business.ok
        for _,item in ipairs(business.ok and business.value.items or {}) do correctType=correctType and item.organizationType=='business' end
        tests[#tests+1]={'type filter',correctType}
        local pagination=page.ok
        if page.ok and page.value.nextCursor then
            local nextPage=OrganizationDirectory.List({limit=1,cursor=page.value.nextCursor},owner)
            pagination=nextPage.ok and #nextPage.value.items==1
                and nextPage.value.items[1].organizationKey>page.value.nextCursor
                and nextPage.value.items[1].organizationId~=page.value.items[1].organizationId
        end
        tests[#tests+1]={'cursor advances',pagination}
        Report('OrganizationsDirectoryContractSmokeTest',tests,'read-only')
    end)
end,true)

Organizations.RegisterDevCommand('OrganizationsIdentityContractSmokeTest',function(source)
    if source~=0 then return end
    Run('OrganizationsIdentityContractSmokeTest',function()
        if not Organizations.AwaitReady(0).ok then print('[OrganizationsIdentityContractSmokeTest] FAIL not ready');return end
        local request={organizationId='00000000-0000-4000-8000-000000000001',expectedRevision=1,
            requestId='identity-contract',reasonCode='development.identity',legalName='Legal Name',displayName='Display Name'}
        local denied=OrganizationDirectory.Update(request,'untrusted-smoke-caller')
        local tests={
            {'identity capability',Organizations.GetCapabilities().value.features.identityUpdates==1},
            {'valid request',OrganizationDirectory.ValidateUpdate(request).ok},
            {'untrusted rejected',not denied.ok and denied.code=='authorization_denied'}
        }
        for _,test in ipairs({ {'immutable key','organizationKey','new_key'},
            {'immutable type','organizationType','government'}, {'status injection','status','active'},
            {'fractional revision','expectedRevision',1.5}, {'oversized ID','requestId',string.rep('x',129)},
            {'control name','displayName','bad\nname'}, {'blank name','legalName','   '},
            {'bad UUID','organizationId','not-a-uuid'} }) do
            local changed=Organizations.Copy(request);changed[test[2]]=test[3]
            tests[#tests+1]={test[1] .. ' rejected',not OrganizationDirectory.ValidateUpdate(changed).ok}
        end
        local changed=Organizations.Copy(request);changed.displayName='Different Display Name'
        tests[#tests+1]={'payload binding',OrganizationDirectory.ValidateUpdate(changed).value~=OrganizationDirectory.ValidateUpdate(request).value}
        Report('OrganizationsIdentityContractSmokeTest',tests,'no identity changes')
    end)
end,true)

Organizations.RegisterDevCommand('OrganizationsIdentityLiveTest',function(source,args)
    if source~=0 or not Config.DevMode then return end
    Run('OrganizationsIdentityLiveTest',function()
        local base=args[1]
        if #args~=1 or type(base)~='string' or #base>100 or not base:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
            print('[OrganizationsIdentityLiveTest] FAIL use <stable requestId>');return
        end
        local owner=GetCurrentResourceName()
        local created=OrganizationIdentity.Create({requestId=base .. ':create',organizationType='business',
            organizationKey='org_identity_test',legalName='Organization Identity Test Company',
            displayName='Organization Identity Test',reasonCode='development.identity_test'},owner)
        if not created.ok then print('[OrganizationsIdentityLiveTest] FAIL create code=' .. created.code);return end
        local request={organizationId=created.value.organizationId,expectedRevision=1,requestId=base .. ':rename',
            reasonCode='development.identity_test',legalName='Renamed Identity Test Company',displayName='Renamed Identity Test'}
        local renamed=OrganizationDirectory.Update(request,owner)
        if not renamed.ok then print('[OrganizationsIdentityLiveTest] FAIL rename code=' .. renamed.code);return end
        local changed=Organizations.Copy(request);changed.displayName='Tampered Identity Test'
        local mismatch=OrganizationDirectory.Update(changed,owner)
        local stale=Organizations.Copy(request);stale.requestId=base .. ':stale'
        local rejected=OrganizationDirectory.Update(stale,owner)
        local restore=Organizations.Copy(request);restore.expectedRevision=2;restore.requestId=base .. ':restore'
        restore.legalName,restore.displayName=created.value.legalName,created.value.displayName
        local restored=OrganizationDirectory.Update(restore,owner)
        if not restored.ok then print('[OrganizationsIdentityLiveTest] FAIL restore code=' .. restored.code);return end
        local replay=OrganizationDirectory.Update(request,owner)
        local noop=Organizations.Copy(restore);noop.expectedRevision=3;noop.requestId=base .. ':noop'
        local noChange=OrganizationDirectory.Update(noop,owner)
        local terminal=OrganizationIdentity.Find({organizationKey='org_lifecycle_test'},owner)
        if not terminal.ok or terminal.value.status~='dissolved' then
            print('[OrganizationsIdentityLiveTest] FAIL run lifecycle acceptance first');return
        end
        local terminalEdit=Organizations.Copy(request)
        terminalEdit.organizationId,terminalEdit.expectedRevision=terminal.value.organizationId,terminal.value.revision
        terminalEdit.requestId=base .. ':terminal'
        local blocked=OrganizationDirectory.Update(terminalEdit,owner)
        local current=OrganizationIdentity.Get({organizationId=request.organizationId},owner)
        local counts=DB.one([[SELECT
            (SELECT COUNT(*) FROM `feather_organization_events` WHERE `organization_id`=?) AS events,
            (SELECT COUNT(*) FROM `feather_organization_identity_receipts`
                WHERE `source_resource`=? AND `request_id` IN (?,?,?)) AS rejected_receipts]], request.organizationId,owner,base .. ':stale',base .. ':noop',base .. ':terminal')
        local good=not mismatch.ok and mismatch.code=='idempotency_conflict'
            and not rejected.ok and rejected.code=='revision_conflict'
            and replay.ok and replay.value.replayed==true and replay.value.revision==2
            and not noChange.ok and noChange.code=='no_change' and current.ok and current.value.revision==3
            and not blocked.ok and blocked.code=='organization_inactive'
            and current.value.organizationKey==created.value.organizationKey and current.value.organizationTypeId==created.value.organizationTypeId
            and current.value.legalName==created.value.legalName and current.value.displayName==created.value.displayName
            and counts and tonumber(counts.events)==3 and tonumber(counts.rejected_receipts)==0
        print(('[OrganizationsIdentityLiveTest] %s id=%s revision=%s firstReplayed=%s oldReceiptReplayed=%s immutableIdentity=%s namesRestored=%s events=%s rolledBack=%s'):format(
            good and 'PASS' or 'FAIL',request.organizationId,tostring(current.ok and current.value.revision),
            tostring(renamed.value.replayed),tostring(replay.ok and replay.value.replayed),
            tostring(current.ok and current.value.organizationKey==created.value.organizationKey),
            tostring(current.ok and current.value.displayName==created.value.displayName),
            tostring(counts and counts.events),tostring(counts and tonumber(counts.rejected_receipts)==0)))
    end)
end,true)
