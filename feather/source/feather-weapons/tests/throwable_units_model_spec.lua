local M=dofile('tests/models/throwable_units.lua')
local state=M.New(3)
local function apply(action,n,id,credit,verified)
    local request={action=action,quantity=n,id=id,revision=state.revision,credit=credit,originVerified=verified}
    state=assert(M.Apply(state,request));return request
end
apply('purchase',3,'paid-order')
assert(state.inventory==3 and state.carried==0)
local equip=apply('equip',3,'equip')
assert(state.inventory==0 and state.carried==3)
local replay,kind=M.Apply(state,equip)
assert(kind=='replayed' and replay.carried==3 and replay.revision==state.revision)
assert(not M.Apply(state,{action='equip',quantity=1,id='equip',revision=state.revision}),'id reuse changes quantity')
apply('throw',1,'throw-1')
assert(state.carried==2 and state.spent==1)
assert(not M.Apply(state,{action='recover',quantity=1,id='pickup',credit='throw-1',revision=state.revision}),
    'pool increase alone never proves pickup origin')
apply('recover',1,'pickup','throw-1',true)
assert(state.carried==3 and state.spent==0)
apply('throw',1,'throw-2')
assert(not M.Apply(state,{action='recover',quantity=1,id='duplicate',credit='throw-1',
    originVerified=true,revision=state.revision}),'claimed receipt cannot recover another unit')
apply('unequip',2,'put-away')
assert(state.inventory==2 and state.carried==0 and state.spent==1)
assert(not M.Apply(state,{action='throw',quantity=1,id='empty-throw',revision=state.revision}))
assert(not M.Apply(state,{action='purchase',quantity=1,id='stale-order',revision=0}))
for _,n in ipairs({-1,0,0.5,math.huge,0/0}) do
    assert(not M.Apply(state,{action='purchase',quantity=n,id='invalid',revision=state.revision}))
end
-- Enumerate small funded states and every legal carried split, including empty.
for total=1,12 do
    for carried=1,math.min(total,3) do
        local s=M.New(3)
        s=assert(M.Apply(s,{action='purchase',quantity=total,id='buy',revision=0}))
        s=assert(M.Apply(s,{action='equip',quantity=carried,id='equip',revision=1}))
        for i=1,carried do
            s=assert(M.Apply(s,{action='throw',quantity=1,id='throw-'..i,revision=s.revision}))
        end
        assert(s.carried==0 and s.inventory==total-carried and s.spent==carried)
        for i=1,carried do
            s=assert(M.Apply(s,{action='recover',quantity=1,id='recover-'..i,credit='throw-'..i,
                originVerified=true,revision=s.revision}))
        end
        assert(s.carried==carried and s.spent==0 and s.inventory+s.carried==total)
    end
end
print('Throwable unit design model PASS: paid quantities, carrying, depletion, receipt replay, unverified pickup refusal, conservation')
