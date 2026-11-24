Config = {}

-- reputation (needs rsg-reputation; action 'arrest' is defined in its Config.Actions)
Config.Reputation = {
    Enabled    = true,
    Action     = 'arrest',
    MinMinutes = 1,    -- jail time needed to count
    Cooldown   = 600,  -- seconds before the same lawman is rewarded again for the same target
}

-- settings
Config.AddGPSRoute = true
Config.AlertTimer = 60               -- seconds an alert blip stays on the map
Config.Keybind = 'J'
Config.StorageMaxWeight = 4000000
Config.StorageMaxSlots = 50
Config.ArmouryAccessGrade = 1        -- and greater than
Config.EnablePlayerDeathAlerts = false
Config.EnableNPCDeathAlerts = false
Config.AlertCooldown = 30000         -- ms between automatic (death) alerts from the same player
Config.AlertDistance = 100.0         -- NPC death alerts only within this distance of the player

-- law actions (all re-checked on the server)
Config.RequireOnDuty = true          -- cuff, escort, search, jail and unjail need the lawman to be on duty
Config.ActionDistance = 4.0          -- max server-side distance between lawman and target (cuff / escort)
Config.JailDistance = 10.0           -- max distance for /jail and the jail dialog (0 = no distance check)
Config.MaxJailTime = 180             -- longest sentence (minutes) a lawman can hand out
Config.CuffFreezePlayer = false      -- true = every cuff is a hard cuff (frozen). Otherwise /cuff = soft (can walk), /cuff hard = frozen

-- searching other players
Config.SearchTime = 10000            -- ms progress bar before the inventory opens (0 = instant)
Config.SearchDistance = 2.5
Config.SearchRequireRestrained = true  -- target must be cuffed, dead, down, hands up, hogtied or lassoed (checked on the server)

-- rebindable key (RegisterKeyMapping through rsg-core). Leave the key empty to leave it unbound until the player binds it in the game's key settings.
Config.UseKeyMapping = true
Config.JailNearKey = ''              -- default key for "jail the closest player" (same as /jailnear)

-- frisk: pat down the closest player and seize weapons / contraband (/frisk)
Config.Frisk = {
    Enabled = true,
    RequireRestrained = true,        -- same rule as searching
    Weapons = true,                  -- list every item whose shared type is 'weapon'...
    IgnoreCategories = { tools = true, fishing = true }, -- ...except these shared item categories (binoculars, fishing rod)
    ExtraItems = {},                 -- extra contraband item names, e.g. { moonshine = true }
    MaxListed = 10,
}

-- fines through rsg-society (/fine). The fine goes to the society named like the lawman's job.
Config.Fines = {
    Enabled = true,
    MaxReasonLength = 100,
}

-- /911: any player can report a crime to the on-duty law
Config.Report = {
    Enabled = true,
    Cooldown = 120,                  -- seconds between reports per player
    MaxLength = 100,
}

-- alert types: sprite = blip sprite, scale / ringScale = blip sizes, timer = seconds (falls back to Config.AlertTimer), notify = notification type
-- 'default' is used when no type (or an unknown one) is sent. Add your own and pass the name as the last argument of SendAlert.
Config.AlertTypes = {
    default = { sprite = 'blip_ambient_law',     scale = 0.8, ringScale = 2.0, notify = 'inform' },
    gunshot = { sprite = 'blip_ambient_law',     scale = 0.8, ringScale = 3.0, notify = 'warning', timer = 40 },
    death   = { sprite = 'blip_ambient_law',     scale = 0.9, ringScale = 2.0, notify = 'error' },
    report  = { sprite = 'blip_ambient_sheriff', scale = 0.8, ringScale = 2.0, notify = 'inform', timer = 120 },
}

-- gunshot alerts: players who are not law and fire a weapon inside a town alert the law
Config.GunshotAlerts = {
    Enabled = false,
    TownRadius = 250.0,              -- distance from a Config.AlertTowns entry that counts as "in town"
    Cooldown = 45000,                -- ms between gunshot alerts per player
}

-- wanted level (players.outlawstatus) cools down over time for everyone
Config.OutlawDecay = {
    Enabled = false,
    Interval = 30,                   -- minutes
    Amount = 1,
}

-- holding cells, one per law office job (key = the office jobaccess). Leave empty to disable /holdcell.
-- ['vallaw'] = { cell = vector4(x, y, z, heading), release = vector4(x, y, z, heading), minutes = 5 },
Config.HoldingCells = {}

-- discord log of arrests, fines, seizures and cell holds (a webhook URL is required)
Config.Discord = {
    Enabled = false,
    Webhook = '',
    Username = 'rsg-lawman',
    Avatar = '',
    Color = 9807270,
}

-- nearest town names used in automatic death alerts
Config.AlertTowns = {
    ['Saint Denis'] = vector3(2683.0, -1455.0, 46.0),
    ['Valentine']   = vector3(-283.0, 805.0, 119.0),
    ['Blackwater']  = vector3(-875.0, -1328.0, 43.0),
    ['Rhodes']      = vector3(1359.0, -1299.0, 77.0),
    ['Annesburg']   = vector3(2913.0, 1311.0, 44.0),
    ['Strawberry']  = vector3(-1826.0, -420.0, 160.0),
    ['Tumbleweed']  = vector3(-5517.0, -2940.0, -2.0),
    ['Armadillo']   = vector3(-3743.0, -2595.0, -13.0),
    ['Van Horn']    = vector3(2985.0, 571.0, 44.0),
}
Config.AlertWilderness = 'Wilderness'

-- Law Office Prompt Locations
Config.LawOfficeLocations =
{
    { -- valentine
        name = 'Lawman Office',
        prompt = 'vallawoffice',
        coords = vector3(-278.42, 805.29, 119.38),
        jobaccess = 'vallaw',
        blipsprite = 'blip_ambient_sheriff',
        blipscale = 0.2,
        showblip = true
    },
    { -- rhodes
        name = 'Lawman Office',
        prompt = 'rholawoffice',
        coords = vector3(1362.04, -1302.10, 77.77),
        jobaccess = 'rholaw',
        blipsprite = 'blip_ambient_sheriff',
        blipscale = 0.2,
        showblip = true
    },
    { -- blackwater
        name = 'Lawman Office',
        prompt = 'blklawoffice',
        coords = vector3(-761.76, -1268.18, 44.04),
        jobaccess = 'blklaw',
        blipsprite = 'blip_ambient_sheriff',
        blipscale = 0.2,
        showblip = true
    },
    { -- strawberry
        name = 'Lawman Office',
        prompt = 'strlawoffice',
        coords = vector3(-1811.95, -353.94, 164.65),
        jobaccess = 'strlaw',
        blipsprite = 'blip_ambient_sheriff',
        blipscale = 0.2,
        showblip = true
    },
    { -- saint denis
        name = 'Lawman Office',
        prompt = 'stdenlawoffice',
        coords = vector3(2507.72, -1301.89, 48.95),
        jobaccess = 'stdenlaw',
        blipsprite = 'blip_ambient_sheriff',
        blipscale = 0.2,
        showblip = true
    },
}

-- While NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
