local foundation={ready=false,status='starting',schemaVersion=0,applied=0,resumed=0}
local stopped=false
local fixtureEnabled=false
local eventFixtureEnabled=false
local accessFixtureEnabled=false
local controllerFixtureEnabled=false
local propertyFixtureEnabled=false
local binding
local authority
local access
local publisher
local function dependencies()
    return GetResourceState('feather-mysql')=='started' and GetResourceState('feather-core')=='started'
end
local function health()
    local ready=foundation.ready and not stopped and dependencies()
    return {
        resource=FeatherDoors.Name,ready=false,status=ready and 'foundation_ready'
            or (foundation.ready and 'dependency_unavailable' or foundation.status),
        stage='access_target_foundation',foundationReady=ready,schemaVersion=foundation.schemaVersion,
        migrationsApplied=foundation.applied,migrationsResumed=foundation.resumed,
        outbox=publisher and {enabled=publisher.enabled,busy=publisher.busy,lastCode=publisher.lastCode} or nil,
        access=access and {registered=access.registered,lastCode=access.lastCode} or nil
    }
end
exports('GetCapabilities',function()
    return {resource=FeatherDoors.Name,version=FeatherDoors.Version,stage='access_target_foundation',
        doorRegistration=false,lockState=false,persistence=false,synchronization=false,playerInteraction=false,
        schema=health().foundationReady and 1 or 0,trustedDefinitions=health().foundationReady and 1 or 0,
        durableReceipts=health().foundationReady and 1 or 0,changeEvents=health().foundationReady and 1 or 0,
        serviceControl=health().foundationReady and 1 or 0,
        accessTargetProvider=access and access.registered and health().foundationReady and 1 or 0,
        playerAuthorization=false,grantManagement=false}
end)
exports('GetHealth',health)
local function authorized(caller)
    return type(caller)=='string' and
        (DoorsConfig.TrustedResources[caller]==true or fixtureEnabled and caller=='feather-doors-api-tests'
            or eventFixtureEnabled and caller=='feather-doors-outbox-tests'
            or accessFixtureEnabled and caller=='feather-doors-access-tests'
            or controllerFixtureEnabled and caller=='feather-doors-service-owner-tests'
            or propertyFixtureEnabled and caller=='feather-doors-property-tests')
end
local function allowed(caller) return (caller=='feather-doors' or authorized(caller)) and health().foundationReady end
local function controllerAuthorized(caller,key)
    if type(caller)~='string' or not DoorsContract.Token(key,100) then return false end
    local map=DoorsConfig.ServiceControllers
    local scopes=type(map)=='table' and map[caller]
    return (type(scopes)=='table' and scopes[key]==true)
        or (controllerFixtureEnabled and caller=='feather-doors-service-tests' and key=='doors.fixture.service.v1')
end
local repository=DoorsRepository.New(DB,allowed,function(caller,key)
    return controllerAuthorized(caller,key) and health().foundationReady
end)
publisher=DoorsEvents.New(DB,function(name,payload)
    return exports['feather-core']:PublishEvent(name,payload)
end,function() return health().foundationReady end)
binding=DoorsBinding.New(DB,repository,{available=function() return GetResourceState('feather-property')=='started' end,
    read=function(id) return exports['feather-property']:GetPropertyLinkContext({linkType='door',externalId=id}) end},
    function() return health().foundationReady end)
authority=DoorsAuthority.New(binding,{
    session=function(source) return exports['feather-core']:GetSessionContext(source) end,
    interest=function(request) return exports['feather-property']:CheckInterest(request) end,
    policy=function(action,request) return exports['feather-core']:Authorize(action,request) end
},function() return health().foundationReady end)
for _,name in ipairs({'core.session.ready.v1','core.session.leaving.v1','core.session.left.v1'}) do
    AddEventHandler(name,function(session) if type(session)=='table' then authority:Bump(session.source) end end)
end
AddEventHandler('playerDropped',function() authority:Bump(tonumber(source)) end)
access=DoorsAccess.New(DB,{available=function() return GetResourceState('feather-access')=='started' end,
    call=function(name,request) return exports['feather-access'][name](nil,request) end},
    function() return health().foundationReady end,binding)
local function register(name,method,kind)
    exports(name,function(request)
        local caller=GetInvokingResource()
        if not authorized(caller) then return DoorsContract.Err('forbidden') end
        if not health().foundationReady then return DoorsContract.Err('unavailable') end
        if method=='Mutate' then return repository:Mutate(caller,kind,request) end
        if method=='ByKey' then return repository:Get(caller,request,true) end
        if method=='AccessContext' then return access:Context(caller,request) end
        if method=='BindingSet' then return binding:Set(caller,request) end
        if method=='BindingContext' then return binding:Context(caller,request) end
        if method=='GrantAuthority' then
            local ok,result=pcall(authority.Check,authority,caller,request)
            return ok and result or DoorsContract.Err('authority_unavailable')
        end
        return repository[method](repository,caller,request)
    end)
