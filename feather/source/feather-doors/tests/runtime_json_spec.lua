-- Supply the installed FXServer citizen/scripting/lua/json.lua as argument1.
local path=assert(arg[1],'Supply FXServer json.lua path')
json=dofile(path)
dofile('server/contract.lua'); dofile('server/events.lua')
local C,E=DoorsContract,DoorsEvents
local passed=0
local function check(ok,label) assert(ok,label); passed=passed+1 end
local payload={contract=1,eventId='22222222-2222-2222-2222-222222222222',eventType=E.Names.definition,
    doorId='11111111-1111-1111-1111-111111111111',revision=1,delegationEpoch=1,
    sourceResource='feather-doors-outbox-tests',requestId='doors-outbox-v1.create',reasonCode='test',operation='create',status='active',locked=true}
local text=json.encode(payload)
local decoded=json.decode(text)
check(getmetatable(decoded)~=nil,'installed decoder reproduces object metadata')
check(not E.Validate(decoded,E.Names.definition),'original strict plain-data check reproduces live rejection')
local plain=E.Decode(text)
check(type(plain)=='table' and getmetatable(plain)==nil,'persistence decoder opts out of metadata')
check(E.Validate(plain,E.Names.definition),'actual JSON roundtrip validates after normalization')
check(not E.Decode(text..'garbage'),'trailing garbage refused')
check(E.Decode(text..' \n')~=nil,'trailing whitespace allowed')
check(not E.Decode('not json') and not E.Decode('null'),'malformed/scalar JSON refused')
check(not E.Decode(string.rep(' ',2049)),'oversized stored JSON refused')
local row={event_id=payload.eventId,door_id=payload.doorId,source_resource=payload.sourceResource,
    request_id=payload.requestId,event_type=payload.eventType,revision=1,payload_json=text,status='quarantined',attempts=1,
    receipt_result_json=json.encode(C.Ok({doorId=payload.doorId,revision=1,delegationEpoch=1,status='active',locked=true}))}
check(E.Matches(row,plain),'installed JSON payload matches stored identity')
local rows={}; for i,operation in ipairs({'create','update','state','retire'}) do
    local r={}; for k,v in pairs(row) do r[k]=v end
    r.event_id=('22222222-2222-2222-2222-%012d'):format(i)
    r.request_id='doors-outbox-v1.'..operation
    local p=E.Decode(text); p.eventId=r.event_id; p.requestId=r.request_id; p.operation=operation
    p.eventType=operation=='state' and E.Names.state or E.Names.definition
    r.event_type=p.eventType; r.payload_json=json.encode(p); rows[i]=r
end
local writes,commit=0,false
local db={transaction=function(callback)
    local tx={query=function(sql,caller,...)
        check(caller=='feather-doors-outbox-tests' and select('#',...)==4,'recovery is exact fixture scope')
        return rows
    end,exec=function(sql,eventId)
        for _,r in ipairs(rows) do if r.event_id==eventId then r.status='pending'; writes=writes+1 end end
    end}
    commit=callback(tx); return commit
end}
local result=E.RecoverFixture(db)
check(result.ok and result.value.requeued==4 and writes==4 and commit,'four valid existing facts requeued')
check(rows[1].attempts==1 and rows[1].payload_json~=nil,'attempt history and payload retained')
result=E.RecoverFixture(db)
check(result.ok and result.value.requeued==0 and writes==4,'recovery retry is idempotent')
rows[1].payload_json=text:gsub('"locked":true','"locked":false')
check(not E.RecoverFixture(db).ok and not commit,'receipt mismatch refuses recovery')
row.status='pending'
local publisher=E.New({query=function() return row.status=='pending' and {row} or {} end,
    exec=function(_,eventId) check(eventId==payload.eventId,'actual JSON event acknowledgement identity'); row.status='published' end},
    function(name,event)
        check(getmetatable(event)==nil and E.Validate(event,name),'publisher uses plain actual-runtime JSON payload')
        return C.Ok({delivered=1,failed=0})
    end,function() return true end)
check(publisher:Drain().value.published==1 and row.status=='published','installed JSON publisher roundtrip succeeds')
local diagnostics=E.DiagnoseFixture({query=function() return rows end,exec=function() error('diagnostic must not write') end})
check(diagnostics.ok and #diagnostics.value.rows==4,'read-only fixture diagnostics cover four existing rows')
check(diagnostics.value.rows[2].validPayload and diagnostics.value.rows[2].matches.eventId,'diagnostics identify actual JSON field/identity validity')
-- Reproduce the live rapidjson compatibility behavior: metadata remains even
-- when extra dkjson-style nil arguments are supplied.
local originalDecode=json.decode
json.decode=function(input,...)
    local value,position,err=originalDecode(input)
    return value,position,err
end
local rapidLike=E.Decode(text)
check(rapidLike and getmetatable(rapidLike)==nil and E.Validate(rapidLike,E.Names.definition),
    'metadata-ignoring decoder normalized without weakening schema')
local hostile=setmetatable({},{__pairs=function() error('must not run JSON metatable hooks') end})
json.decode=function(input) return hostile,#input+1 end
check(E.Decode('{}')~=nil,'normalization uses raw iteration instead of metadata hooks')
hostile.loop=hostile
check(E.Decode('{}')==nil,'cyclic decoder data rejected')
json.decode=originalDecode
print(('PASS %d installed-runtime JSON/recovery checks'):format(passed))
