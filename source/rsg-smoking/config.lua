Config = {}

---------------------------------
-- prompt keys
---------------------------------
Config.Prompts = {
    DropKey   = 0x3B24C470, -- drop / put away / spit
    SmokeKey  = 0x07B8BEAF, -- smoke / chew (tap = short drag, hold = long drag)
    ChangeKey = 0xD51B784F, -- change stance
}

---------------------------------
-- behaviour
---------------------------------
Config.LongDragHoldTime = 500   -- ms the smoke key must be held for a long drag (cigarettes)
Config.DropDespawnTime  = 15000 -- ms a dropped cigarette stays on the ground before it is removed (0 = remove at once)

---------------------------------
-- stress relief (applied by the server through rsg-hud when a smoke starts)
---------------------------------
Config.CigaretteRelieveStress = 5
Config.CigarRelieveStress     = 5
Config.PipeRelieveStress      = 5
Config.ChewingRelieveStress   = 5

---------------------------------
-- coughing
-- After a drag there is a chance to cough when the player is worn out: stamina or health core at or
-- below the limits. Cosmetic only (an animation), nothing is taken from the player.
---------------------------------
Config.Cough = {
    Enabled      = true,
    Chance       = 35, -- % per drag while the player is below a limit
    StaminaBelow = 25, -- stamina core value (0-100)
    HealthBelow  = 25, -- health core value (0-100)
}

---------------------------------
-- cigarette pack
-- The pack is a single non-stacking item ('cigarettes'). Its remaining cigarettes are stored in the
-- item info under `key`, which rsg-inventory shows in the item details. A pack with no info counts as
-- full, so shops and other scripts can simply add 'cigarettes' with no metadata. The pack is removed
-- when the last cigarette is smoked.
---------------------------------
Config.CigarettesPerPack = 20
Config.ChewsPerTin       = 10 -- chews in a full 'chewingtobacco' tin (same system as the pack)

-- Old pack items from before the single-pack change. When enabled, using one converts it into a
-- 'cigarettes' pack holding the remaining cigarettes (number = cigarettes the old pack held).
Config.ConvertLegacyPacks = true
Config.LegacyPacks = {
    cigarette10 = 10, cigarette9 = 9, cigarette8 = 8, cigarette7 = 7, cigarette6 = 6,
    cigarette5  = 5,  cigarette4 = 4, cigarette3 = 3, cigarette2 = 2, cigarette1 = 1,
}

---------------------------------
-- lighters
-- Smokables with `lighter = true` need one of these items. They are checked in this order.
-- uses       : the item is a box with that many lights (info.<key>, removed when empty). Leave nil for
--              an item that is never used up
-- key        : info field that stores the lights left (shown in the item details)
-- failChance : % chance a light fails. The light is still spent, the smoke is not
-- warnAt     : tell the owner how many lights are left once this few remain
---------------------------------
Config.LighterItems = { 'matchbox' }
Config.Lighters = {
    matchbox = { uses = 30, key = 'matches', failChance = 8, warnAt = 5 },
}

---------------------------------
-- share a light
-- A player without a lighter who tries to smoke can ask for a light. For 'Timeout' seconds other
-- players within 'Distance' who carry a lighter get an "Offer a light" option on them (rsg-target).
-- Offering spends one light from the giver's lighter and starts the smoke for the one who asked.
---------------------------------
Config.ShareLight = {
    Enabled       = true,
    Distance      = 3.0, -- metres, checked on the server
    Timeout       = 30,  -- seconds a request for a light stays open
    OfferCooldown = 2,   -- seconds between offers from the same player
}

---------------------------------
-- nicotine addiction (optional, needs rsg-drugs)
-- Smoking calls rsg-drugs AddUse for `Substance`. rsg-drugs only knows alcohol and weed, so add a
-- tobacco substance to its config first: see installation/rsg-drugs_tobacco.lua. Until then AddUse
-- is refused and nothing happens (one warning is printed).
---------------------------------
Config.Nicotine = {
    Enabled      = false,
    Substance    = 'tobacco', -- key in rsg-drugs Config.Addiction.Substances
    BlockInRehab = true,      -- smoking is refused while the player is in rehab
    Amount = {                -- dependency gained per use (0-100 scale)
        cigarette      = 4,
        cigar          = 6,
        pipe           = 4,
        chewingtobacco = 5,
    },
}

---------------------------------
-- usable items
-- kind     : cigarette | cigar | pipe | chewingtobacco
-- lighter  : needs a lighter from Config.LighterItems (see above)
-- requires : other items the player must also be carrying (not consumed)
-- consume  : item removed on use (defaults to the item being used)
-- uses     : item is a multi-use pack; one use is taken per smoke (maximum = this value)
-- key      : info field that stores the uses left (packs)
-- leftMsg / emptyMsg : locale keys for "uses left" / "finished" (default pack_left / pack_empty)
-- legacy   : old pack item holding this many cigarettes, converted to 'cigarettes' on use
---------------------------------
Config.Smokables = {
    cigarettes     = { kind = 'cigarette', lighter = true, uses = Config.CigarettesPerPack, key = 'cigarettes' },
    cigar          = { kind = 'cigar',     lighter = true },
    pipe           = { kind = 'pipe',      lighter = true, requires = { 'pipetobacco' }, consume = 'pipetobacco' },
    chewingtobacco = { kind = 'chewingtobacco', uses = Config.ChewsPerTin, key = 'chews', leftMsg = 'chew_left', emptyMsg = 'chew_empty' },
}

if Config.ConvertLegacyPacks then
    for itemName, count in pairs(Config.LegacyPacks) do
        Config.Smokables[itemName] = { kind = 'cigarette', lighter = true, legacy = count }
    end
end
