Config = {}

Config.Debug = false

-- Defaults (every one can be overridden per call through the options table)
Config.Defaults = {
    rayDistance     = 12.0,  -- how far the camera ray reaches in free mode
    maxDistance     = 10.0,  -- max distance between the player and the prop
    alpha           = 170,   -- ghost transparency (0-255)
    rotation        = 'z',   -- 'z' = heading only, 'all' = pitch / roll / yaw
    snapToGround    = true,  -- free mode sits the prop on the surface hit
    allowInterior   = true,
    allowWater      = false,
    moveSpeed       = 1.5,   -- metres per second in fine mode
    rotateSpeed     = 90.0,  -- degrees per second
    scrollRotate    = 7.5,   -- degrees per wheel tick
    scrollHeight    = 0.05,  -- metres per wheel tick (fine mode)
    precision       = 0.2,   -- multiplier while holding Ctrl
    startMode       = 'free', -- 'free' or 'fine'
    snap            = false, -- start with grid / angle snapping on (toggle in game)
    showRange       = true,  -- draw a ring on the ground showing maxDistance
    maxSlope        = nil,   -- degrees; set (e.g. 25.0) to block steep surfaces. nil = no slope check
    remember        = true,  -- start from the last rotation / mode / snap used for this model by the calling resource
}

-- Grid / angle snapping (toggle with Controls.snap)
Config.Snap = { grid = 0.25, angle = 15.0 }

-- Remember the last placement per calling resource + model (see Defaults.remember)
Config.Remember = true

-- Undo / redo: snapshots kept per session, and the idle time (ms) after which an edit becomes one undo step
Config.History = 30
Config.HistoryDelay = 350

-- Hard limits. They cap whatever maxDistance a calling script asks for (client and server)
-- and reject coords outside the world height range on the server.
Config.Limits = { enabled = true, maxDistance = 30.0, minZ = -250.0, maxZ = 1500.0 }

-- Draw colours (r, g, b, a)
Config.Colours = {
    valid   = { 111, 191, 115, 220 },
    invalid = { 224, 85, 79, 220 },
    axisX   = { 224, 85, 79, 255 },
    axisY   = { 111, 191, 115, 255 },
    axisZ   = { 90, 150, 230, 255 },
    range   = { 255, 255, 255, 70 },
}

-- Control hashes: data/rdr3_discoveries/Controls/README.md
Config.Controls = {
    confirm   = 0x07CE1E61, -- INPUT_ATTACK          (LMB)
    confirm2  = 0xC7B5340A, -- INPUT_FRONTEND_ACCEPT (Enter)
    cancel    = 0xF84FA74F, -- INPUT_AIM             (RMB)
    cancel2   = 0x156F7119, -- INPUT_FRONTEND_CANCEL (Backspace)
    mode      = 0xE30CD707, -- INPUT_RELOAD          (R)  free <-> fine
    ground    = 0x760A9C6F, -- INPUT_INTERACT_OPTION1 (G) snap to ground
    reset     = 0xDE794E3E, -- INPUT_COVER           (Q)  reset rotation
    left      = 0xA65EBAB4, -- INPUT_FRONTEND_LEFT   (Arrow Left)
    right     = 0xDEB34313, -- INPUT_FRONTEND_RIGHT  (Arrow Right)
    up        = 0x6319DB71, -- INPUT_FRONTEND_UP     (Arrow Up)
    down      = 0x05CA7C52, -- INPUT_FRONTEND_DOWN   (Arrow Down)
    scrollUp  = 0xCC1075A7, -- INPUT_PREV_WEAPON     (Scroll Up)
    scrollDn  = 0xFD0F0C2C, -- INPUT_NEXT_WEAPON     (Scroll Down)
    rotate    = 0x8FFC75D6, -- INPUT_SPRINT          (Shift) hold = rotate
    precise   = 0xDB096B85, -- INPUT_DUCK            (Ctrl)  hold = precision
    roll      = 0x9959A6F0, -- INPUT_LOOK_BEHIND     (C)  hold = roll (rotation 'all' only)
    snap      = 0x827E9EE8, -- INPUT_SWITCH_SHOULDER (X)  toggle snapping
    undo      = 0x26E9DC00, -- INPUT_GAME_MENU_TAB_LEFT_SECONDARY (Z)
    redo      = 0x70CBD78D, -- INPUT_DISABLE_RADAR   (V)
}

-- Key captions shown in the HUD (display only: change Config.Controls to change the actual keys)
Config.KeyLabels = {
    confirm = 'LMB', cancel = 'RMB', mode = 'R', ground = 'G', reset = 'Q',
    move = '← ↑ → ↓', rotate = 'Shift', precise = 'Ctrl', roll = 'C', snap = 'X', undo = 'Z', redo = 'V',
}

-- Milliseconds at the start of a session where confirm/cancel are ignored, so the key that
-- opened the gizmo (Enter on a menu, a mouse click) cannot place or cancel it instantly
Config.InputGrace = 250

-- Extra controls blocked while placing
Config.BlockControls = {
    0xB2F377E8, -- INPUT_MELEE_ATTACK
    0xB238FE0B, -- INPUT_TOGGLE_HOLSTER
    0x62800C92, -- INPUT_CURSOR_SCROLL_UP   (wheel alias)
    0x8BDE7443, -- INPUT_CURSOR_SCROLL_DOWN (wheel alias)
    0x81280569, -- INPUT_HORSE_LOOK_BEHIND  (C while mounted)
    0xCF0B11DE, -- INPUT_EXPAND_RADAR       (X)
    0xA5BDCD3C, -- rsg-voice Config.CycleKey (voice range) - change if yours differs
}

-- Admin test commands: /gizmotest [model] and /gizmotestgroup (places the example group below)
Config.TestCommand = {
    enabled = true, name = 'gizmotest', groupName = 'gizmotestgroup', permission = 'admin', model = 'p_chair05x',
    group = {
        { model = 'p_chair05x' },
        { model = 'p_chair05x', offset = vector3(1.0, 0.0, 0.0) },
        { model = 'p_chair05x', offset = vector3(-1.0, 0.0, 0.0), heading = 180.0 },
    },
}
