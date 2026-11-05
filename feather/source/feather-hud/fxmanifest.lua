fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'feather-hud'
description 'The player HUD for the Feather Framework'
author 'Feather @Bytesizd'
version '0.3.2'
dependencies { 'feather-core', 'feather-economy' }

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/imports.lua',
    'client/services/*.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page {
    'ui/index.html'
}

files {
    'ui/index.html',
    'ui/assets/*.*'
}
