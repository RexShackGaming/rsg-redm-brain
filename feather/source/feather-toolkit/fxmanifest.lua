fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-toolkit'
description 'Owned, reusable client utility contracts for Feather Framework'
author 'Feather Framework'
version '0.3.0'

shared_scripts {
    'config.lua',
    'shared/results.lua'
}

client_scripts {
    'client/services/*.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/app.js',
    'ui/style.css'
}
