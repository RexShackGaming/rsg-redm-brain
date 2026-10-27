local DBService <const> = {
    GET = {
        SHARED_INVENTORY = function(inventoryId, cb)
            MySQL.query("SELECT ci.character_id, ic.id, i.item, ci.amount, ic.metadata, ci.created_at, ci.degradation, ci.percentage, ic.durability FROM items_crafted ic\
		LEFT JOIN character_inventories ci on ic.id = ci.item_crafted_id\
		LEFT JOIN items i on ic.item_id = i.id WHERE ci.inventory_type = @invType;", { invType = inventoryId }, function(result)
                cb(result or {})
            end)
        end,
        INVENTORY = function(charIdentifier, inventoryId, cb)
            MySQL.query("SELECT ic.id, i.item, ci.amount, ic.metadata, ci.created_at, ci.character_id, ci.degradation, ic.durability FROM items_crafted ic\
            LEFT JOIN character_inventories ci on ic.id = ci.item_crafted_id\
            LEFT JOIN items i on ic.item_id = i.id WHERE ci.inventory_type = @invType AND ci.character_id = @charid;", { invType = inventoryId, charid = charIdentifier }, function(result)
                cb(result or {})
            end)
        end,
    },
    SET = {
        ITEM_AMOUNT = function(sourceCharIdentifier, itemCraftedId, amount)
            MySQL.update.await("UPDATE character_inventories SET amount = @amount WHERE character_id = @charid AND item_crafted_id = @itemid;", {
                amount = tonumber(amount),
                charid = tonumber(sourceCharIdentifier),
                itemid = tonumber(itemCraftedId)
            })
        end,
        ITEM_METADATA = function(sourceCharIdentifier, itemCraftedId, metadata)
            MySQL.update("UPDATE items_crafted SET metadata = @metadata WHERE character_id = @charid AND id = @itemid;", {
                metadata = json.encode(metadata),
                charid = tonumber(sourceCharIdentifier),
                itemid = tonumber(itemCraftedId)
            })
        end,
        ITEM_DURABILITY = function(sourceCharIdentifier, itemCraftedId, durability)
            MySQL.update("UPDATE items_crafted SET durability = @durability WHERE character_id = @charid AND id = @itemid;", {
                durability = tonumber(durability),
                charid = tonumber(sourceCharIdentifier),
                itemid = tonumber(itemCraftedId)
            })
        end,
    },

    DELETE = {
        ITEM = function(sourceCharIdentifier, itemCraftedId)
            local queries <const> = {
                {
                    query = "DELETE FROM character_inventories WHERE character_id = ? AND item_crafted_id = ?",
                    values = { tonumber(sourceCharIdentifier), tonumber(itemCraftedId) }
                },
                {
                    query = "DELETE FROM items_crafted WHERE id = ?",
                    values = { tonumber(itemCraftedId) }
                }
            }
            MySQL.transaction.await(queries)
        end,
    },

    CREATE = {
        ITEM = function(sourceCharIdentifier, itemId, amount, metadata, name, degradation, durability, cb, invId)
            local resultId <const> = MySQL.insert.await("INSERT INTO items_crafted (character_id, item_id, metadata,item_name, durability) VALUES (@charid, @itemid, @metadata,@item_name, @durability);", {
                charid = tonumber(sourceCharIdentifier),
                itemid = tonumber(itemId),
                metadata = json.encode(metadata),
                item_name = name,
                durability = durability,
            })

            MySQL.insert.await("INSERT INTO character_inventories (character_id, item_crafted_id, amount, inventory_type,item_name, degradation) VALUES (@charid, @itemid, @amount, @invId,@item_name, @degradation);", {
                charid = tonumber(sourceCharIdentifier),
                itemid = resultId,
                amount = tonumber(amount),
                invId = invId or "default",
                item_name = name,
                degradation = degradation,
            })
            cb({ id = resultId })
        end,
    },

    SECONDARY = {
        GET_TOTAL_ITEMS = function(invId)
            local result = MySQL.query.await("SELECT SUM(amount) as total_amount FROM character_inventories WHERE inventory_type = @invType;", { invType = invId })
            if result[1] and result[1].total_amount then
                return result[1].total_amount
            end
            return 0
        end,
        GET_TOTAL_WEAPONS = function(invId)
            local result = MySQL.query.await("SELECT COUNT(*) as total_count FROM loadout WHERE curr_inv = @invType", { invType = invId })
            if result[1] and result[1].total_count then
                return result[1].total_count
            end
            return 0
        end,
    },

    ASYNC = {
        UPDATE = function(query, params, cb)
            MySQL.update(query, params, cb)
        end,

        INSERT = function(query, params, cb)
            MySQL.insert(query, params, cb)
        end,
        DELETE = function(query, params, cb)
            MySQL.query(query, params, cb)
        end,
        QUERY = function(query, params, cb)
            MySQL.query(query, params, cb)
        end,

    },

    AWAIT = {
        QUERY = function(query, params)
            local res = MySQL.query.await(query, params)
            return res
        end,
    },
}

DB_SERVICE = DBService
