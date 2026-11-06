local root = arg and arg[1] or '.'
local function copy(v)
    if type(v) ~= 'table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local docs,seq={},0
json={encode=function(v) seq=seq+1; docs[tostring(seq)]=copy(v); return tostring(seq) end,
    decode=function(v) assert(docs[v],'bad JSON'); return copy(docs[v]) end}
dofile(root..'/config.lua'); dofile(root..'/shared/results.lua')
EconomyOperators={Allowed=function() return false end,SupplyAllowed=function() return false end}
local wallet='10000000-0000-4000-8000-000000000001'
local sink='20000000-0000-4000-8000-000000000002'
local order='30000000-0000-4000-8000-000000000003'
local state, beforeLockedRead, failAfterBalance
local queries, transactions = 0, 0
local function reset()
    state={transactions={},keys={},entries={},outbox=0,next=0,accounts={
        [wallet]={account_id=wallet,account_type='wallet',owner_type='character',currency_code='dollars',status='open',posted_amount=1000},
        [sink]={account_id=sink,account_type='system_sink',owner_type='system',currency_code='dollars',status='open',posted_amount=0}}}
    beforeLockedRead=nil; failAfterBalance=false; queries=0; transactions=0
    state.accounts[wallet].owner_id='50000000-0000-4000-8000-000000000005'
    state.accounts[sink].account_type='treasury'; state.accounts[sink].owner_type='organization'
    state.accounts[sink].owner_id='60000000-0000-4000-8000-000000000006'
    state.inventory=0
end
local function query(sql,...)
    queries=queries+1
    local p={...}
    if sql:find('SELECT * FROM `economy_transactions`',1,true) and sql:find('WHERE `transaction_id`=?',1,true) then
        if sql:find('FOR UPDATE',1,true) and beforeLockedRead then beforeLockedRead(); beforeLockedRead=nil end
        return state.transactions[p[1]] and {state.transactions[p[1]]} or {}
    elseif sql:find('SELECT `account_id`,`amount`',1,true) then return state.entries[p[1]] or {}
    elseif sql:find('INSERT IGNORE INTO `economy_transactions`',1,true) then
        local key=p[6]..'|'..p[1]..'|'..p[10]
        if not state.keys[key] then
            state.next=state.next+1
            local id=('40000000-0000-4000-8000-%012d'):format(state.next)
            state.keys[key]=id
            state.transactions[id]={transaction_id=id,operation_type=p[1],status='pending',currency_code=p[2],reason_code=p[3],
                reference_type=p[4],reference_id=p[5],source_resource=p[6],actor_account_id=p[7],actor_character_id=p[8],idempotency_key=p[10],request_fingerprint=p[11]}
        end
        return {}
    elseif sql:find('AND `idempotency_key`=? FOR UPDATE',1,true) then
        local id=state.keys[p[1]..'|'..p[2]..'|'..p[3]]
        return id and {state.transactions[id]} or {}
    elseif sql:find('FROM `economy_accounts`',1,true) then return {state.accounts[p[1]],state.accounts[p[2]]}
    elseif sql:find('UPDATE `economy_balances`',1,true) then
        state.accounts[p[2]].posted_amount=p[1]
        if failAfterBalance then error('injected SQL error') end
        return {}
    elseif sql:find('INSERT INTO `economy_entries`',1,true) then
        state.entries[p[1]]={{account_id=p[2],amount=p[3]},{account_id=p[6],amount=p[7]}}; return {}
    elseif sql:find('UPDATE `economy_transactions`',1,true) then
        state.transactions[p[2]].status='committed'; state.transactions[p[2]].result_json=p[1]; return {}
    elseif sql:find('INSERT INTO `economy_outbox`',1,true) then state.outbox=state.outbox+1; return {} end
    error('unhandled SQL '..sql)
end
DB={one=function(sql,id) return state.transactions[id] end,
    transaction=function(body)
        transactions=transactions+1
        local snapshot=copy(state)
        local ok,result=pcall(body,{raw=query})
        if not ok or result~=true then state=snapshot end
        if not ok then error(result) end
        return result==true
    end}
dofile(root..'/server/services/journal.lua')
EconomyCurrencies={Get=function() return {ok=true,value={enabled=true}} end}
local buyer='50000000-0000-4000-8000-000000000005'
local organization='60000000-0000-4000-8000-000000000006'
local buyerAccount='70000000-0000-4000-8000-000000000007'
local function terms()
    return {source_resource='feather-shops',order_id=order,buyer_character_id=buyer,
        buyer_account_id=buyerAccount,quantity=3,unit_price=25,total_amount=75,currency_code='dollars'}
