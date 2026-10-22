--[[
    rsg-loading : config.lua

    Seasonal themes. This file is read directly by the loading screen
    (html/script.js), so keep it to plain values: strings, numbers,
    booleans and tables. No functions or logic.

    Dates use the PLAYER'S local clock, format 'MM-DD'.
    A range may wrap the new year, e.g. start '12-01', finish '01-06'.
]]

Config = {}

-- Loading screen language. Must match a file in locales/ (en, de, el, es, fr, ja, nl, pl, pt-br, ro).
-- The loading screen runs before ox_lib, so it cannot read the ox:locale convar; set it here.
-- Server console messages use ox_lib's ox:locale convar as normal.
-- All text (title, subtitles, tips) lives in locales/<lang>.json:
--   ui_tip_1, ui_tip_2 ...                 normal tips (add more by adding numbered keys)
--   theme_<name>_subtitle                  subtitle for a holiday/season theme
--   theme_<name>_tip_1, _tip_2 ...         tips for a holiday/season theme
Config.Locale = 'en'

-- 'auto'      = pick the theme whose date window contains today
-- 'default'   = never use a seasonal theme
-- 'easter' / 'halloween' / 'christmas' / 'newyear' = force that holiday theme all year (handy for testing)
-- 'winter' / 'spring' / 'summer' / 'autumn' = force that season theme all year
Config.Theme = 'auto'

-- Particle effects (snow, bats, petals, leaves, fireflies, fireworks). Set false to disable on all themes.
Config.Particles = true

Config.Themes = {

    easter = {
        enabled  = true,
        -- Easter moves every year, so it is calculated automatically.
        -- The theme shows from X days before Easter Sunday until Y days after.
        easterDaysBefore = 7,
        easterDaysAfter  = 1,

        seal       = '✿',
        divider    = '❀',
        particles  = 'petals',
        background = 'images/easter.jpeg',   -- path inside html/ (or a URL). Blank = keep the normal background
        backgroundDim = 0.35,                -- 0 = full brightness, 1 = black
        colors = {
            accent   = '#f4c7e0',
            accent2  = '#c9e7b8',
            border   = '#8a6f86',
            panel    = '#1d1820',
            panel2   = '#2a2230',
            text     = '#fff8fc',
            muted    = '#c8b6c6',
        },
    },

    halloween = {
        enabled = true,
        start   = '10-15',
        finish  = '11-01',

        seal       = '☠',
        divider    = '✝',
        particles  = 'bats',
        background = 'images/halloween.jpeg',   -- path inside html/ (or a URL). Blank = keep the normal background
        backgroundDim = 0.35,                -- 0 = full brightness, 1 = black
        colors = {
            accent   = '#ff7a1a',
            accent2  = '#ffb347',
            border   = '#7a3d12',
            panel    = '#120a06',
            panel2   = '#1f120a',
            text     = '#fff1e6',
            muted    = '#c59a7c',
        },
    },

    christmas = {
        enabled = true,
        start   = '12-01',
        finish  = '12-30',

        seal       = '❄',
        divider    = '✦',
        particles  = 'snow',
        background = 'images/christmas.jpeg',   -- path inside html/ (or a URL). Blank = keep the normal background
        backgroundDim = 0.35,                -- 0 = full brightness, 1 = black
        colors = {
            accent   = '#e8f4ff',
            accent2  = '#c0392b',
            border   = '#5c7d6a',
            panel    = '#0b1410',
            panel2   = '#13241b',
            text     = '#ffffff',
            muted    = '#a9c4b5',
        },
    },

    newyear = {
        enabled = true,
        start   = '12-31',
        finish  = '01-02',

        seal       = '✷',
        divider    = '✧',
        particles  = 'fireworks',
        background = 'images/newyear.jpeg', -- path inside html/ (or a URL). Blank = keep the normal background
        backgroundDim = 0.45,                -- 0 = full brightness, 1 = black
        colors = {
            accent   = '#ffd86b',
            accent2  = '#ff5e8a',
            border   = '#6b5a2e',
            panel    = '#0a0b14',
            panel2   = '#141628',
            text     = '#fffaf0',
            muted    = '#bfb8a3',
        },
    },
}

-- When true, seasonal tips are added to your normal tips. When false they replace them.
Config.MergeTips = true

--[[
    Season themes. In 'auto' mode, when no holiday theme above is active,
    the season theme whose window contains today is used instead.
    Set Config.UseSeasons = false to fall back to your normal look.
    Windows default to UK meteorological seasons. Same options as the holiday themes.
]]
Config.UseSeasons = true

Config.Seasons = {

    winter = {
        enabled = true,
        start   = '12-01',
        finish  = '02-28',       -- wraps the new year (Feb 29 also counts)

        seal          = '❄',
        divider       = '✦',
        particles     = 'snow',
        background    = 'images/winter.jpeg',
        backgroundDim = 0.4,
        colors = {
            accent  = '#cfe3f5',
            accent2 = '#ffffff',
            border  = '#5d6f82',
            panel   = '#0d1218',
            panel2  = '#18212b',
            text    = '#f4f8fc',
            muted   = '#a3b4c4',
        },
    },

    spring = {
        enabled = true,
        start   = '03-01',
        finish  = '05-31',

        seal          = '❀',
        divider       = '✿',
        particles     = 'petals',
        background    = 'images/spring.jpeg',
        backgroundDim = 0.4,
        colors = {
            accent  = '#9ed67a',
            accent2 = '#ffe98a',
            border  = '#4f6e40',
            panel   = '#0e150c',
            panel2  = '#182414',
            text    = '#f6fff0',
            muted   = '#aec6a2',
        },
    },

    summer = {
        enabled = true,
        start   = '06-01',
        finish  = '08-31',

        seal          = '☀',
        divider       = '✦',
        particles     = 'fireflies',
        background    = 'images/summer.jpeg',
        backgroundDim = 0.4,
        colors = {
            accent  = '#ffb347',
            accent2 = '#ffe08a',
            border  = '#8a5a2e',
            panel   = '#160e07',
            panel2  = '#24170b',
            text    = '#fff6e8',
            muted   = '#cfae8a',
        },
    },

    autumn = {
        enabled = true,
        start   = '09-01',
        finish  = '11-30',

        seal          = '❦',
        divider       = '✦',
        particles     = 'leaves',
        background    = 'images/autumn.jpeg',
        backgroundDim = 0.4,
        colors = {
            accent  = '#e0782a',
            accent2 = '#f2c14e',
            border  = '#7a4a22',
            panel   = '#140c06',
            panel2  = '#22140a',
            text    = '#fff3e6',
            muted   = '#c9a585',
        },
    },
}
