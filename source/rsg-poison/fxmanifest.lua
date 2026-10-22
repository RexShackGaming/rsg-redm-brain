fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-poison'
description 'Poison script for RSG Framework'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

server_scripts {
    'server/webhook_config.lua',
    'server/webhooks.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

ui_page 'html/ui.html'

files {
    'html/ui.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json'
}

client_scripts {
    'client/dataview.lua',
    'client/client.lua'
}

lua54 'yes'

dependencies {
    'rsg-core',
    'rsg-inventory',
    'ox_lib',
    '/assetpacks',
}
