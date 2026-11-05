ShopOrganizations={}
local Ok,Err=ShopService.Ok,ShopService.Err
local links={}
local schema=[[CREATE TABLE IF NOT EXISTS `shop_organization_links` (
    `shop_id` CHAR(36) NOT NULL, `organization_id` CHAR(36) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`shop_id`), KEY `idx_shop_organization` (`organization_id`),
    CONSTRAINT `fk_shop_organization_location` FOREIGN KEY (`shop_id`) REFERENCES `shop_locations` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
function ShopOrganizations.GetId(shopId) return links[shopId] end
function ShopOrganizations.Settlement(shopId,currency,orderId)
    -- Stored intent fixes the destination permanently, including old sink orders.
    if orderId then
        local execution=DB.one('SELECT `to_account_id` FROM `shop_order_executions` WHERE `order_id`=?',orderId)
        if execution then return exports['feather-economy']:GetAccount({accountId=execution.to_account_id}) end
    end
    local id=links[shopId]
    if not ShopService.Uuid(id) then return Err('dependency_unavailable','Business treasury identity unavailable.') end
    -- Checkout is a read when the treasury already exists; no repeated write locks.
    -- Commerce eligibility is independently checked before accepting new intent.
    local found=exports['feather-economy']:FindAccountsByOwner({ownerType='organization',ownerId=id})
    if type(found)~='table' or not found.ok then return found or Err('dependency_unavailable','Treasury lookup failed.') end
    for _,account in ipairs(found.value) do
        if account.currency==currency and account.accountType=='treasury' and account.ownerType=='organization'
            and account.ownerId==id and ShopService.Uuid(account.accountId) then
            if account.status~='open' then return Err('account_closed','Business treasury is closed.') end
            return Ok(account)
        end
    end
    local ensured=exports['feather-economy']:EnsureOrganizationTreasuries({organizationId=id})
    if type(ensured)~='table' or not ensured.ok then return ensured or Err('dependency_unavailable','Treasury provisioning failed.') end
    for _,account in ipairs(ensured.value) do
        if account.currency==currency and account.accountType=='treasury' and account.ownerType=='organization'
            and account.ownerId==id and account.status=='open' and ShopService.Uuid(account.accountId) then return Ok(account) end
    end
    return Err('account_not_found','Business currency treasury unavailable.')
end
function ShopOrganizations.CommerceState(result,id)
    if type(result)~='table' or result.ok~=true or type(result.value)~='table'
        or result.value.organizationId~=id or result.value.organizationType~='business' then
        return Err('dependency_unavailable','Shop organization identity is unavailable.')
    end
    if result.value.status~='active' then return Err('organization_inactive','This business is not currently open for new purchases.') end
    return Ok(true)
end
function ShopOrganizations.CheckCommerce(shopId)
    local id=links[shopId]
    if not ShopService.Uuid(id) then return Err('dependency_unavailable','Shop organization link is unavailable.') end
    local called,result=pcall(function() return exports['feather-organizations']:GetOrganization({organizationId=id}) end)
    if not called then return Err('dependency_unavailable','Organizations lookup failed.') end
    return ShopOrganizations.CommerceState(result,id)
end
function ShopOrganizations.Start()
    local hash=2166136261
    for index=1,#schema do hash=((hash~schema:byte(index))*16777619)&0xffffffff end
    local checksum=('fnv1a32:%08x'):format(hash)
    local stored=DB.value('SELECT checksum FROM shop_schema_migrations WHERE id=?','005_shop_organization_links')
    if stored and stored~=checksum then return Err('migration_checksum_mismatch','Shop organization link migration changed.') end
    if not stored then
        DB.exec(schema)
        DB.insert('INSERT INTO shop_schema_migrations (id,checksum) VALUES (?,?)','005_shop_organization_links',checksum)
    end
    local resolved={}
    for _,shop in ipairs(Config.Shops) do
        local identity=shop.organization
        local created=exports['feather-organizations']:CreateOrganization({requestId='shop-organization:'..shop.id,
            organizationType='business',organizationKey=identity.key,legalName=identity.legalName,displayName=identity.displayName,
            reasonCode='shops.bootstrap'})
        if type(created)~='table' or not created.ok then return Err('organization_provision_failed','Shop organization creation failed.',{shopId=shop.id,code=type(created)=='table' and created.code}) end
        local id=created.value.organizationId
        if not ShopService.Uuid(id) then return Err('invalid_dependency_result','Organizations returned an invalid UUID.') end
        local activated=exports['feather-organizations']:ChangeOrganizationStatus({organizationId=id,expectedRevision=1,status='active',
            requestId='shop-organization-activate:'..shop.id,reasonCode='shops.bootstrap'})
        if type(activated)~='table' or not activated.ok then return Err('organization_provision_failed','Shop organization activation failed.',{shopId=shop.id,code=type(activated)=='table' and activated.code}) end
        local current=exports['feather-organizations']:GetOrganization({organizationId=id})
        if type(current)~='table' or not current.ok or current.value.organizationType~='business' or current.value.organizationKey~=identity.key then
            return Err('invalid_dependency_result','Canonical shop organization did not resolve.')
        end
        resolved[shop.id]=id
    end
    local failure
    local committed=DB.transaction(function(tx)
        for _,shop in ipairs(Config.Shops) do
            tx.exec('INSERT IGNORE INTO shop_organization_links (shop_id,organization_id) VALUES (?,?)',shop.id,resolved[shop.id])
            local rows=tx.query('SELECT organization_id FROM shop_organization_links WHERE shop_id=? FOR UPDATE',shop.id) or {}
            if not rows[1] or rows[1].organization_id~=resolved[shop.id] then
                failure=Err('organization_link_conflict','Existing shop organization link cannot be rebound.',{shopId=shop.id});return false
            end
        end
        return true
    end)
    if committed~=true then return failure or Err('transaction_failed','Shop organization links did not commit.') end
    links=resolved
    return Ok({applied=stored and 0 or 1})
end
ShopService.RegisterDevCommand('ShopOrganizationContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        assert(ShopService.IsReady(),'Shop service not ready')
        local tests={}
        local function Check(label,good) tests[#tests+1]={label,good==true} end
        local ready=exports['feather-organizations']:AwaitReady(0)
        Check('organizations ready',ready.ok)
        local count=tonumber(DB.value('SELECT COUNT(*) FROM shop_organization_links l JOIN shop_locations s ON s.shop_id=l.shop_id WHERE s.enabled=1'))
        Check('links persisted',count==#Config.Shops)
        for _,shop in ipairs(Config.Shops) do
            local id=links[shop.id]
            local current=exports['feather-organizations']:GetOrganization({organizationId=id})
            Check('canonical business identity',current.ok and current.value.organizationKey==shop.organization.key and current.value.organizationType=='business')
            Check('bootstrap activated',current.ok and current.value.status=='active' and current.value.revision>=2)
            local catalog=ShopService.GetCatalog(shop.id)
            Check('catalog UUID linked',catalog.ok and catalog.value.organizationId==id)
            catalog.value.organizationId='tampered'
            Check('snapshot isolated',ShopService.GetCatalog(shop.id).value.organizationId==id)
            local persisted=DB.value('SELECT organization_id FROM shop_organization_links WHERE shop_id=?',shop.id)
            Check('persisted UUID matches',persisted==id)
            local history=exports['feather-organizations']:InspectOrganizationHistory({organizationId=id,limit=50})
            local bootstrap=0
            for _,event in ipairs(history.ok and history.value.items or {}) do
                if event.sourceResource==GetCurrentResourceName() and (event.requestId=='shop-organization:'..shop.id
                    or event.requestId=='shop-organization-activate:'..shop.id) then bootstrap=bootstrap+1 end
            end
            Check('bootstrap audit once',history.ok and bootstrap==2)
            print(('[ShopOrganizationContractSmokeTest] shop=%s organization=%s'):format(shop.id,id))
        end
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[ShopOrganizationContractSmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[ShopOrganizationContractSmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[ShopOrganizationContractSmokeTest] FAIL '..tostring(reason)) end
end,true)

ShopService.RegisterDevCommand('ShopOrganizationCommerceContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        assert(ShopService.IsReady(),'Shops not ready')
        local tests={}
        local function Check(label,good) tests[#tests+1]={label,good==true} end
        local id=links[Config.Shops[1].id]
        Check('active commerce allowed',ShopOrganizations.CommerceState(Ok({organizationId=id,organizationType='business',status='active'}),id).ok)
        for _,status in ipairs({'pending','suspended','dissolving','dissolved'}) do
            local denied=ShopOrganizations.CommerceState(Ok({organizationId=id,organizationType='business',status=status}),id)
            Check(status..' commerce blocked',not denied.ok and denied.code=='organization_inactive')
        end
        Check('missing identity closed',not ShopOrganizations.CommerceState(Err('organization_not_found','Missing'),id).ok)
        Check('malformed result closed',not ShopOrganizations.CommerceState(true,id).ok)
        Check('wrong identity closed',not ShopOrganizations.CommerceState(Ok({organizationId='wrong',organizationType='business',status='active'}),id).ok)
        Check('wrong type closed',not ShopOrganizations.CommerceState(Ok({organizationId=id,organizationType='government',status='active'}),id).ok)
        Check('canonical commerce open',ShopOrganizations.CheckCommerce(Config.Shops[1].id).ok)
        Check('catalog readiness signaled',GlobalState['feather-shops:ready']==true)
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[ShopOrganizationCommerceContractSmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[ShopOrganizationCommerceContractSmokeTest] done %d/%d passed (read-only; inactive cases isolated)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[ShopOrganizationCommerceContractSmokeTest] FAIL '..tostring(reason)) end
end,true)
