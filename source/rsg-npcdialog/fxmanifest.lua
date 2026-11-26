fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'rsg-npcdialog'
author 'RexShack'
description 'NPC dialog system for the RSG Framework'
version '3.1.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/npcs.lua',
    'shared/quests.lua',
}

client_scripts {
    'client/main.lua',
    'client/dialog.lua',
    'client/admin.lua',
    'client/quests.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/world.lua',
    'server/validate.lua',
    'server/database.lua',
    'server/engine.lua',
    'server/quests.lua',
    'server/main.lua',
    'server/admin.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/dialog.js',
    'html/admin.js',
    'html/preview.js',
    'html/quests.js',
}

-- rsg-skills, rsg-reputation and rsg-weather are optional (only needed by dialogs that use them)
dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
    'rsg-gizmo',
    'oxmysql',
}
