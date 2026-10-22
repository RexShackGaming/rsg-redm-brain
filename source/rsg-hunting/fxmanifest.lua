fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-hunting'
author 'RexShack'
description 'Hunting, trapper and butcher script for RSG Framework'
version '2.0.2'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/client.lua',
    'client/vendor.lua',
    'client/main.js',
    'client/butcher.lua',
    'client/npcs.lua',
}

server_scripts {
    'server/server.lua',
    'server/vendor.lua',
    'server/butcher.lua',
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
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json',
    'stream/*.ymap'
}

this_is_a_map 'yes'

exports {
    'DataViewNativeGetEventData'
}

lua54 'yes'
