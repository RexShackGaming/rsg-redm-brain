ContractsMigrationRunner = {}

local logger = ContractsLogging.Create('migrations')

local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff end
    return ('fnv1a32:%08x'):format(hash)
end

local function EnsureLedger()
    DB.exec([[
        CREATE TABLE IF NOT EXISTS `contract_schema_migrations` (
          `id` VARCHAR(100) NOT NULL,
          `checksum` VARCHAR(64) NOT NULL,
          `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

function ContractsMigrationRunner.Run()
    local executed, result = xpcall(function()
        EnsureLedger()
        local rows = DB.query(
            'SELECT `id`, `checksum` FROM `contract_schema_migrations`') or {}
        local applied = {}
        for _, row in ipairs(rows) do applied[row.id] = row.checksum end

        local definitions = ContractsMigrationDefinitions or {}
        table.sort(definitions, function(left, right) return left.id < right.id end)
        local seen, appliedCount = {}, 0
        for _, migration in ipairs(definitions) do
            if type(migration.id) ~= 'string' or migration.id == ''
                or type(migration.statements) ~= 'table' or #migration.statements == 0
                or seen[migration.id] then
                return ContractsResults.Err('invalid_migration',
                    'A Contracts migration definition is invalid.')
            end
            seen[migration.id] = true
            local checksum = Hash(table.concat(migration.statements,
                '\n-- next statement --\n'))
            if applied[migration.id] and applied[migration.id] ~= checksum then
                return ContractsResults.Err('migration_checksum_mismatch',
                    'An applied Contracts migration has changed.', {
                        migrationId = migration.id
                    })
            end
            if not applied[migration.id] then
                logger.Info('migration.applying', { migrationId = migration.id })
                for _, statement in ipairs(migration.statements) do
                    DB.raw(statement)
                end
                DB.insert([[
                    INSERT INTO `contract_schema_migrations` (`id`,`checksum`) VALUES (?,?)
                ]], migration.id, checksum)
                appliedCount = appliedCount + 1
            end
        end
        return ContractsResults.Ok({ total = #definitions, applied = appliedCount })
    end, debug.traceback)

    if not executed then
        logger.Error('migration.failed', { reason = tostring(result) })
        return ContractsResults.Err('migration_failed',
            'A Contracts database migration failed.', { reason = tostring(result) })
    end
    return result
end
