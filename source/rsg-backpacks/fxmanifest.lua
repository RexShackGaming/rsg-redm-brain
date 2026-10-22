fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'rsg-backpacks'
description 'RSG Backpacks: wearable backpacks with stashes and belt/back attachments (lanterns, lasso, machete, quiver)'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
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

-- ox_lib locales: locales/<lang>.json, language picked by the `ox:locale` convar (falls back to en)
ox_lib 'locale'

files {
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'ox_lib',
    'oxmysql',
}
