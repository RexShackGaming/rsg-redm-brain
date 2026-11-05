fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'Feather Framework'
description 'A focused, reactive menu system for Feather Framework and standalone RedM resources'
version '2.0.0-alpha.9'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/assets/*'
}

client_scripts {
    'client/results.lua',
    'client/validation.lua',
    'client/main.lua'
}