end
register('CreateDoorGroup','Mutate','create')
register('UpdateDoorGroup','Mutate','update')
register('DeleteDoorGroup','Mutate','retire')
register('SetLockState','Mutate','state')
register('GetDoorGroup','Get')
register('FindDoorByKey','ByKey')
register('ListDoorGroups','List')
register('FindOperation','Find')
register('GetOperationEvent','Event')
register('GetDoorTargetContext','AccessContext')
register('SetDoorBindingMode','BindingSet')
register('GetDoorBindingContext','BindingContext')
register('CheckDoorGrantAuthority','GrantAuthority')
RegisterCommand('DoorsPropertyFixture',function(player,args)
    if player~=0 then return end
    if #args~=1 or args[1]~='enable' and args[1]~='disable' then
        print('[feather-doors] Server console: DoorsPropertyFixture <enable|disable>');return
    end
    propertyFixtureEnabled=args[1]=='enable'
    print('[feather-doors] temporary Property-binding fixture '..(propertyFixtureEnabled and 'enabled' or 'disabled'))
end,true)
local function controllerExport(name,method)
    exports(name,function(request)
        local caller=GetInvokingResource()
        if type(request)~='table' or not controllerAuthorized(caller,rawget(request,'key')) then return DoorsContract.Err('forbidden') end
        if not health().foundationReady then return DoorsContract.Err('unavailable') end
        if method=='set' then return repository:Mutate(caller,'control',request) end
        return repository[method](repository,caller,request)
    end)
end
controllerExport('GetControlledDoor','ControlGet')
controllerExport('SetControlledLockState','set')
controllerExport('FindControlledOperation','ControlFind')
RegisterCommand('DoorsControllerFixture',function(player,args)
    if player~=0 then return end
    if #args~=1 or args[1]~='enable' and args[1]~='disable' then
        print('[feather-doors] Server console: DoorsControllerFixture <enable|disable>');return
    end
    controllerFixtureEnabled=args[1]=='enable'
    print('[feather-doors] temporary service owner/controller fixture '..(controllerFixtureEnabled and 'enabled' or 'disabled'))
end,true)
RegisterCommand('DoorsAccessFixture',function(player,args)
    if player~=0 then return end
    if #args~=1 or args[1]~='enable' and args[1]~='disable' then
        print('[feather-doors] Server console: DoorsAccessFixture <enable|disable>'); return
    end
    accessFixtureEnabled=args[1]=='enable'
    print('[feather-doors] temporary feather-doors-access-tests authority '..(accessFixtureEnabled and 'enabled' or 'disabled'))
end,true)
RegisterCommand('DoorsAccess',function(player,args)
    if player~=0 then return end
    if #args~=1 or not ({status=true,register=true,unregister=true})[args[1]] then
        print('[feather-doors] Server console: DoorsAccess <status|register|unregister>'); return
    end
    local ok,result=pcall(function()
        if args[1]=='register' then return access:Register() end
        if args[1]=='unregister' then return access:Unregister() end
        return DoorsContract.Ok({registered=access.registered,lastCode=access.lastCode})
    end)
    print('[feather-doors] access '..json.encode(ok and result or DoorsContract.Err('provider_exception')))
end,true)
RegisterCommand('DoorsApiFixture',function(player,args)
    if player~=0 then return end
    if #args~=1 or args[1]~='enable' and args[1]~='disable' then
        print('[feather-doors] Server console: DoorsApiFixture <enable|disable>'); return
    end
    fixtureEnabled=args[1]=='enable'
    print('[feather-doors] temporary feather-doors-api-tests authority '..(fixtureEnabled and 'enabled' or 'disabled'))
end,true)
RegisterCommand('DoorsEventFixture',function(player,args)
    if player~=0 then return end
    if #args~=1 or args[1]~='enable' and args[1]~='disable' then
        print('[feather-doors] Server console: DoorsEventFixture <enable|disable>'); return
    end
    eventFixtureEnabled=args[1]=='enable'
    print('[feather-doors] temporary feather-doors-outbox-tests authority '..(eventFixtureEnabled and 'enabled' or 'disabled'))
end,true)
RegisterCommand('DoorsOutbox',function(player,args)
    if player~=0 then return end
    if #args~=1 or not ({status=true,pause=true,resume=true,drain=true,['recover-fixture']=true,['diagnose-fixture']=true})[args[1]] then
        print('[feather-doors] Server console: DoorsOutbox <status|pause|resume|drain|recover-fixture|diagnose-fixture>'); return
    end
    if not health().foundationReady then print('[feather-doors] outbox unavailable'); return end
    local ok,result=pcall(function()
        if args[1]=='pause' then publisher.enabled=false
        elseif args[1]=='resume' then publisher.enabled=true
        elseif args[1]=='drain' then return publisher:Drain()
        elseif args[1]=='diagnose-fixture' then return DoorsEvents.DiagnoseFixture(DB)
        elseif args[1]=='recover-fixture' then
            if publisher.enabled or publisher.busy then return DoorsContract.Err('pause_and_wait_for_idle') end
            return DoorsEvents.RecoverFixture(DB)
        end
        return DoorsContract.Ok(publisher:Status())
    end)
    if ok and result.ok and args[1]=='diagnose-fixture' then
        print('[feather-doors] outbox decoder '..result.value.decoderVersion)
        for _,row in ipairs(result.value.rows) do print('[feather-doors] outbox diagnostic '..json.encode(row)) end
        return
    end
    print('[feather-doors] outbox '..json.encode(ok and result or DoorsContract.Err('database_exception')))
end,true)
local function fail(code)
    foundation.ready=false; foundation.status=code
    print('[feather-doors] startup unavailable: '..code)
