MedicalMigration = {}

function MedicalMigration.Run()
    local checksum = DB.value('SELECT SHA2(?, 256)', table.concat(MedicalSchema.statements, '\n-- statement boundary --\n'))
    assert(type(checksum) == 'string' and #checksum == 64, 'Medical schema checksum unavailable')
    DB.exec([[CREATE TABLE IF NOT EXISTS fm_schema_migrations (
        version INT UNSIGNED NOT NULL PRIMARY KEY,
        checksum CHAR(64) NOT NULL,
        applied_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ) ENGINE=InnoDB]])
    local installed = DB.one('SELECT checksum FROM fm_schema_migrations WHERE version = ?', MedicalSchema.version)
    if installed then
        assert(installed.checksum == checksum, 'Medical schema drift: installed checksum differs')
        return false
    end
    -- DDL implicitly commits. Resume idempotent statements after failure; record
    -- the version only after every statement succeeds. Do not edit installed v1.
    for _, statement in ipairs(MedicalSchema.statements) do DB.exec(statement) end
    DB.insert('INSERT INTO fm_schema_migrations (version, checksum) VALUES (?, ?)', MedicalSchema.version, checksum)
    return true
end
