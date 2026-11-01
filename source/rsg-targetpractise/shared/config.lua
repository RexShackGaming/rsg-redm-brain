Config = {}

Config.Item = 'target'
Config.AdminPermission = 'admin'
Config.FrameModel = 'p_targetframe01x'
Config.FaceModel = 'p_targetarchery02x'

-- Unmodified values from ../props.txt. Geometry derives a LOCAL offset, not a world delta.
Config.Source = {
    frame = { x = -283.261230, y = 699.297668, z = 112.504021 },
    face = { x = -283.060791, y = 699.359131, z = 113.958031 },
    quaternion = { x = 0.051335, y = -0.002622, z = 0.332772, w = 0.941605 }
}

Config.Placement = {
    distance = 2.5,
    maxDistance = 6.0,
    heightRange = 1.0,
    rotationSpeed = 65.0,
    heightSpeed = 0.4,
    maxPerPlayer = 5,
    maxTotal = 100,
    minimumSpacing = 1.5,
    timeoutSeconds = 120
}
Config.StreamDistance = 120.0
Config.RemoveDistance = 3.0
Config.LeaderboardRefreshMs = 2000
Config.ModelTimeoutMs = 10000
Config.PersistTargets = true
Config.StorageFile = 'data/targets.json'

-- Provisional calibration from the reported local impact (0.0201,-0.2734,0.7174).
-- That test impact is not proof of the visible bullseye: verify with /targetdebug.
-- x/z span the face; y is its depth. Values are in model-local metres.
Config.Scoring = {
    mode = 'rings', -- 'rings': points by distance from center. 'hit': one point per confirmed face hit.
    hitSanityDistance = 3.0, -- Broad anti-abuse bound from the face model origin, not a scoring ring.
    center = { x = 0.0, y = -0.2734, z = 0.7174 },
    depthTolerance = 0.25, -- Covers the observed -0.2734 / -0.0645 local depths; face collision is still required.
    bullseyeRadius = 0.06, -- Local X/Z radius that counts as a bullseye.
    bullseyePoints = 10, -- Bullseye award. Rings below handle the rest of the face.
    distanceBonus = { -- Extra points for shooting from further away.
        startDistance = 5.0, -- No bonus inside this range (metres).
        step = 5.0, -- One bonus step per full 5 metres beyond startDistance.
        pointsPerStep = 1, -- Points added for each completed step.
        maxBonus = 20 -- Cap so extreme ranges cannot dwarf the ring score.
    },
    rings = {
        { radius = 0.12, points = 8 },
        { radius = 0.20, points = 6 },
        { radius = 0.30, points = 4 },
        { radius = 0.40, points = 2 }
    },
    minDistance = 2.0,
    maxDistance = 80.0,
    shotWindowMs = 6000,
    shotCooldownMs = 450,
    impactChangeEpsilon = 0.002,
    impactRayDistance = 0.35,
    impactRayTolerance = 0.25
}
-- Scored weapons. Values are locale keys (locales/*.json) used for the display name.
Config.Weapons = {
    WEAPON_BOW = 'weapon_bow',
    WEAPON_BOW_IMPROVED = 'weapon_bow_improved',
    WEAPON_THROWN_THROWING_KNIVES = 'weapon_throwing_knives'
}
-- Used by the leaderboard to separate arrow and knife hits. Unknown weapons fall back to 'other'.
Config.WeaponKinds = {
    WEAPON_BOW = 'arrow',
    WEAPON_BOW_IMPROVED = 'arrow',
    WEAPON_THROWN_THROWING_KNIVES = 'knife'
}
-- Shots only count if the player has the weapon item in their inventory (blocks spoofed shot events).
Config.RequireWeaponItem = true
Config.Debug = false -- Admins can toggle their own debug display with /targetdebug.
Config.DebugImpactMs = 8000
Config.Projectiles = {
    captureDistance = 6.0, -- Adopt a newly observed, moving own knife near its thrower.
    minimumSpeed = 1.0,
    probeExtension = 0.12, -- Metres ahead of the moving object's origin to cover its tip.
    maxStep = 15.0
}

Config.Controls = {
    confirm = 0xC7B5340A, -- Enter / INPUT_FRONTEND_ACCEPT
    cancel = 0x156F7119, -- Backspace / INPUT_FRONTEND_CANCEL
    left = 0xA65EBAB4, -- Left arrow
    right = 0xDEB34313, -- Right arrow
    up = 0x6319DB71, -- Up arrow
    down = 0x05CA7C52 -- Down arrow
}
