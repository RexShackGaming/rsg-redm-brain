fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'RexShack'
name 'rsg-gangs'
description 'Gang System for RSG Framework'
version '3.0.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/main.lua',
    'server/commands.lua',
    'server/wagon.lua',
    'server/equipment.lua',
    'server/crafting.lua',
    'server/stash.lua',
    'server/features.lua',
    'server/versionchecker.lua',
}

client_scripts {
    'client/main.lua',
    'client/vehicle.lua',
    'client/equipment.lua',
    'client/crafting.lua',
    'client/features.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
    'rsg-gizmo',
    'oxmysql',
}

escrow_ignore {
    'installation/*',
    'locales/*',
    'shared/*',
    'html/*',
    'README.md',
    'DOCS.md',
}
