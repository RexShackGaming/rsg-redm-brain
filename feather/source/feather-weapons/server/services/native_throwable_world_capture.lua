-- Console-only read-only engine evidence. No Inventory calls, grants, world
-- deletion, binding writes or recovery claims. Never accepts client origin proof.
WeaponNativeThrowableWorldCapture={}
local flag='feather_native_throwable_world_capture'
local file='native-throwable-world-capture.json'
local resource=GetCurrentResourceName()
SetConvar(flag,'0')
local run,report,serial,lastFinal,retainedRaw
serial=0
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function int(v,min,max) return type(v)=='number' and v>=min and v<=max and v%1==0 end
local function text(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('%c') end
local function save()
    local ok,value=pcall(function()
        local raw=json.encode(report)
        return type(raw)=='string' and #raw<=131072 and SaveResourceFile(resource,file,raw,#raw)~=false
            and LoadResourceFile(resource,file)==raw
    end)
    return ok and value==true
end
local function summary()
    print('[WeaponThrowableWorldCapture] '..json.encode(report and {phase=report.phase,reason=report.reason,
        clientRecords=#(report.clientRecords or {}),serverRecords=#(report.serverRecords or {}),
        reportFile=file,noEconomicWrites=true,originConfirmed=false,automaticMutationRetries=0} or {phase='idle'}))
end
local raw=LoadResourceFile(resource,file)
if raw then
    retainedRaw=raw
    local ok,value=pcall(json.decode,raw)
    if ok and type(value)=='table' then report=value else report={phase='review_required',reason='saved_report_unreadable'} end
    if report and report.phase=='capturing' then report.phase='review_required';report.reason='capture_interrupted_no_resume' end
end
local function current(r)
    if run~=r or GetConvarInt(flag,0)~=1
        or not CoreAdapter.IsSessionCurrent(r.target,r.bound.sessionId,r.bound.characterId) then return false end
    local state=WeaponCharacterAmmoDispatcher.Status(r.target)
    return run==r and state and state.identity and state.identity.epoch==r.bound.epoch
end
local function rowValid(row)
    if type(row)~='table' or row.referenceBuild~=1491 or row.originConfirmed~=false
        or row.pickupCredits~=false or row.clientDiagnosticOnly~=true or row.noWrites~=true
        or not int(row.elapsedMs,0,30000) then return false end
    if row.kind=='pickup_target_snapshot' then
        local object=row.object
        return type(object)=='table' and int(object.entity,1,2147483647) and type(object.networked)=='boolean'
            and (object.networked and int(object.networkId,1,2147483647) or not object.networked and object.networkId==nil)
            and (object.model==(joaat('w_melee_tomahawk01') & 0xffffffff) or object.model==(joaat('w_melee_tomahawk02') & 0xffffffff))
    end
    if type(row.rawSlots)~='table' or #row.rawSlots~=8 then return false end
    for key,value in pairs(row.rawSlots) do
        if not int(key,1,8) or not int(value,-2147483648,2147483647) then return false end
    end
    return row.kind=='network_pickup' and row.queue==1 and row.eventHash==-454144443
        and row.pickupHandle==row.rawSlots[1] and row.collectorPlayerIndex==row.rawSlots[2]
        and row.pickupType==(row.rawSlots[3] & 0xffffffff) and row.model==(row.rawSlots[5] & 0xffffffff)
        or row.kind=='ai_pickup' and row.queue==0 and row.eventHash==-178091376
        and row.pickupType==(row.rawSlots[1] & 0xffffffff) and row.inventoryItemHash==(row.rawSlots[8] & 0xffffffff)
end
local function correlate()
    local candidates={}
    for index,row in ipairs(report.clientRecords) do
        local object=row.object or row.pickupObject
        if type(object)=='table' and object.networked==true and int(object.networkId,1,2147483647) then
            local matches={}
            for _,server in ipairs(report.serverRecords) do
                if server.kind=='entity_created_sample' and server.settled and not server.networkIdChanged
                    and server.networkId==object.networkId and server.model==object.model then matches[server.lifetimeId]=true end
            end
            local ids={};for id in pairs(matches) do ids[#ids+1]=id end;table.sort(ids)
            candidates[#candidates+1]={clientRecord=index,networkId=object.networkId,serverLifetimes=ids,
                ambiguous=#ids~=1,originConfirmed=false,diagnosticOnly=true}
        end
    end
    return candidates
end
RegisterNetEvent('feather-weapons:server:throwable-capture-report',function(ticket,sequence,payload)
    local actor=source
    if lastFinal and actor==lastFinal.target and ticket==lastFinal.ticket and sequence==lastFinal.sequence
        and payload==lastFinal.raw and CoreAdapter.IsSessionCurrent(actor,lastFinal.sessionId,lastFinal.characterId) then
        return TriggerClientEvent('feather-weapons:client:throwable-capture-ack',actor,ticket,sequence)
    end
    local r=run
    if not r or actor~=r.target or ticket~=r.ticket or not current(r) or not int(sequence,1,9)
        or type(payload)~='string' or #payload>6000 then return end
    if r.packets[sequence] then
        if r.packets[sequence]==payload then TriggerClientEvent('feather-weapons:client:throwable-capture-ack',actor,ticket,sequence) end
        return
    end
    if sequence~=#r.packets+1 then return end
    local ok,value=pcall(json.decode,payload)
    if not ok or type(value)~='table' then return end
    if value.kind=='rows' then
        if value.first~=#report.clientRecords+1 or type(value.rows)~='table' or #value.rows<1 or #value.rows>4
            or #report.clientRecords+#value.rows>32 then return end
        for key,row in pairs(value.rows) do if not int(key,1,#value.rows) or not rowValid(row) then return end end
        for _,row in ipairs(value.rows) do report.clientRecords[#report.clientRecords+1]=copy(row) end
    elseif value.kind=='complete' then
        if value.count~=#report.clientRecords or not int(value.frames,0,3600) or not int(value.readFailures,0,16)
            or type(value.truncated)~='boolean' or not text(value.reason,96)
            or (value.build~=1491 and not (value.build==0 and value.reason=='client_capture_preflight_refused')) then return end
        report.clientSummary=copy(value)
        report.candidateMatches=correlate() -- reference joins only, never pickup entitlement
        report.phase=value.reason=='window_complete' and 'captured' or 'review_required'
        report.reason=value.reason
    else return end
    r.packets[sequence]=payload
    -- Acknowledge only evidence which survived server file readback.
    if not save() then
        r.packets[sequence]=nil;report.phase='review_required';report.reason='capture_report_storage_unconfirmed'
        run=nil;SetConvar(flag,'0');summary();return
    end
    TriggerClientEvent('feather-weapons:client:throwable-capture-ack',actor,ticket,sequence)
    if value.kind=='complete' then
        lastFinal={target=actor,ticket=ticket,sequence=sequence,raw=payload,sessionId=r.bound.sessionId,characterId=r.bound.characterId}
        run=nil;SetConvar(flag,'0');summary()
    end
end)
local function append(r,row)
    if current(r) and #report.serverRecords<64 then report.serverRecords[#report.serverRecords+1]=row end
end
AddEventHandler('startProjectileEvent',function(actor,data)
    local r=run
    if not r or tonumber(actor)~=r.target or not current(r) or type(data)~='table'
        or not int(data.weaponHash,-2147483648,4294967295)
        or (data.weaponHash & 0xffffffff)~=(joaat('WEAPON_THROWN_TOMAHAWK') & 0xffffffff) then return end
    local fields={}
    for _,key in ipairs({'ownerId','weaponHash','projectileHash','throwTaskSequence','initialPositionX','initialPositionY','initialPositionZ'}) do
        local value=data[key]
        if type(value)=='number' and value==value and value>-math.huge and value<math.huge then fields[key]=value end
    end
    append(r,{kind='projectile_start_hint',elapsedMs=(GetGameTimer()-r.started)%4294967296,fields=fields,originConfirmed=false})
end)
AddEventHandler('entityCreated',function(handle)
    local r=run
    if not r or not current(r) or r.entityAttempts>=64 or not int(handle,1,2147483647) then return end
    r.entityAttempts=r.entityAttempts+1
    local lifetime={id=r.ticket..':entity:'..r.entityAttempts}
    r.entities[handle]=lifetime
    local function sample(delay)
        if not current(r) or r.entities[handle]~=lifetime or lifetime.removed then return end
        local ok,row=pcall(function()
            local exists=DoesEntityExist(handle)
            if (exists~=true and exists~=1) or NetworkGetEntityOwner(handle)~=r.target or GetEntityType(handle)~=3 then return nil end
            local model=GetEntityModel(handle) & 0xffffffff
            local known=model==(joaat('w_melee_tomahawk01') & 0xffffffff) or model==(joaat('w_melee_tomahawk02') & 0xffffffff)
            if model~=0 and not known then return nil end
            local net=NetworkGetNetworkIdFromEntity(handle)
            if not int(net,1,2147483647) then return nil end
            local changed=lifetime.networkId~=nil and lifetime.networkId~=net
            lifetime.networkId=lifetime.networkId or net;lifetime.observed=true
            return {kind='entity_created_sample',lifetimeId=lifetime.id,handle=handle,networkId=net,model=model,settled=known,
                networkIdChanged=changed,
                delayMs=delay,elapsedMs=(GetGameTimer()-r.started)%4294967296,originConfirmed=false}
        end)
        if ok and row then append(r,row) end
    end
    sample(0)
    SetTimeout(100,function() sample(100) end)
    SetTimeout(500,function() sample(500) end)
end)
AddEventHandler('entityRemoved',function(handle)
    local r=run;local lifetime=r and r.entities[handle]
    if not r or not lifetime or not current(r) then return end
    lifetime.removed=true
    if lifetime.observed then append(r,{kind='entity_removed',lifetimeId=lifetime.id,handle=handle,
        networkId=lifetime.networkId,elapsedMs=(GetGameTimer()-r.started)%4294967296,originConfirmed=false}) end
end)
RegisterCommand('WeaponThrowableWorldCapture',function(actor,args)
    if actor~=0 then return end
    local action=args and args[1]
    if action=='status' then return summary() end
    if action=='cancel' and run then
        TriggerClientEvent('feather-weapons:client:throwable-capture-cancel',run.target,run.ticket);return
    end
    if action~='run' or (#args~=1 and #args~=2) or run or GetConvarInt(flag,0)~=1 then return summary() end
    local target=tonumber(args[2])
    if #args==1 then
        local players=GetPlayers();if #players~=1 then return print('[WeaponThrowableWorldCapture] Specify run <current-server-id>.') end
        target=tonumber(players[1])
    end
    local session=target and CoreAdapter.ResolveSession(target)
    local state=target and WeaponCharacterAmmoDispatcher.Status(target)
    if not session or not session.ok or not state or state.phase~='active' or state.busy or not state.identity
        or state.identity.characterId~=session.value.characterId or state.identity.sessionId~=session.value.sessionId then return summary() end
    if report then
        local previous=retainedRaw or json.encode(report);local archive='native-throwable-world-capture-'..os.time()..'-'..GetGameTimer()..'-'..(serial+1)..'.json'
        if SaveResourceFile(resource,archive,previous,#previous)==false or LoadResourceFile(resource,archive)~=previous then return end
    end
    serial=serial+1
    local r={target=target,bound=copy(state.identity),ticket='world-capture:'..os.time()..':'..serial,
        started=GetGameTimer(),packets={},entityAttempts=0,entities={}}
    run=r
    report={version=1,phase='capturing',runId=r.ticket,target=target,identity=copy(r.bound),clientRecords={},serverRecords={},
        noEconomicWrites=true,originConfirmed=false,diagnosticOnly=true,automaticMutationRetries=0}
    if not save() then run=nil;SetConvar(flag,'0');return end
    retainedRaw=nil
    TriggerClientEvent('feather-weapons:client:throwable-capture-start',target,r.ticket,r.bound)
    SetTimeout(60000,function()
        if run==r then
            report.phase='review_required';report.reason='capture_report_timeout_no_replay';save()
            TriggerClientEvent('feather-weapons:client:throwable-capture-cancel',target,r.ticket)
            run=nil;SetConvar(flag,'0');summary()
        end
    end)
    print('[WeaponThrowableWorldCapture] Capturing 30 seconds of read-only evidence; no items or ammunition are granted.')
end,true)
