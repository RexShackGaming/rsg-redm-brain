-- Runs inside Inventory's real Tx/capacity fixture. All four production resource
-- modules are loaded in separate environments with caller-bound export proxies.
-- SQL and engine authority are modeled; this does not establish live CFX locks.
return function(h)
    local inventoryRoot,shopRoot,economyRoot,weaponsRoot=arg[1],arg[2],arg[3],arg[4]
    local registry,caller,sqlState,source,session,threads,handlers,envs,quote,now,fault,offline,translations,languages
    local copy=h.copy
    local cases=0
    local function test(name,fn) h.test(name,fn);cases=cases+1 end
    local inventoryQuery=h.query
    local function ExportSurface(owner)
        return setmetatable({},{__call=function(_,name,fn) registry[owner][name]=fn end,
            __index=function(_,target)
                return setmetatable({},{__index=function(_,method)
                    return function(_,...)
                        local fn=assert(registry[target] and registry[target][method],target..':'..method..' missing')
                        local previous=caller;caller=owner
                        local result=table.pack(pcall(fn,...));caller=previous
                        if not result[1] then error(result[2]) end
                        return table.unpack(result,2,result.n)
                    end
                end})
            end})
    end
    local function SQL(sql,p)
        sqlState.queries=(sqlState.queries or 0)+1
        if offline then error({code="DATABASE_UNAVAILABLE",outcome="unknown"}) end
        if sql:find('FROM information_schema.tables',1,true) then
            if sqlState.legacyPartial then return {{name='shop_order_executions'}} end
            if sqlState.legacyExecution then return {{name='shop_order_executions'},{name='shop_order_compensations'}} end
            return {}
        end
        if sql:find('FROM shop_order_executions e',1,true) then
            local row=sqlState.legacyExecution
            if sql:find('SELECT e.order_id',1,true) then return row and row.state=='paid' and {copy(row)} or {} end
            return row and {copy(row)} or {}
        end
        if sql:find('FROM shop_schema_migrations',1,true) then
            if sqlState.legacyMissingTables and sql:find('003_shop_order_executions',1,true) then
                return {{id='003_shop_order_executions'}}
            end
            return {}
        end
        if sql:find('CREATE TABLE',1,true) or sql:find('INSERT INTO shop_schema_migrations',1,true) then return {affectedRows=1} end
        if sql=='SELECT UUID()' then sqlState.uuid=sqlState.uuid+1;return {{uuid=('90000000-0000-4000-8000-%012d'):format(sqlState.uuid)}} end
        if sql:find('INSERT IGNORE INTO shop_checkout_request_fences',1,true) then
            if not sqlState.fences[p[1]] then
                sqlState.fences[p[1]]={request_id=p[1],quote_id=p[2],buyer_account_id=p[3],buyer_character_id=p[4],state='open'}
            end
            return {affectedRows=1}
        end
        if sql:find('FROM shop_checkout_request_fences',1,true) then
            local row=sqlState.fences[p[1]];return row and {copy(row)} or {}
        end
        if sql:find("UPDATE shop_checkout_request_fences SET state='closed'",1,true) then
            sqlState.fences[p[1]].state='closed';return {affectedRows=1}
        end
        if sql:find('INSERT IGNORE INTO `shop_orders`',1,true) then
            for _,row in pairs(sqlState.orders) do if row.request_id==p[3] then return {affectedRows=0} end end
            local fields={'order_id','source_resource','request_id','quote_id','buyer_account_id','buyer_character_id',
                'buyer_session_id','shop_id','offer_id','item_name','definition_id','quantity','currency_code','unit_price','total_amount','catalog_revision','pack_size'}
            local row={status='prepared'};for i,key in ipairs(fields) do row[key]=p[i] end
            sqlState.orders[row.order_id]=row;h.setOrder(copy(row));return {affectedRows=1}
        end
        if sql:find('FROM shop_orders o',1,true) then
            local order=sqlState.orders[p[1]]
            if not order or not sqlState.businessActive then return {} end
            order=copy(order);order.organization_id=sqlState.organization;return {order}
        end
        if sql:find('FROM `shop_orders`',1,true) or sql:find('FROM shop_orders',1,true) then
            local row
            if sql:find('request_id',1,true) then
                local key=p[#p];for _,candidate in pairs(sqlState.orders) do if candidate.request_id==key then row=candidate end end
            else row=sqlState.orders[p[1]] end
            return row and {copy(row)} or {}
        end
        if sql:find('INSERT IGNORE INTO shop_checkout_attempts',1,true) then
            local fresh=sqlState.attempts[p[1]]==nil
            if fresh then sqlState.attempts[p[1]]={order_id=p[1],state='pending'} end
            return {affectedRows=fresh and 1 or 0}
        end
        if sql:find('FROM shop_checkout_attempts',1,true) then
            if sql:find("state='pending'",1,true) then
                local out={};for id,row in pairs(sqlState.attempts) do if row.state=='pending' then out[#out+1]={order_id=id} end end
                return out
            end
            local row=sqlState.attempts[p[1]];return row and {copy(row)} or {}
        end
        if sql:find("UPDATE shop_checkout_attempts SET state='resolved'",1,true) then
            local row=sqlState.attempts[p[2]]
            if row and row.state=='pending' then row.state='resolved';row.result_json=p[1] end
            return {affectedRows=1}
        end
        if sql:find('UPDATE shop_checkout_attempts SET updated_at',1,true) then return {affectedRows=1} end
        if sql:find('SELECT id,name,type,instance_mode FROM items',1,true) then
            local d=h.definitions()[1];return d.name==p[1] and {copy(d)} or {}
        end
        if sql:find('SELECT name,type,instance_mode FROM items',1,true) then return {copy(h.definitions()[p[1]])} end
        if sql:find('SELECT account_id,account_type,owner_type,owner_id FROM economy_accounts',1,true) then
            return {copy(sqlState.accounts[sqlState.wallet]),copy(sqlState.accounts[sqlState.treasury])}
        end
        if sql:find('INSERT IGNORE INTO `economy_transactions`',1,true) then
            local key=p[6]..'|'..p[1]..'|'..p[10]
            if not sqlState.payments[key] then sqlState.payments[key]={transaction_id='80000000-0000-4000-8000-000000000008',
                actor_account_id=p[7],actor_character_id=p[8],request_fingerprint=p[11],status='pending'} end
            return {affectedRows=1}
        end
        if sql:find('FROM `economy_transactions`',1,true) then
            local row=sqlState.payments[p[1]..'|'..p[2]..'|'..p[3]];return row and {copy(row)} or {}
        end
        if sql:find('FROM `economy_accounts`',1,true) then return {copy(sqlState.accounts[p[1]]),copy(sqlState.accounts[p[2]])} end
        if sql:find('UPDATE `economy_balances`',1,true) then
            sqlState.debits=sqlState.debits+1;sqlState.accounts[p[2]].posted_amount=p[1];return {affectedRows=1}
        end
        if sql:find('INSERT INTO `economy_entries`',1,true) then sqlState.entries=sqlState.entries+2;return {affectedRows=2} end
        if sql:find('UPDATE `economy_transactions`',1,true) then
            for _,row in pairs(sqlState.payments) do if row.transaction_id==p[2] then row.status='committed';row.result_json=p[1] end end
            return {affectedRows=1}
        end
        if sql:find('INSERT INTO `economy_outbox`',1,true) then sqlState.outbox=sqlState.outbox+1;return {affectedRows=1} end
        if sql:find('INSERT INTO `feather_weapon_events`',1,true) then
            sqlState.provenance=sqlState.provenance+1
            if sqlState.failProvenance then error('injected provenance SQL failure') end
            return {affectedRows=1,insertId=sqlState.provenance}
        end
        return inventoryQuery(sql,p)
    end
    local db={
        one=function(sql,...) local rows=SQL(sql,table.pack(...));return rows and rows[1] end,
        query=function(sql,...) return SQL(sql,table.pack(...)) end,
        exec=function(sql,...) return SQL(sql,table.pack(...)) end,
        raw=function(sql,...) return SQL(sql,table.pack(...)) end,
        insert=function(sql,...) return SQL(sql,table.pack(...)).insertId end,
        value=function(sql,...)
            local rows=SQL(sql,table.pack(...));if not rows or not rows[1] then return nil end
            for _,value in pairs(rows[1]) do return value end
        end,
        transaction=function(body)
            local snapshot=copy(sqlState)
            local beforeDebits=sqlState.debits
            local beforeQueries=sqlState.queries or 0
            local ok,result=pcall(h.owner,function(tx)
                tx.exec=tx.raw;tx.query=tx.raw
                return body(tx)
            end)
            if not ok or result~=true then sqlState=snapshot end
            if not ok then error(result) end
            if result==true and sqlState.debits>beforeDebits then
                sqlState.economicTransactions=(sqlState.economicTransactions or 0)+1
                sqlState.economicSqlCalls=sqlState.queries-beforeQueries
            end
            if result==true and fault and sqlState.debits>beforeDebits then
                local kind=fault;fault=nil
                if kind=='offline_after_commit' then offline=true end
                error({code='BRIDGE_TIMEOUT',outcome='unknown'})
            end
            return result
        end
    }
    local function Env(owner)
        local e=setmetatable({},{__index=_G});e._G=e;e.exports=ExportSurface(owner)
        e.GetInvokingResource=function() return caller end;e.DB=db
        e.CreateThread=function(fn) threads[#threads+1]={owner=owner,fn=fn} end
        e.AddEventHandler=function() end;e.RegisterCommand=function() end
        e.GetGameTimer=function() return 1000 end
        e.os=setmetatable({time=function() return now end},{__index=os})
        envs[owner]=e;return e
    end
    local function Load(e,root,path) assert(loadfile(root..'/'..path,'t',e))() end
    local function Setup(weapon,package)
        h.setup(weapon)
        registry={['feather-core']={},['feather-inventory']={},['feather-economy']={},['feather-weapons']={},['feather-shops']={}}
        caller=nil;threads={};handlers={};envs={};now=os.time();fault=nil;offline=false;translations={};languages={}
        source=99;local o=h.order()
        session={accountId=o.buyer_account_id,characterId=o.buyer_character_id,sessionId=o.buyer_session_id}
        sqlState={uuid=0,orders={},fences={},attempts={},accounts={},payments={},debits=0,entries=0,outbox=0,provenance=0,businessActive=true,
            organization='60000000-0000-4000-8000-000000000006',wallet='10000000-0000-4000-8000-000000000001',
            treasury='20000000-0000-4000-8000-000000000002'}
        sqlState.accounts[sqlState.wallet]={account_id=sqlState.wallet,owner_type='character',owner_id=session.characterId,
            account_type='wallet',currency_code='dollars',status='open',posted_amount=1000}
        sqlState.accounts[sqlState.treasury]={account_id=sqlState.treasury,owner_type='organization',owner_id=sqlState.organization,
            account_type='treasury',currency_code='dollars',status='open',posted_amount=0}
        h.setQuery(SQL);DB.transaction=db.transaction
        registry['feather-core'].GetSessionContext=function() return {ok=true,value=copy(session)} end
        registry['feather-core'].IsSessionCurrent=function(src,id,cid) return src==source and id==session.sessionId and cid==session.characterId end
        registry['feather-core'].RegisterLocale=function(locale,values)
            translations[locale]=translations[locale] or {};for k,v in pairs(values) do translations[locale][k]=v end
            return {ok=true}
        end
        registry['feather-core'].TranslateLocale=function(src,key,...)
            local locale=languages[src] or 'en';local value=(translations[locale] or {})[key]
            return {ok=true,value=value and string.format(value,...) or ('Translation ['..locale..']['..key..'] does not exist')}
        end
        registry['feather-core'].RegisterRpc=function(name,fn) handlers[name]=fn;return {ok=true} end
        local inv=Env('feather-inventory');inv.InventoryReadiness={state='ready'}
        Load(inv,inventoryRoot,'server/services/shop_checkout_exports.lua')
        local eco=Env('feather-economy')
        Load(eco,economyRoot,'config.lua');Load(eco,economyRoot,'shared/results.lua')
        eco.EconomyFoundation={GetHealth=function() return {state='ready'} end,GetCapabilities=function() return {ok=true,value={features={atomicShopPayment=1}}} end}
        eco.EconomyOperators={Allowed=function() return false end,SupplyAllowed=function() return false end}
        eco.EconomyCurrencies={Get=function() return {ok=true,value={enabled=sqlState.currencyEnabled~=false,precision=2}} end}
        Load(eco,economyRoot,'server/services/journal.lua');Load(eco,economyRoot,'server/services/api.lua')
        registry['feather-economy'].FindAccountsByOwner=function(request)
            local rows={};for _,a in pairs(sqlState.accounts) do if a.owner_id==request.ownerId then rows[#rows+1]={accountId=a.account_id,
                ownerId=a.owner_id,ownerType=a.owner_type,accountType=a.account_type,currency=a.currency_code,status=a.status,balance=a.posted_amount} end end
            return {ok=true,value=rows}
        end
        registry['feather-economy'].GetCurrency=function() return {ok=true,value={enabled=true,precision=2}} end
        if weapon then
            local w=Env('feather-weapons');w.Config={DevMode=false,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
                CharacterAmmoTransportEnabled=true,AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
            for _,path in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
                'shared/validation.lua','shared/character_ammunition_item.lua'}) do Load(w,weaponsRoot,path) end
            w.WeaponResult={Ok=function(v) return {ok=true,value=v} end,Error=function(c,m) return {ok=false,error={code=c,message=m}} end}
            w.WeaponErrors={AUTHORIZATION_INVALID='denied',ITEM_INVALID='invalid',OPERATION_CONFLICT='conflict'}
            w.CoreAdapter={NormalizeCharacterId=function(v) return type(v)=='string' and v end,
                IsSessionCurrent=registry['feather-core'].IsSessionCurrent,
                ResolveSession=function(src) return registry['feather-core'].GetSessionContext(src) end}
            w.WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity={characterId=session.characterId,
                sessionId=session.sessionId,epoch='epoch'}} end}
            w.WeaponCharacterAmmoInventoryProvider={Status=function() return 'ready' end}
            w.WeaponCharacterAmmoPolicy={Build=function() return {weapons={revolver_cattleman={}}} end}
            w.WeaponNativeEquipmentBindings={IsStopping=function() return false end}
            w.DefinitionRegistry={ValidateAttachmentSet=function() return w.WeaponResult.Ok(true) end}
            w.GetResourceState=function() return 'stopped' end
            Load(w,weaponsRoot,'server/services/metadata.lua');Load(w,weaponsRoot,'server/services/provenance.lua')
            w.WeaponProvenanceService.Start()
            Load(w,weaponsRoot,'server/services/issuance.lua');Load(w,weaponsRoot,'server/services/shop_purchases.lua')
            h.definitions()[1].name='weapon_revolver_cattleman'
        end
        local shop=Env('feather-shops');Load(shop,shopRoot,'config.lua')
        local catalog={id=o.shop_id,organizationId=sqlState.organization,position={x=0,y=0,z=0},offers={
            {id=o.offer_id,itemName=h.definitions()[1].name,currency='dollars',unitPrice=25,maximumQuantity=10}}}
        if package then
            catalog.offers[1].packSize=package.size;catalog.offers[1].unitPrice=package.price
            catalog.offers[1].maximumQuantity=math.floor(100/package.size)
        end
        shop.ShopService={Ok=function(v) return {ok=true,value=v} end,Err=function(c,m,d) return {ok=false,code=c,message=m,details=d} end,
            Copy=copy,IsReady=function() return true end,GetCatalog=function() return {ok=true,value=copy(catalog)} end,
            RegisterDevCommand=function() end,Uuid=function(v) return type(v)=='string' and #v==36 end,
            Integer=function(v,min,max) return type(v)=='number' and v%1==0 and v>=min and v<=max end}
        shop.ShopOrganizations={CheckCommerce=function() return {ok=sqlState.businessActive} end,
            Settlement=function() return {ok=true,value={accountId=sqlState.treasury}} end}
        shop.GetPlayerPed=function() return 1 end;shop.DoesEntityExist=function() return true end
        shop.GetEntityCoords=function() return {x=0,y=0,z=0} end
        Load(shop,shopRoot,'shared/localization.lua')
        Load(shop,shopRoot,'server/quotes.lua');Load(shop,shopRoot,'server/orders.lua')
        Load(shop,shopRoot,'server/purchases.lua');Load(shop,shopRoot,'server/player_routes.lua')
        assert(shop.ShopPurchases.Start().ok)
        assert(shop.ShopPlayerRoutes.Start().ok)
        local quoted=shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,
            quantity=package and (package.boxes or 1) or (weapon and 1 or 3)},source)
        assert(quoted.ok,quoted.message)
        quote={quoteId=quoted.value.id,requestId='ui:'..quoted.value.id}
        return shop,catalog
    end
    local function Purchase() return handlers['shops.purchase.v1'](copy(quote),source) end
    local function Status() return handlers['shops.purchase.status.v1'](copy(quote),source) end
    test('four-resource ordinary purchase charges and delivers once through real RPC modules',function()
        Setup(false);local result=Purchase();assert(result.ok,result.message)
        assert(result.value.state=='fulfilled' and #h.rows()==4 and sqlState.accounts[sqlState.wallet].posted_amount==925)
        assert(sqlState.entries==2 and sqlState.outbox==1 and sqlState.debits==2)
        assert(Purchase().ok and Status().ok and sqlState.debits==2 and #h.rows()==4)
    end)
    test('four-resource canonical firearm has one payment and provenance in the same commit',function()
        Setup(true);local result=Purchase();assert(result.ok,result.message)
        assert(#h.rows()==2 and sqlState.provenance==1 and sqlState.accounts[sqlState.wallet].posted_amount==975)
        assert(Status().ok and sqlState.provenance==1 and sqlState.debits==2)
    end)
    test('four-resource insufficient funds rolls back firearm provenance and delivery',function()
        Setup(true);sqlState.accounts[sqlState.wallet].posted_amount=0
        local result=Purchase();assert(not result.ok and result.code=='insufficient_funds' and result.details.safeToClear)
        assert(#h.rows()==1 and sqlState.provenance==0 and sqlState.debits==0 and sqlState.entries==0)
        assert(not Status().ok and sqlState.debits==0)
    end)
    test('four-resource provenance SQL failure cannot charge or grant',function()
        Setup(true);sqlState.failProvenance=true
        local result=Purchase();assert(not result.ok and result.details.safeToClear)
        assert(#h.rows()==1 and sqlState.provenance==0 and sqlState.debits==0)
    end)
    test('status before the original RPC fences the request without any mutation replay',function()
        Setup(false);local result=Status()
        assert(not result.ok and result.details.safeToClear and result.details.purchaseState=='not_accepted')
        assert(not Purchase().ok and #h.rows()==1 and sqlState.debits==0)
    end)
    test('status closes a prepared order and refuses a late original purchase',function()
        local shop=Setup(false)
        assert(shop.ShopOrders.Prepare(copy(quote),source,'feather-shops').ok)
        assert(Status().details.safeToClear)
        assert(not Purchase().ok and #h.rows()==1 and sqlState.debits==0)
    end)
    test('different character cannot inspect or close a saved purchase',function()
        Setup(false);local result=Purchase();assert(result.ok)
        session.characterId='ffffffff-ffff-4fff-8fff-ffffffffffff'
        local other=Status();assert(not other.ok and not (other.details and other.details.safeToClear))
        assert(sqlState.debits==2 and #h.rows()==4)
    end)
    test('lost economic commit reply resolves automatically without another charge',function()
        Setup(true);fault='lose_commit_reply'
        local result=Purchase();assert(result.ok,result.message)
        assert(sqlState.debits==2 and sqlState.provenance==1 and #h.rows()==2 and #h.events()==0)
        assert(Status().ok and sqlState.debits==2 and sqlState.provenance==1)
    end)
    test('database outage after commit recovers by status readback without economic replay',function()
        Setup(true);fault='offline_after_commit'
        local result=Purchase();assert(not result.ok and not (result.details and result.details.safeToClear))
        assert(sqlState.debits==2 and #h.rows()==2 and sqlState.provenance==1)
        offline=false
        assert(Status().ok and sqlState.debits==2 and sqlState.provenance==1 and #h.rows()==2)
    end)
    test('expired quote closes its request before a saved request is abandoned',function()
        Setup(false);now=now+60
        local result=Purchase();assert(not result.ok and result.details.safeToClear)
        assert(sqlState.debits==0 and #h.rows()==1)
        assert(not Purchase().ok and sqlState.debits==0)
    end)
    test('ordinary checkout cannot bypass the one-firearm quantity limit',function()
        local shop,catalog=Setup(true)
        assert(not shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,quantity=2},source).ok)
        assert(sqlState.debits==0 and #h.rows()==1)
    end)
    test('scoped exports reject other callers before accepting query or permit authority',function()
        Setup(true);caller='untrusted'
        local function noSql() error('untrusted query executed') end
        assert(not registry['feather-economy'].StageShopCheckoutPayment(noSql,h.order().order_id).ok)
        assert(not registry['feather-inventory'].CheckoutShopOrder(h.order().order_id,source,'forged').ok)
        assert(not registry['feather-weapons'].PrepareShopCheckoutWeapon(source,h.order()).ok)
        assert(not registry['feather-shops'].ValidateCheckoutPermit('forged',h.order()))
        caller=nil;assert(sqlState.debits==0 and #h.rows()==1)
    end)
    test('selected language changes affect stored rejection responses with English fallback',function()
        Setup(false);sqlState.accounts[sqlState.wallet].posted_amount=0
        local result=Purchase();assert(result.code=='insufficient_funds' and result.message:find('enough money',1,true))
        languages[source]='es'
        result=Status();assert(result.message:find('enough money',1,true),'missing requested dictionary must fall back to English')
        translations.es={ui_shops_error_insufficient_funds='Saldo insuficiente.'}
        result=Status();assert(result.message=='Saldo insuficiente.')
        assert(sqlState.debits==0 and #h.rows()==1)
    end)
    test('background worker resolves committed purchases while both clients are absent',function()
        local shop=Setup(true);fault='offline_after_commit';assert(not Purchase().ok)
        offline=false;session={}
        shop.Wait=function(ms) return coroutine.yield(ms) end
        local first=#threads
        Load(shop,shopRoot,'server/reconciliation.lua')
        local worker=coroutine.create(threads[first+1].fn)
        assert(coroutine.resume(worker))
        assert(coroutine.resume(worker))
        local attempt=next(sqlState.attempts);assert(sqlState.attempts[attempt].state=='resolved')
        assert(sqlState.debits==2 and sqlState.provenance==1 and #h.rows()==2)
    end)
    test('real client polls only the status RPC and clears its saved request after recovery',function()
        Setup(false);fault='offline_after_commit';assert(not Purchase().ok);offline=false
        registry['shops-client']={}
        local client=Env('shops-client');client.GlobalState={['feather-shops:ready']=true}
        client.joaat=function() return 1 end
        local saved=json.encode(copy(quote));local cleared=false;local calls={}
        client.GetResourceKvpString=function() return saved end
        client.DeleteResourceKvp=function() cleared=true end
        client.Wait=function(ms) return coroutine.yield(ms) end
        registry['feather-core'].CallRPCAsync=function(route,request)
            calls[#calls+1]=route;return handlers[route](request,source)
        end
        Load(client,shopRoot,'shared/localization.lua')
        local first=#threads
        Load(client,shopRoot,'client/shop.lua')
        local poll=coroutine.create(threads[first+1].fn)
        assert(coroutine.resume(poll));assert(coroutine.resume(poll))
        -- Async schedules the readback separately from the polling coroutine.
        threads[#threads].fn()
        assert(cleared and #calls==1 and calls[1]=='shops.purchase.status.v1')
        assert(sqlState.debits==2 and #h.rows()==4)
    end)
    test('unresolved previous paid orders block startup without cleanup or replay',function()
        local shop=Setup(false);sqlState.legacyExecution={state='paid',order_id=h.order().order_id}
        assert(shop.ShopPurchases.Start().code=='legacy_orders_need_review')
        assert(sqlState.legacyExecution.state=='paid' and sqlState.debits==0 and #h.rows()==1)
    end)
    test('completed previous orders remain historical receipts without a second delivery',function()
        local shop=Setup(false)
        local order=shop.ShopOrders.Prepare(copy(quote),source,'feather-shops');assert(order.ok)
        sqlState.legacyExecution={state='fulfilled',order_id=order.value.id,payment_transaction_id='old-payment'}
        assert(shop.ShopPurchases.Start().ok)
        assert(Purchase().ok and Status().ok and sqlState.debits==0 and #h.rows()==1)
    end)
    test('partial previous schema blocks startup instead of silently repairing evidence',function()
        local shop=Setup(false);sqlState.legacyPartial=true
        assert(shop.ShopPurchases.Start().code=='legacy_orders_need_review' and sqlState.debits==0)
    end)
    test('settled status uses two indexed reads and no new transaction or monetary writes',function()
        Setup(false);assert(Purchase().ok)
        local previous=sqlState.queries;local economic=sqlState.economicTransactions
        assert(Status().ok and sqlState.queries-previous==2)
        assert(sqlState.economicTransactions==economic and economic==1 and sqlState.debits==2)
    end)
    test('ordinary quantity growth keeps atomic checkout SQL calls bounded',function()
        Setup(false);assert(Purchase().ok);local small=sqlState.economicSqlCalls
        local shop,catalog=Setup(false);catalog.offers[1].maximumQuantity=100
        local q=shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,quantity=100},source);assert(q.ok)
        quote={quoteId=q.value.id,requestId='ui:'..q.value.id}
        sqlState.accounts[sqlState.wallet].posted_amount=10000
        assert(Purchase().ok and #h.rows()==101)
        assert(sqlState.economicSqlCalls==small and small<=35 and sqlState.economicTransactions==1)
        print(('PASS checkout SQL budget: %d atomic calls for both 3 and 100 ordinary items; one economic transaction'):format(small))
    end)
    test('incompatible Economy is rejected at startup before purchases are accepted',function()
        local shop=Setup(false)
        registry['feather-economy'].GetCapabilities=function() return {ok=true,value={features={}}} end
        assert(shop.ShopPurchases.Start().code=='dependency_unavailable' and sqlState.debits==0)
    end)
    test('currency disabled before the locked payment check rolls back delivery',function()
        Setup(false);sqlState.currencyEnabled=false
        local result=Purchase();assert(not result.ok and result.details.safeToClear)
        assert(sqlState.debits==0 and sqlState.entries==0 and #h.rows()==1)
    end)
    test('client-supplied prices are refused before order acceptance',function()
        Setup(false);local request=copy(quote);request.total=1
        local result=handlers['shops.purchase.v1'](request,source)
        assert(not result.ok and result.code=='invalid_input' and sqlState.debits==0 and next(sqlState.orders)==nil)
    end)
    test('reusing a request key with another quote cannot charge again',function()
        local shop,catalog=Setup(false);assert(Purchase().ok)
        local second=shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,quantity=1},source);assert(second.ok)
        quote.quoteId=second.value.id
        local result=Purchase();assert(not result.ok and result.code=='idempotency_conflict')
        assert(sqlState.debits==2 and #h.rows()==4)
    end)
    test('current player source IDs above 65535 remain supported',function()
        local shop,catalog=Setup(false);source=70000
        local q=shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,quantity=1},source);assert(q.ok)
        quote={quoteId=q.value.id,requestId='ui:'..q.value.id}
        assert(Purchase().ok and sqlState.debits==2 and #h.rows()==2)
    end)
    test('previous migration evidence with missing tables blocks startup',function()
        local shop=Setup(false);sqlState.legacyMissingTables=true
        assert(shop.ShopPurchases.Start().code=='legacy_orders_need_review' and sqlState.debits==0)
    end)
    test('general store no longer maintains a duplicate firearm price',function()
        local shop,catalog=Setup(true)
        local offers=shop.Config.Shops[1].offers
        assert(#offers==1 and offers[1].unitPrice==100 and offers[1].itemName=='consumable_apple')
        assert(shop.Config.WeaponStoresEnabled==true)
    end)
    test('50-round box charges exact 62 cents and replay conserves all 50 rounds',function()
        Setup(false,{size=50,price=62})
        local result=Purchase();assert(result.ok,result.message)
        assert(result.value.quantity==1 and result.value.packSize==50 and result.value.itemQuantity==50)
        assert(#h.rows()==51 and sqlState.accounts[sqlState.wallet].posted_amount==938)
        assert(Status().ok and Purchase().ok and #h.rows()==51 and sqlState.debits==2)
    end)
    test('two boxes deliver 100 rounds at exact box prices within the same SQL budget',function()
        Setup(false,{size=50,price=62});assert(Purchase().ok);local small=sqlState.economicSqlCalls
        Setup(false,{size=50,price=62,boxes=2})
        local result=Purchase();assert(result.ok,result.message)
        assert(#h.rows()==101 and result.value.itemQuantity==100 and result.value.total==124)
        assert(sqlState.accounts[sqlState.wallet].posted_amount==876 and sqlState.debits==2)
        assert(sqlState.economicSqlCalls==small and small<=35 and sqlState.economicTransactions==1)
    end)
    test('persisted package quantity cannot diverge from its authorized quote',function()
        local shop=Setup(false,{size=50,price=62})
        local prepared=shop.ShopOrders.Prepare(copy(quote),source,'feather-shops');assert(prepared.ok)
        sqlState.orders[prepared.value.id].pack_size=1
        local result=Purchase();assert(not result.ok and #h.rows()==1 and sqlState.debits==0)
    end)
    test('boxed insufficient funds rolls back payment and every round',function()
        Setup(false,{size=25,price=50});sqlState.accounts[sqlState.wallet].posted_amount=49
        local result=Purchase();assert(not result.ok and result.code=='insufficient_funds')
        assert(#h.rows()==1 and sqlState.debits==0 and Status().details.safeToClear)
    end)
    test('lost boxed checkout reply recovers original delivery without replaying mutation',function()
        Setup(false,{size=20,price=45});fault='offline_after_commit'
        assert(not Purchase().ok and #h.rows()==21 and sqlState.debits==2)
        offline=false;local result=Status();assert(result.ok and result.value.itemQuantity==20)
        assert(#h.rows()==21 and sqlState.accounts[sqlState.wallet].posted_amount==955 and sqlState.debits==2)
    end)
    test('changed pack size invalidates quote and excessive boxes or client pack fields are refused',function()
        local shop,catalog=Setup(false,{size=50,price=62})
        assert(not shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,quantity=3},source).ok)
        assert(not shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,quantity=1,packSize=1},source).ok)
        catalog.offers[1].packSize=25
        assert(not Purchase().ok and #h.rows()==1 and sqlState.debits==0)
    end)
    test('catalog label resolver selects each locale with English fallback and leaves canonical data intact',function()
        local shop,catalog=Setup(false,{size=50,price=62})
        catalog.label='Gun Store';catalog.offers[1].label='Regular cartridges'
        shop.ShopService.ListShops=function() return {ok=true,value={{id=catalog.id}}} end
        languages[source]='es'
        translations.es={['ui_shops_store_'..catalog.id]='Armeria',
            ['ui_shops_item_'..catalog.offers[1].itemName]='Cartuchos'}
        assert(shop.ShopCatalogText(source,'ui_shops_store_'..catalog.id,catalog.label)=='Armeria')
        assert(shop.ShopCatalogText(source,'ui_shops_item_'..catalog.offers[1].itemName,catalog.offers[1].label)=='Cartuchos')
        languages[source]='missing'
        local result=handlers['shops.catalog.v1']({},source)
        assert(result.value[1].label=='Gun Store' and result.value[1].offers[1].label=='Regular cartridges')
        assert(shop.ShopCatalogText(source,'ui_shops_store_'..catalog.id,catalog.label)=='Gun Store')
        assert(catalog.label=='Gun Store' and catalog.offers[1].label=='Regular cartridges')
    end)
    test('actual store client groups offers and reviews boxes plus exact delivered rounds',function()
        local shop,catalog=Setup(false,{size=50,price=62})
        catalog.label='Gun Store';catalog.offers[1].label='Regular cartridges';catalog.offers[1].category='ammunition'
        shop.ShopService.ListShops=function() return {ok=true,value={{id=catalog.id}}} end
        registry['shops-client']={};registry['feather-menu-v2']={};registry['feather-toolkit']={}
        local client=Env('shops-client');client.GlobalState={['feather-shops:ready']=true}
        client.joaat=function() return 1 end;client.GetResourceKvpString=function() end
        client.Wait=function(ms) return coroutine.yield(ms) end
        client.PlayerPedId=function() return 1 end;client.IsEntityDead=function() return false end
        local vectorMT={__sub=function() return setmetatable({}, {__len=function() return 0 end}) end}
        client.vector3=function() return setmetatable({},vectorMT) end
        client.GetEntityCoords=function() return client.vector3() end
        registry['feather-core'].AwaitReady=function() return {ok=true} end
        registry['feather-core'].CallRPCAsync=function(route,request)
            if route=='shops.wallets.v1' then return {ok=true,value={}} end
            return handlers[route](request,source)
        end
        local menu,toolkit=registry['feather-menu-v2'],registry['feather-toolkit']
        local pages,current,lifecycle={},nil,nil
        menu.CreateMenu=function(options) assert(options.position.x=='3%' and options.position.y=='3%' and options.position.anchor=='top-left' and options.draggable==false);return {ok=true,value={menuId='test'}} end
        menu.CreatePage=function() local id=#pages+1;pages[id]={};return {ok=true,value={pageId=id}} end
        menu.DestroyPage=function() return {ok=true} end
        menu.AddElement=function(_,page,kind,settings,callback)
            pages[page][#pages[page]+1]={kind=kind,settings=settings,callback=callback};return {ok=true,value={elementId=#pages[page]}}
        end
        menu.UpdateElement=function(_,page,id,changes) pages[page][id].settings.busy=changes.busy;return {ok=true} end
        menu.RegisterMenuLifecycle=function(_,callback) lifecycle=callback;return {ok=true} end
        menu.OpenMenu=function(_,options) current=options.pageId;lifecycle({event='opened'});return {ok=true} end
        menu.CloseMenu=function() return {ok=true} end
        toolkit.ResolveControl=function() return {ok=true,value=1} end
        toolkit.CreatePrompt=function() return {ok=true,value={id=1}} end
        toolkit.ShowPromptGroup=function() end
        toolkit.IsPromptCompleted=function() return {ok=true,value={completed=true}} end
        Load(client,shopRoot,'shared/localization.lua')
        local first=#threads;Load(client,shopRoot,'client/shop.lua')
        local startup=coroutine.create(threads[first+2].fn);assert(coroutine.resume(startup))
        threads[#threads].fn()
        local function click(label)
            for _,element in ipairs(pages[current]) do
                if element.settings.label==label then element.callback();return end
            end
            error('missing button '..label)
        end
        click('Ammunition');threads[#threads].fn()
        click('Other ammunition');threads[#threads].fn()
        local offerButton
        for _,element in ipairs(pages[current]) do if element.settings.label=='Regular cartridges' then offerButton=element end end
        assert(offerButton.settings.description=='50 rounds / $0.62' and offerButton.settings.busy==false)
        click('Regular cartridges')
        local found=false
        for _,element in ipairs(pages[current]) do
            if element.kind=='number' then assert(element.settings.label=='Boxes' and element.settings.max==2);found=true end
        end
        assert(found)
        click('Review price')
        for _,element in ipairs(pages[current]) do if element.kind=='button' then assert(element.settings.busy==true) end end
        threads[#threads].fn()
        found=false
        for _,element in ipairs(pages[current]) do if element.settings.value=='Rounds delivered: 50' then found=true end end
        assert(found and sqlState.debits==0 and #h.rows()==1,'review must not mutate payment or delivery')
    end)
    test('closed business refuses a fresh quote',function()
        local shop,catalog=Setup(false);sqlState.businessActive=false
        assert(not shop.ShopQuotes.Create({shopId=catalog.id,offerId=catalog.offers[1].id,quantity=1},source).ok)
        assert(sqlState.debits==0 and #h.rows()==1)
    end)
    return cases
end
