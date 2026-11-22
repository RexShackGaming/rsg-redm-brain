fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'RexShack'
name 'rsg-society'
description 'Societies for the RSG Framework: members, ranks, permissions, finances, payroll, storage, fines, audit trail and an API. Replaces rsg-bossmenu and rsg-gangmenu and owns gang membership.'
version '3.4.0'

-- Old resources that this one answers for, so scripts that still call
-- exports['rsg-bossmenu'] / exports['rsg-gangmenu'] keep working.
-- Stop rsg-bossmenu and rsg-gangmenu before starting rsg-society.
provide 'rsg-bossmenu'
provide 'rsg-gangmenu'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/members.lua',
    'server/finance.lua',
    'server/callbacks.lua',
    'server/migration.lua',
    'server/admin.lua',
    'server/commands.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/admin.css',
    'html/admin.js',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'oxmysql',
}
