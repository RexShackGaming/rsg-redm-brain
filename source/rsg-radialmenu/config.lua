lib.locale()

Config = {}

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
Config.Keybind            = 'F6'
Config.HoldToOpen         = true  -- true: hold key, release to close | false: tap to open
Config.EmergencyCooldown  = 60    -- seconds between emergency button presses
Config.WalkstyleCooldown  = 2     -- seconds between walkstyle changes (server enforced)

Config.LawJobs   = { vallaw = true, rholaw = true, blklaw = true, strlaw = true, stdenlaw = true }
Config.MedicJobs = { medic = true }

-- key = { clipset, motion type }  (server only accepts keys listed here)
Config.Walkstyles = {
    normal      = { 'default',     'normal' },
    angry       = { 'default',     'angry'  },
    war_veteran = { 'war_veteran', 'normal' },
    gold_panner = { 'gold_panner', 'normal' },
    lost_man    = { 'lost_Man',    'normal' },
    murfree     = { 'murfree',     'normal' },
    primate     = { 'primate',     'normal' },
}

---------------------------------------------------------------------
-- Builders (keep the menu tables below short)
---------------------------------------------------------------------
local function cmd(id, title, icon, command)
    return { id = id, title = title, icon = icon, type = 'command', event = command, shouldClose = true }
end

local function cl(id, title, icon, event)
    return { id = id, title = title, icon = icon, type = 'client', event = event, shouldClose = true }
end

local function walk(key, title)
    local item = cl('walk_' .. key, title, 'person-walking', 'rsg-radialmenu:client:setWalkstyle')
    item.walkstyle = key
    return item
end

---------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------
Config.MenuItems = {
    {
        id = 'horse', title = locale('menu_horse'), icon = 'horse-head',
        items = {
            cl('horselantern', locale('menu_horse_lantern'), 'lightbulb', 'rsg-horses:client:equipHorseLantern'),
            cmd('sethorsename', locale('menu_horse_name'), 'signature', 'sethorsename'),
        },
    },
    {
        id = 'user', title = locale('menu_user'), icon = 'user',
        items = {
            {
                id = 'walkstyles', title = locale('menu_walkstyles'), icon = 'person-walking',
                items = {
                    walk('normal',      locale('walk_normal')),
                    walk('angry',       locale('walk_angry')),
                    walk('war_veteran', locale('walk_veteran')),
                    walk('gold_panner', locale('walk_gold_panner')),
                    walk('lost_man',    locale('walk_lost')),
                    walk('murfree',     locale('walk_murfree')),
                    walk('primate',     locale('walk_primate')),
                },
            },
            cmd('jobs',         locale('menu_jobs'),         'circle-user',       'myjobs'),
            cl('pvptoggle',     locale('menu_pvp'),          'hand-holding-hand', 'rsg-essentials:client:pvpToggle'),
            cl('addressbook',   locale('menu_addressbook'),  'address-book',      'rsg-telegram:client:OpenAddressbook'),
            cmd('searchplayer', locale('menu_searchplayer'), 'magnifying-glass',  'searchplayer'),
        },
    },
    {
        id = 'clothing', title = locale('menu_clothing'), icon = 'shirt',
        items = {
            cmd('dress',           locale('cloth_dress'),       'person-dress',      'dress'),
            cmd('undress',         locale('cloth_undress'),     'person-half-dress', 'undress'),
            cmd('onoffhat',        locale('cloth_hat'),         'hat-cowboy',        'hat'),
            cmd('onoffvest',       locale('cloth_vest'),        'vest',              'vest'),
            cmd('onoffboots',      locale('cloth_boots'),       'shoe-prints',       'boots'),
            cmd('onoffpants',      locale('cloth_pants'),       'socks',             'pants'),
            cmd('onoffshirt',      locale('cloth_shirt'),       'shirt',             'shirt'),
            cmd('onoffgunbelt',    locale('cloth_gunbelt'),     'gun',               'gunbelt'),
            cmd('onoffmask',       locale('cloth_mask'),        'masks-theater',     'mask'),
            cmd('onoffcoat',       locale('cloth_coat'),        'vest-patches',      'coat'),
            cmd('onoffclosedcoat', locale('cloth_closed_coat'), 'vest-patches',      'closedcoat'),
        },
    },
    cmd('loadskin',   locale('menu_fix_character'), 'recycle', 'loadskin'),
    cmd('playerinfo', locale('menu_your_info'),     'book',    'info'),
}

---------------------------------------------------------------------
-- Job interactions
---------------------------------------------------------------------
local LawItems = {
    cl('policebutton', locale('job_emergency'), 'exclamation', 'rsg-radialmenu:client:SendLawmanEmergencyAlert'),
    cl('handcuff',     locale('law_cuff'),      'user-lock',   'rsg-lawman:client:cuffplayer'),
    cl('escort',       locale('law_escort'),    'user-group',  'rsg-lawman:client:escortplayer'),
    cl('jailplayer',   locale('law_jail'),      'user-lock',   'rsg-lawman:client:jailplayer'),
    cmd('lawbadge',    locale('law_badge'),     'id-badge',    'lawbadge'),
    cmd('lawmdt',      locale('law_mdt'),       'book-open',   'mdt'),
}

Config.JobInteractions = {
    medic = {
        cl('medicbutton', locale('job_emergency'),     'exclamation', 'rsg-radialmenu:client:SendMedicEmergencyAlert'),
        cl('revivep',     locale('medic_revive'),      'user-doctor', 'rsg-medic:client:RevivePlayer'),
        cl('treatwounds', locale('medic_treat'),       'bandage',     'rsg-medic:client:TreatWounds'),
    },
}

for job in pairs(Config.LawJobs) do
    Config.JobInteractions[job] = LawItems
end
