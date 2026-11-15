fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-townhall - Town Hall job vacancies, applications and approvals'
version '3.1.1'

ui_page 'html/index.html'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/server.lua',
    'server/versionchecker.lua',
}

client_scripts {
    'client/client.lua',
}

dependencies {
    'rsg-core',
    'rsg-target',
    'oxmysql',
}

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
