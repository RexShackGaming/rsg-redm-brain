Config = Config or {}

Config.RobDistance = 2.5
Config.CuffDistance = 1.5
Config.ConsumeHandcuffs = false
Config.RobCooldown = 30000
Config.HandcuffItem = 'handcuffs'
Config.AutoUncuffTime = 120000

-- rsg-reputation integration (optional: ignored when rsg-reputation is not started).
-- A successful robbery of another player is reported as this rsg-reputation action (honor/standing amounts
-- come from rsg-reputation's Config.Actions). No region is passed, so only honor changes.
Config.Reputation = {
    Enabled = true,
    Action  = 'robbery',
}
