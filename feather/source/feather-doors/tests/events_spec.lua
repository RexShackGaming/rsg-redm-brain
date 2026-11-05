local function copy(t)
    if type(t)~='table' then return t end
    local out={}; for k,v in pairs(t) do out[k]=copy(v) end; return out
end
local stored,nextCode={},0
json={encode=function(value) nextCode=nextCode+1; stored[tostring(nextCode)]=copy(value); return tostring(nextCode) end,
    decode=function(token) return copy(assert(stored[token],'bad JSON')),#token+1 end}
dofile('server/contract.lua'); dofile('server/events.lua')
local C,E=DoorsContract,DoorsEvents
local passed=0
local function check(ok,label) assert(ok,label); passed=passed+1 end
local payload={contract=1,eventId='22222222-2222-2222-2222-222222222222',eventType=E.Names.state,
    doorId='11111111-1111-1111-1111-111111111111',revision=2,delegationEpoch=1,
    sourceResource='test',requestId='test.state',reasonCode='test',operation='state',status='active',locked=true}
check(E.Validate(payload,E.Names.state),'bounded event validates')
local bad=copy(payload); bad.actorSource=1
check(not E.Validate(bad,E.Names.state),'unknown fields rejected')
bad=copy(payload); bad.locked=1; check(not E.Validate(bad,E.Names.state),'exact boolean required')
check(not E.Validate(payload,E.Names.definition),'channel mismatch rejected')
local function fixture(publish)
    local state={row={event_id=payload.eventId,event_type=payload.eventType,door_id=payload.doorId,source_resource=payload.sourceResource,
        request_id=payload.requestId,revision=payload.revision,payload_json=json.encode(payload),status='pending',attempts=0},ready=true,calls=0}
    local db={}
    function db.query()
        if state.row.status=='pending' then return {copy(state.row)} end
        return {}
    end
    function db.exec(sql)
        if state.failAck then state.failAck=false; error('acknowledgement unavailable') end
        state.row.attempts=state.row.attempts+1
        if sql:find("'published'",1,true) then state.row.status='published'
        elseif sql:find("'quarantined'",1,true) then state.row.status='quarantined' end
    end
    local api=E.New(db,function(name,event)
        state.calls=state.calls+1
        return publish(state,name,event)
    end,function() return state.ready end)
    return api,state
end
local api,state=fixture(function() return C.Ok({delivered=0,failed=0}) end)
state.ready=false; check(api:Drain().code=='unavailable' and state.calls==0,'unavailable denies publication')
state.ready=true; api.busy=true; check(api:Drain().code=='busy','concurrent drain refused'); api.busy=false
check(api:Drain().value.published==1 and state.row.status=='published','zero-subscriber broker acceptance recorded')
check(api:Drain().value.published==0 and state.calls==1,'published record not redispatched')
api,state=fixture(function() return C.Ok({delivered=1,failed=1}) end)
check(api:Drain().value.retried==1 and state.row.status=='pending','listener error retains pending row despite broker ok')
check(api.lastCode=='retry_pending','retry visible in health')
api,state=fixture(function() return C.Ok({failed=0}) end)
check(api:Drain().value.retried==1,'malformed broker result not success')
api,state=fixture(function() error('broker unavailable') end)
check(api:Drain().value.retried==1 and not api.busy,'broker exception is retryable')
api,state=fixture(function() error('must not publish') end); state.row.payload_json='invalid'
check(api:Drain().value.quarantined==1 and state.calls==0,'poison row quarantined without publication')
check(api.lastCode=='quarantined','quarantine visible in health')
api,state=fixture(function() error('must not publish mismatched identity') end); state.row.door_id='different'
check(api:Drain().value.quarantined==1,'row/payload identity mismatch quarantined')
api,state=fixture(function(s,_,event)
    check(event.eventId==payload.eventId,'stable event identity on acknowledgement retry')
    if s.calls==1 then s.failAck=true end
    return C.Ok({delivered=1,failed=0})
end)
check(api:Drain().code=='database_exception' and not api.busy and state.row.status=='pending','failed ack preserves retry')
check(api:Drain().value.published==1 and state.calls==2,'acknowledgement retry can duplicate publication')
api,state=fixture(function(s) s.ready=false; return C.Ok({delivered=1,failed=0}) end)
check(api:Drain().code=='unavailable' and state.row.status=='pending','dependency loss during publication does not acknowledge')
local nested
api,state=fixture(function() nested=api:Drain(); return C.Ok({delivered=1,failed=0}) end)
api:Drain(); check(nested.code=='busy','reentrant publication is bounded')

-- Execute current Core broker source, not a substitute for its failure result.
Config={}; CoreResults=C
CoreResults.Is=function(value) return type(value)=='table' and value.ok~=nil end
CoreLogging={Create=function() return {Error=function() end} end}
local owner=nil
GetCurrentResourceName=function() return 'feather-core' end
GetInvokingResource=function() return owner end
IsCallable=function(value) return type(value)=='function' end
exports=function() end; AddEventHandler=function() end; RegisterCommand=function() end
dofile('../feather-core/server/services/event_broker.lua')
owner='feather-doors'
check(CoreEventBroker.Declare(E.Names.state,{contract=1,validatePayload=function(value) return E.Validate(value,E.Names.state) end}).ok,'actual Core declaration')
owner='observer'
local failOnce=true
CoreEventBroker.Subscribe(E.Names.state,function(event) event.locked=false end)
CoreEventBroker.Subscribe(E.Names.state,function(event)
    check(event.locked==true,'actual Core isolates subscriber payload mutation')
    if failOnce then failOnce=false; error('expected one-shot listener failure') end
end)
owner='feather-doors'
api,state=fixture(function(_,name,event) return CoreEventBroker.Publish(name,event) end)
check(api:Drain().value.retried==1,'actual Core ok with failed listener remains pending')
check(api:Drain().value.published==1 and state.row.attempts==2,'actual Core listener recovery permits acknowledgement')
check(CoreEventBroker.Publish(E.Names.state,payload).ok,'actual Core publisher owner')
owner='other'; check(CoreEventBroker.Publish(E.Names.state,payload).code=='forbidden','actual Core rejects foreign publisher')
print(('PASS %d event/outbox checks'):format(passed))
