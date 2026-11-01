fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'RexShack'
description 'Real-time auction system for RSG Framework'
version '3.1.0'

ui_page 'web/dist/index.html'

files {
    'web/dist/**/*',
    'locales/*.json'
}

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/money.lua'
}

client_scripts {
    'client/main.lua',
    'client/npc.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/database.lua',
    'server/webhooks.lua',
    'server/main.lua',
    'server/versionchecker.lua'
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
    'oxmysql'
}
