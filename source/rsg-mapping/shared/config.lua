Config = {}

Config.Command        = 'imaps'      -- /imaps [radius]  open the nearby IMAP menu
Config.DrawCommand    = 'imapdraw'   -- /imapdraw [radius] toggle 3D labels in the world
Config.DefaultRadius  = 50.0
Config.MaxRadius      = 500.0
Config.MaxResults     = 200          -- max rows rendered in the UI
Config.OnlyAdmins     = true         -- require rsg-core 'admin' permission
Config.AdminPerm      = 'admin'
Config.DrawDistance   = 60.0         -- labels farther than this are hidden
Config.DrawRefresh    = 1000         -- ms between re-scans while labels are on
Config.HighlightSize  = 3.0          -- ring diameter around the selected IMAP
Config.HighlightBeam  = 40.0         -- height of the beam above the selected IMAP
Config.PersistToggles = true         -- enabling/disabling in the UI is saved to the DB and synced to all players
Config.ViewDistance   = 25.0         -- view camera distance from the IMAP
Config.ViewHeight     = 15.0         -- view camera height above the IMAP
Config.ViewOrbitSpeed = 0.25         -- orbit speed (radians/sec), 0 = static
