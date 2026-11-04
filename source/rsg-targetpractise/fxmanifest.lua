fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rsg-targetpractise'
author 'Mack'
description 'Placeable archery and throwing-knife practice targets for RSG Framework'
version '3.1.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/locale.lua',
    'shared/geometry.lua'
}

client_scripts {
    'client/diagnostics.lua',
    'client/projectiles.lua',
    'client/client.lua',
    'client/leaderboard.lua'
}

server_scripts {
    'server/leaderboard.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
    '/onesync'
}

lua54 'yes'
