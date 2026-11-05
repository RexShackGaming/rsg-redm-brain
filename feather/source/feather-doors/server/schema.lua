-- Immutable once accepted live. Add migrations rather than editing accepted SQL.
DoorsSchema = {}
local definitions = {
    { id='001_groups_and_leaves', tables={'feather_door_groups','feather_door_leaves'}, statements={
        [[CREATE TABLE IF NOT EXISTS `feather_door_groups` (
            `door_id` CHAR(36) NOT NULL,
            `door_key` VARCHAR(100) NOT NULL,
            `label` VARCHAR(128) NOT NULL,
            `manager_resource` VARCHAR(100) NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'active',
            `locked` TINYINT UNSIGNED NOT NULL DEFAULT 1,
            `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `delegation_epoch` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `startup_policy` VARCHAR(20) NOT NULL DEFAULT 'preserve',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`door_id`),
            UNIQUE KEY `uq_door_key` (`door_key`),
            KEY `idx_door_manager` (`manager_resource`,`status`),
            CONSTRAINT `chk_door_status` CHECK (`status` IN ('active','suspended','retired')),
            CONSTRAINT `chk_door_locked` CHECK (`locked` IN (0,1)),
            CONSTRAINT `chk_door_revision` CHECK (`revision` BETWEEN 1 AND 9007199254740990),
            CONSTRAINT `chk_door_epoch` CHECK (`delegation_epoch` BETWEEN 1 AND 9007199254740990),
            CONSTRAINT `chk_door_startup` CHECK (`startup_policy` IN ('preserve','force_locked','force_unlocked'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_door_leaves` (
            `door_hash` BIGINT UNSIGNED NOT NULL,
            `door_id` CHAR(36) NOT NULL,
            `model_hash` BIGINT UNSIGNED NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `ordinal` TINYINT UNSIGNED NOT NULL,
            PRIMARY KEY (`door_hash`),
            UNIQUE KEY `uq_door_leaf_ordinal` (`door_id`,`ordinal`),
            CONSTRAINT `fk_door_leaf_group` FOREIGN KEY (`door_id`) REFERENCES `feather_door_groups` (`door_id`),
            CONSTRAINT `chk_door_hash` CHECK (`door_hash` BETWEEN 1 AND 4294967295),
            CONSTRAINT `chk_door_model` CHECK (`model_hash` BETWEEN 1 AND 4294967295),
            CONSTRAINT `chk_door_ordinal` CHECK (`ordinal` BETWEEN 1 AND 2),
            CONSTRAINT `chk_door_position` CHECK (`x` BETWEEN -20000 AND 20000 AND `y` BETWEEN -20000 AND 20000 AND `z` BETWEEN -2000 AND 5000)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id='002_operation_receipts', tables={'feather_door_operations'}, statements={
        [[CREATE TABLE IF NOT EXISTS `feather_door_operations` (
            `source_resource` VARCHAR(100) NOT NULL,
            `request_id` VARCHAR(128) NOT NULL,
            `request_json` LONGTEXT NOT NULL,
            `result_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id='003_change_outbox', tables={'feather_door_outbox'}, statements={
        [[CREATE TABLE IF NOT EXISTS `feather_door_outbox` (
            `event_id` CHAR(36) NOT NULL,
            `door_id` CHAR(36) NOT NULL,
            `source_resource` VARCHAR(100) NOT NULL,
            `request_id` VARCHAR(128) NOT NULL,
            `event_type` VARCHAR(64) NOT NULL,
            `revision` BIGINT UNSIGNED NOT NULL,
            `payload_json` LONGTEXT NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
            `attempts` INT UNSIGNED NOT NULL DEFAULT 0,
            `available_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `published_at` TIMESTAMP NULL,
            PRIMARY KEY (`event_id`),
            UNIQUE KEY `uq_door_event_operation` (`source_resource`,`request_id`),
            KEY `idx_door_outbox_pending` (`status`,`created_at`,`event_id`),
            CONSTRAINT `fk_door_event_group` FOREIGN KEY (`door_id`) REFERENCES `feather_door_groups` (`door_id`),
            CONSTRAINT `fk_door_event_receipt` FOREIGN KEY (`source_resource`,`request_id`)
                REFERENCES `feather_door_operations` (`source_resource`,`request_id`),
            CONSTRAINT `chk_door_event_status` CHECK (`status` IN ('pending','published','quarantined')),
            CONSTRAINT `chk_door_event_revision` CHECK (`revision` BETWEEN 1 AND 9007199254740990)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id='004_authority_bindings', tables={'feather_door_bindings'}, statements={
        [[CREATE TABLE IF NOT EXISTS `feather_door_bindings` (
            `door_id` CHAR(36) NOT NULL,
            `mode` VARCHAR(16) NOT NULL,
            `link_id` CHAR(36) NULL,
            `property_id` CHAR(36) NULL,
            `property_epoch` BIGINT UNSIGNED NULL,
            `property_status` VARCHAR(16) NULL,
            PRIMARY KEY (`door_id`),
            CONSTRAINT `fk_door_binding_group` FOREIGN KEY (`door_id`) REFERENCES `feather_door_groups` (`door_id`),
            CONSTRAINT `chk_door_binding_mode` CHECK (`mode` IN ('standalone','property')),
            CONSTRAINT `chk_door_binding_facts` CHECK (
                (`mode`='standalone' AND `link_id` IS NULL AND `property_id` IS NULL AND `property_epoch` IS NULL AND `property_status` IS NULL)
                OR (`mode`='property' AND `link_id` IS NOT NULL AND `property_id` IS NOT NULL
                    AND `property_epoch` IS NOT NULL AND `property_status` IS NOT NULL
                    AND `property_epoch` BETWEEN 1 AND 9007199254740991
                    AND `property_status` IN ('active','suspended','retired','unavailable')))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } }
}
local ledger = [[CREATE TABLE IF NOT EXISTS `feather_door_schema_migrations` (
    `id` VARCHAR(100) NOT NULL,
    `checksum` VARCHAR(64) NOT NULL,
    `status` VARCHAR(16) NOT NULL,
    `applied_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `chk_door_migration_status` CHECK (`status` IN ('applying','applied'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
local function checksum(value)
    local hash=2166136261
    for i=1,#value do hash=((hash ~ value:byte(i))*16777619)&0xffffffff end
    return ('fnv1a32:%08x'):format(hash)
end
local function fail(code) return {ok=false,code=code} end
local expectedColumns={
    feather_door_groups={door_id='char',door_key='varchar',label='varchar',manager_resource='varchar',
        status='varchar',locked='tinyint',revision='bigint',delegation_epoch='bigint',startup_policy='varchar',
        created_at='timestamp',updated_at='timestamp'},
    feather_door_leaves={door_hash='bigint',door_id='char',model_hash='bigint',x='double',y='double',z='double',ordinal='tinyint'},
    feather_door_schema_migrations={id='varchar',checksum='varchar',status='varchar',applied_at='timestamp'},
    feather_door_operations={source_resource='varchar',request_id='varchar',request_json='longtext',result_json='longtext',created_at='timestamp'},
    feather_door_outbox={event_id='char',door_id='char',source_resource='varchar',request_id='varchar',event_type='varchar',
        revision='bigint',payload_json='longtext',status='varchar',attempts='int',available_at='timestamp',created_at='timestamp',published_at='timestamp'},
    feather_door_bindings={door_id='char',mode='varchar',link_id='char',property_id='char',property_epoch='bigint',property_status='varchar'}
}
local function knownRows(db)
    local rows=db.query('SELECT `id`,`checksum`,`status` FROM `feather_door_schema_migrations`')
    local known,found={},{}
    for _,migration in ipairs(definitions) do known[migration.id]=migration end
    for _,row in ipairs(rows) do
        local migration=known[row.id]
        if not migration then return nil,'unknown_migration' end
        if row.checksum~=checksum(table.concat(migration.statements,'\n-- next statement --\n')) then
            return nil,'migration_checksum_mismatch'
        end
        if row.status~='applying' and row.status~='applied' then return nil,'invalid_migration_status' end
        found[row.id]=row
    end
    return found
end
function DoorsSchema.Run(db)
    db.exec(ledger)
    local found,err=knownRows(db)
    if not found then return fail(err) end
    local applied,resumed=0,0
    for _,migration in ipairs(definitions) do
        local row=found[migration.id]
        if not row then
            local names={}
            for _,name in ipairs(migration.tables) do names[#names+1]="'"..name.."'" end
            local existing=tonumber(db.value([[SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema=DATABASE() AND table_name IN (]]..table.concat(names,',')..')'))
            if existing~=0 then return fail('untracked_schema') end
            db.exec('INSERT INTO `feather_door_schema_migrations` (`id`,`checksum`,`status`) VALUES (?,?,?)',
                migration.id,checksum(table.concat(migration.statements,'\n-- next statement --\n')),'applying')
        end
        if not row or row.status=='applying' then
            -- DDL auto-commits. Persist intent before DDL for same-checksum replay.
            for _,statement in ipairs(migration.statements) do db.exec(statement) end
            db.exec("UPDATE `feather_door_schema_migrations` SET `status`='applied', `applied_at`=CURRENT_TIMESTAMP WHERE `id`=?",migration.id)
            if row then resumed=resumed+1 else applied=applied+1 end
        end
    end
    return {ok=true,value={version=#definitions,applied=applied,resumed=resumed}}
end
function DoorsSchema.Check(db)
    local found,err=knownRows(db)
    if not found then return fail(err) end
    for _,migration in ipairs(definitions) do
        if not found[migration.id] or found[migration.id].status~='applied' then return fail('migration_incomplete') end
    end
    local tables=tonumber(db.value([[SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema=DATABASE() AND table_name IN ('feather_door_schema_migrations','feather_door_groups','feather_door_leaves','feather_door_operations','feather_door_outbox','feather_door_bindings')
        AND engine='InnoDB']]))
    if tables~=6 then return fail('schema_tables_missing') end
    local columns=db.query([[SELECT table_name AS tableName,column_name AS columnName,data_type AS dataType
        FROM information_schema.columns WHERE table_schema=DATABASE()
        AND table_name IN ('feather_door_schema_migrations','feather_door_groups','feather_door_leaves','feather_door_operations','feather_door_outbox','feather_door_bindings')]])
    local seen,count={},0
    for _,column in ipairs(columns) do
        local expected=expectedColumns[column.tableName]
        if not expected or expected[column.columnName]~=column.dataType then return fail('schema_columns_mismatch') end
        seen[column.tableName..'.'..column.columnName]=true; count=count+1
    end
    for tableName,expected in pairs(expectedColumns) do
        for columnName in pairs(expected) do
            if not seen[tableName..'.'..columnName] then return fail('schema_columns_missing') end
        end
    end
    return {ok=true,value={version=#definitions,tables=tables,columns=count}}
end