end
local function accounts()
    return {organizationId=organization,fromAccountId=wallet,toAccountId=sink}
end
local function stage(tx,o,a)
    return EconomyJournal.ApplyShopPayment(tx,o or terms(),a or accounts())
end
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS shared checkout '..name) end

test('payment and delivery share one owner transaction and one commit',function()
    reset();local result
    assert(DB.transaction(function(tx)
        result=stage(tx);assert(result.ok and result.meta.pendingCommit==true)
        state.inventory=state.inventory+3
        return true
    end))
    assert(transactions==1 and state.inventory==3)
    assert(state.accounts[wallet].posted_amount==925 and state.accounts[sink].posted_amount==75)
    assert(state.outbox==1 and queries==8, 'fresh payment must use eight SQL round trips')
end)

test('late capacity or delivery rejection rolls back payment journal and outbox',function()
    reset()
    assert(not DB.transaction(function(tx)
        assert(stage(tx).ok);state.inventory=3;return false
    end))
    assert(transactions==1 and state.inventory==0 and state.outbox==0 and next(state.transactions)==nil)
    assert(state.accounts[wallet].posted_amount==1000 and state.accounts[sink].posted_amount==0)
end)

test('receipt replay is two indexed queries with no balance updates',function()
    reset();local original
    assert(DB.transaction(function(tx) original=stage(tx);return original.ok end))
    queries=0
    assert(DB.transaction(function(tx)
        local replay=stage(tx);assert(replay.ok and replay.value.replayed)
        assert(replay.value.transactionId==original.value.transactionId and replay.meta.pendingCommit)
        return true
    end))
    assert(queries==2 and state.outbox==1 and state.accounts[wallet].posted_amount==925)
end)

test('changed amount cannot reuse a receipt',function()
    reset();assert(DB.transaction(function(tx) return stage(tx).ok end))
    assert(not DB.transaction(function(tx)
        local changed=terms();changed.unit_price=30;changed.total_amount=90
        assert(stage(tx,changed).code=='idempotency_conflict');return false
    end))
    assert(state.accounts[wallet].posted_amount==925 and state.outbox==1)
end)

test('changed buyer cannot read another buyer payment receipt',function()
    for _,field in ipairs({'buyer_character_id','buyer_account_id'}) do
        reset();assert(DB.transaction(function(tx) return stage(tx).ok end))
        assert(not DB.transaction(function(tx)
            local changed=terms();changed[field]='80000000-0000-4000-8000-000000000008'
            assert(stage(tx,changed).code=='idempotency_conflict');return false
        end))
        assert(state.accounts[wallet].posted_amount==925 and state.outbox==1)
    end
end)

test('locked account ownership and types are enforced before debit',function()
    local cases={{wallet,'owner_id',organization},{wallet,'owner_type','account'},
        {wallet,'account_type','bank'},{sink,'owner_id',buyer},
        {sink,'owner_type','character'},{sink,'account_type','wallet'}}
    for _,case in ipairs(cases) do
        reset();state.accounts[case[1]][case[2]]=case[3]
        assert(not DB.transaction(function(tx)
            assert(stage(tx).code=='authorization_denied');return false
        end))
        assert(state.accounts[wallet].posted_amount==1000 and state.outbox==0 and next(state.transactions)==nil)
    end
end)

test('insufficient funds and closed currency accounts do not write money',function()
    for _,case in ipairs({{'posted_amount',50,'insufficient_funds'},
        {'status','closed','account_closed'},{'currency_code','gold','currency_mismatch'}}) do
        reset();state.accounts[wallet][case[1]]=case[2]
        assert(not DB.transaction(function(tx) assert(stage(tx).code==case[3]);return false end))
        assert(state.outbox==0 and next(state.transactions)==nil)
    end
end)

test('SQL failure after debit is returned to owner for full rollback',function()
    reset();failAfterBalance=true
    assert(not DB.transaction(function(tx) local r=stage(tx);assert(not r.ok);return r.ok end))
    assert(state.accounts[wallet].posted_amount==1000 and state.outbox==0 and next(state.transactions)==nil)
    assert(transactions==1)
end)

