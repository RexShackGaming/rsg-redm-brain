fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'PHIL & RexShack'
name 'rsg-robbery'
description 'Player-to-player robbery system for RSG Framework'
version '3.0.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua'
}

files {
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target'
}
