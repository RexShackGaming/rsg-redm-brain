fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-weather'
description 'World time, weather, and climate synchronization for RedM'
author 'Feather Framework'
version '0.1.0'

shared_scripts {
    'config.lua',
    'shared/contract.lua'
}

server_scripts {
    'server/engine.lua',
    'server/main.lua'
}

client_scripts {
    'client/overrides.lua',
    'client/regions.lua',
    'client/native.lua',
    'client/main.lua'
}
