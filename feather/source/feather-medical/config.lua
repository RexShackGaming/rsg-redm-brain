Config = Config or {}
-- Server-owner settings. Restart Medical after changing this file.
-- Durations are configurable; recovery selects the nearest enabled hospital.
Config.medical = {
    enabled = true,
    -- Keep true to prevent logout/reconnect from reviving a dead character.
    -- Setting false intentionally lets fresh activation clear death and revive.
    persistentDeath = true,
    lethalMode = 'dead',
    bleedOutSeconds = 60,
    doctorDelaySeconds = 120,
    -- Named Toolkit control. The panel never takes NUI focus.
    respawnKey = 'E',
    temporarySpawnEnabled = true,
    temporarySpawnPoint = 'valentine'
}

-- Owner-provided hospital locations. Empty uses the temporary Character
-- spawn only when temporarySpawnEnabled is true. Each entry needs:
-- id (unique string), label, x, y, z, heading (numbers), enabled (optional bool).
Config.hospitals = {
    {id = 'valentine', label = 'Valentine', x = -286.013, y = 806.890, z = 119.386, heading = 245.806, enabled = true},
    {id = 'saint-denis', label = 'Saint Denis', x = 2731.918, y = -1231.263, z = 50.370, heading = 73.324, enabled = true},
    {id = 'rhodes', label = 'Rhodes', x = 1369.666, y = -1310.896, z = 77.938, heading = 136.157, enabled = true},
    {id = 'strawberry', label = 'Strawberry', x = -1804.731, y = -430.417, z = 158.832, heading = 53.766, enabled = true},
    {id = 'blackwater', label = 'Blackwater', x = -791.369, y = -1304.758, z = 43.632, heading = 91.226, enabled = true},
    {id = 'armadillo', label = 'Armadillo', x = -3647.573, y = -2602.567, z = -13.164, heading = 181.126, enabled = true}
}
