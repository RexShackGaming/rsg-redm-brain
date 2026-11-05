fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-settings'
description 'Player settings presentation for Feather Framework'
author 'Feather Framework'
version '0.1.8'

shared_scripts {
    'config.lua',
    'locale/*.lua'
}

client_scripts {
    'client/providers.lua',
    'client/main.lua'
}

dependencies {
    'feather-core',
    'feather-menu-v2',
    'feather-pvp',
    'feather-character'
}
