Config = {}

-- Tables are created automatically on start. Set to false to import install.sql manually.
Config.AutoDatabase = true

-- While the NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- Chat command that opens the reputation panel ('' to disable)
Config.Command = 'reputation'

-- Permission level needed for the admin commands
Config.AdminPermission = 'admin'

-- Small "+5 Honor" / "-8 Valentine standing" notifications on every change (a new one replaces the old one)
Config.NotifyChanges = true
-- Notification when a player moves into a new honor or standing tier
Config.NotifyTierChange = true

-- Seconds between database saves of changed reputations (also saved on logout)
Config.SaveInterval = 60

-- Safety cap on the size of a single change made through AddHonor / AddStanding
Config.MaxChangePerCall = 200

------------------------------------------
-- Honor: one score per character, how honorable they are overall.
-- Tiers: the highest entry whose `min` the score has reached. label = locale key (plain text works too).
------------------------------------------
Config.Honor = {
    Min = -1000,
    Max = 1000,
    Start = 0,
    -- pulls the score back toward 0 by PerDay for every full day (works while the player is offline too)
    Decay = { Enabled = false, PerDay = 5 },
    Tiers = {
        { min = -1000, label = 'honor_notorious' },
        { min = -600,  label = 'honor_outlaw' },
        { min = -200,  label = 'honor_scoundrel' },
        { min = -50,   label = 'honor_drifter' },
        { min = 50,    label = 'honor_decent' },
        { min = 400,   label = 'honor_honorable' },
        { min = 750,   label = 'honor_exemplary' },
    },
}

------------------------------------------
-- Standing: one score per character per region, how a town or state sees them.
-- Below 0 is infamy, above 0 is fame. Tier fields:
--   priceModifier  fraction added to prices (0.10 = 10% dearer, -0.05 = 5% cheaper). Read with GetPriceModifier.
--   hostile        true = lawmen and townsfolk should treat the player as hostile. Read with IsHostile.
------------------------------------------
Config.Standing = {
    Min = -100,
    Max = 100,
    Start = 0,
    -- a change in a town also moves its state by this fraction (0 = never), rounded toward zero
    ParentSpill = 0.5,
    -- infamy and fame fade back toward 0 by PerDay for every full day
    Decay = { Enabled = true, PerDay = 2 },
    Tiers = {
        { min = -100, label = 'standing_hated',     priceModifier = 0.25,  hostile = true },
        { min = -50,  label = 'standing_disliked',  priceModifier = 0.10 },
        { min = -15,  label = 'standing_neutral',   priceModifier = 0.0 },
        { min = 15,   label = 'standing_liked',     priceModifier = -0.05 },
        { min = 50,   label = 'standing_respected', priceModifier = -0.10 },
        { min = 85,   label = 'standing_celebrated', priceModifier = -0.15 },
    },
}

------------------------------------------
-- Regions (same ids as rsg-economy). label = plain text or locale key.
-- type 'state' or 'town'. A town's `parent` is the state that receives the spill-over.
------------------------------------------
Config.Regions = {
    new_hanover     = { label = 'New Hanover',     type = 'state', order = 10 },
    valentine       = { label = 'Valentine',       type = 'town', parent = 'new_hanover',     order = 11 },
    annesburg       = { label = 'Annesburg',       type = 'town', parent = 'new_hanover',     order = 12 },
    van_horn        = { label = 'Van Horn',        type = 'town', parent = 'new_hanover',     order = 13 },
    lemoyne         = { label = 'Lemoyne',         type = 'state', order = 20 },
    rhodes          = { label = 'Rhodes',          type = 'town', parent = 'lemoyne',         order = 21 },
    saint_denis     = { label = 'Saint Denis',     type = 'town', parent = 'lemoyne',         order = 22 },
    west_elizabeth  = { label = 'West Elizabeth',  type = 'state', order = 30 },
    strawberry      = { label = 'Strawberry',      type = 'town', parent = 'west_elizabeth',  order = 31 },
    blackwater      = { label = 'Blackwater',      type = 'town', parent = 'west_elizabeth',  order = 32 },
    new_austin      = { label = 'New Austin',      type = 'state', order = 40 },
    armadillo       = { label = 'Armadillo',       type = 'town', parent = 'new_austin',      order = 41 },
    tumbleweed      = { label = 'Tumbleweed',      type = 'town', parent = 'new_austin',      order = 42 },
    ambarino        = { label = 'Ambarino',        type = 'state', order = 50 },
    guarma          = { label = 'Guarma',          type = 'state', order = 60 },
}

------------------------------------------
-- Actions: named changes other scripts apply with ApplyAction(src, 'name', region?).
-- Tune the numbers here instead of editing the scripts that report the event.
-- standing only applies when the calling script passes a region.
------------------------------------------
Config.Actions = {
    theft            = { honor = -8,  standing = -8 },
    robbery          = { honor = -15, standing = -15 },
    murder           = { honor = -40, standing = -30 },
    bounty_delivered = { honor = 5,   standing = 5 },
    outlaw_killed    = { honor = 8,   standing = 6 },
    arrest           = { honor = 3,   standing = 4 },
    helped_lawman    = { honor = 5,   standing = 4 },
    revive           = { honor = 5,   standing = 3 },
    donation         = { honor = 3,   standing = 5 },
    delivery         = { honor = 0,   standing = 2 },
    gang_territory   = { honor = -3,  standing = -5 }, -- a gang claims turf in a town (rsg-gangs)
}
