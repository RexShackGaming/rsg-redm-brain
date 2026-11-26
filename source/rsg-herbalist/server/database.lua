----------------------------------------------------------------------------
-- Saved server state (MySQL, not resource KVP, so no server "db" folder)
----------------------------------------------------------------------------

local CREATE_SQL = [[
CREATE TABLE IF NOT EXISTS `rsg_herbalist_state` (
  `key` VARCHAR(50) NOT NULL,
  `value` LONGTEXT NOT NULL,
  PRIMARY KEY (`key`)
)]]

-- cb(raw|nil) runs once the database is ready. If a query fails cb never runs,
-- so callers stay "not loaded" and don't overwrite what is stored.
function Herbalist.LoadState(key, cb)
    MySQL.ready(function()
        if Config.AutoDatabase then MySQL.query.await(CREATE_SQL) end
        cb(MySQL.scalar.await('SELECT `value` FROM rsg_herbalist_state WHERE `key` = ?', { key }))
    end)
end

function Herbalist.SaveState(key, data)
    MySQL.prepare('INSERT INTO rsg_herbalist_state (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', { key, json.encode(data) })
end
