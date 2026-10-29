fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-hunting'
author 'RexShack'
description 'Hunting, trapper and butcher script for RSG Framework'
version '3.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/client.lua',
    'client/vendor.lua',
    'client/leaderboard.lua',
    'client/main.js',
    'client/butcher.lua',
    'client/npcs.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/webhooks.lua',
    'server/xp.lua',
    'server/server.lua',
    'server/vendor.lua',
    'server/butcher.lua',
    'server/versionchecker.lua'
}

dependencies {
    'oxmysql',
    'rsg-core',
    'ox_lib',
    'ox_target',
    'rsg-inventory',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/board.css',
    'html/board.js',
    'locales/*.json',
    'stream/*.ymap'
}

this_is_a_map 'yes'

exports {
    'DataViewNativeGetEventData'
}

lua54 'yes'
