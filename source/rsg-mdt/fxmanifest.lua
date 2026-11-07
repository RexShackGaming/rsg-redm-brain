fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'RexShack'
description 'Mobile Data Terminal for RSG Framework'
version '3.0.0'

ui_page 'web/dist/index.html'
files { 'web/dist/**/*', 'locales/*.json' }

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/callbacks.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

dependencies {
    'rsg-core',
    'rsg-target',
    'oxmysql',
}