test('invalid immutable order is rejected without any SQL',function()
    for field,value in pairs({source_resource='untrusted',order_id='bad',quantity=0,
        unit_price=-1,total_amount=1,buyer_character_id='bad',buyer_account_id='bad'}) do
        reset();local changed=terms();changed[field]=value
        assert(stage({raw=query},changed).code=='invalid_input')
        assert(queries==0 and transactions==0)
    end
    reset();assert(stage({}).code=='invalid_input' and queries==0)
end)

test('callable CFX transaction methods are supported',function()
    reset()
    local raw=setmetatable({__cfx_functionReference='test-reference'},{__call=function(_,...) return query(...) end})
    assert(DB.transaction(function() return stage({raw=raw}).ok end))
    assert(state.accounts[wallet].posted_amount==925 and transactions==1)
end)

test('no raw transaction participant is exposed through public exports',function()
    local registered={};local env=setmetatable({},{__index=_G})
    env.exports=function(name,fn) registered[name]=fn end
    env.GetInvokingResource=function() return 'untrusted' end
    assert(loadfile(root..'/server/services/api.lua','t',env))()
    assert(registered.ApplyShopPayment==nil and registered.ApplyTransfer==nil)
end)
test('scoped export derives caller and uses canonical order and accounts on supplied transaction',function()
    reset();local registered,caller={},'untrusted'
    local env=setmetatable({EconomyFoundation={GetHealth=function() return {state='ready'} end}},{__index=_G})
    env.exports=function(name,fn) registered[name]=fn end
    env.GetInvokingResource=function() return caller end
    assert(loadfile(root..'/server/services/api.lua','t',env))()
    local callbackCalls=0
    local q=setmetatable({__cfx_functionReference='bound-query'},{__call=function(_,sql,p)
        callbackCalls=callbackCalls+1
        if sql:find('FROM shop_orders o',1,true) then
            assert(sql:find('LOCK IN SHARE MODE',1,true))
            local o=terms();o.organization_id=organization;return {o}
        end
        if sql:find('SELECT account_id,account_type,owner_type,owner_id',1,true) then
            return {state.accounts[wallet],state.accounts[sink]}
        end
        return query(sql,table.unpack(p,1,p.n or #p))
    end})
    assert(registered.StageShopCheckoutPayment(q,order).code=='authorization_denied' and callbackCalls==0)
    caller='feather-shops'
    assert(registered.StageShopCheckoutPayment(q,order).code=='authorization_denied' and callbackCalls==0)
    caller='feather-inventory'
    assert(registered.StageShopCheckoutPayment(q,'bad').code=='invalid_input' and callbackCalls==0)
    assert(DB.transaction(function()
        local result=registered.StageShopCheckoutPayment(q,order)
        assert(result.ok and result.meta.pendingCommit)
        return true
    end))
    assert(transactions==1 and callbackCalls==10 and state.accounts[wallet].posted_amount==925)
end)
test('scoped export refuses unavailable commerce before any monetary SQL',function()
    local ready,orderFound,includeWallet=true,true,true
    local registered={}
    local env=setmetatable({EconomyFoundation={GetHealth=function() return {state=ready and 'ready' or 'booting'} end}},{__index=_G})
    env.exports=function(name,fn) registered[name]=fn end
    env.GetInvokingResource=function() return 'feather-inventory' end
    assert(loadfile(root..'/server/services/api.lua','t',env))()
    local calls=0
    local function q(sql,p)
        calls=calls+1
        if sql:find('FROM shop_orders o',1,true) then
            if not orderFound then return {} end
            local o=terms();o.organization_id=organization;return {o}
        end
        if sql:find('SELECT account_id,account_type,owner_type,owner_id',1,true) then
            return includeWallet and {state.accounts[wallet],state.accounts[sink]} or {state.accounts[sink]}
        end
        error('monetary SQL should not run')
    end
    reset();ready=false
    assert(registered.StageShopCheckoutPayment(q,order).code=='not_ready' and calls==0)
    ready=true;orderFound=false
    assert(registered.StageShopCheckoutPayment(q,order).code=='checkout_unavailable' and calls==1)
    orderFound=true;includeWallet=false;calls=0
    assert(registered.StageShopCheckoutPayment(q,order).code=='invalid_input' and calls==2)
    assert(transactions==0 and state.accounts[wallet].posted_amount==1000 and state.outbox==0)
end)
print(('%d shared checkout scenarios passed; live cross-resource acceptance pending'):format(count))
