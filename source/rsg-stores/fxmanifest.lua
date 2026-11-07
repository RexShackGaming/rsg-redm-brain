fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-stores'
version '3.1.2'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_webhooks_config.lua',
    'server/sv_webhooks.lua',
    'server/sv_database.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
    'rsg-gizmo',
    'oxmysql'
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/admin.js',
    'html/admin.css',
    'html/manage.js',
    'html/manage.css'
}

lua54 'yes'
