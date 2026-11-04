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
}

-- Draw colours (r, g, b, a)
Config.Colours = {
    valid   = { 111, 191, 115, 220 },
    invalid = { 224, 85, 79, 220 },
    axisX   = { 224, 85, 79, 255 },
    axisY   = { 111, 191, 115, 255 },
    axisZ   = { 90, 150, 230, 255 },
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
}

-- Extra controls blocked while placing
Config.BlockControls = {
    0xB2F377E8, -- INPUT_MELEE_ATTACK
    0xB238FE0B, -- INPUT_TOGGLE_HOLSTER
    0x62800C92, -- INPUT_CURSOR_SCROLL_UP   (wheel alias)
    0x8BDE7443, -- INPUT_CURSOR_SCROLL_DOWN (wheel alias)
    0xA5BDCD3C, -- rsg-voice Config.CycleKey (voice range) - change if yours differs
}

-- Admin test command: /gizmotest [model]
Config.TestCommand = { enabled = true, name = 'gizmotest', permission = 'admin', model = 'p_chair05x' }
