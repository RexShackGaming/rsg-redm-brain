fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-treasure'
description 'Treasure map hunting for RSG Framework'
version '3.1.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/sv_config.lua',
    'server/webhook.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files { 
    'locales/*.json',
    'html/index.html'
}

dependencies {
    'rsg-core',
    'rsg-inventory'
}

lua54 'yes'
