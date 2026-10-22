fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'RexShack'
description 'Mobile Data Terminal for RSG Framework'
version '2.0.10'

ui_page 'web/dist/index.html'
files { 'web/dist/**/*', 'locales/*.json' }

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/locale.lua',
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
    'ox_lib',
    'oxmysql',
}
