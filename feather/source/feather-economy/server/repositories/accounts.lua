EconomyAccounts = {}

local function IsUuid(value)
    return type(value) == 'string' and value:match(
        '^[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+$') ~= nil
        and #value == 36
end

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local output = {}
    for key, child in pairs(value) do output[key] = Copy(child) end
    return output
end

local function Normalize(row)
    if type(row) ~= 'table' then return nil end
    return {
        accountId = row.account_id,
        ownerType = row.owner_type,
        ownerId = row.owner_id,
        accountType = row.account_type,
        accountRef = row.account_ref ~= '' and row.account_ref or nil,
        currency = row.currency_code,
        status = row.status,
        label = row.label,
        revision = tonumber(row.account_revision),
        balance = tonumber(row.posted_amount),
        balanceRevision = tonumber(row.balance_revision),
        createdAt = row.created_at,
        closedAt = row.closed_at,
        updatedAt = row.updated_at,
        -- The resource an organization treasury is bound to (operated accounts).
        operatorResource = row.operator_resource
    }
end

local function RunTransaction(body)
    local bodyResult, bodyError
    local called, committed = pcall(DB.transaction, function(tx)
        -- Values are passed as separate arguments so a nil anywhere binds SQL NULL.
        local function query(sql, ...) return tx.raw(sql, ...) end
        local ok, result = pcall(body, query)
        if not ok then bodyError = tostring(result) return false end
        bodyResult = result
        return EconomyResults.Is(result) and result.ok
    end)
    if not called then
        -- DB.transaction raises after rolling back when a statement fails, and also
        -- when the transaction cannot begin; either way nothing was committed.
        return EconomyResults.Err('internal_error',
            'Economy account transaction failed.', { reason = tostring(committed) })
    end
    if committed ~= true then
        if EconomyResults.Is(bodyResult) then return bodyResult end
        return EconomyResults.Err('internal_error',
            'Economy account transaction failed.', { reason = bodyError })
    end
    return Copy(bodyResult)
end

