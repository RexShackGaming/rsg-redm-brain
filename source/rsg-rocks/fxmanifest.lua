fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-rocks'
author 'RexShack'
description 'Mining system for RSG Framework'
version '3.0.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/nui.lua',
    'client/client.lua',
    'client/mininghat.lua',
    'client/workshop.lua',
    'client/drillmenu.lua',
    'client/hatlight.lua',
    'client/npcs.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/hatlight.js',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
    'rsg-gizmo',
    'oxmysql',
}

lua54 'yes'

escrow_ignore {
    'locales/*',
    'shared/config.lua',
    'install.sql',
    'README.md',
    'DOCS.md',
}
