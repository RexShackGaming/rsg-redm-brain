fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'rsg-lockpick'
author 'RexShack Gaming'
description 'Lockpicking minigame for RSG Core'
version '3.0.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'rsg-core',
    'rsg-inventory'
}
