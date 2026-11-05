-- Deliberately not loaded by the live manifest yet. SQL is executed using the
-- Inventory transaction's bound query(sql, paramsTable), never another DB
-- connection. Transaction ownership, authorization and commit belong to caller.
CharacterAmmunitionRepository = {}
local R = CharacterAmmunitionRepository
local function character(id)
    assert(type(id) == 'string' and id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'),
        'Character UUID required')
    return id
end
function R.Lock(query, characterId)
    local rows = query('SELECT character_id, revision, pools, migrated_at FROM feather_character_ammunition WHERE character_id = ? FOR UPDATE',
        { character(characterId) })
    if not rows or not rows[1] then return nil, 'not_enrolled' end
    local row = rows[1]
    local ok, pools = pcall(json.decode, row.pools)
    if not ok or type(pools) ~= 'table' then return nil, 'corrupt_persistence' end
    return { characterId = row.character_id, revision = tonumber(row.revision),
        pools = pools, migratedAt = row.migrated_at }
end
function R.Create(query, characterId, pools)
    -- Duplicate enrollment must abort, not silently overwrite or sum again.
    return query('INSERT INTO feather_character_ammunition (character_id, revision, pools, migrated_at) VALUES (?, 0, ?, CURRENT_TIMESTAMP)',
        { character(characterId), json.encode(pools) })
end
function R.Write(query, record, expectedRevision)
    assert(record.revision == expectedRevision + 1, 'Revision must advance once')
    local result = query('UPDATE feather_character_ammunition SET pools = ?, revision = ? WHERE character_id = ? AND revision = ?',
        { json.encode(record.pools), record.revision, character(record.characterId), expectedRevision })
    return type(result) == 'table' and result.affectedRows == 1
end
function R.Receipt(query, characterId, operationId)
    local rows = query('SELECT result FROM feather_ammunition_operations WHERE character_id = ? AND operation_id = ? FOR UPDATE',
        { character(characterId), operationId })
    if not rows or not rows[1] then return nil end
    local ok, result = pcall(json.decode, rows[1].result)
    if not ok then error('Corrupt ammunition operation receipt') end
    return result
end
function R.RecordReceipt(query, characterId, operationId, result)
    assert(type(operationId) == 'string' and #operationId > 0 and #operationId <= 64,
        'Bounded operation ID required')
    return query('INSERT INTO feather_ammunition_operations (character_id, operation_id, result) VALUES (?, ?, ?)',
        { character(characterId), operationId, json.encode(result) })
end
