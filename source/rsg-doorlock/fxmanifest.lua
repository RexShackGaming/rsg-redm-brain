fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-doorlock'
version '3.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'shared/doorhashes.lua',
    'shared/doorhashes_custom.lua',
    'client/main.lua',
    'client/editor.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/webhooks.lua',
    'server/seed_doors.lua',
    'server/main.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'oxmysql'
}

lua54 'yes'
