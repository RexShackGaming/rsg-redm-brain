fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'RexShack'
description 'rsg-wagons - wagon store with full NUI catalogue, 3D preview and wagon ownership'
version '3.0.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/liveries.lua',
    'shared/propsets.lua',
    'shared/huntingcart.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/drag.js',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
    'oxmysql',
}
