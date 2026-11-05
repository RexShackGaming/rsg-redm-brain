ChatModeration = {}

local ready = false
local routesReady = false
local routeState = { toggle=false, list=false, remove=false }
local deliveries = {}
local maximumRememberedDeliveries = 100
local providers, providerOrder = {}, {}

local function Callable(value)
    return type(value) == 'function' or (type(value) == 'table'
        and type(rawget(value, '__cfx_functionReference')) == 'string')
end

local function Owner()
    local resource = GetInvokingResource and GetInvokingResource() or nil
    return type(resource) == 'string' and resource ~= '' and resource or GetCurrentResourceName()
end

local function Uuid(value)
    return type(value) == 'string' and value:match(
        '^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') ~= nil
end

local function NewUuid()
    return ('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(token)
        local value = token == 'x' and math.random(0, 15) or math.random(8, 11)
        return ('%x'):format(value)
    end)
end

local function Migrate()
    DB.raw([[CREATE TABLE IF NOT EXISTS `feather_chat_mutes` (
        `mute_id` CHAR(36) NOT NULL, `account_id` CHAR(36) NOT NULL,
        `scope_type` VARCHAR(16) NOT NULL, `scope_key` VARCHAR(96) NULL,
        `reason` VARCHAR(255) NOT NULL, `issued_by_account_id` CHAR(36) NOT NULL,
        `expires_at` TIMESTAMP NULL, `revoked_at` TIMESTAMP NULL,
        `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`mute_id`), KEY `idx_chat_active_mutes` (`account_id`,`revoked_at`,`expires_at`),
        CONSTRAINT `chk_chat_mute_scope` CHECK (`scope_type` IN ('all','channel','ooc'))
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    DB.raw([[CREATE TABLE IF NOT EXISTS `feather_chat_ignores` (
        `owner_account_id` CHAR(36) NOT NULL, `subject_type` VARCHAR(16) NOT NULL,
        `subject_id` CHAR(36) NOT NULL, `ignore_id` CHAR(36) NULL,
        `display_name` VARCHAR(96) NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`owner_account_id`,`subject_type`,`subject_id`),
        CONSTRAINT `chk_chat_ignore_subject` CHECK (`subject_type` IN ('account','character'))
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    DB.raw([[ALTER TABLE `feather_chat_ignores`
        ADD COLUMN IF NOT EXISTS `ignore_id` CHAR(36) NULL AFTER `subject_id`,
        ADD COLUMN IF NOT EXISTS `display_name` VARCHAR(96) NULL AFTER `ignore_id`]])
    DB.exec('UPDATE `feather_chat_ignores` SET `ignore_id`=UUID() WHERE `ignore_id` IS NULL')
    DB.raw([[CREATE TABLE IF NOT EXISTS `feather_chat_moderation_audit` (
        `audit_id` CHAR(36) NOT NULL, `action_key` VARCHAR(64) NOT NULL,
        `actor_account_id` CHAR(36) NOT NULL, `subject_account_id` CHAR(36) NOT NULL,
        `mute_id` CHAR(36) NULL, `reason` VARCHAR(255) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`audit_id`), KEY `idx_chat_audit_subject` (`subject_account_id`,`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
end

local function Authorized(action, source)
    local decision = exports['feather-core']:Authorize(action, { source=source })
    return type(decision) == 'table' and decision.ok and decision.value
        and decision.value.allowed == true, decision
end

local function ScopeAllowed(scope)
    for _, allowed in ipairs(Config.Moderation.mutes.allowedScopes) do
        if scope == allowed then return true end
    end
    return false
end

function ChatModeration.Start()
    if ready then return ChatResults.Ok(true) end
    local called, failure = pcall(function()
        if not DB.awaitReady(30000) then error(ChatLocale.T('error_database_readiness_timed_out'), 0) end
        Migrate()
    end)
    if not called then
        return ChatResults.Err('persistence_unavailable', ChatLocale.T('error_chat_moderation_persistence_is_unavailable'),
            { reason=tostring(failure) })
    end
    ready = true
    return ChatResults.Ok(true)
end

local function ActiveMute(database, actor, channel)
    return database.one([[SELECT `mute_id`,`scope_type`,`scope_key`,`expires_at` FROM `feather_chat_mutes`
        WHERE `account_id`=? AND `revoked_at` IS NULL AND (`expires_at` IS NULL OR `expires_at`>CURRENT_TIMESTAMP)
        AND (`scope_type`='all' OR (`scope_type`='channel' AND `scope_key`=?)
        OR (`scope_type`='ooc' AND ?='ooc')) ORDER BY `created_at` DESC LIMIT 1]],
        actor.accountId, channel.channelKey, channel.presentation and channel.presentation.variant or '')
end

function ChatModeration.CanSend(actor, channel)
    if not Config.Moderation.mutes.enabled then return ChatResults.Ok({ allowed=true }) end
    local row = ActiveMute(DB, actor, channel)
    if row then return ChatResults.Err('muted', ChatLocale.T('error_you_cannot_send_messages_in_this_chat_context')) end
    return ChatResults.Ok({ allowed=true })
end

function ChatModeration.RegisterProvider(name, implementation, options)
    if type(name) ~= 'string' or #name < 3 or #name > 64
        or name:match('^[a-z][a-z0-9_.%-]+$') == nil
        or type(implementation) ~= 'table' or not Callable(implementation.Evaluate) then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_moderation_provider_registration_is_invalid'))
    end
    if providers[name] then return ChatResults.Err('already_registered', ChatLocale.T('error_moderation_provider_is_already_registered')) end
    if #providerOrder >= Config.Moderation.providers.maximumRegistered then
        return ChatResults.Err('limit_reached', ChatLocale.T('error_moderation_provider_limit_reached'))
    end
    options = type(options) == 'table' and options or {}
    providers[name] = { owner=Owner(), implementation=implementation, required=options.required == true }
    providerOrder[#providerOrder + 1] = name
    table.sort(providerOrder)
    return ChatResults.Ok({ name=name, required=providers[name].required })
end

function ChatModeration.UnregisterProvider(name)
    local provider = providers[name]
    if not provider then return ChatResults.Err('not_found', ChatLocale.T('error_moderation_provider_was_not_found')) end
    if provider.owner ~= Owner() then return ChatResults.Err('forbidden', ChatLocale.T('error_moderation_provider_belongs_to_another_resource')) end
    providers[name] = nil
    for index, key in ipairs(providerOrder) do
        if key == name then table.remove(providerOrder, index) break end
    end
    return ChatResults.Ok(true)
end

local function EvaluateProviders(actor, channel, text, forceEnabled)
    if not forceEnabled and not Config.Moderation.providers.enabled then
        return ChatResults.Ok({ text=text })
    end
    local globallyRequired = not forceEnabled and Config.Moderation.providers.required or false
    if #providerOrder == 0 and globallyRequired then
        return ChatResults.Err('provider_unavailable', ChatLocale.T('error_required_chat_moderation_is_unavailable'))
    end
    local normalized = text
    for _, name in ipairs(providerOrder) do
        local provider = providers[name]
        local called, result = pcall(provider.implementation.Evaluate, {
            actor={ accountId=actor.accountId, characterId=actor.characterId },
            channelKey=channel.channelKey, text=normalized
        })
        local valid = called and type(result) == 'table' and result.ok == true
            and type(result.value) == 'table' and type(result.value.allowed) == 'boolean'
        if not valid then
            print(ChatLocale.Format('operator_moderation_provider_failed_name_value_required_value',
                name, tostring(provider.required or Config.Moderation.providers.required)))
            if provider.required or globallyRequired then
                return ChatResults.Err('provider_unavailable', ChatLocale.T('error_required_chat_moderation_is_unavailable'))
            end
        elseif result.value.allowed ~= true then
            return ChatResults.Err('invalid_content', ChatLocale.T('error_that_message_was_rejected_by_moderation'), {
                provider=name, reasonCode=result.value.reasonCode })
        elseif result.value.text ~= nil then
            if type(result.value.text) ~= 'string' then
                return ChatResults.Err('provider_unavailable', ChatLocale.T('error_chat_moderation_returned_an_invalid_replacement'))
            end
            normalized = result.value.text
        end
    end
    return ChatResults.Ok({ text=normalized })
end

function ChatModeration.EvaluateMessage(actor, channel, text)
    return EvaluateProviders(actor, channel, text, false)
end

local function BypassesIgnore(kind)
    local policy = Config.Moderation.staffBypass
    return (kind == 'system' and policy.system)
        or (kind == 'moderation' and policy.moderation)
        or ((kind == 'staff' or kind == 'staff_channel') and policy.staffChannel)
        or (kind == 'staff_case' and policy.staffCase)
end

function ChatModeration.FilterRecipients(actor, recipients, channel)
    if not Config.Moderation.playerControls.ignoreEnabled then return recipients end
    if type(channel) == 'table' and BypassesIgnore(channel.kind) then return recipients end
    local selected = {}
    for _, target in ipairs(recipients) do
        local session = exports['feather-core']:GetSessionContext(target)
        if type(session) == 'table' and session.ok then
            local subjectId = Config.Moderation.playerControls.ignoreSubjectScope == 'account'
                and actor.accountId or actor.characterId
            local ignored = DB.value([[SELECT 1 FROM `feather_chat_ignores` WHERE `owner_account_id`=?
                AND `subject_type`=? AND `subject_id`=? LIMIT 1]], session.value.accountId,
                Config.Moderation.playerControls.ignoreSubjectScope, subjectId)
            if not ignored then selected[#selected + 1] = target end
        end
    end
    return selected
end

function ChatModeration.RecordDelivery(target, message, actor)
    if type(target) ~= 'number' or type(message) ~= 'table' or type(message.messageId) ~= 'string' then return end
    local session = exports['feather-core']:GetSessionContext(target)
    if type(session) ~= 'table' or not session.ok then return end
    deliveries[target] = deliveries[target] or { order={}, values={} }
    local cache = deliveries[target]
    cache.values[message.messageId] = {
        recipientSessionId=session.value.sessionId,
        accountId=actor.accountId,
        characterId=actor.characterId,
        displayName=message.author and message.author.displayName,
        kind=message.kind
    }
    cache.order[#cache.order + 1] = message.messageId
    while #cache.order > maximumRememberedDeliveries do
        cache.values[table.remove(cache.order, 1)] = nil
    end
end

local function OfficialKind(kind)
    return kind == 'system' or kind == 'moderation' or kind == 'staff'
        or kind == 'staff_channel' or kind == 'staff_case'
end

function ChatModeration.ToggleIgnore(payload, source, context)
    if not Config.Moderation.playerControls.ignoreEnabled then
        return ChatResults.Err('disabled', ChatLocale.T('error_player_ignores_are_disabled'))
    end
    local cache = deliveries[source]
    local receipt = cache and cache.values[payload.messageId] or nil
    if not receipt or receipt.recipientSessionId ~= context.sessionId then
        return ChatResults.Err('message_unavailable', ChatLocale.T('error_that_message_is_no_longer_available_for_this_action'))
    end
    if OfficialKind(receipt.kind) then
        return ChatResults.Err('not_ignorable', ChatLocale.T('error_official_staff_and_system_messages_cannot_be_ignored'))
    end
    local subjectId = Config.Moderation.playerControls.ignoreSubjectScope == 'account'
        and receipt.accountId or receipt.characterId
    if context.accountId == receipt.accountId then
        return ChatResults.Err('invalid_target', ChatLocale.T('error_you_cannot_ignore_yourself'))
    end
    local existing = DB.value([[SELECT 1 FROM `feather_chat_ignores` WHERE `owner_account_id`=?
        AND `subject_type`=? AND `subject_id`=? LIMIT 1]], context.accountId,
        Config.Moderation.playerControls.ignoreSubjectScope, subjectId)
    local ignored = not existing
    if ignored then
        local count = tonumber(DB.value('SELECT COUNT(*) FROM `feather_chat_ignores` WHERE `owner_account_id`=?', context.accountId)) or 0
        if count >= Config.Moderation.playerControls.maximumIgnoredSubjects then
            return ChatResults.Err('limit_reached', ChatLocale.T('error_ignore_limit_reached'))
        end
        DB.exec([[INSERT INTO `feather_chat_ignores`
            (`owner_account_id`,`subject_type`,`subject_id`,`ignore_id`,`display_name`)
            VALUES (?,?,?,?,?)]], context.accountId,
            Config.Moderation.playerControls.ignoreSubjectScope, subjectId, NewUuid(), receipt.displayName)
    else
        DB.exec([[DELETE FROM `feather_chat_ignores` WHERE `owner_account_id`=?
            AND `subject_type`=? AND `subject_id`=?]], context.accountId,
            Config.Moderation.playerControls.ignoreSubjectScope, subjectId)
    end
    return ChatResults.Ok({ ignored=ignored, displayName=receipt.displayName })
end

function ChatModeration.ListIgnores(_, _, context)
    if not Config.Moderation.playerControls.ignoreEnabled then
        return ChatResults.Ok({ ignores={} })
    end
    local rows = DB.query([[SELECT `ignore_id` AS `ignoreId`,COALESCE(`display_name`,'Unknown player') AS `displayName`,
        `subject_type` AS `scope`,DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS `createdAt`
        FROM `feather_chat_ignores` WHERE `owner_account_id`=? ORDER BY `created_at` DESC LIMIT 500]],
        context.accountId) or {}
    return ChatResults.Ok({ ignores=rows })
end

function ChatModeration.RemoveIgnore(payload, _, context)
    local changed = DB.exec([[DELETE FROM `feather_chat_ignores`
        WHERE `owner_account_id`=? AND `ignore_id`=?]], context.accountId, payload.ignoreId)
    if tonumber(changed) ~= 1 then return ChatResults.Err('not_found', ChatLocale.T('error_ignore_preference_was_not_found')) end
    return ChatResults.Ok(true)
end

function ChatModeration.RegisterRoutes()
    if routesReady then return ChatResults.Ok(true) end
    if not routeState.toggle then
        local result = exports['feather-core']:RegisterContractRPC('chat.ignore.toggle.v1',
            ChatModeration.ToggleIgnore, {
                contract=1, direction='client_to_server', requireCharacter=true,
                windowMs=3000, maxCalls=4, maxPayloadBytes=128, maxDepth=2, maxNodes=4,
                validatePayload=ChatContract.ValidateIgnoreRequest
            })
        if type(result) ~= 'table' or not result.ok then return result end
        routeState.toggle = true
    end
    if not routeState.list then
        local result = exports['feather-core']:RegisterContractRPC('chat.ignore.list.v1',
            ChatModeration.ListIgnores, { contract=1, direction='client_to_server', requireCharacter=true,
                windowMs=3000, maxCalls=4, maxPayloadBytes=32, maxDepth=1, maxNodes=1,
                validatePayload=function(payload) return type(payload) == 'table' and next(payload) == nil end })
        if type(result) ~= 'table' or not result.ok then return result end
        routeState.list = true
    end
    if not routeState.remove then
        local result = exports['feather-core']:RegisterContractRPC('chat.ignore.remove.v1',
            ChatModeration.RemoveIgnore, { contract=1, direction='client_to_server', requireCharacter=true,
                windowMs=3000, maxCalls=4, maxPayloadBytes=128, maxDepth=2, maxNodes=4,
                validatePayload=ChatContract.ValidateIgnoreRemove })
        if type(result) ~= 'table' or not result.ok then return result end
        routeState.remove = true
    end
    routesReady = true
    return ChatResults.Ok(true)
end

function ChatModeration.IssueMute(request)
    if type(request) ~= 'table' or not Uuid(request.accountId) or not ScopeAllowed(request.scopeType)
        or type(request.reason) ~= 'string' or #request.reason < 1 or #request.reason > 255
        or (request.scopeType == 'channel' and (type(request.scopeKey) ~= 'string'
            or #request.scopeKey < 3 or #request.scopeKey > 96))
        or (request.scopeType ~= 'channel' and request.scopeKey ~= nil) then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_mute_request_is_invalid'))
    end
    local source = math.floor(tonumber(request.source) or 0)
    local allowed, decision = Authorized('chat.mute.issue', source)
    if not allowed then return ChatResults.Err('forbidden', ChatLocale.T('error_mute_authorization_was_denied'), { decision=decision and decision.code }) end
    local session = exports['feather-core']:GetSessionContext(source)
    if type(session) ~= 'table' or not session.ok then return ChatResults.Err('unauthenticated', ChatLocale.T('error_staff_session_is_unavailable')) end
    local minutes = request.durationMinutes and tonumber(request.durationMinutes) or nil
    if minutes and minutes % 1 ~= 0 then return ChatResults.Err('invalid_input', ChatLocale.T('error_mute_duration_must_be_whole_minutes')) end
    if not minutes and not Config.Moderation.mutes.permanentAllowed then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_permanent_mutes_are_disabled'))
    end
    if minutes and (minutes < 1 or minutes > Config.Moderation.mutes.maximumDurationMinutes) then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_mute_duration_is_outside_the_configured_limit'))
    end
    local muteId = NewUuid()
    DB.transaction(function(tx)
        tx.insert([[INSERT INTO `feather_chat_mutes`
            (`mute_id`,`account_id`,`scope_type`,`scope_key`,`reason`,`issued_by_account_id`,`expires_at`)
            VALUES (?,?,?,?,?,?,CASE WHEN ? IS NULL THEN NULL ELSE DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? MINUTE) END)]],
            muteId, request.accountId:lower(), request.scopeType, request.scopeKey, request.reason,
            session.value.accountId, minutes, minutes)
        if Config.Moderation.audit.enabled then
            tx.insert([[INSERT INTO `feather_chat_moderation_audit`
                (`audit_id`,`action_key`,`actor_account_id`,`subject_account_id`,`mute_id`,`reason`)
                VALUES (?,?,?,?,?,?)]], NewUuid(), 'chat.mute.issue', session.value.accountId,
                request.accountId:lower(), muteId, request.reason)
        end
        return true
    end)
    return ChatResults.Ok({ muteId=muteId, revision=1 })
end

function ChatModeration.RevokeMute(request)
    if type(request) ~= 'table' or not Uuid(request.muteId) then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_mute_revocation_request_is_invalid'))
    end
    local source = math.floor(tonumber(request.source) or 0)
    local allowed = Authorized('chat.mute.revoke', source)
    if not allowed then return ChatResults.Err('forbidden', ChatLocale.T('error_mute_authorization_was_denied')) end
    local session = exports['feather-core']:GetSessionContext(source)
    if type(session) ~= 'table' or not session.ok then return ChatResults.Err('unauthenticated', ChatLocale.T('error_staff_session_is_unavailable')) end
    local found = DB.one('SELECT `account_id` FROM `feather_chat_mutes` WHERE `mute_id`=? AND `revoked_at` IS NULL', request.muteId:lower())
    if not found then return ChatResults.Err('not_found', ChatLocale.T('error_active_mute_was_not_found')) end
    local revoked = DB.transaction(function(tx)
        local changed = tx.exec([[UPDATE `feather_chat_mutes` SET `revoked_at`=CURRENT_TIMESTAMP, `revision`=`revision`+1
            WHERE `mute_id`=? AND `revoked_at` IS NULL]], request.muteId:lower())
        if tonumber(changed) ~= 1 then return false end
        if Config.Moderation.audit.enabled then
            tx.insert([[INSERT INTO `feather_chat_moderation_audit`
                (`audit_id`,`action_key`,`actor_account_id`,`subject_account_id`,`mute_id`,`reason`)
                VALUES (?,?,?,?,?,?)]], NewUuid(), 'chat.mute.revoke', session.value.accountId,
                found.account_id, request.muteId:lower(), 'revoked')
        end
        return true
    end)
    if not revoked then return ChatResults.Err('not_found', ChatLocale.T('error_active_mute_was_not_found')) end
    return ChatResults.Ok(true)
end

function ChatModeration.GetMuteSnapshot(request)
    if type(request) ~= 'table' or not Uuid(request.accountId) then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_mute_inspection_request_is_invalid'))
    end
    local allowed = Authorized('chat.mute.inspect', math.floor(tonumber(request.source) or 0))
    if not allowed then return ChatResults.Err('forbidden', ChatLocale.T('error_mute_inspection_authorization_was_denied')) end
    local rows = DB.query([[SELECT `mute_id` AS `muteId`,`scope_type` AS `scopeType`,
        `scope_key` AS `scopeKey`,`reason`,`issued_by_account_id` AS `issuedByAccountId`,
        DATE_FORMAT(`expires_at`,'%Y-%m-%d %H:%i:%s') AS `expiresAt`,
        `revision`,DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS `createdAt`
        FROM `feather_chat_mutes` WHERE `account_id`=?
        AND `revoked_at` IS NULL AND (`expires_at` IS NULL OR `expires_at`>CURRENT_TIMESTAMP)
        ORDER BY `created_at` DESC LIMIT 100]], request.accountId:lower()) or {}
    return ChatResults.Ok({ accountId=request.accountId:lower(), mutes=rows })
end

function ChatModeration.GetDiagnostics(request)
    local allowed = Authorized('chat.diagnostics', math.floor(tonumber(request and request.source) or 0))
    if not allowed then return ChatResults.Err('forbidden', ChatLocale.T('error_chat_diagnostics_authorization_was_denied')) end
    local counts = DB.one([[SELECT
        (SELECT COUNT(*) FROM `feather_chat_mutes` WHERE `revoked_at` IS NULL
            AND (`expires_at` IS NULL OR `expires_at`>CURRENT_TIMESTAMP)) AS `activeMutes`,
        (SELECT COUNT(*) FROM `feather_chat_ignores`) AS `ignores`,
        (SELECT COUNT(*) FROM `feather_chat_moderation_audit`) AS `auditRecords`]]) or {}
    local registered = {}
    for _, name in ipairs(providerOrder) do
        registered[#registered + 1] = { name=name, required=providers[name].required }
    end
    return ChatResults.Ok({
        activeMutes=tonumber(counts.activeMutes) or 0,
        ignores=tonumber(counts.ignores) or 0,
        auditRecords=tonumber(counts.auditRecords) or 0,
        providers={ enabled=Config.Moderation.providers.enabled,
            required=Config.Moderation.providers.required, registered=registered },
        auditIncludesMessageBody=false
    })
end

function ChatModeration.Smoke()
    local tables = tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema=DATABASE() AND table_name IN
        ('feather_chat_mutes','feather_chat_ignores','feather_chat_moderation_audit')]])) or 0
    local invalid = ChatModeration.IssueMute({ accountId='spoofed', scopeType='all', reason='test' })
    local account = '00000000-0000-4000-8000-000000000061'
    local issuer = '00000000-0000-4000-8000-000000000062'
    local activeId = '00000000-0000-4000-8000-000000000063'
    local expiredId = '00000000-0000-4000-8000-000000000064'
    local checks = {}
    local executed, committed = pcall(DB.transaction, function(tx)
        tx.exec([[INSERT INTO `feather_chat_mutes`
            (`mute_id`,`account_id`,`scope_type`,`reason`,`issued_by_account_id`,`expires_at`)
            VALUES (?,?,?,'smoke',?,DATE_ADD(CURRENT_TIMESTAMP,INTERVAL 10 MINUTE))]],
            activeId, account, 'all', issuer)
        checks.active = ActiveMute(tx, { accountId=account }, {
            channelKey='local.say', presentation={ variant='speech' } }) ~= nil
        tx.exec('UPDATE `feather_chat_mutes` SET `revoked_at`=CURRENT_TIMESTAMP WHERE `mute_id`=?', activeId)
        checks.revoked = ActiveMute(tx, { accountId=account }, {
            channelKey='local.say', presentation={ variant='speech' } }) == nil
        tx.exec([[INSERT INTO `feather_chat_mutes`
            (`mute_id`,`account_id`,`scope_type`,`reason`,`issued_by_account_id`,`expires_at`)
            VALUES (?,?,?,'smoke',?,DATE_SUB(CURRENT_TIMESTAMP,INTERVAL 10 MINUTE))]],
            expiredId, account, 'all', issuer)
        checks.expired = ActiveMute(tx, { accountId=account }, {
            channelKey='local.say', presentation={ variant='speech' } }) == nil
        tx.exec([[INSERT INTO `feather_chat_moderation_audit`
            (`audit_id`,`action_key`,`actor_account_id`,`subject_account_id`,`mute_id`,`reason`)
            VALUES (UUID(),'chat.mute.issue',?,?,?,'smoke')]], issuer, account, activeId)
        checks.audit = tonumber(tx.value([[SELECT COUNT(*) FROM `feather_chat_moderation_audit`
            WHERE `subject_account_id`=? AND `reason`='smoke']], account)) == 1
        return false
    end)
    local rolledBack = tonumber(DB.value([[SELECT
        (SELECT COUNT(*) FROM `feather_chat_mutes` WHERE `account_id`=?)+
        (SELECT COUNT(*) FROM `feather_chat_moderation_audit` WHERE `subject_account_id`=?)]],
        account, account)) == 0
    local bodyColumns = tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema=DATABASE() AND table_name='feather_chat_moderation_audit'
        AND column_name IN ('message','message_body','body','text')]])) or -1
    return {
        { 'persistence tables', tables == 3 },
        { 'account mute invariant', Config.Moderation.mutes.enabled
            and Config.Moderation.mutes.persistenceRequired },
        { 'ignore scope configured', Config.Moderation.playerControls.ignoreSubjectScope == 'account'
            or Config.Moderation.playerControls.ignoreSubjectScope == 'character' },
        { 'official context bypass', BypassesIgnore('system') and BypassesIgnore('moderation')
            and BypassesIgnore('staff_channel') and BypassesIgnore('staff_case')
            and not BypassesIgnore('player') },
        { 'invalid mute rejected', not invalid.ok and invalid.code == 'invalid_input' },
        { 'active mute enforced', executed and checks.active == true },
        { 'revoked mute released', checks.revoked == true },
        { 'expired mute released', checks.expired == true },
        { 'audit mutation recorded', checks.audit == true },
        { 'smoke transaction rolled back', committed == false and rolledBack },
        { 'audit excludes message body', bodyColumns == 0 }
    }
end

function ChatModeration.ProviderSmoke()
    local name = 'feather.chat.smoke.provider'
    local function Remove()
        providers[name] = nil
        for index, key in ipairs(providerOrder) do
            if key == name then table.remove(providerOrder, index) break end
        end
    end
    providers[name] = { owner=GetCurrentResourceName(), required=true,
        implementation={ Evaluate=function() error('expected smoke failure', 0) end } }
    providerOrder[#providerOrder + 1] = name
    table.sort(providerOrder)
    local failed = EvaluateProviders({ accountId='account', characterId='character' },
        { channelKey='local.say' }, 'safe', true)
    Remove()
    providers[name] = { owner=GetCurrentResourceName(), required=false,
        implementation={ Evaluate=function() error('expected optional smoke failure', 0) end } }
    providerOrder[#providerOrder + 1] = name
    local optional = EvaluateProviders({ accountId='account', characterId='character' },
        { channelKey='local.say' }, 'safe', true)
    Remove()
    providers[name] = { owner=GetCurrentResourceName(), required=true,
        implementation={ Evaluate=function() return ChatResults.Ok({ allowed=true, text='replacement' }) end } }
    providerOrder[#providerOrder + 1] = name
    local replacement = EvaluateProviders({ accountId='account', characterId='character' },
        { channelKey='local.say' }, 'safe', true)
    Remove()
    providers[name] = { owner=GetCurrentResourceName(), required=true,
        implementation={ Evaluate=function() return ChatResults.Ok({ allowed=false, reasonCode='smoke' }) end } }
    providerOrder[#providerOrder + 1] = name
    local denied = EvaluateProviders({ accountId='account', characterId='character' },
        { channelKey='local.say' }, 'safe', true)
    Remove()
    return {
        { 'required provider fails closed', not failed.ok and failed.code == 'provider_unavailable' },
        { 'optional provider fails open', optional.ok and optional.value.text == 'safe' },
        { 'plain replacement accepted', replacement.ok and replacement.value.text == 'replacement' },
        { 'provider rejection enforced', not denied.ok and denied.code == 'invalid_content' }
    }
end

local function Boundary(operation, request)
    local caller = Owner()
    if Config.Moderation.trustedCallers[caller] ~= true then
        return ChatResults.Err('forbidden', ChatLocale.T('error_calling_resource_is_not_trusted_for_chat_moderation'))
    end
    local called, result = pcall(operation, request)
    if called and type(result) == 'table' and type(result.ok) == 'boolean' then return result end
    print(ChatLocale.Format('operator_moderation_operation_failed_value', tostring(result)))
    return ChatResults.Err('internal_error', ChatLocale.T('error_chat_moderation_operation_failed'))
end

exports('IssueMute', function(request) return Boundary(ChatModeration.IssueMute, request) end)
exports('RevokeMute', function(request) return Boundary(ChatModeration.RevokeMute, request) end)
exports('GetMuteSnapshot', function(request) return Boundary(ChatModeration.GetMuteSnapshot, request) end)
exports('GetModerationDiagnostics', function(request) return Boundary(ChatModeration.GetDiagnostics, request) end)
exports('RegisterModerationProvider', ChatModeration.RegisterProvider)
exports('UnregisterModerationProvider', ChatModeration.UnregisterProvider)

AddEventHandler('playerDropped', function() deliveries[source] = nil end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' then
        routesReady = false
        routeState = { toggle=false, list=false, remove=false }
    end
    if resource == 'feather-mysql' then ready = false end
    for index = #providerOrder, 1, -1 do
        local name = providerOrder[index]
        if providers[name] and providers[name].owner == resource then
            providers[name] = nil
            table.remove(providerOrder, index)
        end
    end
end)

