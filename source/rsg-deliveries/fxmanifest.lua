fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'RexShack'
name 'rsg-deliveries'
description 'Wagon delivery system RSG Framework'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/functions.lua',
}

client_scripts {
    'client/client.lua',
    'client/npcs.lua'
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'ox_target',
    'rsg-inventory',
}

ui_page 'html/index.html'

files {
  'locales/*.json',
  'html/index.html',
  'html/style.css',
  'html/script.js',
}

lua54 'yes'
