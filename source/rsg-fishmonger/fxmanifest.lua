fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-fishmonger'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    'server/sv_config.lua',
    'server/webhook.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/client.lua'
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
    'ox_lib',
    'ox_target',
}

lua54 'yes'