local function Ensure(ownerType, ownerId, accountTypes, accountRef)
    accountRef = accountRef or ''
    if (ownerType ~= 'character' and ownerType ~= 'system' and ownerType ~= 'organization') or not IsUuid(ownerId) then
        return EconomyResults.Err('invalid_input', 'A valid account owner is required.')
    end
    local currencies = EconomyCurrencies.List()
    if not currencies.ok then return currencies end

    return RunTransaction(function(query)
        local accounts = {}
        for _, currency in ipairs(currencies.value) do
            for _, accountType in ipairs(accountTypes) do
                local label = ('%s %s'):format(currency.label, (accountType:gsub('_', ' ')))
                if accountRef ~= '' then label = label .. ' ' .. accountRef end
                query([[
                    INSERT IGNORE INTO `economy_accounts`
                        (`account_id`,`owner_type`,`owner_id`,`account_type`,`account_ref`,`currency_code`,`status`,`label`)
                    VALUES (UUID(),?,?,?,?,?, 'open', ?)
                ]], ownerType, ownerId, accountType, accountRef, currency.code, label)
                local rows = query([[
                    SELECT `account_id`,`owner_type`,`owner_id`,`account_type`,`account_ref`,`currency_code`,
                           `status`,`label`,`revision` AS `account_revision`,`created_at`,`closed_at`
                    FROM `economy_accounts`
                    WHERE `owner_type`=? AND `owner_id`=? AND `account_type`=?
                      AND `account_ref`=? AND `currency_code`=? FOR UPDATE
                ]], ownerType, ownerId, accountType, accountRef, currency.code) or {}
                local account = rows[1]
                if not account or account.status ~= 'open' then
                    return EconomyResults.Err('account_closed',
                        'An Economy account is unavailable.', {
                            ownerType = ownerType, ownerId = ownerId,
                            accountType = accountType, currency = currency.code
                        })
                end
                query([[
                    INSERT IGNORE INTO `economy_balances`
                        (`account_id`,`posted_amount`,`revision`) VALUES (?,0,1)
                ]], account.account_id)
                local balanceRows = query([[
                    SELECT `posted_amount`,`revision` AS `balance_revision`,`updated_at`
                    FROM `economy_balances` WHERE `account_id`=? FOR UPDATE
                ]], account.account_id) or {}
                local balance = balanceRows[1]
                if not balance then
                    return EconomyResults.Err('internal_error',
                        'An Economy balance could not be provisioned.')
                end
                for key, value in pairs(balance) do account[key] = value end
                accounts[#accounts + 1] = Normalize(account)
            end
        end
        table.sort(accounts, function(left, right)
            if left.currency == right.currency then return left.accountType < right.accountType end
            return left.currency < right.currency
        end)
        return EconomyResults.Ok(accounts)
    end)
end

function EconomyAccounts.Start()
    if not IsUuid(Config and Config.SystemOwnerId) then
        return EconomyResults.Err('invalid_config', 'Config.SystemOwnerId must be a UUID.')
    end
    local ensured = Ensure('system', Config.SystemOwnerId,
        { 'system_source', 'system_sink' })
    if not ensured.ok then return ensured end
    return EconomyResults.Ok({ systemAccounts = #ensured.value })
end

function EconomyAccounts.EnsureCharacterWallets(characterId)
    return Ensure('character', characterId, { 'wallet' })
end

function EconomyAccounts.EnsureOrganizationTreasuries(organizationId)
    return Ensure('organization', organizationId, { 'treasury' })
end

local function IsAccountRef(value)
    return type(value) == 'string' and #value >= 1 and #value <= 64
        and value:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end

-- One bank account per currency for each (character, accountRef). A character
-- may hold several bank accounts by using different references.
function EconomyAccounts.EnsureCharacterBankAccounts(characterId, accountRef)
    if not IsAccountRef(accountRef) then
        return EconomyResults.Err('invalid_input', 'A bank account reference is required.')
    end
    return Ensure('character', characterId, { 'bank' }, accountRef)
end

-- Newest-first journal entries for one account, in posting order (entry
-- sequence, migration 007). Each row names the account on the other side of the
-- movement so a consumer can render a statement without reading the journal
-- tables itself. Offsets count from the newest entry, so entries posted between
-- two page reads shift later pages; `sequence` lets a consumer drop repeats.
-- Newest first. A page continues from `before` (the sequence of the last entry
-- already read, given back as meta.nextBefore) or skips `offset` entries; the
-- cursor is stable while new entries are posted, the offset is not.
function EconomyAccounts.ListEntries(accountId, limit, offset, before)
    if not IsUuid(accountId) then
        return EconomyResults.Err('invalid_input', 'accountId must be a UUID.')
    end
    local maximum = Config.Limits.maximumPageSize
    limit = limit == nil and maximum or tonumber(limit)
    if before ~= nil and offset ~= nil then
        return EconomyResults.Err('invalid_input', 'Use before or offset, not both.')
    end
    offset = offset == nil and 0 or tonumber(offset)
    if not limit or limit < 1 or limit > maximum or limit ~= math.floor(limit)
        or not offset or offset < 0 or offset > 100000 or offset ~= math.floor(offset) then
        return EconomyResults.Err('invalid_input', 'limit or offset is out of range.')
    end
    local cursor = ''
    local params = { accountId }
    if before ~= nil then
        before = tonumber(before)
        if not before or before < 1 or before ~= math.floor(before) then
            return EconomyResults.Err('invalid_input', 'before must be an entry sequence.')
        end
        -- The cursor entry must belong to this account; its posting time anchors
        -- the page in the same order the history is listed in.
        local anchor = DB.one([[SELECT DATE_FORMAT(t.`posted_at`,'%Y-%m-%d %H:%i:%s') AS `posted_at`
            FROM `economy_entries` e
            INNER JOIN `economy_transactions` t ON t.`transaction_id`=e.`transaction_id`
            WHERE e.`entry_sequence`=? AND e.`account_id`=?]], before, accountId)
        if not anchor then
            return EconomyResults.Err('invalid_cursor', 'before does not name an entry of this account.')
        end
        cursor = ' AND (t.`posted_at`<? OR (t.`posted_at`=? AND e.`entry_sequence`<?))'
        params[#params + 1] = anchor.posted_at
        params[#params + 1] = anchor.posted_at
        params[#params + 1] = before
    end
    params[#params + 1] = limit
    params[#params + 1] = offset
    local rows = DB.query([[
        SELECT e.`entry_id`,e.`entry_sequence`,e.`transaction_id`,e.`amount`,e.`resulting_balance`,
               t.`operation_type`,t.`currency_code`,t.`reason_code`,t.`reference_type`,
               t.`reference_id`,t.`source_resource`,t.`posted_at`,
               c.`account_id` AS `counterparty_account_id`
        FROM `economy_entries` e
        INNER JOIN `economy_transactions` t ON t.`transaction_id`=e.`transaction_id`
        LEFT JOIN `economy_entries` c
               ON c.`transaction_id`=e.`transaction_id` AND c.`account_id`<>e.`account_id`
        WHERE e.`account_id`=? AND t.`status`='committed']] .. cursor .. [[
        ORDER BY t.`posted_at` DESC,e.`entry_sequence` DESC
        LIMIT ? OFFSET ?
    ]], table.unpack(params)) or {}
    local entries = {}
    for _, row in ipairs(rows) do
        entries[#entries + 1] = {
            entryId = row.entry_id,
            sequence = tonumber(row.entry_sequence),
            transactionId = row.transaction_id,
            operation = row.operation_type,
            currency = row.currency_code,
            amount = tonumber(row.amount),
            resultingBalance = tonumber(row.resulting_balance),
            reasonCode = row.reason_code,
            referenceType = row.reference_type,
            referenceId = row.reference_id,
            sourceResource = row.source_resource,
            counterpartyAccountId = row.counterparty_account_id,
            postedAt = row.posted_at
        }
    end
    -- A full page may have more after it; an empty meta means the history ended.
    local meta = #entries == limit and { nextBefore = entries[#entries].sequence } or nil
    return EconomyResults.Ok(entries, meta)
end

function EconomyAccounts.Get(accountId)
    if not IsUuid(accountId) then
        return EconomyResults.Err('invalid_input', 'accountId must be a UUID.')
    end
    local row = DB.one([[
        SELECT a.`account_id`,a.`owner_type`,a.`owner_id`,a.`account_type`,a.`account_ref`,a.`currency_code`,
               a.`status`,a.`label`,a.`revision` AS `account_revision`,a.`created_at`,a.`closed_at`,
               b.`posted_amount`,b.`revision` AS `balance_revision`,b.`updated_at`,o.`operator_resource`
        FROM `economy_accounts` a
        INNER JOIN `economy_balances` b ON b.`account_id`=a.`account_id`
        LEFT JOIN `economy_treasury_operators` o
               ON a.`owner_type`='organization' AND a.`account_type`='treasury' AND o.`organization_id`=a.`owner_id`
        WHERE a.`account_id`=? LIMIT 1
    ]], accountId)
    if not row then
        return EconomyResults.Err('account_not_found', 'Economy account was not found.')
    end
    return EconomyResults.Ok(Normalize(row))
end

function EconomyAccounts.FindByOwner(ownerType, ownerId)
    if (ownerType ~= 'character' and ownerType ~= 'system' and ownerType ~= 'organization') or not IsUuid(ownerId) then
        return EconomyResults.Err('invalid_input', 'A valid account owner is required.')
    end
    local rows = DB.query([[
        SELECT a.`account_id`,a.`owner_type`,a.`owner_id`,a.`account_type`,a.`account_ref`,a.`currency_code`,
               a.`status`,a.`label`,a.`revision` AS `account_revision`,a.`created_at`,a.`closed_at`,
               b.`posted_amount`,b.`revision` AS `balance_revision`,b.`updated_at`,o.`operator_resource`
        FROM `economy_accounts` a
        INNER JOIN `economy_balances` b ON b.`account_id`=a.`account_id`
        LEFT JOIN `economy_treasury_operators` o
               ON a.`owner_type`='organization' AND a.`account_type`='treasury' AND o.`organization_id`=a.`owner_id`
        WHERE a.`owner_type`=? AND a.`owner_id`=?
        ORDER BY a.`currency_code`,a.`account_type`,a.`account_ref`
        LIMIT ?
    ]], ownerType, ownerId, Config.Limits.maximumPageSize)
    local accounts = {}
    for _, row in ipairs(rows) do accounts[#accounts + 1] = Normalize(row) end
    return EconomyResults.Ok(accounts)
end