end
CreateThread(function()
    local ok,result=pcall(function()
        foundation.status='waiting_for_core'
        local core=exports['feather-core']:AwaitReady(30000)
        local caps=exports['feather-core']:GetCapabilities()
        if type(core)~='table' or core.ok~=true or type(caps)~='table' or caps.ok~=true
            or type(caps.value)~='table' or caps.value.contract~=1 then return {ok=false,code='core_unavailable'} end
        foundation.status='waiting_for_database'
        if DB.awaitReady(30000)~=true then return {ok=false,code='database_unavailable'} end
        if stopped or not dependencies() then return {ok=false,code='dependency_stopped'} end
        foundation.status='migrating'
        local migrated=DoorsSchema.Run(DB)
        if not migrated.ok then return migrated end
        local checked=DoorsSchema.Check(DB)
        if not checked.ok then return checked end
        for _,name in pairs(DoorsEvents.Names) do
            local eventName=name
            local declared=exports['feather-core']:DeclareEvent(eventName,{contract=1,maxPayloadBytes=2048,maxDepth=2,maxNodes=32,maxSubscribers=64,
                validatePayload=function(payload) return DoorsEvents.Validate(payload,eventName) end})
            if type(declared)~='table' or declared.ok~=true then return {ok=false,code='event_declaration_failed'} end
        end
        if stopped or not dependencies() then return {ok=false,code='dependency_stopped'} end
        foundation.schemaVersion=migrated.value.version
        foundation.applied=migrated.value.applied; foundation.resumed=migrated.value.resumed
        foundation.status='foundation_ready'; foundation.ready=true
        publisher.enabled=DoorsConfig.Outbox.Enabled==true
        CreateThread(function()
            while not stopped do
                if publisher.enabled and health().foundationReady then publisher:Drain() end
                Wait(1000)
            end
        end)
        print(('[feather-doors] foundation ready schema=%d applied=%d resumed=%d; player/native operations disabled'):format(
            foundation.schemaVersion,foundation.applied,foundation.resumed))
        return {ok=true}
    end)
    if not ok then fail('startup_exception'); print('[feather-doors] '..tostring(result))
    elseif not result.ok then fail(result.code) end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource=='feather-doors-api-tests' then fixtureEnabled=false end
    if resource=='feather-doors-outbox-tests' then eventFixtureEnabled=false end
    if resource=='feather-doors-access-tests' then accessFixtureEnabled=false end
    if resource=='feather-doors-service-tests' or resource=='feather-doors-service-owner-tests' then controllerFixtureEnabled=false end
    if resource=='feather-doors-property-tests' then propertyFixtureEnabled=false end
    if resource=='feather-property' then binding:Drop(); authority:Drop() end
    if resource=='feather-admin' then authority:Drop() end
    if resource=='feather-access' then access:Drop() end
    if resource=='feather-core' or resource=='feather-mysql' or resource==GetCurrentResourceName() then
        stopped=true; foundation.ready=false; foundation.status='dependency_stopped'
        publisher.enabled=false
        access:Drop()
        binding:Drop()
        authority:Drop()
    end
end)
RegisterCommand('DoorsSchemaSmokeTest',function(player,args)
    if player~=0 then return end
    if #args~=0 then print('[feather-doors] Usage: DoorsSchemaSmokeTest (server console)'); return end
    if not health().foundationReady then print('[feather-doors] schema smoke unavailable: '..foundation.status); return end
    local ok,result=pcall(DoorsSchema.Check,DB)
    if not ok then print('[feather-doors] schema smoke failed: database_exception'); return end
    print('[feather-doors] schema smoke '..(result.ok and ('PASS schema=%d tables=%d columns=%d; operational ready=false'):format(
        result.value.version,result.value.tables,result.value.columns) or ('FAIL '..result.code)))
end,true)
