fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-stables'
description 'Horse and stables script for RSG Framework'
version '3.1.5'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/dataview.lua',
    'client/coat.lua',
    'client/client.lua',
    'client/horseinfo.lua',
    'client/wildhorse.lua',
}

dependencies {
    'rsg-core',
    'ox_lib',
    'ox_target',
    'oxmysql',
    'rsg-inventory',
}

ui_page 'html/index.html'

files {
  'locales/*.json',
  'html/index.html',
  'html/style.css',
  'html/app.js'
}

lua54 'yes'
