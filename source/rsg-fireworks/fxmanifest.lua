fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-fireworks'
author 'RexShack'
description 'Firework script for RSG Framework'
version '3.0.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/client.lua'
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-gizmo',
}

files {
  'locales/*.json'
}

lua54 'yes'
