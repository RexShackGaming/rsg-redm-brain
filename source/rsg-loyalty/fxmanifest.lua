fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'RexShack'
description 'Loyalty script for RSG Framework'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/discord.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/client.lua',
    'client/npcs.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'ox_target',
    'rsg-inventory',
    'oxmysql',
}

lua54 'yes'
