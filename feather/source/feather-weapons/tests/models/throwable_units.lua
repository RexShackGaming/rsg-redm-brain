-- Executable design model, NOT a runtime authority or a database adapter.
-- Purchased units have exactly one location: inventory, carried, or spent.
-- A native carrier/GUID is presentation only and contributes no unit.
local M={}
local function integer(v) return type(v)=='number' and v>=0 and v%1==0 and v<math.huge end
local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
function M.New(capacity)
    assert(integer(capacity) and capacity>0)
    return {revision=0,inventory=0,carried=0,purchased=0,spent=0,capacity=capacity,receipts={}}
end
function M.Apply(state,request)
    if type(state)~='table' or type(request)~='table' or type(request.id)~='string' or request.id=='' then
        return nil,'invalid_request'
    end
    local old=state.receipts[request.id]
    if old then
        if old.action~=request.action or old.quantity~=request.quantity or old.credit~=request.credit then
            return nil,'receipt_conflict'
        end
        -- Replay is a read of the committed outcome, never another mutation.
        return copy(state),'replayed'
    end
    if request.revision~=state.revision then return nil,'stale_revision' end
    local n=request.quantity
    if not integer(n) or n<1 then return nil,'invalid_quantity' end
    local nextState=copy(state)
    if request.action=='purchase' then
        -- Production adapter must commit payment + these units + receipt together.
        nextState.inventory=state.inventory+n;nextState.purchased=state.purchased+n
    elseif request.action=='equip' then
        if n>state.inventory or state.carried+n>state.capacity then return nil,'quantity_unavailable' end
        nextState.inventory=state.inventory-n;nextState.carried=state.carried+n
    elseif request.action=='unequip' then
        if n>state.carried then return nil,'quantity_unavailable' end
        nextState.inventory=state.inventory+n;nextState.carried=state.carried-n
    elseif request.action=='throw' then
        if n>state.carried then return nil,'quantity_unavailable' end
        nextState.carried=state.carried-n;nextState.spent=state.spent+n
    elseif request.action=='recover' then
        local credit=state.receipts[request.credit]
        -- Only a trusted adapter may establish origin/session eligibility.
        -- This model deliberately does not infer it from proximity or pool gain.
        if not credit or credit.action~='throw' or credit.claimed or credit.quantity~=n
            or request.originVerified~=true or state.carried+n>state.capacity then
            return nil,'recovery_unverified'
        end
        nextState.receipts[request.credit].claimed=true
        nextState.spent=state.spent-n;nextState.carried=state.carried+n
    else return nil,'unsupported_action' end
    nextState.revision=state.revision+1
    nextState.receipts[request.id]={action=request.action,quantity=n,credit=request.credit}
    assert(nextState.inventory+nextState.carried+nextState.spent==nextState.purchased,'unit conservation')
    return nextState,'committed'
end
return M
