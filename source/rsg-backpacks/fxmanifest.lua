fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'rsg-backpacks'
description 'RSG Backpacks: wearable backpacks with stashes and belt/back attachments (lanterns, lasso, machete, quiver)'
version '3.0.4'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/belt.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/database.lua',
    'server/main.lua',
    'server/versionchecker.lua',
}

-- rsg-core locales: locales/<lang>.json, language from `setr rsg:locale` (falls back to ox:locale, then en)

files {
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'oxmysql',
}
