EconomyMigrationRunner = {}

local logger = EconomyLogging.Create('migrations')

local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff end
    return ('fnv1a32:%08x'):format(hash)
end

local function Checksum(migration)
    return Hash(table.concat(migration.statements, '\n-- next statement --\n'))
end
EconomyMigrationRunner.Checksum = Checksum

local function EnsureLedger()
    DB.exec([[
        CREATE TABLE IF NOT EXISTS `economy_schema_migrations` (
          `id` VARCHAR(100) NOT NULL,
          `checksum` VARCHAR(64) NOT NULL,
          `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

-- The economy_* table a CREATE TABLE IF NOT EXISTS statement creates, or nil.
local function CreatedTable(statement)
    local name = statement:upper():match(
        '^%s*CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+`?(ECONOMY_[%w_]+)`?')
    return name and name:lower() or nil
end

local function TableExists(name)
    return (tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=?]], name)) or 0) > 0
end

-- A migration is either one statement, which InnoDB applies atomically, or only
-- CREATE TABLE IF NOT EXISTS statements for economy_* tables, which the runner
-- can undo. Anything else could be left half applied, so it is rejected before
-- any statement runs.
local function Validate(definitions)
    local seen = {}
    for _, migration in ipairs(definitions) do
        local valid = type(migration) == 'table' and type(migration.id) == 'string'
            and migration.id ~= '' and not seen[migration.id]
            and type(migration.statements) == 'table' and #migration.statements > 0
        for _, statement in ipairs(valid and migration.statements or {}) do
            valid = valid and type(statement) == 'string' and statement:match('%S') ~= nil
                and (#migration.statements == 1 or CreatedTable(statement) ~= nil)
        end
        if not valid then
            return EconomyResults.Err('invalid_migration',
                'An Economy migration definition is invalid. A migration is one statement, '
                    .. 'or only CREATE TABLE IF NOT EXISTS statements for economy_* tables.', {
                    migrationId = type(migration) == 'table' and tostring(migration.id) or nil
                })
        end
        seen[migration.id] = true
    end
    return EconomyResults.Ok(true)
end

-- feather-mysql passes the database's own message (`detail`) only with the
-- convar feather_mysql_error_detail; its driverCode is the MySQL name for the
-- error number, which can differ on MariaDB.
local function Reason(failure)
    if type(failure) == 'table' then
        local reason = tostring(failure.message)
        if type(failure.detail) == 'string' then
            reason = reason .. ': ' .. failure.detail
        elseif failure.code == 'DATABASE_ERROR' then
            reason = reason .. ' (set feather_mysql_error_detail true to include the database message)'
        end
        return reason, failure.driverCode, failure.sqlState
    end
    return tostring(failure):match('^[^\n]*'), nil, nil
end

-- Runs one pending migration and records it. On any failure the tables this
-- run created for it are dropped again (newest first), so the migration is
-- retried whole on the next start.
local function Apply(migration, checksum)
    local created, failed, failure = {}, nil, nil
    for index, statement in ipairs(migration.statements) do
        local name, fresh = CreatedTable(statement), false
        local executed, problem = true, nil
        if name then
            local exists
            executed, exists = pcall(TableExists, name)
            if executed then fresh = not exists else problem = exists end
        end
        if executed then executed, problem = pcall(DB.raw, statement) end
        if not executed then
            failed, failure = index, problem
            break
        end
        if fresh then created[#created + 1] = name end
    end
    if not failed then
        local recorded, problem = pcall(DB.insert, [[
            INSERT INTO `economy_schema_migrations` (`id`,`checksum`) VALUES (?,?)
        ]], migration.id, checksum)
        if recorded then return EconomyResults.Ok(true) end
        failed, failure = 'ledger', problem
    end

    local dropped, kept = {}, {}
    for position = #created, 1, -1 do
        local name = created[position]
        if pcall(DB.exec, ('DROP TABLE IF EXISTS `%s`'):format(name)) then
            dropped[#dropped + 1] = name
        else
            kept[#kept + 1] = name
        end
    end
    local reason, driverCode, sqlState = Reason(failure)
    -- Only a recorded-step failure after a lone non-table statement can leave a change behind.
    local unrecorded = failed == 'ledger' and #migration.statements == 1
        and CreatedTable(migration.statements[1]) == nil
    local message = ('Economy migration %s failed at %s; '):format(migration.id,
        failed == 'ledger' and 'recording it in economy_schema_migrations'
            or ('statement %d of %d'):format(failed, #migration.statements))
    if #kept > 0 then
        message = message .. ('drop %s by hand, then fix the cause and restart feather-economy.')
            :format(table.concat(kept, ', '))
    elseif unrecorded then
        message = message .. 'the statement was applied but not recorded; revert it by hand, '
            .. 'then fix the cause and restart feather-economy.'
    else
        message = message .. 'nothing from it was kept. Fix the cause and restart feather-economy.'
    end
    logger.Error('migration.failed', { migrationId = migration.id, statement = failed,
        reason = reason, driverCode = driverCode, dropped = dropped, kept = kept })
    return EconomyResults.Err('migration_failed', message, {
        migrationId = migration.id,
        statement = failed,
        statements = #migration.statements,
        reason = reason,
        driverCode = driverCode,
        sqlState = sqlState,
        droppedTables = dropped,
        keptTables = kept,
        appliedUnrecorded = unrecorded or nil
    })
end

-- Applies pending migrations in id order. `definitions` defaults to every
-- migration file; tests pass their own lists. Every recorded checksum is
-- compared before anything runs, so a changed migration stops startup without
-- applying newer ones.
function EconomyMigrationRunner.Run(definitions)
    local executed, result = xpcall(function()
        local ordered = {}
        for index, migration in ipairs(definitions or EconomyMigrationDefinitions or {}) do
            ordered[index] = migration
        end
        local valid = Validate(ordered)
        if not valid.ok then return valid end
        table.sort(ordered, function(left, right) return left.id < right.id end)

        EnsureLedger()
        local applied = {}
        for _, row in ipairs(DB.query(
            'SELECT `id`, `checksum` FROM `economy_schema_migrations`') or {}) do
            applied[row.id] = row.checksum
        end

        local checksums, known, pending = {}, {}, {}
        for _, migration in ipairs(ordered) do
            local checksum = Checksum(migration)
            checksums[migration.id], known[migration.id] = checksum, true
            if applied[migration.id] and applied[migration.id] ~= checksum then
                return EconomyResults.Err('migration_checksum_mismatch',
                    ('Applied Economy migration %s has changed since it ran. Restore its original '
                        .. 'statements and put the change in a new migration.'):format(migration.id), {
                        migrationId = migration.id,
                        recorded = applied[migration.id],
                        current = checksum
                    })
            end
            if not applied[migration.id] then pending[#pending + 1] = migration end
        end
        -- Recorded migrations this version does not know (a downgrade, or a renamed
        -- development migration). Startup continues; the warning names them.
        local unknown = {}
        for id in pairs(applied) do
            if not known[id] then unknown[#unknown + 1] = id end
        end
        table.sort(unknown)
        if #unknown > 0 then logger.Warn('migration.unknown_recorded', { migrationIds = unknown }) end

        for _, migration in ipairs(pending) do
            logger.Info('migration.applying', { migrationId = migration.id })
            local outcome = Apply(migration, checksums[migration.id])
            if not outcome.ok then return outcome end
        end
        return EconomyResults.Ok({ total = #ordered, applied = #pending, unknown = unknown })
    end, debug.traceback)

    if not executed then
        logger.Error('migration.failed', { reason = tostring(result) })
        return EconomyResults.Err('migration_failed',
            'An Economy database migration failed.', { reason = tostring(result) })
    end
    return result
end

-- Development only: the migration list with one injected fault, for
-- EconomyMigrationFaultTest and the economy_dev_migration_fault convar.
--   checksum  an applied migration is altered and a pending probe must not run
--   failure   a pending probe whose second statement fails
--   invalid   a pending probe that mixes a table statement with another statement
--   probe     a pending probe that succeeds (the test removes it again)
local PROBE_TABLE = 'economy_fault_probe'
local PROBE_ID = '999_fault_probe'
local PROBE_CREATE = 'CREATE TABLE IF NOT EXISTS `economy_fault_probe` (`id` INT NOT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB'
local PROBE_BROKEN = 'CREATE TABLE IF NOT EXISTS `economy_fault_probe_broken` (`id` NOT_A_TYPE NOT NULL) ENGINE=InnoDB'
EconomyMigrationRunner.ProbeTable, EconomyMigrationRunner.ProbeId = PROBE_TABLE, PROBE_ID

function EconomyMigrationRunner.FaultDefinitions(kind)
    if not Config.DevMode then return nil end
    local definitions = {}
    for index, migration in ipairs(EconomyMigrationDefinitions or {}) do definitions[index] = migration end
    if kind == 'checksum' then
        local first = definitions[1]
        local statements = {}
        for index, statement in ipairs(first.statements) do statements[index] = statement end
        statements[1] = statements[1] .. ' '
        definitions[1] = { id = first.id, statements = statements }
        definitions[#definitions + 1] = { id = PROBE_ID, statements = { PROBE_CREATE } }
    elseif kind == 'failure' then
        definitions[#definitions + 1] = { id = PROBE_ID, statements = { PROBE_CREATE, PROBE_BROKEN } }
    elseif kind == 'invalid' then
        definitions[#definitions + 1] = { id = PROBE_ID, statements = { PROBE_CREATE, 'DO 1' } }
    elseif kind == 'probe' then
        definitions[#definitions + 1] = { id = PROBE_ID, statements = { PROBE_CREATE } }
    else
        return nil
    end
    return definitions
end
