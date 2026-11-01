fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-barbers'
version '3.0.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'config.lua',
    'shared/hairs.lua',
    'shared/functions.lua',
}

client_scripts {
    'shared/overlays.lua',
    'client/npcs.lua',
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'rsg-character',
    'rsg-target',
    'oxmysql',
}
