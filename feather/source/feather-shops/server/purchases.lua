local Ok,Err=ShopService.Ok,ShopService.Err
ShopPurchases={}
local active,permits={},{}
local legacy=false
local function Normalize(result)
    if type(result)~='table' then return Err('checkout_pending','Checkout is awaiting automatic readback.') end
    if result.ok==true then return result end
    local error=type(result.error)=='table' and result.error or result
    return Err(error.code or 'checkout_pending',error.message or 'Checkout is awaiting automatic readback.',error.details)
end
local function Pending(orderId)
    return Err('checkout_pending','Checkout is awaiting automatic readback.',{orderId=orderId,safeToClear=false})
end
local function Order(id)
    if not ShopService.Uuid(id) then return nil end
    local order=DB.one("SELECT * FROM shop_orders WHERE order_id=? AND source_resource='feather-shops'",id)
    if order then for _,key in ipairs({'quantity','definition_id','unit_price','total_amount'}) do order[key]=tonumber(order[key]) end end
    return order
end
function ShopPurchases.Start()
    local available,economy=pcall(function() return exports['feather-economy']:GetCapabilities() end)
    if not available or type(economy)~='table' or not economy.ok or type(economy.value)~='table'
        or type(economy.value.features)~='table' or economy.value.features.atomicShopPayment~=1 then
        return Err('dependency_unavailable','Compatible atomic Economy payment contract required.')
    end
    local contract=exports['feather-inventory']:GetShopCheckoutContract()
    if type(contract)~='table' or contract.contractVersion~=1 or not contract.ready
        or not contract.atomicPaymentDelivery or not contract.recoveryFence then
        return Err('dependency_unavailable','Atomic Inventory checkout contract required.')
    end
    local tables=DB.query([[SELECT table_name AS name FROM information_schema.tables
        WHERE table_schema=DATABASE() AND table_name IN ('shop_order_executions','shop_order_compensations')]]) or {}
    if #tables==0 and DB.value([[SELECT id FROM shop_schema_migrations
        WHERE id IN ('003_shop_order_executions','004_shop_order_compensations') LIMIT 1]]) then
        return Err('legacy_orders_need_review','Previous checkout tables are missing; retain migration and payment evidence.')
    end
    if #tables>0 then
        if #tables~=2 then return Err('legacy_orders_need_review','Incomplete previous checkout schema; retain payment evidence.') end
        legacy=true
        local unresolved=DB.one([[SELECT e.order_id FROM shop_order_executions e
            LEFT JOIN shop_order_compensations c ON c.order_id=e.order_id
            WHERE (e.state IN ('payment_pending','paid') AND (c.state IS NULL OR c.state<>'refunded'))
                OR c.state IN ('cancellation_pending','refund_pending') LIMIT 1]])
        if unresolved then return Err('legacy_orders_need_review','Previous checkout has an unresolved payment; retain its evidence.',{orderId=unresolved.order_id}) end
    end
    local schema=[[CREATE TABLE IF NOT EXISTS shop_checkout_attempts (
        order_id CHAR(36) NOT NULL,
        state VARCHAR(16) NOT NULL DEFAULT 'pending',
        result_json LONGTEXT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY(order_id),KEY idx_shop_checkout_pending(state,updated_at,order_id),
        CONSTRAINT fk_shop_checkout_order FOREIGN KEY(order_id) REFERENCES shop_orders(order_id),
        CONSTRAINT chk_shop_checkout_state CHECK(state IN ('pending','resolved'))
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
    local hash=2166136261
    for i=1,#schema do hash=((hash~schema:byte(i))*16777619)&0xffffffff end
    local checksum=('fnv1a32:%08x'):format(hash)
    local stored=DB.value('SELECT checksum FROM shop_schema_migrations WHERE id=?','006_atomic_checkout')
    if stored and stored~=checksum then return Err('migration_checksum_mismatch','Atomic checkout migration changed.') end
    if not stored then
        DB.exec(schema)
        DB.insert('INSERT INTO shop_schema_migrations (id,checksum) VALUES (?,?)','006_atomic_checkout',checksum)
    end
    return Ok({applied=stored and 0 or 1})
end
local function Wallet(characterId, currency)
    local found = exports['feather-economy']:FindAccountsByOwner({ ownerType = 'character', ownerId = characterId })
    if type(found) ~= 'table' or not found.ok then return found or Err('dependency_unavailable', 'Wallet lookup failed.') end
    for _, account in ipairs(found.value) do
        if account.currency == currency and account.accountType == 'wallet' then
            if account.status ~= 'open' then return Err('account_closed', 'Buyer wallet is closed.') end
            return Ok(account)
        end
    end
    local ensured = exports['feather-economy']:EnsureCharacterWallets({ characterId = characterId })
    if type(ensured) ~= 'table' or not ensured.ok then return ensured or Err('dependency_unavailable', 'Wallet provisioning failed.') end
    for _, account in ipairs(ensured.value) do
        if account.currency == currency and account.accountType == 'wallet' and account.status == 'open' then return Ok(account) end
    end
    return Err('account_not_found', 'Buyer currency wallet missing.')
end
local function Attempt(id)
    return DB.one('SELECT state,result_json FROM shop_checkout_attempts WHERE order_id=?',id)
end
local function Saved(row)
    if not row or row.state~='resolved' then return nil end
    local decoded,result=pcall(json.decode,row.result_json)
    if not decoded or type(result)~='table' or type(result.ok)~='boolean' then
        return Err('checkout_receipt_invalid','Checkout receipt needs inspection.')
    end
    if result.ok then result.value.replayed=true end
    return result
end
local function Terminal(result)
    return result.ok==true or (result.code=='checkout_not_committed'
        and type(result.details)=='table' and result.details.safeToClear==true)
end
local function Save(id,result)
    -- Economic truth already lives in the atomic Inventory receipt. If updating
    -- this polling index fails, the next readback safely finds the same outcome.
    local saved=pcall(DB.exec,[[UPDATE shop_checkout_attempts SET state='resolved',result_json=?
        WHERE order_id=? AND state='pending']],json.encode(result),id)
    if not saved then print('[feather-shops] checkout outcome retained; index refresh pending order='..id) end
    if result.ok then
        print(('[feather-shops] checkout confirmed order=%s transaction=%s total=%s currency=%s'):format(
            id,tostring(result.value.transactionId),tostring(result.value.total),tostring(result.value.currency)))
    end
    return result
end
function ShopPurchases.RecoverPurchase(id,originalFailure)
    local attempt=Attempt(id)
    if not attempt then return Err('checkout_not_accepted','No checkout attempt was accepted.') end
    local saved=Saved(attempt);if saved then return saved end
    local called,result=pcall(function() return exports['feather-inventory']:ResolveShopCheckout(id) end)
    result=called and Normalize(result) or Pending(id)
    if Terminal(result) then
        if not result.ok and originalFailure and originalFailure.ok==false
            and originalFailure.code~='checkout_pending' and originalFailure.code~='transaction_outcome_unknown' then
            result=Err(originalFailure.code,originalFailure.message,{safeToClear=true,orderId=id})
        end
        return Save(id,result)
    end
    return Pending(id)
end
local function Historical(order)
    if not legacy then return nil end
    local row=DB.one([[SELECT e.*,c.state AS compensation_state FROM shop_order_executions e
        LEFT JOIN shop_order_compensations c ON c.order_id=e.order_id WHERE e.order_id=?]],order.order_id)
    if not row then return nil end
    if row.compensation_state=='refunded' or row.state=='rejected' then
        return Err('checkout_not_committed','Previous order is closed.',{safeToClear=true})
    end
    if row.state=='fulfilled' and row.payment_transaction_id then
        return Ok({orderId=order.order_id,state='fulfilled',transactionId=row.payment_transaction_id,replayed=true})
    end
    return Err('legacy_orders_need_review','Previous payment needs inspection.')
end
function ShopPurchases.Status(id)
    if legacy then
        local order=Order(id)
        if not order then return Pending(id) end
        local historical=Historical(order);if historical then return historical end
    end
    local attempt=Attempt(id)
    local saved=Saved(attempt);if saved then return saved end
    if not attempt then
        local called=pcall(DB.exec,'INSERT IGNORE INTO shop_checkout_attempts (order_id) VALUES (?)',id)
        if not called then return Pending(id) end
    end
    return ShopPurchases.RecoverPurchase(id)
end
local function Current(permit,order)
    if not permit or not ShopService.IsReady() then return false end
    for _,key in ipairs({'order_id','source_resource','quote_id','buyer_account_id','buyer_character_id',
        'buyer_session_id','shop_id','offer_id','item_name','definition_id','quantity','currency_code',
        'unit_price','total_amount','catalog_revision'}) do
        if order[key]~=permit.order[key] then return false end
    end
    return ShopQuotes.Current(order.quote_id,permit.source,permit.quote)==true
end
exports('ValidateCheckoutPermit',function(id,order)
    return GetInvokingResource()=='feather-inventory' and type(order)=='table' and Current(permits[id],order)
end)
local function Coordinate(order,source)
    local session=exports['feather-core']:GetSessionContext(source)
    if type(session)~='table' or not session.ok or session.value.characterId~=order.buyer_character_id
        or session.value.accountId~=order.buyer_account_id then return Err('session_expired','Current order buyer required.') end
    local function Bound()
        return exports['feather-core']:IsSessionCurrent(source,session.value.sessionId,order.buyer_character_id)==true
    end
    local attempt=Attempt(order.order_id)
    if not Bound() then return Err('session_expired','Buyer session changed.') end
    if attempt then return Saved(attempt) or ShopPurchases.RecoverPurchase(order.order_id) end
    local historic=Historical(order);if historic then return historic end
    -- Prepare already validated the quoted catalog. Definition, currency and
    -- business are revalidated under checkout locks, so do not repeat their
    -- preflight database reads here.
    local quote=ShopQuotes.Capture(order.quote_id,source)
    if not quote.ok then quote.details={safeToClear=true,purchaseState='not_accepted'};return quote end
    if quote.value.sessionId~=order.buyer_session_id then return Err('session_expired','Original quote session required.') end
    local wallet=Wallet(order.buyer_character_id,order.currency_code)
    if not wallet or not wallet.ok then return wallet or Err('dependency_unavailable','Wallet unavailable.') end
    local treasury=ShopOrganizations.Settlement(order.shop_id,order.currency_code)
    if not treasury or not treasury.ok then return treasury or Err('dependency_unavailable','Treasury unavailable.') end
    -- Provisioning may yield. Check ephemeral terms again without opening an
    -- unrelated SQL transaction while Inventory owns the physical checkout.
    local permit={source=source,order=ShopService.Copy(order),quote=quote.value}
    if not Bound() or not Current(permit,order) then return Err('quote_expired','Quote or buyer changed.') end
    local claimed=false
    local executed,committed=pcall(DB.transaction,function(tx)
        local inserted=tx.raw('INSERT IGNORE INTO shop_checkout_attempts (order_id) VALUES (?)',order.order_id)
        claimed=inserted and tonumber(inserted.affectedRows or inserted.affected_rows)==1
        return true
    end)
    if not executed or committed~=true then return Pending(order.order_id) end
    if not claimed then return ShopPurchases.RecoverPurchase(order.order_id) end
    local permitId=order.order_id
    permits[permitId]=permit
    local called,result=pcall(function() return exports['feather-inventory']:CheckoutShopOrder(order.order_id,source,permitId) end)
    permits[permitId]=nil
    result=called and Normalize(result) or Pending(order.order_id)
    if result.ok then return Save(order.order_id,result) end
    return ShopPurchases.RecoverPurchase(order.order_id,result)
end
function ShopPurchases.Purchase(id,source)
    if not ShopService.IsReady() then return Err('not_ready','Shops is not ready.') end
    if active[id] then return Pending(id) end
    if not ShopService.Uuid(id) then return Err('invalid_input','Order UUID required.') end
    active[id]=true -- acquire before the first database yield
    local called,result=xpcall(function()
        local order=Order(id)
        if not order then return Err('order_not_found','Order not found.') end
        return Coordinate(order,source)
    end,debug.traceback)
    permits[id]=nil;active[id]=nil
    if not called then
        print('[feather-shops] checkout readback pending order='..id)
        return Pending(id)
    end
    return result
end
function ShopPurchases.IsActive(id) return active[id]==true end
RegisterCommand('ShopPurchaseState',function(source,args)
    if source~=0 then return end
    if not ShopService.IsReady() or not ShopService.Uuid(args[1]) then print('[ShopPurchaseState] supply order UUID');return end
    print('[ShopPurchaseState] '..json.encode(Attempt(args[1]) or {state='not_accepted'}))
end,true)
