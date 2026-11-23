fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-crafting'
version '3.3.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
    'client/stations.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/webhook.lua',
    'server/database.lua',
    'server/stations.lua',
    'server/server.lua',
    'server/commands.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'oxmysql',
    'rsg-target',
    'rsg-gizmo',
}
