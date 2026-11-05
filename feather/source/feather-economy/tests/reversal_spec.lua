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
local function reset()
    state={transactions={},keys={},entries={},outbox=0,next=0,accounts={
        [wallet]={account_id=wallet,account_type='wallet',owner_type='character',currency_code='dollars',status='open',posted_amount=1000},
        [sink]={account_id=sink,account_type='system_sink',owner_type='system',currency_code='dollars',status='open',posted_amount=0}}}
    beforeLockedRead=nil; failAfterBalance=false
end
local function query(sql,...)
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
                reference_type=p[4],reference_id=p[5],source_resource=p[6],idempotency_key=p[10],request_fingerprint=p[11]}
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
        local snapshot=copy(state)
        local ok,result=pcall(body,{raw=query})
        if not ok or result~=true then state=snapshot end
        if not ok then error(result) end
        return result==true
    end}
dofile(root..'/server/services/journal.lua')
local function pay(reason,resource,refType)
    return EconomyJournal.Transfer({fromAccountId=wallet,toAccountId=sink,amount=75,currency='dollars',
        reasonCode=reason or 'stables.horse_purchase',referenceType=refType or 'stables_order',referenceId=order,
        idempotencyKey='purchase-1'}, {resource=resource or 'bcc-stables'})
end
local function reverse(id,resource,extra)
    local req={transactionId=id}; if extra then req.amount=1 end
    return EconomyJournal.ReversePayment(req,{resource=resource or 'bcc-stables'})
end
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS reversal '..name) end
test('horse and tack payments reverse once with original accounts and amounts',function()
    for _,reason in ipairs({'stables.horse_purchase','stables.tack_purchase'}) do
        reset(); local paid=pay(reason); assert(paid.ok,paid.code)
        assert(state.accounts[wallet].posted_amount==925)
        local refunded=reverse(paid.value.transactionId); assert(refunded.ok,refunded.code)
        assert(refunded.value.amount==75 and refunded.value.toAccountId==wallet and refunded.value.fromAccountId==sink)
        assert(refunded.value.reasonCode=='stables.payment_reversal' and state.accounts[wallet].posted_amount==1000)
        dofile(root..'/server/services/journal.lua')
        local replay=reverse(paid.value.transactionId); assert(replay.ok and replay.value.replayed)
        assert(state.accounts[wallet].posted_amount==1000 and state.outbox==2)
    end
end)
test('player tack trade capture refunds once under its exact scope',function()
    reset();local paid=pay('stables.tack_trade_payment','bcc-stables','stables_tack_trade');assert(paid.ok,paid.code)
    local refunded=reverse(paid.value.transactionId);assert(refunded.ok,refunded.code)
    assert(refunded.value.reasonCode=='stables.tack_trade_refund' and state.accounts[wallet].posted_amount==1000)
    assert(reverse(paid.value.transactionId).value.replayed)
    assert(EconomyJournal.MayPost('issue','bcc-stables','stables.tack_trade_sale'))
    assert(not EconomyJournal.MayPost('issue','bcc-stables','unrelated.reward'))
end)
test('existing shop reversal and replay are preserved',function()
    reset(); local paid=pay('shop.purchase','feather-shops','shop_order'); assert(paid.ok)
    assert(reverse(paid.value.transactionId,'feather-shops').value.reasonCode=='shop.payment_reversal')
    assert(reverse(paid.value.transactionId,'feather-shops').value.replayed)
end)
test('existing shop configuration without additional reversal scopes still works',function()
    reset(); local scopes=Config.ReversiblePayments; Config.ReversiblePayments=nil
    local paid=pay('shop.purchase','feather-shops','shop_order'); assert(paid.ok)
    assert(reverse(paid.value.transactionId,'feather-shops').ok)
    Config.ReversiblePayments=scopes
end)
test('caller scope reference and original transfer status are enforced',function()
    for _,field in ipairs({'source_resource','reason_code','reference_type','reference_id','operation_type','status'}) do
        reset(); local paid=pay(); assert(paid.ok)
        local row=state.transactions[paid.value.transactionId]
        row[field]=field=='source_resource' and 'feather-shops' or 'unsupported'
        assert(reverse(paid.value.transactionId).code=='reversal_not_allowed')
        assert(state.accounts[wallet].posted_amount==925)
    end
    reset(); local paid=pay('shop.purchase','bcc-stables','shop_order'); assert(paid.ok)
    assert(reverse(paid.value.transactionId).code=='reversal_not_allowed')
end)
test('untrusted caller and caller supplied refund amount are refused',function()
    reset(); local paid=pay(); assert(paid.ok)
    assert(reverse(paid.value.transactionId,'untrusted').code=='authorization_denied')
    assert(reverse(paid.value.transactionId,nil,true).code=='invalid_input')
    assert(reverse(order).code=='reversal_not_allowed')
end)
test('locked original is revalidated and ledger mismatch cannot refund',function()
    reset(); local paid=pay(); assert(paid.ok)
    beforeLockedRead=function() state.transactions[paid.value.transactionId].reference_type='wrong' end
    assert(reverse(paid.value.transactionId).code=='reversal_not_allowed')
    reset(); paid=pay(); state.entries[paid.value.transactionId][1].amount=-1
    assert(reverse(paid.value.transactionId).code=='internal_error' and state.accounts[wallet].posted_amount==925)
end)
test('failed refund rolls back balances receipts and outbox',function()
    reset(); local paid=pay(); assert(paid.ok); failAfterBalance=true
    assert(not reverse(paid.value.transactionId).ok)
    assert(state.accounts[wallet].posted_amount==925 and state.outbox==1)
    failAfterBalance=false; assert(reverse(paid.value.transactionId).ok and state.accounts[wallet].posted_amount==1000)
end)
test('public refund export derives caller instead of trusting context resource',function()
    reset(); local paid=pay(); assert(paid.ok)
    local registered,caller={},'untrusted'
    local env=setmetatable({},{__index=_G})
    env.exports=function(name,fn) registered[name]=fn end
    env.GetInvokingResource=function() return caller end
    assert(loadfile(root..'/server/services/api.lua','t',env))()
    assert(registered.ReversePayment({transactionId=paid.value.transactionId},{resource='bcc-stables'}).code=='authorization_denied')
    caller='bcc-stables'
    assert(registered.ReversePayment({transactionId=paid.value.transactionId},{resource='feather-shops'}).ok)
end)
test('startup rejects malformed reversal scopes and advertises the feature',function()
    for _,bad in ipairs({'not-a-table', {['bcc-stables']={bad_reason={referenceType='stables_order',reversalReason='stables.refund'}}},
        {['bcc-stables']={['stables.horse_purchase']={referenceType='',reversalReason='stables.refund'}}}}) do
        local env=setmetatable({},{__index=_G})
        env.Config=copy(Config); env.Config.ReversiblePayments=bad
        env.GetCurrentResourceName=function() return 'feather-economy' end
        env.GetResourceMetadata=function() return 'test' end
        env.EconomyLogging={Create=function() return {Info=function() end,Error=function() end} end}
        assert(loadfile(root..'/server/services/foundation.lua','t',env))()
        assert(env.EconomyFoundation.BeginStartup().code=='invalid_config')
        assert(env.EconomyFoundation.GetCapabilities().value.features.scopedPaymentReversals==1)
    end
end)
print(('%d reversal scenarios passed (mocked SQL; live concurrency pending)'):format(count))
