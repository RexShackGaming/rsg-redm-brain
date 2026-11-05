OrganizationTypes = {}
local catalog = {}

function OrganizationTypes.Load()
    -- Explicit UUID values for MariaDB; stable keys retain UUID identity on restart.
    for _, definition in ipairs(Config.Types) do
        local existing = DB.one('SELECT `owner_resource` FROM `feather_organization_types` WHERE `type_key`=?', definition.key)
        if existing and existing.owner_resource ~= GetCurrentResourceName() then
            return Organizations.Err('type_owner_conflict', 'Configured type belongs to another resource.')
        end
        DB.exec([[INSERT INTO `feather_organization_types`
            (`organization_type_id`,`type_key`,`label`,`owner_resource`) VALUES (UUID(),?,?,?)
            ON DUPLICATE KEY UPDATE
                `revision`=`revision` + IF(`label` <> VALUES(`label`),1,0),
                `label`=VALUES(`label`)]], definition.key, definition.label, GetCurrentResourceName())
    end
    local rows = DB.query([[SELECT `organization_type_id`,`type_key`,`label`,`status`,`revision`
        FROM `feather_organization_types` ORDER BY `type_key` LIMIT 33]]) or {}
    if #rows > 32 then return Organizations.Err('type_catalog_limit', 'Type catalog exceeds the foundation limit of 32.') end
    local loaded = {}
    for _, row in ipairs(rows) do
        if not Organizations.Uuid(row.organization_type_id)
            or (row.status ~= 'active' and row.status ~= 'retired')
            or not Organizations.Integer(tonumber(row.revision), 1, 9007199254740991) then
            return Organizations.Err('invalid_persistence', 'Persisted type identity/status/revision is invalid.')
        end
        loaded[row.type_key] = { organizationTypeId = row.organization_type_id,
            key = row.type_key, label = row.label, status = row.status, revision = tonumber(row.revision) }
    end
    catalog = loaded
    return Organizations.Ok({ types = #rows })
end
function OrganizationTypes.Get(key, resource)
    local allowed = Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(key) ~= 'string' or #key > 48 or not key:match('^[a-z][a-z0-9_]*$') then
        return Organizations.Err('invalid_input', 'Valid type key required.')
    end
    if not catalog[key] then return Organizations.Err('type_not_found', 'Organization type not found.') end
    return Organizations.Ok(Organizations.Copy(catalog[key]))
end
function OrganizationTypes.List(resource)
    local allowed = Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local result = {}
    for _, definition in pairs(catalog) do result[#result + 1] = Organizations.Copy(definition) end
    table.sort(result, function(left, right) return left.key < right.key end)
    return Organizations.Ok(result)
end
exports('GetOrganizationType', function(key) return OrganizationTypes.Get(key, GetInvokingResource()) end)
exports('ListOrganizationTypes', function() return OrganizationTypes.List(GetInvokingResource()) end)
