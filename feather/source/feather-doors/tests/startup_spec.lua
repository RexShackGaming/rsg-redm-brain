local passed=0
local function check(value,label) assert(value,label); passed=passed+1 end
local function boot(options)
    options=options or {}
    local state={exports={},commands={},handlers={},messages={},dependency='started',dbCalls=0}
    FeatherDoors={Name='feather-doors',Version='0.1.0-dev'}
    DoorsConfig={TrustedResources={},Outbox={Enabled=false}}
    DoorsContract={Err=function(code) return {ok=false,code=code} end}
    DoorsRepository={New=function() return {} end}
    DoorsAccess={New=function() return {registered=false,lastCode='not_registered',Drop=function() end} end}
    DoorsAuthority={New=function() return {Drop=function() end,Bump=function() end} end}
    DoorsBinding={New=function() return {Drop=function() end} end}
    DoorsEvents={Names={definition='doors.definition.changed.v1',state='doors.state.changed.v1'},
        Validate=function() return true end,New=function() return {enabled=false,busy=false,lastCode='idle'} end}
    exports=setmetatable({['feather-core']={
        AwaitReady=function() return {ok=not options.coreFailure} end,
        GetCapabilities=function() return {ok=true,value={contract=options.contract or 1}} end,
        DeclareEvent=function() return {ok=not options.eventFailure} end
    }},{__call=function(_,name,handler) state.exports[name]=handler end})
    GetResourceState=function() return state.dependency end
    GetCurrentResourceName=function() return 'feather-doors' end
    GetInvokingResource=function() return 'untrusted' end
    CreateThread=function(handler) state.thread=handler end
    AddEventHandler=function(name,handler) state.handlers[name]=handler end
    RegisterCommand=function(name,handler) state.commands[name]=handler end
    DB={awaitReady=function() return not options.dbFailure end}
    DoorsSchema={
        Run=function()
            state.dbCalls=state.dbCalls+1
            if options.exception then error('database error') end
            if options.migrationFailure then return {ok=false,code='migration_checksum_mismatch'} end
            if options.stopDuringMigration then state.handlers.onResourceStop('feather-mysql') end
            return {ok=true,value={version=1,applied=1,resumed=0}}
        end,
        Check=function() return {ok=not options.checkFailure,code='schema_tables_missing'} end
    }
    local oldPrint=print
    print=function(message) state.messages[#state.messages+1]=message end
    dofile('server/main.lua'); state.thread()
    print=oldPrint
    return state
end
local state=boot()
check(state.exports.CreateDoorGroup({}).code=='forbidden','default caller policy denies API')
check(state.exports.FindOperation({requestId='other'}).code=='forbidden','default caller policy denies receipts')
check(state.exports.CheckDoorGrantAuthority({}).code=='forbidden','authority preflight requires caller trust')
check(state.exports.GetHealth().foundationReady,'schema foundation ready')
check(state.exports.GetHealth().ready==false,'schema readiness never enables domain')
check(state.exports.GetCapabilities().schema==1 and not state.exports.GetCapabilities().doorRegistration,'only schema capability enabled')
local health=state.exports.GetHealth(); health.foundationReady=false
check(state.exports.GetHealth().foundationReady,'defensive health snapshot')
state.handlers.onResourceStop('unrelated'); check(state.exports.GetHealth().foundationReady,'unrelated resource stop ignored')
state.handlers.onResourceStop('feather-mysql'); check(not state.exports.GetHealth().foundationReady,'dependency stop latches unavailable')
state.dependency='started'; check(not state.exports.GetHealth().foundationReady,'dependency restart does not silently recover')
for _,options in ipairs({{coreFailure=true},{contract=2},{dbFailure=true}}) do
    state=boot(options)
    check(not state.exports.GetHealth().foundationReady and state.dbCalls==0,'bad dependency cannot migrate')
end
for _,options in ipairs({{migrationFailure=true},{checkFailure=true},{exception=true},{stopDuringMigration=true},{eventFailure=true}}) do
    state=boot(options)
    check(not state.exports.GetHealth().foundationReady,'startup failure never marks ready')
end
print(('PASS %d startup checks'):format(passed))
