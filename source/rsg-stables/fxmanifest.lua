fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-stables'
description 'Horse and stables script for RSG Framework'
version '3.4.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/training.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/dataview.lua',
    'client/coat.lua',
    'client/client.lua',
    'client/horseinfo.lua',
    'client/wildhorse.lua',
    'client/training.lua',
    'client/fence.lua',
    'client/actions.lua',
    'client/spook.lua',
    'client/salvage.lua',
    'client/races.lua',
}

dependencies {
    'rsg-core',
    'rsg-target',
    'oxmysql',
    'rsg-inventory',
}

ui_page 'html/index.html'

files {
  'locales/*.json',
  'html/index.html',
  'html/style.css',
  'html/app.js',
  'html/training.js',
  'html/actions.js',
  'html/horsecard.js'
}

lua54 'yes'
