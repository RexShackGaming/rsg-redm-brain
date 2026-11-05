WeaponProvenanceService = {}

local ready = false

local function Clean(value, maximum)
    if value == nil then return nil end
    value = tostring(value)
    if value == '' then return nil end
    return value:sub(1, maximum)
end

local function Trusted(resource)
    return type(resource) == 'string'
        and ((Config.Ownership or {}).trustedResources or {})[resource] == true
end

function WeaponProvenanceService.Start()
    DB.exec([[
        CREATE TABLE IF NOT EXISTS `feather_weapon_events` (
          `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
          `item_instance_id` BIGINT UNSIGNED NOT NULL,
          `serial_number` VARCHAR(128) NOT NULL,
          `definition_id` VARCHAR(64) NOT NULL,
          `event_type` VARCHAR(48) NOT NULL,
          `operation` VARCHAR(48) NOT NULL,
          `actor_character_id` CHAR(36) NULL,
          `from_character_id` CHAR(36) NULL,
          `to_character_id` CHAR(36) NULL,
          `from_inventory_id` BIGINT UNSIGNED NULL,
          `to_inventory_id` BIGINT UNSIGNED NULL,
          `reason` VARCHAR(64) NULL,
          `resource` VARCHAR(64) NOT NULL,
          `correlation_id` VARCHAR(128) NULL,
          `snapshot` LONGTEXT NOT NULL,
          `occurred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_weapon_events_item` (`item_instance_id`,`id`),
          KEY `idx_weapon_events_serial` (`serial_number`,`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    ready = true
    return WeaponResult.Ok(true)
end

function WeaponProvenanceService.Record(fact)
    if not ready or type(fact) ~= 'table' then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            'Weapon provenance ledger is unavailable', nil, fact and fact.correlationId)
    end
    local itemId = tonumber(fact.itemInstanceId)
    local serial = Clean(fact.serialNumber, 128)
    local definitionId = Clean(fact.definitionId, 64)
    local eventType = Clean(fact.transitionType or fact.eventType, 48)
    local operation = Clean(fact.operation, 48)
    if not itemId or not serial or not definitionId or not eventType or not operation then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'Weapon provenance fact is incomplete', nil, fact.correlationId)
    end
    -- DB.insert raises on failure (unlike MySQL.insert.await, which returned nil); pcall keeps
    -- that failure inside this service's existing WeaponResult.Error contract instead of letting
    -- a raw Lua error cross the exports() boundary into whatever resource called IssueWeapon etc.
    local inserted, id = pcall(DB.insert, [[
        INSERT INTO `feather_weapon_events`
        (`item_instance_id`,`serial_number`,`definition_id`,`event_type`,`operation`,
         `actor_character_id`,`from_character_id`,`to_character_id`,
         `from_inventory_id`,`to_inventory_id`,`reason`,`resource`,`correlation_id`,`snapshot`,`occurred_at`)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,FROM_UNIXTIME(?))
    ]],
        itemId, serial, definitionId, eventType, operation,
        CoreAdapter.NormalizeCharacterId(fact.actorCharacterId),
        CoreAdapter.NormalizeCharacterId(fact.fromCharacterId),
        CoreAdapter.NormalizeCharacterId(fact.toCharacterId),
        tonumber(fact.fromInventoryId), tonumber(fact.toInventoryId),
        Clean(fact.reason, 64), Clean(fact.resource or 'feather-weapons', 64),
        Clean(fact.correlationId, 128), json.encode(fact), tonumber(fact.occurredAt) or os.time())
    if not inserted or not id then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
            'Weapon provenance event could not be persisted', nil, fact.correlationId)
    end
    return WeaponResult.Ok({ eventId = id }, fact.correlationId)
end

function WeaponProvenanceService.Inspect(request, context, invokingResource)
    request = type(request) == 'table' and request or {}
    context = type(context) == 'table' and context or {}
    if not Trusted(invokingResource) then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            'Calling resource is not trusted for weapon inspection', nil, context.correlationId)
    end
    local itemId = tonumber(request.itemInstanceId)
    local serial = Clean(request.serialNumber, 128)
    if not itemId and not serial then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'Item instance ID or serial number is required', nil, context.correlationId)
    end
    local maximum = math.max(1, math.min(500,
        math.floor(tonumber((Config.Provenance or {}).maxInspectionEvents) or 100)))
    local limit = math.max(1, math.min(maximum, math.floor(tonumber(request.limit) or 50)))
    local queried, rows
    if itemId then
        queried, rows = pcall(DB.query, [[SELECT * FROM `feather_weapon_events`
            WHERE `item_instance_id`=? ORDER BY `id` DESC LIMIT ?]], itemId, limit)
    else
        queried, rows = pcall(DB.query, [[SELECT * FROM `feather_weapon_events`
            WHERE `serial_number`=? ORDER BY `id` DESC LIMIT ?]], serial, limit)
    end
    if not queried then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            'Weapon provenance ledger could not be read', nil, context.correlationId)
    end
    if not itemId then
        itemId = rows[1] and tonumber(rows[1].item_instance_id) or nil
    end
    local reader=WeaponNativeOwnershipReader
    local current = itemId and reader and reader.GetInstance(context, itemId) or nil
    return WeaponResult.Ok({
        itemInstanceId = itemId,
        serialNumber = serial or (rows[1] and rows[1].serial_number),
        current = current and current.ok and current.value or nil,
        destroyed = #rows > 0 and rows[1].event_type == 'destruction',
        events = rows
    }, context.correlationId)
end

function WeaponProvenanceService.IsReady() return ready end

function WeaponProvenanceService.FindIssuanceEvent(itemInstanceId, correlationId)
    local queried, rows = pcall(DB.query, [[SELECT `id` FROM `feather_weapon_events`
        WHERE `item_instance_id`=? AND `event_type`='issuance'
        ORDER BY `id` ASC LIMIT 1]], tonumber(itemInstanceId))
    if not queried then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            'Weapon provenance ledger could not be read', nil, correlationId)
    end
    return WeaponResult.Ok({ eventId = rows[1] and tonumber(rows[1].id) or nil }, correlationId)
end

function WeaponProvenanceService.CheckContract()
    local untrusted = WeaponProvenanceService.Inspect({ itemInstanceId = 1 }, {}, 'untrusted-smoke-resource')
    local incomplete = WeaponProvenanceService.Inspect({}, {}, 'feather-weapons')
    return {
        ready = ready,
        trustedResourceConfigured = Trusted('feather-weapons'),
        untrustedRejected = untrusted.ok == false and untrusted.error
            and untrusted.error.code == WeaponErrors.AUTHORIZATION_INVALID,
        incompleteRejected = incomplete.ok == false and incomplete.error
            and incomplete.error.code == WeaponErrors.ITEM_INVALID,
        boundedInspection = tonumber((Config.Provenance or {}).maxInspectionEvents) ~= nil
            and tonumber(Config.Provenance.maxInspectionEvents) >= 1
            and tonumber(Config.Provenance.maxInspectionEvents) <= 500,
        retentionConfigured = tonumber((Config.Provenance or {}).retentionDays) ~= nil
            and tonumber(Config.Provenance.retentionDays) >= 0
    }
end
